import 'exercise.dart';
import 'exercise_protocol.dart';
import 'exercise_protocol_fingerprint.dart';
import 'exercise_result.dart';
import 'measurement_provenance.dart';

/// Identity of comparable evidence, independent of score and validity.
/// Invalid attempts in the SAME cohort remain available for retry guidance.
class ResultCohort {
  const ResultCohort({
    required this.exerciseId,
    required this.skill,
    required this.mode,
    required this.difficulty,
    required this.contentVersion,
    required this.scoringVersion,
    required this.source,
    required this.analyzerVersion,
    this.protocolFingerprint,
  });

  factory ResultCohort.forExercise(
    Exercise exercise, {
    required MeasurementSource source,
    required String analyzerVersion,
    String scoringVersion = '2',
  }) => ResultCohort(
    exerciseId: exercise.id,
    skill: exercise.skill,
    mode: exercise.mode,
    difficulty: exercise.difficulty,
    contentVersion: exercise.contentVersion,
    scoringVersion: scoringVersion,
    source: source,
    analyzerVersion: analyzerVersion,
  );

  factory ResultCohort.forConfiguredExercise(
    ConfiguredExercise exercise, {
    required MeasurementSource source,
    required String analyzerVersion,
    String scoringVersion = '2',
  }) => ResultCohort(
    exerciseId: exercise.exercise.id,
    skill: exercise.exercise.skill,
    mode: exercise.exercise.mode,
    difficulty: exercise.exercise.difficulty,
    contentVersion: exercise.exercise.contentVersion,
    scoringVersion: scoringVersion,
    source: source,
    analyzerVersion: analyzerVersion,
    protocolFingerprint: ExerciseProtocolFingerprint.compute(exercise.protocol),
  );

  final String exerciseId;
  final Skill skill;
  final ExerciseMode mode;
  final int difficulty;
  final String contentVersion;
  final String scoringVersion;
  final MeasurementSource source;
  final String analyzerVersion;
  final String? protocolFingerprint;

  bool matches(ExerciseResult result) =>
      result.exerciseId == exerciseId &&
      result.skill == skill &&
      result.exerciseMode == mode &&
      result.difficulty == difficulty &&
      result.contentVersion == contentVersion &&
      result.scoringVersion == scoringVersion &&
      result.provenance.source == source &&
      result.provenance.analyzerVersion == analyzerVersion &&
      (protocolFingerprint == null ||
          (ExerciseProtocolFingerprint.isValid(protocolFingerprint!) &&
              result.measurements[ExerciseProtocolFingerprint.measurementKey] ==
                  protocolFingerprint));
}
