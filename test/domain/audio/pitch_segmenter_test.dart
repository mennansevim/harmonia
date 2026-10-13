import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_segmenter.dart';
import 'package:harmonia/domain/audio/pitch_deviation.dart';
import 'package:harmonia/domain/audio/pitch_sequence_alignment.dart';
import 'package:harmonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:harmonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';

const provenance = MeasurementProvenance(
  source: MeasurementSource.synthetic,
  analyzerVersion: 'synthetic-trace',
);
SegmentationPitchFrame frame(
  int i,
  double? hz, {
  int? start,
  PitchFrameStatus? status,
}) => SegmentationPitchFrame(
  startSample: start ?? i * 400,
  sampleCount: 800,
  status:
      status ??
      (hz == null ? PitchFrameStatus.silence : PitchFrameStatus.pitched),
  frequencyHz: hz,
);
PitchSegmentationEvidence segment(
  List<SegmentationPitchFrame> frames, {
  int count = 8000,
}) => PitchSegmenter.segment(
  frames: frames,
  sampleRateHz: 8000,
  sampleCount: count,
  provenance: provenance,
);
void main() {
  test(
    'synthetic two-tone PCM reaches segments and symbolic alignment without scoring',
    () {
      List<double> tone(double hz) => List.generate(
        5600,
        (i) => 0.25 * math.sin(2 * math.pi * hz * i / 8000),
      );
      final recording = RecordingPitchAnalyzer().analyze(
        samples: [...tone(440), ...List<double>.filled(1600, 0), ...tone(660)],
        sampleRateHz: 8000,
        source: MeasurementSource.synthetic,
      );
      final segmented = PitchSegmenter.fromRecording(recording);
      expect(segmented.segments.length, 2);
      expect(segmented.segments.first.frequencyHz, closeTo(440, 2));
      // Use the existing frame regression's 15-cent bound, not a fixed Hz
      // distance whose musical meaning changes with register.
      expect(
        PitchDeviation(
          detectedHz: segmented.segments.last.frequencyHz,
          targetHz: 660,
        ).absoluteCents.abs(),
        lessThan(15),
      );
      final response = [
        for (final s in segmented.segments)
          SequencePitchEvent(
            frequencyHz: s.frequencyHz,
            onsetMs: (s.startSample * 1000 / 8000).round(),
            durationMs: ((s.endSample - s.startSample) * 1000 / 8000).floor(),
          ),
      ];
      final aligned = PitchSequenceAligner.align(
        reference: const [
          SequencePitchEvent(frequencyHz: 440, onsetMs: 0, durationMs: 700),
          SequencePitchEvent(frequencyHz: 660, onsetMs: 900, durationMs: 700),
        ],
        response: response,
        source: segmented.provenance.source,
      );
      expect(aligned.wholeSequenceCorrect, isTrue);
      expect(aligned.source, MeasurementSource.synthetic);
    },
  );
  test('stable periodic run uses raw median and explicit source', () {
    final r = segment([for (var i = 0; i < 6; i++) frame(i, 440)]);
    expect(r.status, PitchSegmentationStatus.candidatesObserved);
    expect(r.segments.single.frequencyHz, 440);
    expect(r.segments.single.startSample, 400);
    expect(r.segments.single.endSample, 2400);
    expect(r.provenance.source, MeasurementSource.synthetic);
    expect(r.provenance.analyzerVersion, contains(PitchSegmenter.version));
  });
  test('pitch changes preserve order and octave rather than fold', () {
    final r = segment([
      for (var i = 0; i < 18; i++)
        frame(
          i,
          i < 6
              ? 440
              : i < 12
              ? 880
              : 440,
        ),
    ]);
    expect(r.segments.map((s) => s.frequencyHz), [440, 880, 440]);
    for (var i = 1; i < r.segments.length; i++) {
      expect(
        r.segments[i].startSample,
        greaterThanOrEqualTo(r.segments[i - 1].endSample),
      );
    }
  });
  test('silence separates repeated notes', () {
    final r = segment([
      for (var i = 0; i < 13; i++) frame(i, i == 6 ? null : 440),
    ]);
    expect(r.segments.length, 2);
    expect(r.nonPitchedFrameIndices, [6]);
  });
  test('unreliable and clipped windows are never bridged', () {
    for (final status in [
      PitchFrameStatus.unreliable,
      PitchFrameStatus.clipped,
    ]) {
      final r = segment([
        for (var i = 0; i < 13; i++)
          frame(i, i == 6 ? null : 440, status: i == 6 ? status : null),
      ]);
      expect(r.segments.length, 2);
      expect(r.nonPitchedFrameIndices, [6]);
    }
  });
  test(
    'short octave spike is audited not silently treated as correct note',
    () {
      final r = segment([
        for (var i = 0; i < 13; i++) frame(i, i == 6 ? 880 : 440),
      ]);
      expect(r.discardedFrameIndices, [6]);
      expect(r.segments.length, 2);
    },
  );
  test('short run is unmeasured candidate, not zero student score', () {
    final r = segment([for (var i = 0; i < 3; i++) frame(i, 440)]);
    expect(r.status, PitchSegmentationStatus.noCandidates);
    expect(r.discardedFrameIndices, [0, 1, 2]);
  });
  test('window overlap does not multiply observed duration', () {
    final r = segment([for (var i = 0; i < 4; i++) frame(i, 440)]);
    expect(r.segments, isEmpty); // 150ms center span, not 4 * 100ms.
  });
  test('uncovered gap is not represented as sustained pitch', () {
    final r = segment([
      for (var i = 0; i < 6; i++) frame(i, 440),
      for (var i = 0; i < 6; i++) frame(i, 440, start: 5000 + i * 400),
    ], count: 9000);
    expect(r.segments.length, 2);
    expect(r.segments.first.endSample, 2400);
    expect(r.segments.last.startSample, 5400);
  });
  test('invalid late frame rejects clean prefix', () {
    for (final bad in [
      frame(6, double.nan),
      frame(6, 0),
      frame(6, 2200),
      frame(6, null, status: PitchFrameStatus.invalidInput),
      frame(6, 440, status: PitchFrameStatus.silence),
    ]) {
      final r = segment([for (var i = 0; i < 6; i++) frame(i, 440), bad]);
      expect(r.status, PitchSegmentationStatus.invalidInput);
      expect(r.segments, isEmpty);
    }
  });
  test('bounds and chronology reject malformed timeline', () {
    expect(
      segment([frame(0, 440), frame(0, 440)]).status,
      PitchSegmentationStatus.invalidInput,
    );
    expect(
      segment([frame(0, 440, start: -1)]).status,
      PitchSegmentationStatus.invalidInput,
    );
    expect(
      segment([frame(0, 440)], count: 799).status,
      PitchSegmentationStatus.invalidInput,
    );
    expect(
      segment([for (var i = 0; i < 513; i++) frame(i, 440)]).status,
      PitchSegmentationStatus.invalidInput,
    );
    expect(segment([]).status, PitchSegmentationStatus.noCandidates);
  });
  test('slow pitch drift cannot chain through adjacent tolerance', () {
    final r = segment([
      for (var i = 0; i < 12; i++)
        frame(i, 440 * math.pow(2, i * 20 / 1200).toDouble()),
    ]);
    expect(r.segments, isEmpty);
    expect(r.discardedFrameIndices.length, 12);
  });
  test(
    'recording DSP adapter works with synthetic PCM and immutable evidence',
    () {
      final samples = List.generate(
        8000,
        (i) => 0.25 * math.sin(2 * math.pi * 440 * i / 8000),
      );
      final recording = RecordingPitchAnalyzer().analyze(
        samples: samples,
        sampleRateHz: 8000,
        source: MeasurementSource.synthetic,
      );
      final r = PitchSegmenter.fromRecording(recording);
      expect(r.status, PitchSegmentationStatus.candidatesObserved);
      expect(r.segments.single.frequencyHz, closeTo(440, 2));
      expect(() => r.segments.clear(), throwsUnsupportedError);
      expect(
        () => r.segments.single.frameIndices.clear(),
        throwsUnsupportedError,
      );
      expect(() => r.discardedFrameIndices.add(1), throwsUnsupportedError);
      final silence = RecordingPitchAnalyzer().analyze(
        samples: List.filled(8000, 0),
        sampleRateHz: 8000,
      );
      expect(
        PitchSegmenter.fromRecording(silence).status,
        PitchSegmentationStatus.noCandidates,
      );
      final invalid = RecordingPitchAnalyzer().analyze(
        samples: [double.nan],
        sampleRateHz: 8000,
      );
      expect(
        PitchSegmenter.fromRecording(invalid).status,
        PitchSegmentationStatus.invalidInput,
      );
    },
  );
}
