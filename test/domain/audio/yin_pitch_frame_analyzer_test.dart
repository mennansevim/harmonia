import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_deviation.dart';
import 'package:harmonia/domain/audio/yin_pitch_frame_analyzer.dart';

List<double> tone(
  int count,
  int rate,
  double hz, {
  double amplitude = 0.25,
  double phase = 0,
  double dc = 0,
}) => List.generate(
  count,
  (i) => dc + amplitude * math.sin(2 * math.pi * hz * i / rate + phase),
);

void main() {
  final analyzer = YinPitchFrameAnalyzer();
  for (final rate in [8000, 16000, 44100, 48000]) {
    for (final hz in [65.406, 130.813, 261.626, 440.0, 880.0, 1200.0]) {
      test('synthetic sine $hz Hz at $rate Hz retains note and octave', () {
        final samples = tone(analyzer.recommendedFrameSamples(rate), rate, hz);
        final result = analyzer.analyze(samples, sampleRateHz: rate);
        expect(result.status, PitchFrameStatus.pitched);
        final deviation = PitchDeviation(
          detectedHz: result.frequencyHz!,
          targetHz: hz,
        );
        expect(deviation.absoluteCents.abs(), lessThan(15));
        expect(deviation.octaveOffset, 0);
        expect(result.periodicity, inInclusiveRange(0.85, 1));
        expect(result.rmsDb!.isFinite, isTrue);
        expect(samples, tone(samples.length, rate, hz));
        final repeat = analyzer.analyze(samples, sampleRateHz: rate);
        expect(repeat.frequencyHz, result.frequencyHz);
        expect(repeat.periodicity, result.periodicity);
      });
    }
  }

  test(
    'weak fundamental with stronger second/third harmonics stays fundamental',
    () {
      const rate = 48000;
      final samples = List.generate(analyzer.recommendedFrameSamples(rate), (
        i,
      ) {
        final phase = 2 * math.pi * 220 * i / rate;
        return 0.08 * math.sin(phase) +
            0.3 * math.sin(2 * phase) +
            0.15 * math.sin(3 * phase);
      });
      final result = analyzer.analyze(samples, sampleRateHz: rate);
      expect(result.status, PitchFrameStatus.pitched);
      expect(
        PitchDeviation(
          detectedHz: result.frequencyHz!,
          targetHz: 220,
        ).absoluteCents.abs(),
        lessThan(5),
      );
    },
  );

  test('phase, gain and DC shift do not force the pitch toward a target', () {
    const rate = 48000;
    for (final amplitude in [0.02, 0.25, 0.5]) {
      final result = analyzer.analyze(
        tone(
          analyzer.recommendedFrameSamples(rate),
          rate,
          330,
          amplitude: amplitude,
          phase: 1.7,
          dc: 0.2,
        ),
        sampleRateHz: rate,
      );
      expect(result.status, PitchFrameStatus.pitched);
      expect(
        PitchDeviation(
          detectedHz: result.frequencyHz!,
          targetHz: 330,
        ).absoluteCents.abs(),
        lessThan(5),
      );
    }
  });

  test('octave above/below remain octave errors in separate comparison', () {
    for (final hz in [220.0, 880.0]) {
      final result = analyzer.analyze(
        tone(4096, 48000, hz),
        sampleRateHz: 48000,
      );
      final deviation = PitchDeviation(
        detectedHz: result.frequencyHz!,
        targetHz: 440,
      );
      expect(deviation.octaveOffset, hz < 440 ? -1 : 1);
      expect(deviation.absoluteCents.abs(), closeTo(1200, 5));
      expect(deviation.pitchClassCents.abs(), lessThan(5));
    }
  });

  for (final value in [0.0, 0.3, -0.3]) {
    test('silence/constant DC $value yields finite neutral evidence', () {
      final result = analyzer.analyze(
        List.filled(4096, value),
        sampleRateHz: 48000,
      );
      expect(result.status, PitchFrameStatus.silence);
      expect(result.frequencyHz, isNull);
      expect(result.rmsDb, -120);
      expect(result.periodicity, 0);
    });
  }
  test('below-gate tone is not a guessed pitch', () {
    final result = analyzer.analyze(
      tone(4096, 48000, 440, amplitude: 0.001),
      sampleRateHz: 48000,
    );
    expect(result.status, PitchFrameStatus.silence);
    expect(result.frequencyHz, isNull);
  });
  for (final seed in [17, 42, 100]) {
    test('seeded broadband noise $seed abstains, not a voice classifier', () {
      final random = math.Random(seed);
      final result = analyzer.analyze(
        List.generate(4096, (_) => (random.nextDouble() - 0.5) * 0.6),
        sampleRateHz: 48000,
      );
      expect(result.status, PitchFrameStatus.unreliable);
      expect(result.frequencyHz, isNull);
      expect(result.periodicity, 0);
    });
  }
  test('clipped periodic signal is not accepted', () {
    final result = analyzer.analyze(
      List.generate(4096, (i) => i % 100 < 50 ? 1.0 : -1.0),
      sampleRateHz: 48000,
    );
    expect(result.status, PitchFrameStatus.clipped);
    expect(result.frequencyHz, isNull);
    expect(result.rmsDb!.isFinite, isTrue);
  });
  for (final count in [0, 1, 256, 2048, 2881]) {
    test('short buffer $count terminates without recursion or guessed Hz', () {
      final result = analyzer.analyze(
        tone(count, 48000, 440),
        sampleRateHz: 48000,
      );
      expect(result.status, PitchFrameStatus.insufficientData);
      expect(result.frequencyHz, isNull);
      expect(result.rmsDb, isNull);
    });
  }
  for (final sample in [
    double.nan,
    double.infinity,
    double.negativeInfinity,
    1.01,
    -1.01,
  ]) {
    test('invalid PCM $sample is rejected even in short input', () {
      final result = analyzer.analyze([sample], sampleRateHz: 48000);
      expect(result.status, PitchFrameStatus.invalidInput);
      expect(result.frequencyHz, isNull);
      expect(result.rmsDb, isNull);
    });
  }
  for (final rate in [0, 7999, 48001, 96000]) {
    test('unsupported sample rate $rate is never silently reinterpreted', () {
      expect(
        analyzer.analyze(tone(4096, 48000, 440), sampleRateHz: rate).status,
        PitchFrameStatus.invalidInput,
      );
      expect(() => analyzer.recommendedFrameSamples(rate), throwsArgumentError);
    });
  }
  test('oversized input is rejected before touching its samples', () {
    final result = analyzer.analyze(
      List.filled(8193, double.nan),
      sampleRateHz: 48000,
    );
    expect(result.status, PitchFrameStatus.invalidInput);
  });
  test('minimum and maximum supported window sizes are safe', () {
    final count = analyzer.minimumFrameSamples(48000);
    expect(count, 2882);
    for (final size in [count, 8192]) {
      expect(
        analyzer.analyze(tone(size, 48000, 65.406), sampleRateHz: 48000).status,
        PitchFrameStatus.pitched,
      );
    }
    expect(analyzer.recommendedFrameSamples(8000), 512);
    expect(analyzer.recommendedFrameSamples(48000), 4096);
  });
  test('invalid configuration is rejected at runtime', () {
    for (final factory in <YinPitchFrameAnalyzer Function()>[
      () => YinPitchFrameAnalyzer(minFrequencyHz: double.nan),
      () => YinPitchFrameAnalyzer(minFrequencyHz: 39),
      () => YinPitchFrameAnalyzer(maxFrequencyHz: 2001),
      () => YinPitchFrameAnalyzer(minFrequencyHz: 100, maxFrequencyHz: 90),
      () => YinPitchFrameAnalyzer(silenceDb: double.infinity),
      () => YinPitchFrameAnalyzer(silenceDb: -121),
      () => YinPitchFrameAnalyzer(silenceDb: -9),
      () => YinPitchFrameAnalyzer(differenceThreshold: 0),
      () => YinPitchFrameAnalyzer(differenceThreshold: 0.31),
      () => YinPitchFrameAnalyzer(maxClippedRatio: -0.1),
      () => YinPitchFrameAnalyzer(maxClippedRatio: 0.06),
    ]) {
      expect(factory, throwsArgumentError);
    }
  });
}
