import 'exercise.dart';
import 'score_metric.dart';
import 'immutable_json.dart';
import 'measurement_provenance.dart';

enum MeasurementStatus { valid, invalid }

/// Error categories a deterministic scorer can attach to a result.
///
/// Matches ARCHITECTURE.md § `ExerciseResult` sözleşmesi `errors[].type`.
enum ExerciseErrorType {
  wrongNote,
  wrongOctave,
  late_, // "late" — trailing underscore avoids the `late` keyword.
  early,
  unstable,
  missingVoice,
  noise,
  invalidSignal,
}

extension ExerciseErrorTypeJson on ExerciseErrorType {
  String get wireValue => switch (this) {
    ExerciseErrorType.wrongNote => 'wrong_note',
    ExerciseErrorType.wrongOctave => 'wrong_octave',
    ExerciseErrorType.late_ => 'late',
    ExerciseErrorType.early => 'early',
    ExerciseErrorType.unstable => 'unstable',
    ExerciseErrorType.missingVoice => 'missing_voice',
    ExerciseErrorType.noise => 'noise',
    ExerciseErrorType.invalidSignal => 'invalid_signal',
  };
}

enum ExerciseErrorSeverity { low, medium, high }

/// One detected problem with an attempt, with supporting evidence.
///
/// `evidence` holds raw measurement values (e.g. `centsDifference`) so the
/// UI and AI Coach can explain *why* the error was raised without
/// recomputing it.
class ExerciseError {
  const ExerciseError({
    required this.type,
    required this.severity,
    this.evidence = const {},
  });

  final ExerciseErrorType type;
  final ExerciseErrorSeverity severity;
  final Map<String, Object?> evidence;

  Map<String, Object?> toJson() => {
    'type': type.wireValue,
    'severity': severity.name,
    'evidence': evidence,
  };

  factory ExerciseError.fromJson(Map<String, Object?> json) {
    final type = ExerciseErrorType.values.where(
      (t) => t.wireValue == json['type'],
    );
    final severity = ExerciseErrorSeverity.values.where(
      (s) => s.name == json['severity'],
    );
    final evidence = json['evidence'];
    if (type.length != 1 ||
        severity.length != 1 ||
        evidence is! Map<String, Object?>) {
      throw const FormatException('Invalid exercise error');
    }
    return ExerciseError(
      type: type.single,
      severity: severity.single,
      evidence: evidence,
    );
  }
}

/// Metrics retain their evidence status, not just a number.
///
/// AI never sets or changes these (ADR-001, ADR-009).
class ExerciseScores {
  const ExerciseScores({
    this.overall = const ScoreMetric.notMeasured(),
    this.accuracy = const ScoreMetric.notMeasured(),
    this.timing = const ScoreMetric.notMeasured(),
    this.stability = const ScoreMetric.notMeasured(),
    this.memory = const ScoreMetric.notMeasured(),
  });

  final ScoreMetric overall;
  final ScoreMetric accuracy;
  final ScoreMetric timing;
  final ScoreMetric stability;
  final ScoreMetric memory;

  bool get hasMeasurements =>
      [overall, accuracy, timing, stability, memory].any((s) => s.isMeasured);

  factory ExerciseScores.fromJson(Map<String, Object?> json) {
    ScoreMetric metric(String key) {
      final raw = json[key];
      if (raw is! Map<String, Object?>) {
        throw FormatException('Missing metric $key');
      }
      return ScoreMetric.fromJson(raw);
    }

    return ExerciseScores(
      overall: metric('overall'),
      accuracy: metric('accuracy'),
      timing: metric('timing'),
      stability: metric('stability'),
      memory: metric('memory'),
    );
  }

  Map<String, Object?> toJson() => {
    'overall': overall.toJson(),
    'accuracy': accuracy.toJson(),
    'timing': timing.toJson(),
    'stability': stability.toJson(),
    'memory': memory.toJson(),
  };
}

