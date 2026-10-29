import '../models/exercise_result.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'skill_graph.dart';

enum StartingCheckStatus {
  notTried,
  retryNeeded,
  practiceSuggested,
  strongRound,
}

class StartingCheckItem {
  const StartingCheckItem({
    required this.node,
    required this.exercise,
    required this.status,
  });

  final SkillNode node;
  final MeasuredExercise exercise;
  final StartingCheckStatus status;

  bool get hasValidRound =>
      status == StartingCheckStatus.practiceSuggested ||
      status == StartingCheckStatus.strongRound;
}

/// SHELL-03a: an honest, short starting check over skills this build can
/// already measure. It is not an admissions level or conservatory readiness
/// score; educator-approved placement bands remain a separate gate.
class StartingCheckSummary {
  StartingCheckSummary._({
    required List<StartingCheckItem> items,
    required this.unknownSkillCount,
  }) : items = List.unmodifiable(items);

  static const exerciseIds = [
    'draft-perc-highlow-200',
    'draft-rhythm-quarters',
    'draft-int-do-re-mi-sol',
  ];

  final List<StartingCheckItem> items;

  /// Goal-route skills that this build cannot measure yet.
  final int unknownSkillCount;

  int get completedCount => items.where((item) => item.hasValidRound).length;
  bool get isComplete => items.isNotEmpty && completedCount == items.length;

  /// Finish missing/invalid rounds before suggesting practice from a weak one.
  StartingCheckItem? get next {
    for (final item in items) {
      if (item.status == StartingCheckStatus.retryNeeded) return item;
    }
    for (final item in items) {
      if (item.status == StartingCheckStatus.notTried) return item;
    }
    for (final item in items) {
      if (item.status == StartingCheckStatus.practiceSuggested) return item;
    }
    return null;
  }

  static StartingCheckSummary build({
    required SkillGraph graph,
    required PracticeGoal goal,
    required List<ExerciseResult> results,
    List<MeasuredExercise>? catalog,
  }) {
    final route = graph.forGoal(goal);
    final known = {
      for (final exercise in catalog ?? defaultMeasuredCatalog())
        exercise.exerciseId: exercise,
    };
    final items = <StartingCheckItem>[];
    for (final id in exerciseIds) {
      final exercise = known[id];
      if (exercise == null) continue;
      final nodes = route.where((node) => node.exerciseIds.contains(id));
      if (nodes.isEmpty) continue;
      final attempts = comparableResults(results, exercise);
      final latest = attempts.isEmpty ? null : attempts.last;
      final status = latest == null
          ? StartingCheckStatus.notTried
          : !latest.isValid
          ? StartingCheckStatus.retryNeeded
          : exercise.isClean(latest)
          ? StartingCheckStatus.strongRound
          : StartingCheckStatus.practiceSuggested;
      items.add(
        StartingCheckItem(
          node: nodes.single,
          exercise: exercise,
          status: status,
        ),
      );
    }
    return StartingCheckSummary._(
      items: items,
      unknownSkillCount: route
          .where((node) => node.support != MeasurementSupport.measuredInApp)
          .length,
    );
  }
}
