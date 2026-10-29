import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/learning/measured_exercise.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/learning/starting_check.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/models/score_metric.dart';

ExerciseResult _result(
  MeasuredExercise exercise,
  int minute, {
  bool clean = true,
  bool valid = true,
}) => ExerciseResult(
  sessionId: 'starting-$minute',
  exerciseId: exercise.exerciseId,
  skill: exercise.cohort.skill,
  target: const {},
  measurements: {
    'correct': clean ? 8 : 3,
    'missed': clean ? 0 : 1,
    'extra': 0,
    'late': 0,
    'early': 0,
    'meanAbsoluteOffsetMs': 20,
  },
  scores: valid
      ? ExerciseScores(accuracy: ScoreMetric.measured(80))
      : const ExerciseScores(),
  createdAt: DateTime(2026, 10, 22, 10, minute),
  measurementStatus: valid
      ? MeasurementStatus.valid
      : MeasurementStatus.invalid,
  exerciseMode: exercise.cohort.mode,
  difficulty: exercise.cohort.difficulty,
  contentVersion: exercise.contentVersion,
  scoringVersion: exercise.cohort.scoringVersion,
  provenance: MeasurementProvenance(
    source: exercise.cohort.source,
    analyzerVersion: exercise.analyzerVersion,
  ),
);

void main() {
  final catalog = defaultMeasuredCatalog();
  MeasuredExercise byId(String id) =>
      catalog.singleWhere((exercise) => exercise.exerciseId == id);

  test('new learner gets three short checks and unknowns stay explicit', () {
    final summary = StartingCheckSummary.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.conservatory,
      results: const [],
    );

    expect(
      summary.items.map((item) => item.exercise.exerciseId),
      StartingCheckSummary.exerciseIds,
    );
    expect(summary.completedCount, 0);
    expect(summary.isComplete, isFalse);
    expect(summary.next!.exercise.exerciseId, 'draft-perc-highlow-200');
    expect(summary.unknownSkillCount, 8);
  });

  test('invalid is retried before untried; no aggregate level is invented', () {
    final first = byId(StartingCheckSummary.exerciseIds.first);
    final summary = StartingCheckSummary.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.foundations,
      results: [_result(first, 1, valid: false)],
    );

    expect(summary.items.first.status, StartingCheckStatus.retryNeeded);
    expect(summary.completedCount, 0);
    expect(summary.next, same(summary.items.first));
  });

  test('after all valid rounds the first weak area becomes practice focus', () {
    final results = [
      _result(byId(StartingCheckSummary.exerciseIds[0]), 1),
      _result(byId(StartingCheckSummary.exerciseIds[1]), 2, clean: false),
      _result(byId(StartingCheckSummary.exerciseIds[2]), 3),
    ];
    final summary = StartingCheckSummary.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.choir,
      results: results,
    );

    expect(summary.isComplete, isTrue);
    expect(summary.completedCount, 3);
    expect(
      summary.next!.exercise.exerciseId,
      StartingCheckSummary.exerciseIds[1],
    );
    expect(summary.next!.status, StartingCheckStatus.practiceSuggested);
  });

  test('all strong rounds finish without a fabricated next level', () {
    final summary = StartingCheckSummary.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.foundations,
      results: [
        for (final (index, id) in StartingCheckSummary.exerciseIds.indexed)
          _result(byId(id), index),
      ],
    );

    expect(summary.isComplete, isTrue);
    expect(summary.next, isNull);
    expect(() => summary.items.clear(), throwsUnsupportedError);
  });
}
