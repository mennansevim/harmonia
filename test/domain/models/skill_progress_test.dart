import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/skill_progress.dart';
import 'package:resonia/domain/models/score_metric.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  ExerciseResult resultWith({
    double? accuracy,
    double? stability,
    double? timing,
    double? memory,
    MeasurementStatus status = MeasurementStatus.valid,
    Skill skill = Skill.pitch,
    int difficulty = 1,
    ExerciseMode mode = ExerciseMode.learning,
    String contentVersion = '1',
    String scoringVersion = '2',
    DateTime? createdAt,
  }) {
    return ExerciseResult(
      sessionId: 's1',
      exerciseId: 'e1',
      skill: skill,
      measurementStatus: status,
      difficulty: difficulty,
      exerciseMode: mode,
      contentVersion: contentVersion,
      scoringVersion: scoringVersion,
      target: const {'note': 'C4', 'frequency': 261.63},
      measurements: const {},
      scores: ExerciseScores(
        overall: accuracy == null
            ? const ScoreMetric.notMeasured()
            : ScoreMetric.measured(accuracy),
        accuracy: accuracy == null
            ? const ScoreMetric.notMeasured()
            : ScoreMetric.measured(accuracy),
        timing: timing == null
            ? const ScoreMetric.notMeasured()
            : ScoreMetric.measured(timing),
        stability: stability == null
            ? const ScoreMetric.notMeasured()
            : ScoreMetric.measured(stability),
        memory: memory == null
            ? const ScoreMetric.notMeasured()
            : ScoreMetric.measured(memory),
      ),
      createdAt: createdAt ?? now,
    );
  }

  test('no evidence is unknown, not a measured zero', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    );

    expect(progress.attemptsCount, 0);
    expect(progress.accuracyAvg, isNull);
    expect(progress.stabilityAvg, isNull);
    expect(progress.accuracy.sampleCount, 0);
  });

  test('withResult folds a single result in directly', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    );
    final result = resultWith(
      accuracy: 80,
      stability: 90,
      timing: 100,
      memory: 100,
    );

    final updated = progress.withResult(result);

    expect(updated.attemptsCount, 1);
    expect(updated.accuracyAvg, 80);
    expect(updated.stabilityAvg, 90);
  });

  test('withResult computes a running average across multiple results', () {
    var progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    );

    progress = progress.withResult(
      resultWith(accuracy: 100, stability: 100, timing: 100, memory: 100),
    );
    progress = progress.withResult(
      resultWith(accuracy: 50, stability: 60, timing: 100, memory: 100),
    );

    expect(progress.attemptsCount, 2);
    expect(progress.accuracyAvg, 75);
    expect(progress.stabilityAvg, 80);
  });

  test('withResult rejects a result from a different skill', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.rhythm,
      now: now,
    );
    final pitchResult = resultWith(
      accuracy: 80,
      stability: 90,
      timing: 100,
      memory: 100,
    );

    expect(() => progress.withResult(pitchResult), throwsArgumentError);
  });

  test('invalid measurements do not change averages or attempt count', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    ).withResult(resultWith(accuracy: 80));
    final invalid = resultWith(
      status: MeasurementStatus.invalid,
      createdAt: now.add(const Duration(days: 1)),
    );
    expect(progress.withResult(invalid), same(progress));
    expect(progress.attemptsCount, 1);
    expect(progress.accuracyAvg, 80);
  });

  test('each metric uses only its own measured sample count', () {
    var progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    );
    progress = progress.withResult(resultWith(accuracy: 80));
    progress = progress.withResult(resultWith(accuracy: 100, timing: 40));
    expect(progress.accuracyAvg, 90);
    expect(progress.accuracy.sampleCount, 2);
    expect(progress.timingAvg, 40);
    expect(progress.timing.sampleCount, 1);
    expect(progress.memoryAvg, isNull);
  });

  test('measured zero remains evidence', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    ).withResult(resultWith(accuracy: 0));
    expect(progress.accuracyAvg, 0);
    expect(progress.accuracy.sampleCount, 1);
  });

  test('empty analysis does not count as an assessed attempt', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    );
    expect(progress.withResult(resultWith()), same(progress));
  });

  test('difficulty, mode and version cohorts cannot be silently mixed', () {
    final progress = SkillProgress.initial(
      userId: 'u1',
      skill: Skill.pitch,
      now: now,
    );
    for (final other in [
      resultWith(accuracy: 80, difficulty: 2),
      resultWith(accuracy: 80, mode: ExerciseMode.recallExam),
      resultWith(accuracy: 80, contentVersion: 'new'),
      resultWith(accuracy: 80, scoringVersion: '3'),
    ]) {
      expect(() => progress.withResult(other), throwsArgumentError);
    }
  });

  test(
    'an older imported result does not rewind the last measurement date',
    () {
      final progress =
          SkillProgress.initial(
            userId: 'u1',
            skill: Skill.pitch,
            now: now,
          ).withResult(
            resultWith(
              accuracy: 80,
              createdAt: now.subtract(const Duration(days: 1)),
            ),
          );
      expect(progress.lastUpdated, now);
    },
  );
}
