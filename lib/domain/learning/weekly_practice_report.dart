import '../models/exercise_result.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'skill_graph.dart';

enum PracticeVolumeComparison { noBaseline, increased, unchanged, decreased }

class WeeklyExerciseActivity {
  const WeeklyExerciseActivity({
    required this.exerciseId,
    required this.title,
    required this.validRounds,
  });

  final String exerciseId;
  final String title;
  final int validRounds;
}

/// Rolling local-calendar activity summary; never a skill or readiness score.
class WeeklyPracticeReport {
  const WeeklyPracticeReport({
    required this.activeDays,
    required this.validRounds,
    required this.incompleteMeasurements,
    required this.previousValidRounds,
    required this.comparison,
    required this.activities,
  });

  final int activeDays;
  final int validRounds;
  final int incompleteMeasurements;
  final int previousValidRounds;
  final PracticeVolumeComparison comparison;
  final List<WeeklyExerciseActivity> activities;

  static WeeklyPracticeReport build({
    required SkillGraph graph,
    required PracticeGoal goal,
    required List<ExerciseResult> results,
    required DateTime now,
    List<MeasuredExercise>? catalog,
  }) {
    final allowed = {
      for (final node in graph.forGoal(goal)) ...node.exerciseIds,
    };
    final exercises = [
      for (final exercise in catalog ?? defaultMeasuredCatalog())
        if (allowed.contains(exercise.exerciseId)) exercise,
    ];
    final today = _day(now);
    final currentStart = DateTime(today.year, today.month, today.day - 6);
    final previousStart = DateTime(today.year, today.month, today.day - 13);
    final previousEnd = DateTime(today.year, today.month, today.day - 7);
    final active = <DateTime>{};
    final counts = <String, int>{};
    var valid = 0;
    var incomplete = 0;
    var previous = 0;

    for (final result in results) {
      if (result.createdAt.isAfter(now)) continue;
      MeasuredExercise? exercise;
      for (final candidate in exercises) {
        if (candidate.cohort.matches(result)) {
          exercise = candidate;
          break;
        }
      }
      if (exercise == null) continue;
      final day = _day(result.createdAt);
      if (!day.isBefore(currentStart) && !day.isAfter(today)) {
        if (result.isValid) {
          valid++;
          active.add(day);
          counts.update(
            exercise.exerciseId,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        } else {
          incomplete++;
        }
      } else if (!day.isBefore(previousStart) &&
          !day.isAfter(previousEnd) &&
          result.isValid) {
        previous++;
      }
    }

    final comparison = previous == 0
        ? PracticeVolumeComparison.noBaseline
        : valid > previous
        ? PracticeVolumeComparison.increased
        : valid < previous
        ? PracticeVolumeComparison.decreased
        : PracticeVolumeComparison.unchanged;
    return WeeklyPracticeReport(
      activeDays: active.length,
      validRounds: valid,
      incompleteMeasurements: incomplete,
      previousValidRounds: previous,
      comparison: comparison,
      activities: List.unmodifiable([
        for (final exercise in exercises)
          if ((counts[exercise.exerciseId] ?? 0) > 0)
            WeeklyExerciseActivity(
              exerciseId: exercise.exerciseId,
              title: exercise.title,
              validRounds: counts[exercise.exerciseId]!,
            ),
      ]),
    );
  }

  static DateTime _day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