/// The single output contract every exercise scorer produces
/// (ARCHITECTURE.md § `ExerciseResult` sözleşmesi).
class ExerciseResult {
  ExerciseResult({
    required this.sessionId,
    required this.exerciseId,
    required this.skill,
    required Map<String, Object?> target,
    required Map<String, Object?> measurements,
    required this.scores,
    required this.createdAt,
    List<ExerciseError> errors = const [],
    this.provenance = const MeasurementProvenance(),
    this.measurementStatus = MeasurementStatus.valid,
    this.exerciseMode = ExerciseMode.learning,
    this.difficulty = 1,
    this.contentVersion = '1',
    this.scoringVersion = '2',
  }) : target = freezeJsonMap(target),
       measurements = freezeJsonMap(measurements),
       errors = List.unmodifiable(
         errors.map(
           (error) => ExerciseError(
             type: error.type,
             severity: error.severity,
             evidence: freezeJsonMap(error.evidence),
           ),
         ),
       ) {
    if (measurementStatus == MeasurementStatus.invalid &&
        scores.hasMeasurements) {
      throw ArgumentError('An invalid measurement cannot carry scored metrics');
    }
    if (difficulty < 1) {
      throw ArgumentError.value(difficulty, 'difficulty', 'Must be positive');
    }
  }

  final String sessionId;
  final String exerciseId;
  final Skill skill;

  /// e.g. `{"note": "C4", "frequency": 261.63}`.
  final Map<String, Object?> target;

  /// Raw/derived measurement values behind the scores, e.g.
  /// `{"centsDifference": -100, "octaveOffset": -1, "voicedRatio": 0.91}`.
  final Map<String, Object?> measurements;

  final ExerciseScores scores;
  final List<ExerciseError> errors;
  final DateTime createdAt;
  final MeasurementStatus measurementStatus;
  final ExerciseMode exerciseMode;
  final int difficulty;
  final String contentVersion;
  final String scoringVersion;
  final MeasurementProvenance provenance;

  bool get isValid => measurementStatus == MeasurementStatus.valid;
  bool get isSuccess => isValid && scores.overall.isMeasured && errors.isEmpty;

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'provenance': provenance.toJson(),
    'sessionId': sessionId,
    'exerciseId': exerciseId,
    'skill': skill.name,
    'measurementStatus': measurementStatus.name,
    'exerciseMode': exerciseMode.wireValue,
    'difficulty': difficulty,
    'contentVersion': contentVersion,
    'scoringVersion': scoringVersion,
    'target': target,
    'measurements': measurements,
    'scores': scores.toJson(),
    'errors': errors.map((e) => e.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  /// Strict v2 reader for local history. Any unknown enum, missing field,
  /// non-finite evidence or invalid-with-scores combination throws.
  factory ExerciseResult.fromJson(Map<String, Object?> json) {
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) throw FormatException('Invalid result field $key');
      return value;
    }

    T one<T extends Enum>(List<T> values, String key, String Function(T) wire) {
      final raw = field<String>(key);
      final match = values.where((v) => wire(v) == raw);
      if (match.length != 1) throw FormatException('Unknown $key');
      return match.single;
    }

    if (json['schemaVersion'] != 2) {
      throw const FormatException('Unsupported result schema');
    }
    final created = DateTime.tryParse(field<String>('createdAt'));
    if (created == null) throw const FormatException('Invalid createdAt');
    try {
      return ExerciseResult(
        sessionId: field<String>('sessionId'),
        exerciseId: field<String>('exerciseId'),
        skill: one(Skill.values, 'skill', (s) => s.name),
        target: field<Map<String, Object?>>('target'),
        measurements: field<Map<String, Object?>>('measurements'),
        scores: ExerciseScores.fromJson(field<Map<String, Object?>>('scores')),
        errors: [
          for (final e in field<List<Object?>>('errors'))
            if (e is Map<String, Object?>)
              ExerciseError.fromJson(e)
            else
              throw const FormatException('Invalid error entry'),
        ],
        createdAt: created,
        provenance: MeasurementProvenance.fromJson(
          field<Map<String, Object?>>('provenance'),
        ),
        measurementStatus: one(
          MeasurementStatus.values,
          'measurementStatus',
          (s) => s.name,
        ),
        exerciseMode: one(
          ExerciseMode.values,
          'exerciseMode',
          (m) => m.wireValue,
        ),
        difficulty: field<int>('difficulty'),
        contentVersion: field<String>('contentVersion'),
        scoringVersion: field<String>('scoringVersion'),
      );
    } on ArgumentError catch (e) {
      throw FormatException('Result contract violation: ${e.message}');
    }
  }
}
