import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/event_rhythm_analyzer.dart';
import 'package:resonia/domain/audio/rhythm_analyzer.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/score_metric.dart';

void main() {
  final analyzer = EventRhythmAnalyzer();

  test('exact events score 100', () async {
    final r = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500, 1000],
        userOnsetsMs: [0, 500, 1000],
      ),
    );
    expect(r.timingAccuracy.value, 100);
    expect(r.averageAbsoluteOffsetMs, 0);
    expect(r.measurementStatus, MeasurementStatus.valid);
  });

  test('extra and duplicated taps reduce the score', () async {
    for (final taps in [
      [0, 500, 900],
      [0, 0, 500],
    ]) {
      final r = await analyzer.analyze(
        RhythmAnalysisRequest(
          expectedOnsetsMs: const [0, 500],
          userOnsetsMs: taps,
        ),
      );
      expect(r.matchedCount, 2);
      expect(r.extraCount, 1);
      expect(r.timingAccuracy.value, closeTo(80, 0.001));
    }
  });

  test('opposing offsets do not hide timing spread', () async {
    final r = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [500, 1000],
        userOnsetsMs: [450, 1050],
      ),
    );
    expect(r.averageOffsetMs, 0);
    expect(r.averageAbsoluteOffsetMs, 50);
    expect(r.earlyCount, 1);
    expect(r.lateCount, 1);
    expect(r.timingAccuracy.value, lessThan(100));
  });

  test(
    'global monotonic matching avoids the greedy nearest-tap trap',
    () async {
      final r = await analyzer.analyze(
        const RhythmAnalysisRequest(
          expectedOnsetsMs: [100, 200],
          userOnsetsMs: [0, 140],
          toleranceMs: 110,
        ),
      );
      expect(r.matchedCount, 2);
      expect(r.missedCount, 0);
      expect(r.extraCount, 0);
    },
  );

  test('independent latency calibration removes device delay only', () async {
    final r = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500],
        userOnsetsMs: [80, 580],
        latencyCompensationMs: 80,
      ),
    );
    expect(r.timingAccuracy.value, 100);
    expect(r.averageOffsetMs, 0);
  });

  test('uncalibrated delay is not secretly aligned away', () async {
    final r = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500],
        userOnsetsMs: [80, 580],
      ),
    );
    expect(r.averageOffsetMs, 80);
    expect(r.timingAccuracy.value, lessThan(100));
  });

  test('missing input is unmeasured, not a zero grade', () async {
    final r = await analyzer.analyze(
      const RhythmAnalysisRequest(expectedOnsetsMs: [0, 500], userOnsetsMs: []),
    );
    expect(r.measurementStatus, MeasurementStatus.invalid);
    expect(r.timingAccuracy.status, ScoreMetricStatus.notMeasured);
    expect(r.averageOffsetMs, isNull);
    expect(r.averageAbsoluteOffsetMs, isNull);
  });

  test(
    'recorded taps entirely outside the window are a measured miss',
    () async {
      final r = await analyzer.analyze(
        const RhythmAnalysisRequest(expectedOnsetsMs: [0], userOnsetsMs: [500]),
      );
      expect(r.measurementStatus, MeasurementStatus.valid);
      expect(r.timingAccuracy.value, 0);
      expect(r.missedCount, 1);
      expect(r.extraCount, 1);
    },
  );

  test('zero tolerance accepts only exact timestamps', () async {
    final r = await analyzer.analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500],
        userOnsetsMs: [0, 501],
        toleranceMs: 0,
      ),
    );
    expect(r.matchedCount, 1);
    expect(r.timingAccuracy.value, 50);
  });

  test(
    'in-window offsets inside the deadband are neither early nor late',
    () async {
      final r = await analyzer.analyze(
        const RhythmAnalysisRequest(
          expectedOnsetsMs: [100, 500],
          userOnsetsMs: [95, 505],
        ),
      );
      expect(r.earlyCount, 0);
      expect(r.lateCount, 0);
      expect(r.timingAccuracy.value, 100);
    },
  );

  test('malformed references and timestamps are rejected', () async {
    for (final request in [
      const RhythmAnalysisRequest(expectedOnsetsMs: [], userOnsetsMs: []),
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [500, 0],
        userOnsetsMs: [0],
      ),
      const RhythmAnalysisRequest(expectedOnsetsMs: [0, 0], userOnsetsMs: [0]),
      const RhythmAnalysisRequest(expectedOnsetsMs: [0], userOnsetsMs: [-1]),
      const RhythmAnalysisRequest(expectedOnsetsMs: [0], userOnsetsMs: [50, 0]),
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0],
        userOnsetsMs: [0],
        toleranceMs: -1,
      ),
    ]) {
      await expectLater(analyzer.analyze(request), throwsArgumentError);
    }
  });

  test('bounded event sets obey coverage and count conservation', () async {
    for (var n = 1; n <= 12; n++) {
      for (var removed = 0; removed <= n; removed++) {
        final reference = List.generate(n, (i) => i * 500);
        final taps = reference.skip(removed).toList();
        final r = await analyzer.analyze(
          RhythmAnalysisRequest(
            expectedOnsetsMs: reference,
            userOnsetsMs: taps,
          ),
        );
        expect(r.matchedCount + r.missedCount, n);
        expect(r.matchedCount + r.extraCount, taps.length);
        if (taps.isNotEmpty) {
          expect(r.timingAccuracy.value, inInclusiveRange(0, 100));
        }
      }
    }
  });
}
