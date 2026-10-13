import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_sequence_alignment.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';

List<SequencePitchEvent> notes(List<double> hz) => [
  for (var i = 0; i < hz.length; i++)
    SequencePitchEvent(frequencyHz: hz[i], onsetMs: i * 500, durationMs: 300),
];
PitchSequenceEvidence align(List<double> target, List<double> actual) =>
    PitchSequenceAligner.align(
      reference: notes(target),
      response: notes(actual),
      source: MeasurementSource.synthetic,
    );
void main() {
  test('correct sequence preserves all indices and explicit source', () {
    final r = align([261.63, 329.63, 392], [261.63, 329.63, 392]);
    expect(r.wholeSequenceCorrect, isTrue);
    expect(r.source, MeasurementSource.synthetic);
    expect(r.steps.map((s) => s.referenceIndex), [0, 1, 2]);
    expect(r.steps.map((s) => s.responseIndex), [0, 1, 2]);
  });
  test('same count and reverse order is not success', () {
    final r = align([261.63, 329.63, 392], [392, 329.63, 261.63]);
    expect(r.wholeSequenceCorrect, isFalse);
    expect(r.count(PitchSequenceStepKind.correct), lessThan(3));
  });
  test('middle missing note retains later correct match', () {
    final r = align([261.63, 329.63, 392], [261.63, 392]);
    expect(r.count(PitchSequenceStepKind.missing), 1);
    expect(r.count(PitchSequenceStepKind.correct), 2);
    expect(r.wholeSequenceCorrect, isFalse);
  });
  test('extra note cannot disappear from evidence', () {
    final r = align([261.63, 392], [261.63, 329.63, 392]);
    expect(r.count(PitchSequenceStepKind.extra), 1);
    expect(r.count(PitchSequenceStepKind.correct), 2);
    expect(r.wholeSequenceCorrect, isFalse);
  });
  test('duplicate note is extra, never another correct trial', () {
    final r = align([440, 660], [440, 440, 660]);
    expect(r.count(PitchSequenceStepKind.extra), 1);
    expect(r.count(PitchSequenceStepKind.correct), 2);
  });
  test('repeated reference needs distinct response events', () {
    final r = align([440, 440], [440]);
    expect(r.count(PitchSequenceStepKind.correct), 1);
    expect(r.count(PitchSequenceStepKind.missing), 1);
  });
  test('octaves above and below are explicit errors', () {
    for (final hz in [220.0, 880.0]) {
      final r = align([440], [hz]);
      expect(r.steps.single.kind, PitchSequenceStepKind.wrongOctave);
      expect(r.steps.single.absoluteCents!.abs(), closeTo(1200, 0.001));
      expect(r.steps.single.octaveOffset!.abs(), 1);
      expect(r.wholeSequenceCorrect, isFalse);
    }
  });
  test('pitch substitution is not a missing or correct note', () {
    expect(
      align([440], [466.16]).steps.single.kind,
      PitchSequenceStepKind.wrongPitch,
    );
  });
  test('empty response unmeasured, not a measured wrong sequence', () {
    final r = align([440, 660], []);
    expect(r.status, PitchSequenceStatus.noResponse);
    expect(r.wholeSequenceCorrect, isNull);
    expect(r.count(PitchSequenceStepKind.missing), 2);
  });
  test('invalid late pitch rejects whole response', () {
    for (final value in [double.nan, double.infinity, 0.0, -1.0]) {
      final r = align([440, 660], [440, value]);
      expect(r.status, PitchSequenceStatus.invalidResponse);
      expect(r.wholeSequenceCorrect, isNull);
      expect(r.steps, isEmpty);
    }
  });
  test('overlap, negative onset and invalid duration are not aligned', () {
    for (final bad in [
      const SequencePitchEvent(frequencyHz: 440, onsetMs: -1, durationMs: 10),
      const SequencePitchEvent(frequencyHz: 440, onsetMs: 0, durationMs: 0),
      const SequencePitchEvent(frequencyHz: 440, onsetMs: 59999, durationMs: 2),
    ]) {
      expect(
        PitchSequenceAligner.align(
          reference: notes([440]),
          response: [bad],
          source: MeasurementSource.mock,
        ).status,
        PitchSequenceStatus.invalidResponse,
      );
    }
    expect(
      PitchSequenceAligner.align(
        reference: notes([440]),
        response: [
          notes([440]).first,
          const SequencePitchEvent(
            frequencyHz: 660,
            onsetMs: 100,
            durationMs: 300,
          ),
        ],
        source: MeasurementSource.mock,
      ).status,
      PitchSequenceStatus.invalidResponse,
    );
  });
  test(
    'invalid reference and tolerance throw, oversized response abstains',
    () {
      expect(() => align([], [440]), throwsArgumentError);
      expect(() => align([double.nan], [440]), throwsArgumentError);
      expect(
        () => PitchSequenceAligner.align(
          reference: notes([440]),
          response: notes([440]),
          source: MeasurementSource.mock,
          toleranceCents: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        align([440], List.filled(65, 440.0)).status,
        PitchSequenceStatus.invalidResponse,
      );
      expect(
        align(
          List.filled(64, 440.0),
          List.filled(64, 440.0),
        ).wholeSequenceCorrect,
        isTrue,
      );
    },
  );
  test('raw frequency tolerance is not octave folding', () {
    expect(
      align(
        [440],
        [440 * math.pow(2, 49 / 1200).toDouble()],
      ).wholeSequenceCorrect,
      isTrue,
    );
    expect(
      align(
        [440],
        [440 * math.pow(2, 51 / 1200).toDouble()],
      ).wholeSequenceCorrect,
      isFalse,
    );
  });
  test(
    'result immutable and deterministic; timestamps do not imply timing score',
    () {
      final r = align([440, 660], [440, 660]);
      expect(() => r.steps.clear(), throwsUnsupportedError);
      final delayed = notes([440, 660])
          .map(
            (n) => SequencePitchEvent(
              frequencyHz: n.frequencyHz,
              onsetMs: n.onsetMs + 10000,
              durationMs: 100,
            ),
          )
          .toList();
      final other = PitchSequenceAligner.align(
        reference: notes([440, 660]),
        response: delayed,
        source: MeasurementSource.synthetic,
      );
      expect(other.wholeSequenceCorrect, isTrue);
      expect(other.steps.map((s) => s.kind), r.steps.map((s) => s.kind));
    },
  );
}
