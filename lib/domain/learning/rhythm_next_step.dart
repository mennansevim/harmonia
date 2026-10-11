import '../audio/rhythm_imitation.dart';
import '../content/rhythm_patterns.dart';
import '../models/exercise_result.dart';
import '../models/measurement_provenance.dart';

enum NextStepKind {
  /// No comparable history yet: start with the first pattern.
  start,

  /// Last attempt could not be measured (e.g. one tap): listen and retry.
  retryUnmeasured,

  /// Targeted repetition of the same pattern, citing its dominant error.
  repeat,

  /// Current pattern met the (draft) criterion: move to a new pattern.
  nextPattern,

  /// A pattern mastered on an earlier day: check retention without hints.
  delayedCheck,

  /// Every available draft pattern is mastered and retained.
  allDone,
}

enum RhythmErrorFocus { missed, extra, late, early, none }

class NextStep {
  const NextStep({
    required this.kind,
    this.pattern,
    this.focus = RhythmErrorFocus.none,
    this.focusCount = 0,
  });
  final NextStepKind kind;
  final RhythmPattern? pattern;
  final RhythmErrorFocus focus;
  final int focusCount;
}

/// Deterministic next-step rule for rhythm imitation. Uses only valid,
/// comparable results (touch source, current analyzer and content version).
/// Streaks, time spent or repeating one item are NOT treated as learning
/// beyond this explicit, educator-reviewable criterion.
class RhythmNextStepPolicy {
  const RhythmNextStepPolicy._();

  /// Draft criterion (hypothesis, awaiting educator review): the last
  /// [masteryStreak] valid attempts have no missed/extra beat and a mean
  /// absolute offset ≤ [maxMeanAbsOffsetMs].
  static const masteryStreak = 2;
  static const maxMeanAbsOffsetMs = 60.0;

  /// Retention check opens on a later calendar day (local time).
  static bool laterDay(DateTime a, DateTime b) => _laterDay(a, b);

  static bool _laterDay(DateTime a, DateTime b) {
    final x = a.toLocal(), y = b.toLocal();
    return DateTime(
      y.year,
      y.month,
      y.day,
    ).isAfter(DateTime(x.year, x.month, x.day));
  }

  /// Shared draft criterion: valid, no missed/extra, mean |offset| ≤ limit.
  static bool isClean(ExerciseResult r) => _clean(r);

  static bool _clean(ExerciseResult r) =>
      r.isValid &&
      (r.measurements['missed'] as int? ?? 1) == 0 &&
      (r.measurements['extra'] as int? ?? 1) == 0 &&
      ((r.measurements['meanAbsoluteOffsetMs'] as num?)?.toDouble() ??
              double.infinity) <=
          maxMeanAbsOffsetMs;

  /// Comparable results for one pattern, oldest first.
  static List<ExerciseResult> comparable(
    List<ExerciseResult> results,
    RhythmPattern p,
  ) => _comparable(results, p);

  static List<ExerciseResult> _comparable(
    List<ExerciseResult> results,
    RhythmPattern p,
  ) => [
    for (final r in results)
      if (r.exerciseId == p.exercise.exercise.id &&
          r.contentVersion == p.exercise.exercise.contentVersion &&
          r.provenance.source == MeasurementSource.touch &&
          r.provenance.analyzerVersion == RhythmImitationOutcome.version)
        r,
  ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Priority: a due retention check, then [current] if it is not mastered
  /// (the result screen's "next step" must relate to what was just done),
  /// then the first pattern that is not mastered, then done.
  static NextStep recommend({
    required List<ExerciseResult> results,
    required List<RhythmPattern> patterns,
    required DateTime now,
    RhythmPattern? current,
  }) {
    NextStep? pending;
    NextStep? currentPending;
    for (final p in patterns) {
      final all = _comparable(results, p);
      final valid = all.where((r) => r.isValid).toList();
      final mastered =
          valid.length >= masteryStreak &&
          valid.sublist(valid.length - masteryStreak).every(_clean);
      if (mastered && all.last.isValid) {
        final streakStart = valid[valid.length - masteryStreak].createdAt;
        final retained = _laterDay(streakStart, valid.last.createdAt);
        if (!retained && _laterDay(valid.last.createdAt, now)) {
          return NextStep(kind: NextStepKind.delayedCheck, pattern: p);
        }
        continue;
      }
      final step = all.isEmpty
          ? NextStep(
              kind: identical(p, patterns.first)
                  ? NextStepKind.start
                  : NextStepKind.nextPattern,
              pattern: p,
            )
          : !all.last.isValid
          ? NextStep(kind: NextStepKind.retryUnmeasured, pattern: p)
          : _repeat(p, valid.last);
      pending ??= step;
      if (identical(p, current) && all.isNotEmpty) currentPending = step;
    }
    return currentPending ??
        pending ??
        const NextStep(kind: NextStepKind.allDone);
  }

  static NextStep _repeat(RhythmPattern p, ExerciseResult last) {
    int count(String key) => last.measurements[key] as int? ?? 0;
    final ordered = [
      (RhythmErrorFocus.missed, count('missed')),
      (RhythmErrorFocus.extra, count('extra')),
      (RhythmErrorFocus.late, count('late')),
      (RhythmErrorFocus.early, count('early')),
    ];
    for (final (focus, n) in ordered) {
      if (n > 0) {
        return NextStep(
          kind: NextStepKind.repeat,
          pattern: p,
          focus: focus,
          focusCount: n,
        );
      }
    }
    return NextStep(kind: NextStepKind.repeat, pattern: p);
  }
}
