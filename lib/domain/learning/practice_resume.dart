import '../models/exercise_result.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'skill_graph.dart';

/// A safe return target derived from completed local evidence.
///
/// This never restores an in-flight question, player or microphone session. It
/// only offers a fresh round of the most recently attempted current exercise.
class PracticeResume {
  const PracticeResume({
    required this.exercise,
    required this.attemptedAt,
    required this.previousMeasurementValid,
  });

  final MeasuredExercise exercise;
  final DateTime attemptedAt;
  final bool previousMeasurementValid;

  static PracticeResume? latest({
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
    ExerciseResult? latestResult;
    MeasuredExercise? latestExercise;
    for (final result in results) {
      if (result.createdAt.isAfter(now)) continue;
      for (final exercise in exercises) {
        if (!exercise.cohort.matches(result)) continue;
        if (latestResult == null ||
            result.createdAt.isAfter(latestResult.createdAt)) {
          latestResult = result;
          latestExercise = exercise;
        }
        break;
      }
    }
    if (latestResult == null || latestExercise == null) return null;
    return PracticeResume(
      exercise: latestExercise,
      attemptedAt: latestResult.createdAt,
      previousMeasurementValid: latestResult.isValid,
    );
  }
}
