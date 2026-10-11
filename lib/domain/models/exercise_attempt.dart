/// A single user attempt at an [Exercise].
///
/// This only records *that an attempt happened* and, if the user opted in,
/// a pointer to a separately stored recording. It never embeds raw audio
/// (ARCHITECTURE.md § Veri varlıkları: "Ham kayıtlar ExerciseAttempt içine
/// gömülmemeli; ayrı storage kaydı olmalı").
class ExerciseAttempt {
  const ExerciseAttempt({
    required this.id,
    required this.exerciseId,
    required this.userId,
    required this.sessionId,
    required this.startedAt,
    this.completedAt,
    this.rawAudioStorageRef,
  });

  final String id;
  final String exerciseId;
  final String userId;
  final String sessionId;

  final DateTime startedAt;
  final DateTime? completedAt;

  /// Reference (e.g. object storage key) to a raw recording, only ever set
  /// when the user has given explicit consent (ADR-003). Never the audio
  /// bytes themselves.
  final String? rawAudioStorageRef;

  bool get isComplete => completedAt != null;

  ExerciseAttempt complete({DateTime? at, String? rawAudioStorageRef}) {
    return ExerciseAttempt(
      id: id,
      exerciseId: exerciseId,
      userId: userId,
      sessionId: sessionId,
      startedAt: startedAt,
      completedAt: at,
      rawAudioStorageRef: rawAudioStorageRef ?? this.rawAudioStorageRef,
    );
  }
}
