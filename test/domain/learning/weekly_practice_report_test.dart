import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/learning/measured_exercise.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/learning/weekly_practice_report.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/models/score_metric.dart';

ExerciseResult _result(
  MeasuredExercise exercise,
  DateTime createdAt, {
  bool valid = true,
  String? contentVersion,
}) => ExerciseResult(
  sessionId: 'weekly-${createdAt.microsecondsSinceEpoch}',
  exerciseId: exercise.exerciseId,
  skill: exercise.cohort.skill,
  target: const {},
  measurements: const {'correct': 6},
  scores: valid
      ? ExerciseScores(accuracy: ScoreMetric.measured(75))
      : const ExerciseScores(),
  createdAt: createdAt,
  measurementStatus: valid
      ? MeasurementStatus.valid
      : MeasurementStatus.invalid,
  exerciseMode: exercise.cohort.mode,
  difficulty: exercise.cohort.difficulty,
  contentVersion: contentVersion ?? exercise.contentVersion,
  scoringVersion: exercise.cohort.scoringVersion,
  provenance: MeasurementProvenance(
    source: exercise.cohort.source,
    analyzerVersion: exercise.analyzerVersion,
  ),
);

void main() {
  final catalog = defaultMeasuredCatalog();
  final first = catalog.first;
  final second = catalog[1];
  final now = DateTime(2026, 10, 22, 12);

  WeeklyPracticeReport report(List<ExerciseResult> results) =>
      WeeklyPracticeReport.build(
        graph: draftSkillGraph,
        goal: PracticeGoal.foundations,
        results: results,
        now: now,
        catalog: catalog,
      );

  test('empty history stays an activity summary, never a progress score', () {
    final value = report(const []);

    expect(value.activeDays, 0);
    expect(value.validRounds, 0);
    expect(value.previousValidRounds, 0);
    expect(value.comparison, PracticeVolumeComparison.noBaseline);
    expect(value.activities, isEmpty);
  });

  test('counts valid current cohorts by day and exercise', () {
    final value = report([
      _result(first, DateTime(2026, 10, 22, 9)),
      _result(first, DateTime(2026, 10, 22, 10)),
      _result(second, DateTime(2026, 10, 19, 10)),
    ]);

    expect(value.activeDays, 2);
    expect(value.validRounds, 3);
    expect(value.activities.map((a) => a.validRounds), [2, 1]);
  });

  test('invalid is separate; stale and future evidence are ignored', () {
    final value = report([
      _result(first, DateTime(2026, 10, 21), valid: false),
      _result(first, DateTime(2026, 10, 20), contentVersion: 'retired-content'),
      _result(first, now.add(const Duration(minutes: 1))),
    ]);

    expect(value.validRounds, 0);
    expect(value.incompleteMeasurements, 1);
    expect(value.activeDays, 0);
  });

  test('compares round volume with the preceding seven local days', () {
    final value = report([
      _result(first, DateTime(2026, 10, 22)),
      _result(first, DateTime(2026, 10, 20)),
      _result(first, DateTime(2026, 10, 15)),
    ]);

    expect(value.validRounds, 2);
    expect(value.previousValidRounds, 1);
    expect(value.comparison, PracticeVolumeComparison.increased);
  });

  test('calendar windows exclude results older than fourteen days', () {
    final value = report([
      _result(first, DateTime(2026, 10, 9, 23, 59)),
      _result(first, DateTime(2026, 10, 8)),
    ]);

    expect(value.previousValidRounds, 1);
    expect(value.validRounds, 0);
    expect(value.comparison, PracticeVolumeComparison.decreased);
  });
}
