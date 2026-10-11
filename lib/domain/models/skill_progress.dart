import 'exercise.dart';
import 'exercise_result.dart';
import 'score_metric.dart';
import 'measurement_provenance.dart';

/// Each metric has its own denominator; absence never becomes a zero.
class MetricAggregate {
  const MetricAggregate._(this.sampleCount, this.total);
  const MetricAggregate.empty() : this._(0, 0);

  final int sampleCount;
  final double total;
  double? get average => sampleCount == 0 ? null : total / sampleCount;

  MetricAggregate withMetric(ScoreMetric metric) => metric.isMeasured
      ? MetricAggregate._(sampleCount + 1, total + metric.value!)
      : this;
}

/// Progress for one comparable skill/difficulty/mode/content/scoring cohort.
///
/// PRODUCT_SPEC.md keeps skills scored separately rather than one combined
/// score, so a `SkillProgress` exists per (user, skill) pair.
class SkillProgress {
  const SkillProgress({
    required this.userId,
    required this.skill,
    required this.lastUpdated,
    this.attemptsCount = 0,
    this.difficulty = 1,
    this.exerciseMode = ExerciseMode.learning,
    this.contentVersion = '1',
    this.scoringVersion = '2',
    this.measurementSource = MeasurementSource.unverified,
    this.analyzerVersion = 'unknown',
    this.accuracy = const MetricAggregate.empty(),
    this.stability = const MetricAggregate.empty(),
    this.timing = const MetricAggregate.empty(),
    this.memory = const MetricAggregate.empty(),
  });

  factory SkillProgress.initial({
    required String userId,
    required Skill skill,
    required DateTime now,
    int difficulty = 1,
    ExerciseMode exerciseMode = ExerciseMode.learning,
    String contentVersion = '1',
    String scoringVersion = '2',
    MeasurementSource measurementSource = MeasurementSource.unverified,
    String analyzerVersion = 'unknown',
  }) {
    return SkillProgress(
      userId: userId,
      skill: skill,
      lastUpdated: now,
      difficulty: difficulty,
      exerciseMode: exerciseMode,
      contentVersion: contentVersion,
      scoringVersion: scoringVersion,
      measurementSource: measurementSource,
      analyzerVersion: analyzerVersion,
    );
  }

  final String userId;
  final Skill skill;

  final int attemptsCount;
  final int difficulty;
  final ExerciseMode exerciseMode;
  final String contentVersion;
  final String scoringVersion;
  final MeasurementSource measurementSource;
  final String analyzerVersion;
  final MetricAggregate accuracy;
  final MetricAggregate stability;
  final MetricAggregate timing;
  final MetricAggregate memory;

  double? get accuracyAvg => accuracy.average;
  double? get stabilityAvg => stability.average;
  double? get timingAvg => timing.average;
  double? get memoryAvg => memory.average;

  final DateTime lastUpdated;

  /// Folds a new [ExerciseResult] into the running average.
  ///
  /// Pure aggregation, no AI involved — see ARCHITECTURE.md's domain layer
  /// list ("Progress aggregation").
  SkillProgress withResult(ExerciseResult result) {
    if (result.skill != skill ||
        result.difficulty != difficulty ||
        result.exerciseMode != exerciseMode ||
        result.contentVersion != contentVersion ||
        result.scoringVersion != scoringVersion ||
        result.provenance.source != measurementSource ||
        result.provenance.analyzerVersion != analyzerVersion) {
      throw ArgumentError('Cannot aggregate results from a different cohort');
    }
    if (!result.isValid || !result.scores.hasMeasurements) return this;

    return SkillProgress(
      userId: userId,
      skill: skill,
      attemptsCount: attemptsCount + 1,
      difficulty: difficulty,
      exerciseMode: exerciseMode,
      contentVersion: contentVersion,
      scoringVersion: scoringVersion,
      measurementSource: measurementSource,
      analyzerVersion: analyzerVersion,
      accuracy: accuracy.withMetric(result.scores.accuracy),
      stability: stability.withMetric(result.scores.stability),
      timing: timing.withMetric(result.scores.timing),
      memory: memory.withMetric(result.scores.memory),
      lastUpdated: result.createdAt.isAfter(lastUpdated)
          ? result.createdAt
          : lastUpdated,
    );
  }
}
