import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/learning/measured_exercise.dart';
import 'package:resonia/domain/learning/practice_resume.dart';
import 'package:resonia/domain/learning/skill_graph.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/domain/models/score_metric.dart';

ExerciseResult _result(
  MeasuredExercise exercise,
  DateTime createdAt, {
  bool valid = true,
  String? contentVersion,
  String? analyzerVersion,
}) => ExerciseResult(
  sessionId: 'resume-${createdAt.microsecondsSinceEpoch}',
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
    analyzerVersion: analyzerVersion ?? exercise.analyzerVersion,
  ),
);

void main() {
  final catalog = defaultMeasuredCatalog();
  final first = catalog.first;
  final second = catalog[1];
  final now = DateTime(2026, 10, 22, 12);

  PracticeResume? latest(List<ExerciseResult> results) => PracticeResume.latest(
    graph: draftSkillGraph,
    goal: PracticeGoal.foundations,
    results: results,
    now: now,
    catalog: catalog,
  );

  test('empty history and future evidence do not create a return target', () {
    expect(latest(const []), isNull);
    expect(
      latest([_result(first, now.add(const Duration(minutes: 1)))]),
      isNull,
    );
  });

  test('latest current cohort wins regardless of history order', () {
    final earlier = _result(first, now.subtract(const Duration(hours: 2)));
    final recent = _result(second, now.subtract(const Duration(minutes: 5)));

    final resume = latest([recent, earlier]);

    expect(resume!.exercise.exerciseId, second.exerciseId);
    expect(resume.attemptedAt, recent.createdAt);
    expect(resume.previousMeasurementValid, isTrue);
  });

  test(
    'stale cohorts are ignored and an invalid current attempt is retryable',
    () {
      final stale = _result(
        second,
        now.subtract(const Duration(minutes: 1)),
        contentVersion: 'retired-content',
      );
      final invalid = _result(
        first,
        now.subtract(const Duration(minutes: 10)),
        valid: false,
      );

      final resume = latest([stale, invalid]);

      expect(resume!.exercise.exerciseId, first.exerciseId);
      expect(resume.previousMeasurementValid, isFalse);
    },
  );

  test('unknown analyzer evidence cannot become the return target', () {
    final unknown = _result(
      first,
      now.subtract(const Duration(minutes: 1)),
      analyzerVersion: 'unknown-analyzer',
    );

    expect(latest([unknown]), isNull);
  });
}
