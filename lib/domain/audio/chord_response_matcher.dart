import 'dart:math' as math;

import '../models/exercise_protocol.dart';
import '../models/measurement_provenance.dart';
import 'pitch_deviation.dart';
import 'pitch_segmenter.dart';
import 'pitch_sequence_alignment.dart';
import 'reviewed_chord_recording_manifest.dart';

enum ChordResponseStatus { invalidEvidence, noResponse, candidatesCompared }

class ChordSetComparison {
  const ChordSetComparison._({
    required this.correctCount,
    required this.wrongOctaveCount,
    required this.missingTargetCount,
    required this.extraCandidateCount,
  });

  final int correctCount;
  final int wrongOctaveCount;
  final int missingTargetCount;
  final int extraCandidateCount;

  bool get allAbsoluteTargetsMatched =>
      wrongOctaveCount == 0 &&
      missingTargetCount == 0 &&
      extraCandidateCount == 0;
}

/// Diagnostic comparison of sequential monophonic candidates against one
/// reviewed 2/3/4-note piano target. This is not a score, VAD decision, memory
/// measurement or proof that the candidates were sung by a learner.
class ChordResponseEvidence {
  const ChordResponseEvidence._({
    required this.recordingId,
    required this.voiceCount,
    required this.responseOrder,
    required this.status,
    required this.source,
    required this.analyzerVersion,
    required this.discardedFrameCount,
    required this.nonPitchedFrameCount,
    required this.reorderedTargetCandidates,
    this.setComparison,
    this.alignment,
  });

  static const version = 'chord-response-diagnostic-2';

  final String recordingId;
  final int voiceCount;
  final ResponseOrder responseOrder;
  final ChordResponseStatus status;
  final MeasurementSource source;
  final String analyzerVersion;
  final int discardedFrameCount;
  final int nonPitchedFrameCount;
  final bool reorderedTargetCandidates;
  final ChordSetComparison? setComparison;
  final PitchSequenceEvidence? alignment;

  /// Candidate-only exact-order match. Null means there was no valid response
  /// comparison; true must not be persisted as mastery or an exam result.
  bool? get diagnosticCandidateMatch =>
      status == ChordResponseStatus.candidatesCompared
      ? responseOrder == ResponseOrder.exact
            ? alignment!.wholeSequenceCorrect
            : setComparison!.allAbsoluteTargetsMatched
      : null;
}

/// CONS-02a adapter: reviewed MIDI labels → exact-order symbolic comparison.
/// Segment timing is intentionally replaced with nominal ordering, so this
/// cannot manufacture timing, rhythm, recall or acoustic-onset evidence.
class ChordResponseMatcher {
  const ChordResponseMatcher._();

  static ChordResponseEvidence compare({
    required ReviewedChordRecording recording,
    required PitchSegmentationEvidence segmentation,
    ResponseOrder responseOrder = ResponseOrder.exact,
    double toleranceCents = PitchSequenceAligner.defaultToleranceCents,
  }) {
    ChordResponseEvidence report({
      required ChordResponseStatus status,
      PitchSequenceEvidence? alignment,
      ChordSetComparison? setComparison,
      bool reordered = false,
    }) => ChordResponseEvidence._(
      recordingId: recording.id,
      voiceCount: recording.voiceCount,
      responseOrder: responseOrder,
      status: status,
      source: segmentation.provenance.source,
      analyzerVersion:
          '${segmentation.provenance.analyzerVersion}/${ChordResponseEvidence.version}',
      discardedFrameCount: segmentation.discardedFrameIndices.length,
      nonPitchedFrameCount: segmentation.nonPitchedFrameIndices.length,
      reorderedTargetCandidates: reordered,
      setComparison: setComparison,
      alignment: alignment,
    );

    if (!toleranceCents.isFinite ||
        toleranceCents < 0 ||
        toleranceCents > 100) {
      throw ArgumentError('Invalid chord response tolerance');
    }
    if (segmentation.status == PitchSegmentationStatus.invalidInput) {
      return report(status: ChordResponseStatus.invalidEvidence);
    }

    final targets = [
      for (final midi in recording.targetMidiNotes)
        recording.a4Hz * math.pow(2, (midi - 69) / 12).toDouble(),
    ];
    final candidates = [
      for (final segment in segmentation.segments) segment.frequencyHz,
    ];
    final alignment = PitchSequenceAligner.align(
      reference: _nominalEvents(targets),
      response: _nominalEvents(candidates),
      source: segmentation.provenance.source,
      toleranceCents: toleranceCents,
    );
    final setComparison = _compareSet(targets, candidates, toleranceCents);
    if (segmentation.status == PitchSegmentationStatus.noCandidates) {
      return report(
        status: ChordResponseStatus.noResponse,
        alignment: alignment,
        setComparison: setComparison,
      );
    }
    return report(
      status: ChordResponseStatus.candidatesCompared,
      alignment: alignment,
      setComparison: setComparison,
      reordered:
          alignment.wholeSequenceCorrect == false &&
          setComparison.allAbsoluteTargetsMatched,
    );
  }
}

List<SequencePitchEvent> _nominalEvents(List<double> frequenciesHz) => [
  for (var i = 0; i < frequenciesHz.length; i++)
    SequencePitchEvent(
      frequencyHz: frequenciesHz[i],
      onsetMs: i * 800,
      durationMs: 600,
    ),
];

class _SetState {
  const _SetState(this.correct, this.wrongOctave);

  final int correct;
  final int wrongOctave;

  bool betterThan(_SetState other) =>
      correct > other.correct ||
      (correct == other.correct && wrongOctave > other.wrongOctave);
}

ChordSetComparison _compareSet(
  List<double> targets,
  List<double> candidates,
  double toleranceCents,
) {
  final states = List<_SetState?>.filled(1 << targets.length, null);
  states[0] = const _SetState(0, 0);
  for (final candidate in candidates) {
    final next = List<_SetState?>.from(states);
    for (var mask = 0; mask < states.length; mask++) {
      final state = states[mask];
      if (state == null) continue;
      for (var targetIndex = 0; targetIndex < targets.length; targetIndex++) {
        final bit = 1 << targetIndex;
        if (mask & bit != 0) continue;
        final deviation = PitchDeviation(
          detectedHz: candidate,
          targetHz: targets[targetIndex],
        );
        final isCorrect = deviation.absoluteCents.abs() <= toleranceCents;
        final isWrongOctave =
            !isCorrect &&
            deviation.octaveOffset != 0 &&
            deviation.pitchClassCents.abs() <= toleranceCents;
        if (!isCorrect && !isWrongOctave) continue;
        final candidateState = _SetState(
          state.correct + (isCorrect ? 1 : 0),
          state.wrongOctave + (isWrongOctave ? 1 : 0),
        );
        final destination = mask | bit;
        final previous = next[destination];
        if (previous == null || candidateState.betterThan(previous)) {
          next[destination] = candidateState;
        }
      }
    }
    for (var i = 0; i < states.length; i++) {
      states[i] = next[i];
    }
  }

  var best = const _SetState(0, 0);
  for (final state in states) {
    if (state != null && state.betterThan(best)) best = state;
  }
  final matched = best.correct + best.wrongOctave;
  return ChordSetComparison._(
    correctCount: best.correct,
    wrongOctaveCount: best.wrongOctave,
    missingTargetCount: targets.length - matched,
    extraCandidateCount: candidates.length - matched,
  );
}
