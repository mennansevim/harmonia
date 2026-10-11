import '../audio/rhythm_imitation.dart';
import '../content/rhythm_patterns.dart';
import '../models/exercise_result.dart';
import '../models/measurement_provenance.dart';
import '../perception/pitch_comparison.dart';
import 'rhythm_next_step.dart';

/// An in-app exercise that can produce comparable evidence for a skill.
abstract interface class MeasuredExercise {
  String get exerciseId;
  String get title;
  String get contentVersion;
  String get analyzerVersion;

  /// Draft criterion for one attempt (educator review pending).
  bool isClean(ExerciseResult r);
}

class RhythmMeasuredExercise implements MeasuredExercise {
  RhythmMeasuredExercise(this.pattern);
  final RhythmPattern pattern;
  @override
  String get exerciseId => pattern.exercise.exercise.id;
  @override
  String get title => pattern.title;
  @override
  String get contentVersion => pattern.exercise.exercise.contentVersion;
  @override
  String get analyzerVersion => RhythmImitationOutcome.version;
  @override
  bool isClean(ExerciseResult r) => RhythmNextStepPolicy.isClean(r);
}

class PitchComparisonMeasuredExercise implements MeasuredExercise {
  PitchComparisonMeasuredExercise(this.level);
  final PitchComparisonLevel level;

  /// Draft: ≥ 7 of 8 correct (P(≥7/8 | guessing) ≈ 3.5 %).
  static const minCorrect = 7;

  @override
  String get exerciseId => level.exerciseId;
  @override
  String get title => level.title;
  @override
  String get contentVersion => level.contentVersion;
  @override
  String get analyzerVersion => PitchComparisonOutcome.version;
  @override
  bool isClean(ExerciseResult r) =>
      r.isValid && (r.measurements['correct'] as int? ?? 0) >= minCorrect;
}

/// Comparable results: same id, content and analyzer version, touch source.
List<ExerciseResult> comparableResults(
  List<ExerciseResult> results,
  MeasuredExercise e,
) => [
  for (final r in results)
    if (r.exerciseId == e.exerciseId &&
        r.contentVersion == e.contentVersion &&
        r.provenance.source == MeasurementSource.touch &&
        r.provenance.analyzerVersion == e.analyzerVersion)
      r,
]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

List<MeasuredExercise> defaultMeasuredCatalog() => [
  for (final p in draftRhythmPatterns) RhythmMeasuredExercise(p),
  for (final l in draftPitchLevels) PitchComparisonMeasuredExercise(l),
];
