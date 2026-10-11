import '../models/exercise_result.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'rhythm_next_step.dart';
import 'skill_graph.dart';

/// One concrete action for today across all measured skills of the goal's
/// route (LEARN-03b). Rule-based; criteria are the draft ones of each
/// exercise. Unmeasured prerequisites never block (their state is unknown).
class TodayStep {
  const TodayStep({
    required this.kind,
    this.node,
    this.exercise,
    this.lastResult,
  });
  final NextStepKind kind;
  final SkillNode? node;
  final MeasuredExercise? exercise;

  /// Last valid comparable result, for an evidence-citing explanation.
  final ExerciseResult? lastResult;
}

class TodayPlanner {
  const TodayPlanner._();

  static TodayStep recommend({
    required SkillGraph graph,
    required PracticeGoal goal,
    required List<ExerciseResult> results,
    required DateTime now,
    List<MeasuredExercise>? catalog,
  }) {
    final known = {
      for (final e in catalog ?? defaultMeasuredCatalog()) e.exerciseId: e,
    };
    TodayStep? pending;
    var anyHistory = false;
    for (final node in graph.forGoal(goal)) {
      if (node.support != MeasurementSupport.measuredInApp) continue;
      for (final id in node.exerciseIds) {
        final e = known[id];
        if (e == null) continue;
        final all = comparableResults(results, e);
        if (all.isNotEmpty) anyHistory = true;
        final valid = all.where((r) => r.isValid).toList();
        final state = SkillStatusEvaluator.exerciseState(e, results);
        final mastered =
            state == MasteryState.supported ||
            state == MasteryState.independent ||
            state == MasteryState.retained;
        if (mastered && all.last.isValid) {
          if (state != MasteryState.retained &&
              RhythmNextStepPolicy.laterDay(valid.last.createdAt, now)) {
            return TodayStep(
              kind: NextStepKind.delayedCheck,
              node: node,
              exercise: e,
              lastResult: valid.last,
            );
          }
          continue;
        }
        pending ??= TodayStep(
          kind: all.isEmpty
              ? NextStepKind.nextPattern
              : !all.last.isValid
              ? NextStepKind.retryUnmeasured
              : NextStepKind.repeat,
          node: node,
          exercise: e,
          lastResult: valid.isEmpty ? null : valid.last,
        );
      }
    }
    if (pending == null) return const TodayStep(kind: NextStepKind.allDone);
    if (!anyHistory) {
      return TodayStep(
        kind: NextStepKind.start,
        node: pending.node,
        exercise: pending.exercise,
      );
    }
    return pending;
  }
}
