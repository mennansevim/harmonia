import '../../domain/learning/measured_exercise.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/learning/today_planner.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/learner_profile.dart';

class PracticeDay {
  const PracticeDay({required this.date, required this.practiced});
  final DateTime date;
  final bool practiced;
}

/// One node on the home path, derived only from local evidence.
class PathNode {
  const PathNode({
    required this.node,
    required this.state,
    required this.nextExercise,
  });
  final SkillNode node;
  final MasteryState state;

  /// First not-yet-mastered linked exercise (or the first one), null when
  /// the build cannot measure this skill.
  final MeasuredExercise? nextExercise;

  bool get measurable => node.support == MeasurementSupport.measuredInApp;
  bool get mastered =>
      state == MasteryState.independent || state == MasteryState.retained;
}

/// Everything the Today tab shows, computed once per history load.
class HomeData {
  const HomeData({
    required this.step,
    required this.path,
    required this.streakDays,
    required this.practicedToday,
    required this.recentPractice,
  });
  final TodayStep step;
  final List<PathNode> path;

  /// Consecutive local days ending today (or yesterday) with ≥1 valid result.
  final int streakDays;
  final bool practicedToday;
  final List<PracticeDay> recentPractice;

  static HomeData build({
    required SkillGraph graph,
    required PracticeGoal goal,
    required List<ExerciseResult> results,
    required DateTime now,
    List<MeasuredExercise>? catalog,
  }) {
    final known = {
      for (final e in catalog ?? defaultMeasuredCatalog()) e.exerciseId: e,
    };
    final path = <PathNode>[];
    for (final n in graph.forGoal(goal)) {
      MeasuredExercise? next;
      if (n.support == MeasurementSupport.measuredInApp) {
        for (final id in n.exerciseIds) {
          final e = known[id];
          if (e == null) continue;
          next ??= e;
          final s = SkillStatusEvaluator.exerciseState(e, results);
          if (s != MasteryState.independent && s != MasteryState.retained) {
            next = e;
            break;
          }
        }
      }
      path.add(
        PathNode(
          node: n,
          state: SkillStatusEvaluator.stateOf(n, results, catalog: catalog),
          nextExercise: next,
        ),
      );
    }
    final (streak, today) = streakOf(results, now);
    return HomeData(
      step: TodayPlanner.recommend(
        graph: graph,
        goal: goal,
        results: results,
        now: now,
        catalog: catalog,
      ),
      path: path,
      streakDays: streak,
      practicedToday: today,
      recentPractice: recentPracticeOf(results, now, catalog: catalog),
    );
  }

  static DateTime _day(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// Rolling seven local calendar days, not a score or a completion target.
  /// Only valid results from currently supported cohorts count, even if wrong.
  /// Duplicate attempts on one day never inflate the number of active days.
  static List<PracticeDay> recentPracticeOf(
    List<ExerciseResult> results,
    DateTime now, {
    List<MeasuredExercise>? catalog,
  }) {
    final cohorts = [
      for (final e in catalog ?? defaultMeasuredCatalog()) e.cohort,
    ];
    final days = {
      for (final r in results)
        if (r.isValid &&
            !r.createdAt.isAfter(now) &&
            cohorts.any((cohort) => cohort.matches(r)))
          _day(r.createdAt),
    };
    final today = _day(now);
    return List.unmodifiable([
      for (var back = 6; back >= 0; back--)
        () {
          final date = DateTime(today.year, today.month, today.day - back);
          return PracticeDay(date: date, practiced: days.contains(date));
        }(),
    ]);
  }

  /// (streak, practicedToday). A streak survives until the end of the day
  /// after the last practice, so the morning does not show 0.
  static (int, bool) streakOf(List<ExerciseResult> results, DateTime now) {
    final days = {
      for (final r in results)
        if (r.isValid) _day(r.createdAt),
    };
    final today = _day(now);
    final practicedToday = days.contains(today);
    var cursor = practicedToday
        ? today
        : DateTime(today.year, today.month, today.day - 1);
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return (n, practicedToday);
  }
}
