import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

List<double> tone(int length, int rate, double hz) =>
    List.generate(length, (i) => 0.25 * math.sin(2 * math.pi * hz * i / rate));

void main() {
  final analyzer = RecordingPitchAnalyzer();
  for (final rate in [8000, 16000, 44100, 48000]) {
    test('bounded synthetic recording at $rate Hz retains raw pitch', () {
      final input = tone((rate * 0.2).round(), rate, 440);
      final result = analyzer.analyze(
        samples: input,
        sampleRateHz: rate,
        source: MeasurementSource.synthetic,
      );
      expect(result.status, RecordingPitchStatus.periodicSignalObserved);
      expect(result.representativeFrequencyHz, closeTo(440, 2));
      expect(result.pitchDispersionCents, lessThan(2));
      expect(result.periodicFrameRatio, 1);
      expect(result.provenance.source, MeasurementSource.synthetic);
      expect(result.provenance.analyzerVersion, RecordingPitchAnalyzer.version);
      final repeat = analyzer.analyze(
        samples: input,
        sampleRateHz: rate,
        source: MeasurementSource.synthetic,
      );
      expect(jsonEncode(repeat.toJson()), jsonEncode(result.toJson()));
    });
  }
  test('default provenance remains unverified, even for a clear sine', () {
    final result = analyzer.analyze(
      samples: tone(1600, 8000, 440),
      sampleRateHz: 8000,
    );
    expect(result.provenance.source, MeasurementSource.unverified);
    expect(result.toJson().containsKey('voicedRatio'), isFalse);
    expect(result.toJson().containsKey('scores'), isFalse);
    expect(result.toJson().containsKey('samples'), isFalse);
  });
  test(
    'caller-declared microphone source is not inferred accuracy or consent',
    () {
      final result = analyzer.analyze(
        samples: List.filled(1600, 0),
        sampleRateHz: 8000,
        source: MeasurementSource.microphone,
      );
      expect(result.provenance.source, MeasurementSource.microphone);
      expect(result.status, RecordingPitchStatus.noPeriodicSignal);
      expect(result.representativeFrequencyHz, isNull);
    },
  );
  test('regular half-hop windows plus one end anchor cover the entire PCM', () {
    final result = analyzer.analyze(
      samples: tone(1300, 8000, 440),
      sampleRateHz: 8000,
    );
    expect(result.frameSize, 512);
    expect(result.hopSize, 256);
    expect(result.frames.map((f) => f.startSample), [0, 256, 512, 768, 788]);
    expect(
      result.frames.last.startSample + result.frames.last.sampleCount,
      1300,
    );
    expect(
      result.frameCounts.values.reduce((a, b) => a + b),
      result.frames.length,
    );
  });
  test('exact grid endpoint is not duplicated', () {
    final result = analyzer.analyze(
      samples: tone(1024, 8000, 440),
      sampleRateHz: 8000,
    );
    expect(result.frames.map((f) => f.startSample), [0, 256, 512]);
  });
  test('one full frame does not manufacture zero dispersion', () {
    final result = analyzer.analyze(
      samples: tone(512, 8000, 440),
      sampleRateHz: 8000,
    );
    expect(result.frames.length, 1);
    expect(result.representativeFrequencyHz, isNotNull);
    expect(result.pitchDispersionCents, isNull);
  });
  test('silence and noise stay in periodic frame denominator', () {
    final random = math.Random(42);
    final input = <double>[
      ...tone(2048, 8000, 440),
      ...List<double>.filled(2048, 0),
      ...List.generate(2048, (_) => (random.nextDouble() - 0.5) * 0.4),
    ];
    final result = analyzer.analyze(samples: input, sampleRateHz: 8000);
    final periodic = result.frameCounts[PitchFrameStatus.pitched]!;
    expect(periodic, greaterThan(0));
    expect(result.frameCounts[PitchFrameStatus.silence], greaterThan(0));
    expect(result.frameCounts[PitchFrameStatus.unreliable], greaterThan(0));
    expect(result.periodicFrameRatio, periodic / result.frames.length);
    expect(result.periodicFrameRatio, lessThan(0.6));
  });
  test('clipped tail is analyzed rather than silently dropped', () {
    final input = tone(1300, 8000, 440);
    input.fillRange(1200, 1300, 1);
    final result = analyzer.analyze(samples: input, sampleRateHz: 8000);
    expect(result.frames.last.estimate.status, PitchFrameStatus.clipped);
    expect(result.periodicFrameRatio, lessThan(1));
    expect(result.frameCounts[PitchFrameStatus.clipped], greaterThan(0));
  });
  test('octave shifts remain in dispersion and raw frame trace', () {
    final result = analyzer.analyze(
      samples: [...tone(4096, 8000, 220), ...tone(4096, 8000, 440)],
      sampleRateHz: 8000,
    );
    expect(result.pitchDispersionCents, greaterThan(500));
    final frequencies =
        result.frames
            .where((f) => f.estimate.status == PitchFrameStatus.pitched)
            .map((f) => f.estimate.frequencyHz!)
            .toList()
          ..sort();
    expect(frequencies.first, closeTo(220, 2));
    expect(frequencies.last, closeTo(440, 2));
    expect(
      result.representativeFrequencyHz,
      frequencies[(frequencies.length - 1) ~/ 2],
    );
    expect(frequencies.contains(result.representativeFrequencyHz), isTrue);
  });
  test('late malformed sample invalidates clean prefix before DSP', () {
    for (final value in [double.nan, double.infinity, -1.01]) {
      final samples = tone(1300, 8000, 440)..last = value;
      final result = analyzer.analyze(samples: samples, sampleRateHz: 8000);
      expect(result.status, RecordingPitchStatus.invalidInput);
      expect(result.frames, isEmpty);
      expect(result.representativeFrequencyHz, isNull);
      expect(result.pitchDispersionCents, isNull);
      expect(() => jsonEncode(result.toJson()), returnsNormally);
    }
  });
  test('empty/short recording never pads or guesses evidence', () {
    for (final count in [0, 1, 511]) {
      final result = analyzer.analyze(
        samples: tone(count, 8000, 440),
        sampleRateHz: 8000,
      );
      expect(result.status, RecordingPitchStatus.insufficientData);
      expect(result.frames, isEmpty);
      expect(result.periodicFrameRatio, isNull);
      expect(result.pitchDispersionCents, isNull);
    }
  });
  test('unsupported clock and excessive duration fail before DSP', () {
    for (final rate in [0, 7999, 48001, 96000]) {
      expect(
        analyzer.analyze(samples: [], sampleRateHz: rate).status,
        RecordingPitchStatus.invalidInput,
      );
    }
    final result = analyzer.analyze(
      samples: List.filled(80001, 0),
      sampleRateHz: 8000,
    );
    expect(result.status, RecordingPitchStatus.invalidInput);
    expect(result.frames, isEmpty);
  });
  test(
    'maximum duration is bounded even at highest rate; silence has no pitch',
    () {
      final result = analyzer.analyze(
        samples: List.filled(480000, 0),
        sampleRateHz: 48000,
      );
      expect(result.status, RecordingPitchStatus.noPeriodicSignal);
      expect(
        result.frames.length,
        lessThanOrEqualTo(RecordingPitchAnalyzer.maxFrames),
      );
      expect(
        result.frameCounts[PitchFrameStatus.silence],
        result.frames.length,
      );
      expect(result.periodicFrameRatio, 0);
      expect(result.representativeFrequencyHz, isNull);
      expect(result.pitchDispersionCents, isNull);
    },
  );
  test('evidence is immutable, PCM-free and finite JSON', () {
    final input = tone(1600, 8000, 440);
    final result = analyzer.analyze(samples: input, sampleRateHz: 8000);
    final json = jsonEncode(result.toJson());
    input.fillRange(0, input.length, 0);
    expect(jsonEncode(result.toJson()), json);
    expect(() => result.frames.clear(), throwsUnsupportedError);
    expect(() => result.frameCounts.clear(), throwsUnsupportedError);
    final exported = result.toJson();
    (exported['frames']! as List).clear();
    expect(result.frames, isNotEmpty);
  });
}
