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
    final steps = <RhythmEventMatch>[];
    while (i > 0 || j > 0) {
      // Row 0 only holds extras and column 0 only misses; guard explicitly.
      final step = i == 0
          ? _Step.extra
          : j == 0
          ? _Step.missed
          : cells[i][j].step;
      switch (step) {
        case _Step.matched:
          final offset = user[j - 1] - expected[i - 1];
          offsets.add(offset);
          steps.add(
            RhythmEventMatch(
              referenceIndex: i - 1,
              userIndex: j - 1,
              offsetMs: offset,
            ),
          );
          i--;
          j--;
        case _Step.missed:
          steps.add(RhythmEventMatch(referenceIndex: i - 1));
          i--;
        case _Step.extra:
          steps.add(RhythmEventMatch(userIndex: j - 1));
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
      alignment: List.unmodifiable(
        _chronological(steps.reversed, expected, user),
      ),
    );
  }
}

/// Orders each run of unmatched steps between two matches by event time
/// (reference time for misses, latency-corrected user time for extras), so a
/// timeline reads left to right. Matches keep their positions.
List<RhythmEventMatch> _chronological(
  Iterable<RhythmEventMatch> steps,
  List<int> expected,
  List<int> user,
) {
  int time(RhythmEventMatch e) =>
      e.isExtra ? user[e.userIndex!] : expected[e.referenceIndex!];
  final out = <RhythmEventMatch>[];
  final run = <RhythmEventMatch>[];
  void flush() {
    run.sort((a, b) => time(a).compareTo(time(b)));
    out.addAll(run);
    run.clear();
  }

  for (final step in steps) {
    if (step.isMatched) {
      flush();
      out.add(step);
    } else {
      run.add(step);
    }
  }
  flush();
  return out;
}
