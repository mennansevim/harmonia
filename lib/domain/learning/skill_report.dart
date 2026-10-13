import '../models/exercise_result.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'skill_graph.dart';
import 'today_planner.dart';

/// LEARN-04: evidence summary for the goal's route plus one focus. Counts
/// only; no readiness percentage. Skills the app cannot measure are
/// reported as unknown, never as weak.
class SkillReport {
  SkillReport._({
    required Map<MasteryState, int> measured,
    required Map<MeasurementSupport, int> unmeasurable,
    required this.focus,
  }) : measured = Map.unmodifiable(measured),
       unmeasurable = Map.unmodifiable(unmeasurable);

  /// States of skills this build measures (notMeasured = not tried yet).
  final Map<MasteryState, int> measured;

  /// Skills without in-app evidence, by why they are not measured.
  final Map<MeasurementSupport, int> unmeasurable;

  /// The single next focus (same rule as the home recommendation).
  final TodayStep focus;

  int get measurableCount => measured.values.fold(0, (a, b) => a + b);
  int get unknownCount => unmeasurable.values.fold(0, (a, b) => a + b);
  int count(MasteryState s) => measured[s] ?? 0;

  static SkillReport build({
    required SkillGraph graph,
    required PracticeGoal goal,
    required List<ExerciseResult> results,
    required DateTime now,
    List<MeasuredExercise>? catalog,
  }) {
    final measured = {for (final s in MasteryState.values) s: 0};
    final unmeasurable = <MeasurementSupport, int>{};
    for (final n in graph.forGoal(goal)) {
      if (n.support == MeasurementSupport.measuredInApp) {
        final s = SkillStatusEvaluator.stateOf(n, results, catalog: catalog);
        measured[s] = measured[s]! + 1;
      } else {
        unmeasurable[n.support] = (unmeasurable[n.support] ?? 0) + 1;
      }
    }
    return SkillReport._(
      measured: measured,
      unmeasurable: unmeasurable,
      focus: TodayPlanner.recommend(
        graph: graph,
        goal: goal,
        results: results,
        now: now,
        catalog: catalog,
      ),
    );
  }
}
