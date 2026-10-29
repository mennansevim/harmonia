import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/chord_response_matcher.dart';
import 'package:harmonia/domain/audio/pitch_segmenter.dart';
import 'package:harmonia/domain/audio/pitch_sequence_alignment.dart';
import 'package:harmonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:harmonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:harmonia/domain/models/exercise_protocol.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';

const _rate = 8000;
const _provenance = MeasurementProvenance(
  source: MeasurementSource.synthetic,
  analyzerVersion: 'controlled-segments',
);

ReviewedChordRecording _recording({
  List<int> notes = const [60, 64, 67],
  double a4Hz = 440,
}) => ReviewedChordRecording(
  id: 'reviewed-target',
  voiceCount: notes.length,
  relativePath: '${notes.length}-notes/reviewed-target.wav',
  targetMidiNotes: notes,
  sha256: 'a' * 64,
  sampleRateHz: 48000,
  channels: 1,
  sampleFrames: 96000,
  a4Hz: a4Hz,
  rightsReference: 'rights/user-recorded',
  labelReviewReference: 'reviews/reviewed-target',
);

double _hz(int midi, [double a4Hz = 440]) =>
    a4Hz * math.pow(2, (midi - 69) / 12).toDouble();

PitchSegmentationEvidence _segments(
  List<double> frequencies, {
  bool addShortDiscardedRun = false,
}) {
  final frames = <SegmentationPitchFrame>[];
  var start = 0;
  for (var noteIndex = 0; noteIndex < frequencies.length; noteIndex++) {
    final frequency = frequencies[noteIndex];
    for (var i = 0; i < 6; i++) {
      frames.add(
        SegmentationPitchFrame(
          startSample: start,
          sampleCount: 800,
          status: PitchFrameStatus.pitched,
          frequencyHz: frequency,
        ),
      );
      start += 400;
    }
    if (noteIndex + 1 < frequencies.length) {
      frames.add(
        SegmentationPitchFrame(
          startSample: start,
          sampleCount: 800,
          status: PitchFrameStatus.silence,
        ),
      );
      start += 400;
    }
  }
  if (addShortDiscardedRun) {
    for (var i = 0; i < 2; i++) {
      frames.add(
        SegmentationPitchFrame(
          startSample: start,
          sampleCount: 800,
          status: PitchFrameStatus.pitched,
          frequencyHz: 1000,
        ),
      );
      start += 400;
    }
  }
  return PitchSegmenter.segment(
    frames: frames,
    sampleRateHz: _rate,
    sampleCount: start + 800,
    provenance: _provenance,
  );
}

PitchSegmentationEvidence _emptySegments() => PitchSegmenter.segment(
  frames: const [],
  sampleRateHz: _rate,
  sampleCount: _rate,
  provenance: _provenance,
);

