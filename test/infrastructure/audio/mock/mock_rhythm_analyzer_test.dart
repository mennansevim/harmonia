import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/rhythm_analyzer.dart';
import 'package:harmonia/infrastructure/audio/mock/mock_rhythm_analyzer.dart';

void main() {
  final analyzer = MockRhythmAnalyzer();

  test('perfectly matched onsets score full timing accuracy', () async {
    final result = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500, 1000],
        userOnsetsMs: [10, 505, 995],
      ),
    );

    expect(result.matchedCount, 3);
    expect(result.missedCount, 0);
    expect(result.extraCount, 0);
    expect(result.timingAccuracy.value, 100);
  });

  test('a missing tap is reported as missed, not extra', () async {
    final result = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500, 1000],
        userOnsetsMs: [0, 1000],
      ),
    );

    expect(result.matchedCount, 2);
    expect(result.missedCount, 1);
    expect(result.extraCount, 0);
  });

  test('an extra tap beyond the expected beats is reported as extra', () async {
    final result = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500],
        userOnsetsMs: [0, 500, 900],
      ),
    );

    expect(result.matchedCount, 2);
    expect(result.extraCount, 1);
    expect(result.timingAccuracy.value, lessThan(100));
  });

  test('taps outside the tolerance window are not matched', () async {
    final result = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0],
        userOnsetsMs: [500],
        toleranceMs: 100,
      ),
    );

    expect(result.matchedCount, 0);
    expect(result.missedCount, 1);
    expect(result.extraCount, 1);
  });

  test('early and late taps are classified by sign of the offset', () async {
    final result = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [500, 1000],
        userOnsetsMs: [480, 1050],
      ),
    );

    expect(result.earlyCount, 1);
    expect(result.lateCount, 1);
  });
}
