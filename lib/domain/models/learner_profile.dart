enum PracticeGoal { conservatory, foundations, choir }

/// Local guest profile. No account, e-mail or audio; never uploaded.
class LearnerProfile {
  const LearnerProfile({required this.goal, required this.createdAt});

  static const schemaVersion = 1;

  final PracticeGoal goal;
  final DateTime createdAt;

  LearnerProfile copyWith({PracticeGoal? goal}) =>
      LearnerProfile(goal: goal ?? this.goal, createdAt: createdAt);

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'goal': goal.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Strict: unknown version/goal throws instead of guessing a default.
  factory LearnerProfile.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported profile schema');
    }
    final goal = PracticeGoal.values.where((g) => g.name == json['goal']);
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (goal.length != 1 || created == null) {
      throw const FormatException('Invalid profile');
    }
    return LearnerProfile(goal: goal.single, createdAt: created.toUtc());
  }
}