void main() {
  test('2, 3 and 4 exact candidates preserve reviewed target order', () {
    for (final notes in [
      [60, 67],
      [60, 64, 67],
      [60, 64, 67, 71],
    ]) {
      final result = ChordResponseMatcher.compare(
        recording: _recording(notes: notes),
        segmentation: _segments([for (final note in notes) _hz(note)]),
      );
      expect(result.status, ChordResponseStatus.candidatesCompared);
      expect(result.voiceCount, notes.length);
      expect(result.responseOrder, ResponseOrder.exact);
      expect(result.diagnosticCandidateMatch, isTrue);
      expect(result.reorderedTargetCandidates, isFalse);
      expect(
        result.alignment!.count(PitchSequenceStepKind.correct),
        notes.length,
      );
    }
  });

  test('same absolute targets in reverse are disclosed as reordered', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _segments([_hz(67), _hz(64), _hz(60)]),
    );
    expect(result.diagnosticCandidateMatch, isFalse);
    expect(result.reorderedTargetCandidates, isTrue);
  });

  test('missing target remains missing and is not called reordering', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _segments([_hz(60), _hz(67)]),
    );
    expect(result.alignment!.count(PitchSequenceStepKind.missing), 1);
    expect(result.diagnosticCandidateMatch, isFalse);
    expect(result.reorderedTargetCandidates, isFalse);
  });

  test('extra and duplicate candidates remain visible', () {
    for (final response in [
      [_hz(60), _hz(64), _hz(65), _hz(67)],
      [_hz(60), _hz(64), _hz(64), _hz(67)],
    ]) {
      final result = ChordResponseMatcher.compare(
        recording: _recording(),
        segmentation: _segments(response),
      );
      expect(result.alignment!.count(PitchSequenceStepKind.extra), 1);
      expect(result.diagnosticCandidateMatch, isFalse);
      expect(result.reorderedTargetCandidates, isFalse);
    }
  });

  test('pitch class in another octave is an octave error, never match', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(notes: const [60, 67]),
      segmentation: _segments([_hz(48), _hz(67)]),
    );
    expect(result.alignment!.count(PitchSequenceStepKind.wrongOctave), 1);
    expect(result.diagnosticCandidateMatch, isFalse);
    expect(result.reorderedTargetCandidates, isFalse);
  });

  test('no segments is neutral no-response with explicit missing targets', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _emptySegments(),
    );
    expect(result.status, ChordResponseStatus.noResponse);
    expect(result.diagnosticCandidateMatch, isNull);
    expect(result.alignment!.status, PitchSequenceStatus.noResponse);
    expect(result.alignment!.count(PitchSequenceStepKind.missing), 3);
  });

  test('invalid segmentation abstains without a partial comparison', () {
    final invalid = PitchSegmenter.segment(
      frames: const [
        SegmentationPitchFrame(
          startSample: 0,
          sampleCount: 800,
          status: PitchFrameStatus.invalidInput,
        ),
      ],
      sampleRateHz: _rate,
      sampleCount: _rate,
      provenance: _provenance,
    );
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: invalid,
    );
    expect(result.status, ChordResponseStatus.invalidEvidence);
    expect(result.alignment, isNull);
    expect(result.diagnosticCandidateMatch, isNull);
  });

  test('discarded candidates and provenance remain disclosed', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(notes: const [60, 67]),
      segmentation: _segments([_hz(60), _hz(67)], addShortDiscardedRun: true),
    );
    expect(result.diagnosticCandidateMatch, isTrue);
    expect(result.discardedFrameCount, 2);
    expect(result.source, MeasurementSource.synthetic);
    expect(result.analyzerVersion, contains(PitchSegmenter.version));
    expect(result.analyzerVersion, contains(ChordResponseEvidence.version));
  });

  test('reviewed A4 tuning determines targets without octave folding', () {
    const tuning = 442.0;
    final result = ChordResponseMatcher.compare(
      recording: _recording(notes: const [69, 76], a4Hz: tuning),
      segmentation: _segments([_hz(69, tuning), _hz(76, tuning)]),
      toleranceCents: 1,
    );
    expect(result.diagnosticCandidateMatch, isTrue);
    final wrongTuning = ChordResponseMatcher.compare(
      recording: _recording(notes: const [69, 76], a4Hz: tuning),
      segmentation: _segments([_hz(69, 440), _hz(76, 440)]),
      toleranceCents: 1,
    );
    expect(wrongTuning.diagnosticCandidateMatch, isFalse);
  });

  test('tolerance is bounded before any diagnostic comparison', () {
    for (final tolerance in [double.nan, -1.0, 101.0]) {
      expect(
        () => ChordResponseMatcher.compare(
          recording: _recording(),
          segmentation: _emptySegments(),
          toleranceCents: tolerance,
        ),
        throwsArgumentError,
      );
    }
  });

  test('any-order accepts the same exact pitches in reverse order', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _segments([_hz(67), _hz(64), _hz(60)]),
      responseOrder: ResponseOrder.anyOrder,
    );
    expect(result.responseOrder, ResponseOrder.anyOrder);
    expect(result.alignment!.wholeSequenceCorrect, isFalse);
    expect(result.reorderedTargetCandidates, isTrue);
    expect(result.setComparison!.correctCount, 3);
    expect(result.setComparison!.wrongOctaveCount, 0);
    expect(result.diagnosticCandidateMatch, isTrue);
  });

  test('any-order reports missing and unrelated candidate as separate', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _segments([_hz(60), _hz(65), _hz(67)]),
      responseOrder: ResponseOrder.anyOrder,
    );
    expect(result.setComparison!.correctCount, 2);
    expect(result.setComparison!.wrongOctaveCount, 0);
    expect(result.setComparison!.missingTargetCount, 1);
    expect(result.setComparison!.extraCandidateCount, 1);
    expect(result.diagnosticCandidateMatch, isFalse);
  });

  test('any-order consumes wrong octave once without hiding it', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(notes: const [60, 67]),
      segmentation: _segments([_hz(48), _hz(67)]),
      responseOrder: ResponseOrder.anyOrder,
    );
    expect(result.setComparison!.correctCount, 1);
    expect(result.setComparison!.wrongOctaveCount, 1);
    expect(result.setComparison!.missingTargetCount, 0);
    expect(result.setComparison!.extraCandidateCount, 0);
    expect(result.diagnosticCandidateMatch, isFalse);
  });

  test('any-order duplicate stays extra after all targets match', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _segments([_hz(67), _hz(64), _hz(64), _hz(60)]),
      responseOrder: ResponseOrder.anyOrder,
    );
    expect(result.setComparison!.correctCount, 3);
    expect(result.setComparison!.missingTargetCount, 0);
    expect(result.setComparison!.extraCandidateCount, 1);
    expect(result.diagnosticCandidateMatch, isFalse);
  });

  test('one ambiguous candidate cannot satisfy two adjacent targets', () {
    final midpoint = math.sqrt(_hz(60) * _hz(61));
    final result = ChordResponseMatcher.compare(
      recording: _recording(notes: const [60, 61]),
      segmentation: _segments([midpoint]),
      responseOrder: ResponseOrder.anyOrder,
      toleranceCents: 51,
    );
    expect(result.setComparison!.correctCount, 1);
    expect(result.setComparison!.missingTargetCount, 1);
    expect(result.setComparison!.extraCandidateCount, 0);
    expect(result.diagnosticCandidateMatch, isFalse);
  });

  test('any-order no-response is neutral but retains target count', () {
    final result = ChordResponseMatcher.compare(
      recording: _recording(),
      segmentation: _emptySegments(),
      responseOrder: ResponseOrder.anyOrder,
    );
    expect(result.status, ChordResponseStatus.noResponse);
    expect(result.diagnosticCandidateMatch, isNull);
    expect(result.setComparison!.correctCount, 0);
    expect(result.setComparison!.missingTargetCount, 3);
    expect(result.setComparison!.extraCandidateCount, 0);
  });
}
