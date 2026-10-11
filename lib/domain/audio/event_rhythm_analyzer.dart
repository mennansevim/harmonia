import 'dart:math' as math;

import '../models/exercise_result.dart';
import '../models/score_metric.dart';
import 'rhythm_analyzer.dart';

enum _Step { missed, extra, matched }

class _Cell {
  const _Cell(this.matches, this.distance, this.step);
  final int matches;
  final int distance;
  final _Step step;

  bool isBetterThan(_Cell other) =>
      matches > other.matches ||
      (matches == other.matches && distance < other.distance);
}

/// Monotonic event alignment: maximize one-to-one matches, then minimize
/// absolute timing error. No microphone capture or onset extraction happens here.
class EventRhythmAnalyzer implements RhythmAnalyzer {
  @override
  Future<RhythmAnalysisResult> analyze(RhythmAnalysisRequest request) async {
    final expected = request.expectedOnsetsMs;
    final raw = request.userOnsetsMs;
    if (expected.isEmpty ||
        expected.length > 256 ||
        raw.length > 256 ||
        request.toleranceMs < 0 ||
        request.onTimeToleranceMs < 0 ||
        request.latencyCompensationMs < 0) {
      throw ArgumentError(
        'Invalid rhythm reference, event budget or tolerance',
      );
    }
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] < 0 || (i > 0 && expected[i] <= expected[i - 1])) {
        throw ArgumentError('Reference onsets must be strictly increasing');
      }
    }
    for (var i = 0; i < raw.length; i++) {
      if (raw[i] < 0 || (i > 0 && raw[i] < raw[i - 1])) {
        throw ArgumentError('User onsets must be chronological');
      }
    }
    final user = raw.map((v) => v - request.latencyCompensationMs).toList();
    final n = expected.length;
    final m = user.length;
    final cells = List.generate(
      n + 1,
      (_) => List.filled(m + 1, const _Cell(0, 0, _Step.missed)),
    );
    for (var j = 1; j <= m; j++) {
      cells[0][j] = const _Cell(0, 0, _Step.extra);
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final miss = cells[i - 1][j];
        var best = _Cell(miss.matches, miss.distance, _Step.missed);
        final extra = cells[i][j - 1];
        final skip = _Cell(extra.matches, extra.distance, _Step.extra);
        if (skip.isBetterThan(best)) best = skip;
        final distance = (user[j - 1] - expected[i - 1]).abs();
        if (distance <= request.toleranceMs) {
          final previous = cells[i - 1][j - 1];
          final match = _Cell(
            previous.matches + 1,
            previous.distance + distance,
            _Step.matched,
          );
          if (match.isBetterThan(best)) best = match;
        }
        cells[i][j] = best;
      }
    }

    var i = n;
    var j = m;
    final offsets = <int>[];
    while (i > 0 || j > 0) {
      switch (cells[i][j].step) {
        case _Step.matched:
          offsets.add(user[j - 1] - expected[i - 1]);
          i--;
          j--;
        case _Step.missed:
          i--;
        case _Step.extra:
          j--;
      }
    }
    final matched = offsets.length;
    final deadband = math.min(request.onTimeToleranceMs, request.toleranceMs);
    final mean = matched == 0
        ? null
        : offsets.reduce((a, b) => a + b) / matched;
    final meanAbsolute = matched == 0
        ? null
        : offsets.map((v) => v.abs()).reduce((a, b) => a + b) / matched;
    double quality(int offset) {
      final distance = offset.abs();
      if (distance <= deadband) return 1;
      return (1 - (distance - deadband) / (request.toleranceMs - deadband))
          .clamp(0, 1)
          .toDouble();
    }

    // F1 coverage penalizes both missed and extra events. Timing quality is
    // continuous outside the deadband; opposing errors cannot cancel it.
    final coverage = 2 * matched / (n + m);
    final fidelity = matched == 0
        ? 0.0
        : offsets.map(quality).reduce((a, b) => a + b) / matched;
    return RhythmAnalysisResult(
      matchedCount: matched,
      missedCount: n - matched,
      extraCount: m - matched,
      earlyCount: offsets.where((v) => v < -deadband).length,
      lateCount: offsets.where((v) => v > deadband).length,
      averageOffsetMs: mean,
      averageAbsoluteOffsetMs: meanAbsolute,
      measurementStatus: m == 0
          ? MeasurementStatus.invalid
          : MeasurementStatus.valid,
      timingAccuracy: m == 0
          ? const ScoreMetric.notMeasured()
          : ScoreMetric.measured(100 * coverage * fidelity),
    );
  }
}
