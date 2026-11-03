import 'exercise_protocol.dart';

/// Structured, session-observed learning-aid usage.
///
/// This is evidence about how an attempt was made, not a score. The recall
/// delay is the configured policy copied from the protocol; it does not claim
/// measured output/input latency or prove that a human remembered the target.
class AttemptAssistanceEvidence {
  AttemptAssistanceEvidence({
    required this.referencePlaysCompleted,
    required this.pitchHintsUsed,
    required this.transpositionUsed,
    required this.accompanimentUsed,
    required this.configuredRecallDelayMs,
  }) {
    if (referencePlaysCompleted < 1 ||
        referencePlaysCompleted > maxReferencePlays ||
        pitchHintsUsed < 0 ||
        pitchHintsUsed > maxPitchHints ||
        configuredRecallDelayMs < 0 ||
        configuredRecallDelayMs > maxRecallDelayMs) {
      throw ArgumentError('Invalid attempt assistance evidence');
    }
  }

  static const schemaVersion = 1;
  static const maxReferencePlays = ExerciseProtocol.maxReferencePlaysLimit;
  static const maxPitchHints = 256;
  static const maxRecallDelayMs = ExerciseProtocol.maxRecallDelayMs;
  static const measurementKey = 'assistance';

  factory AttemptAssistanceEvidence.forProtocol(
    ExerciseProtocol protocol, {
    required int referencePlaysCompleted,
    int pitchHintsUsed = 0,
    bool transpositionUsed = false,
    bool accompanimentUsed = false,
  }) {
    if (referencePlaysCompleted > protocol.maxReferencePlays ||
        (pitchHintsUsed > 0 && !protocol.allowPitchHint) ||
        (transpositionUsed && !protocol.allowTransposition) ||
        (accompanimentUsed && !protocol.allowAccompaniment)) {
      throw ArgumentError('Assistance use conflicts with exercise protocol');
    }
    return AttemptAssistanceEvidence(
      referencePlaysCompleted: referencePlaysCompleted,
      pitchHintsUsed: pitchHintsUsed,
      transpositionUsed: transpositionUsed,
      accompanimentUsed: accompanimentUsed,
      configuredRecallDelayMs: protocol.recallDelayMs,
    );
  }

  final int referencePlaysCompleted;
  final int pitchHintsUsed;
  final bool transpositionUsed;
  final bool accompanimentUsed;
  final int configuredRecallDelayMs;

  bool get isIndependent =>
      referencePlaysCompleted == 1 &&
      pitchHintsUsed == 0 &&
      !transpositionUsed &&
      !accompanimentUsed;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'referencePlaysCompleted': referencePlaysCompleted,
    'pitchHintsUsed': pitchHintsUsed,
    'transpositionUsed': transpositionUsed,
    'accompanimentUsed': accompanimentUsed,
    'configuredRecallDelayMs': configuredRecallDelayMs,
  };

  factory AttemptAssistanceEvidence.fromJson(Map<String, Object?> json) {
    const keys = {
      'schemaVersion',
      'referencePlaysCompleted',
      'pitchHintsUsed',
      'transpositionUsed',
      'accompanimentUsed',
      'configuredRecallDelayMs',
    };
    if (json.length != keys.length ||
        !json.keys.every(keys.contains) ||
        json['schemaVersion'] != schemaVersion ||
        json['referencePlaysCompleted'] is! int ||
        json['pitchHintsUsed'] is! int ||
        json['transpositionUsed'] is! bool ||
        json['accompanimentUsed'] is! bool ||
        json['configuredRecallDelayMs'] is! int) {
      throw const FormatException('Invalid assistance evidence');
    }
    try {
      return AttemptAssistanceEvidence(
        referencePlaysCompleted: json['referencePlaysCompleted']! as int,
        pitchHintsUsed: json['pitchHintsUsed']! as int,
        transpositionUsed: json['transpositionUsed']! as bool,
        accompanimentUsed: json['accompanimentUsed']! as bool,
        configuredRecallDelayMs: json['configuredRecallDelayMs']! as int,
      );
    } on ArgumentError {
      throw const FormatException('Invalid assistance evidence');
    }
  }

  /// Fail-closed independence claim for mastery consumers.
  ///
  /// Legacy results have only `referencePlays`; new results must keep that
  /// field consistent with the structured evidence. Malformed or conflicting
  /// evidence is treated as assisted, never as independent.
  static bool claimsIndependent(Map<String, Object?> measurements) {
    final raw = measurements[measurementKey];
    if (raw == null) {
      return measurements['referencePlays'] == 1;
    }
    if (raw is! Map<String, Object?>) return false;
    try {
      final evidence = AttemptAssistanceEvidence.fromJson(raw);
      final legacyPlays = measurements['referencePlays'];
      return (legacyPlays == null ||
              legacyPlays == evidence.referencePlaysCompleted) &&
          evidence.isIndependent;
    } on FormatException {
      return false;
    }
  }
}
