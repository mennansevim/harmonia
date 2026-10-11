/// Skill categories an [Exercise] can measure.
///
/// Matches the `skill` field of the `ExerciseResult` contract
/// (see ARCHITECTURE.md § `ExerciseResult` sözleşmesi).
enum Skill { pitch, interval, chord, rhythm, melody, range }

enum ExerciseMode { learning, recallExam, sightReading, choirPractice }

extension ExerciseModeJson on ExerciseMode {
  String get wireValue => switch (this) {
    ExerciseMode.learning => 'learning',
    ExerciseMode.recallExam => 'recall_exam',
    ExerciseMode.sightReading => 'sight_reading',
    ExerciseMode.choirPractice => 'choir_practice',
  };
}

/// A single named musical note used as a target, e.g. "C4" at 261.63 Hz.
class TargetNote {
  const TargetNote({required this.note, required this.frequencyHz});

  final String note;
  final double frequencyHz;

  Map<String, Object?> toJson() => {'note': note, 'frequency': frequencyHz};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetNote &&
          runtimeType == other.runtimeType &&
          note == other.note &&
          frequencyHz == other.frequencyHz;

  @override
  int get hashCode => Object.hash(note, frequencyHz);
}

/// A definition of a practice exercise (not an attempt at one).
///
/// The MVP's first exercise type is the single-tone "dinle-söyle" exercise
/// (PRODUCT_SPEC.md § Egzersiz türleri).
class Exercise {
  const Exercise({
    required this.id,
    required this.skill,
    required this.title,
    required this.difficulty,
    this.targetNote,
    this.description,
    this.mode = ExerciseMode.learning,
    this.contentVersion = '1',
  });

  final String id;
  final Skill skill;
  final String title;
  final String? description;

  /// 1 (easiest) and up. Difficulty selection is rule-based, never AI-decided
  /// (AI_COACH.md § AI'nin ürün içindeki sınırı).
  final int difficulty;
  final ExerciseMode mode;
  final String contentVersion;

  /// Populated for single-tone / interval-style exercises.
  final TargetNote? targetNote;
}
