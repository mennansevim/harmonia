import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/pitch_analyzer.dart';
import 'package:resonia/infrastructure/audio/mock/mock_pitch_analyzer.dart';

void main() {
  const targetFrequencyHz = 261.63;
  const request = PitchAnalysisRequest(
    samples: [],
    sampleRateHz: 44100,
    targetFrequencyHz: targetFrequencyHz,
  );

  final analyzer = MockPitchAnalyzer(simulatedLatency: Duration.zero);

  test(
    'correct scenario returns an in-tune, same-octave, low-noise result',
    () async {
      analyzer.setScenario(MockPitchScenario.correct);
      final result = await analyzer.analyze(request);

      expect(result.octaveOffset, 0);
      expect(result.centsDifference!.abs(), lessThan(50));
      expect(result.isNoisy, isFalse);
      expect(result.voicedRatio, greaterThan(0.6));
    },
  );

  test(
    'wrongNote scenario stays in the target octave but off pitch class',
    () async {
      analyzer.setScenario(MockPitchScenario.wrongNote);
      final result = await analyzer.analyze(request);

      expect(result.octaveOffset, 0);
      expect(result.centsDifference!.abs(), greaterThan(50));
    },
  );

  test(
    'wrongOctaveDown scenario reports a correct pitch class one octave low',
    () async {
      analyzer.setScenario(MockPitchScenario.wrongOctaveDown);
      final result = await analyzer.analyze(request);

      expect(result.octaveOffset, -1);
      expect(result.centsDifference!.abs(), lessThan(50));
    },
  );

  test(
    'wrongOctaveUp scenario reports a correct pitch class one octave high',
    () async {
      analyzer.setScenario(MockPitchScenario.wrongOctaveUp);
      final result = await analyzer.analyze(request);

      expect(result.octaveOffset, 1);
      expect(result.centsDifference!.abs(), lessThan(50));
    },
  );

  test('noisy scenario reports isNoisy with a low voiced ratio', () async {
    analyzer.setScenario(MockPitchScenario.noisy);
    final result = await analyzer.analyze(request);

    expect(result.isNoisy, isTrue);
    expect(result.voicedRatio, lessThan(0.6));
  });

  test('silence scenario reports no detected frequency at all', () async {
    analyzer.setScenario(MockPitchScenario.silence);
    final result = await analyzer.analyze(request);

    expect(result.detectedFrequencyHz, isNull);
    expect(result.centsDifference, isNull);
  });

  test(
    'detected frequency is derived from the request target frequency',
    () async {
      analyzer.setScenario(MockPitchScenario.correct);
      const otherRequest = PitchAnalysisRequest(
        samples: [],
        sampleRateHz: 44100,
        targetFrequencyHz: 440,
      );
      final result = await analyzer.analyze(otherRequest);

      // 6 cents above 440 Hz.
      expect(result.detectedFrequencyHz, closeTo(441.53, 0.5));
    },
  );
}
