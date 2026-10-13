import '../models/measurement_provenance.dart';
import 'pitch_deviation.dart';

/// Already segmented monophonic events. This is NOT microphone segmentation.
class SequencePitchEvent {
  const SequencePitchEvent({
    required this.frequencyHz,
    required this.onsetMs,
    required this.durationMs,
  });
  final double frequencyHz;
  final int onsetMs, durationMs;
}

enum PitchSequenceStatus { aligned, noResponse, invalidResponse }

enum PitchSequenceStepKind { correct, wrongPitch, wrongOctave, missing, extra }

class PitchSequenceStep {
  const PitchSequenceStep({
    required this.kind,
    this.referenceIndex,
    this.responseIndex,
    this.absoluteCents,
    this.octaveOffset,
  });
  final PitchSequenceStepKind kind;
  final int? referenceIndex, responseIndex;
  final double? absoluteCents;
  final int? octaveOffset;
}

/// Symbolic alignment evidence only: no timing, VAD or memory/overall score.
class PitchSequenceEvidence {
  PitchSequenceEvidence._({
    required this.status,
    required this.source,
    required this.toleranceCents,
    required List<PitchSequenceStep> steps,
  }) : steps = List.unmodifiable(steps);
  static const version = 'pitch-sequence-exact-1';
  final PitchSequenceStatus status;
  final MeasurementSource source;
  final double toleranceCents;
  final List<PitchSequenceStep> steps;
  bool? get wholeSequenceCorrect => status == PitchSequenceStatus.aligned
      ? steps.every((step) => step.kind == PitchSequenceStepKind.correct)
      : null;
  int count(PitchSequenceStepKind kind) =>
      steps.where((step) => step.kind == kind).length;
}

class _Cell {
  const _Cell(this.edits, this.correct, this.distance, this.kind);
  final int edits, correct;
  final double distance;
  final PitchSequenceStepKind kind;
  bool betterThan(_Cell other) =>
      edits < other.edits ||
      (edits == other.edits &&
          (correct > other.correct ||
              (correct == other.correct && distance < other.distance)));
}

/// CORE-03a bounded exact-order alignment. One response cannot satisfy two
/// references. Raw octave is never folded into a correct match. No time shift,
/// tempo fitting, reference sorting or any-order mode is performed here.
class PitchSequenceAligner {
  const PitchSequenceAligner._();
  static const maxEvents = 64;
  static const maxTimelineMs = 60000;
  static const defaultToleranceCents = 50.0;

  static PitchSequenceEvidence align({
    required List<SequencePitchEvent> reference,
    required List<SequencePitchEvent> response,
    required MeasurementSource source,
    double toleranceCents = defaultToleranceCents,
  }) {
    if (!toleranceCents.isFinite ||
        toleranceCents < 0 ||
        toleranceCents > 100 ||
        reference.isEmpty ||
        reference.length > maxEvents ||
        !_valid(reference)) {
      throw ArgumentError('Invalid sequence reference, budget or tolerance');
    }
    PitchSequenceEvidence report(
      PitchSequenceStatus status,
      List<PitchSequenceStep> steps,
    ) => PitchSequenceEvidence._(
      status: status,
      source: source,
      toleranceCents: toleranceCents,
      steps: steps,
    );
    if (response.length > maxEvents || !_valid(response)) {
      return report(PitchSequenceStatus.invalidResponse, const []);
    }
    if (response.isEmpty) {
      return report(PitchSequenceStatus.noResponse, [
        for (var i = 0; i < reference.length; i++)
          PitchSequenceStep(
            kind: PitchSequenceStepKind.missing,
            referenceIndex: i,
          ),
      ]);
    }
    final n = reference.length, m = response.length;
    final cells = List.generate(
      n + 1,
      (_) => List.filled(
        m + 1,
        const _Cell(0, 0, 0, PitchSequenceStepKind.missing),
      ),
    );
    for (var i = 1; i <= n; i++) {
      cells[i][0] = _Cell(i, 0, 0, PitchSequenceStepKind.missing);
    }
    for (var j = 1; j <= m; j++) {
      cells[0][j] = _Cell(j, 0, 0, PitchSequenceStepKind.extra);
    }
    PitchDeviation deviation(int i, int j) => PitchDeviation(
      detectedHz: response[j].frequencyHz,
      targetHz: reference[i].frequencyHz,
    );
    PitchSequenceStepKind classify(PitchDeviation delta) =>
        delta.absoluteCents.abs() <= toleranceCents
        ? PitchSequenceStepKind.correct
        : delta.octaveOffset != 0 &&
              delta.pitchClassCents.abs() <= toleranceCents
        ? PitchSequenceStepKind.wrongOctave
        : PitchSequenceStepKind.wrongPitch;
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final delta = deviation(i - 1, j - 1), kind = classify(delta);
        final previous = cells[i - 1][j - 1];
        var best = _Cell(
          previous.edits + (kind == PitchSequenceStepKind.correct ? 0 : 1),
          previous.correct + (kind == PitchSequenceStepKind.correct ? 1 : 0),
          previous.distance + delta.absoluteCents.abs(),
          kind,
        );
        final miss = cells[i - 1][j];
        final missing = _Cell(
          miss.edits + 1,
          miss.correct,
          miss.distance,
          PitchSequenceStepKind.missing,
        );
        if (missing.betterThan(best)) best = missing;
        final skip = cells[i][j - 1];
        final extra = _Cell(
          skip.edits + 1,
          skip.correct,
          skip.distance,
          PitchSequenceStepKind.extra,
        );
        if (extra.betterThan(best)) best = extra;
        cells[i][j] = best;
      }
    }
    var i = n, j = m;
    final steps = <PitchSequenceStep>[];
    while (i > 0 || j > 0) {
      final kind = i == 0
          ? PitchSequenceStepKind.extra
          : j == 0
          ? PitchSequenceStepKind.missing
          : cells[i][j].kind;
      if (kind == PitchSequenceStepKind.missing) {
        steps.add(PitchSequenceStep(kind: kind, referenceIndex: --i));
      } else if (kind == PitchSequenceStepKind.extra) {
        steps.add(PitchSequenceStep(kind: kind, responseIndex: --j));
      } else {
        final delta = deviation(i - 1, j - 1);
        steps.add(
          PitchSequenceStep(
            kind: kind,
            referenceIndex: --i,
            responseIndex: --j,
            absoluteCents: delta.absoluteCents,
            octaveOffset: delta.octaveOffset,
          ),
        );
      }
    }
    return report(PitchSequenceStatus.aligned, steps.reversed.toList());
  }
}

bool _valid(List<SequencePitchEvent> events) {
  var previousEnd = 0;
  for (final event in events) {
    if (!event.frequencyHz.isFinite ||
        event.frequencyHz <= 0 ||
        event.onsetMs < previousEnd ||
        event.durationMs <= 0 ||
        event.onsetMs > PitchSequenceAligner.maxTimelineMs ||
        event.durationMs > PitchSequenceAligner.maxTimelineMs - event.onsetMs) {
      return false;
    }
    previousEnd = event.onsetMs + event.durationMs;
  }
  return true;
}
