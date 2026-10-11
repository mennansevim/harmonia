import '../models/exercise.dart';
import '../models/exercise_result.dart';
import '../models/score_metric.dart';
import '../models/measurement_provenance.dart';

/// AI-02a: the ONLY data a future server-side coach may see. Built from a
/// stored result: statuses, rounded measured values, error counts and an
/// allow-list of next exercises. No audio, no free text, no identity.
/// AI never sets scores; it may only explain and pick an allowed exercise.
class CoachInput {
  CoachInput._(this.payload, this.allowedExerciseIds, this.measured);

  static const promptVersion = 'coach-prompt-1';
  static const model = 'gpt-4o-mini';

  final Map<String, Object?> payload;
  final Set<String> allowedExerciseIds;
  final bool measured;

  /// Returns null when coaching is not allowed for this result: mock /
  /// synthetic / unverified sources never reach the model.
  static CoachInput? fromResult(
    ExerciseResult r, {
    required Set<String> allowedExerciseIds,
  }) {
    const allowedSources = {
      MeasurementSource.touch,
      MeasurementSource.microphone,
    };
    if (!allowedSources.contains(r.provenance.source)) return null;
    Object? metric(ScoreMetric m) => m.isMeasured
        ? {'status': 'measured', 'value': m.value!.round()}
        : {'status': m.status.wireValue};
    const countKeys = {'matched', 'missed', 'extra', 'early', 'late'};
    return CoachInput._(
      Map.unmodifiable({
        'schemaVersion': 1,
        'promptVersion': promptVersion,
        'skill': r.skill.name,
        'mode': r.exerciseMode.wireValue,
        'measurementStatus': r.measurementStatus.name,
        'scores': {
          'timing': metric(r.scores.timing),
          'accuracy': metric(r.scores.accuracy),
          'memory': metric(r.scores.memory),
        },
        'counts': {
          for (final k in countKeys)
            if (r.measurements[k] is int) k: r.measurements[k],
        },
        'errors': [for (final e in r.errors) e.type.wireValue],
        'allowedNextExercises': allowedExerciseIds.toList()..sort(),
      }),
      Set.unmodifiable(allowedExerciseIds),
      r.isValid,
    );
  }
}

enum CoachRejection {
  malformed,
  scoreField,
  unknownExercise,
  tooLong,
  forbiddenClaim,
  praiseOnInvalid,
}

class CoachReply {
  const CoachReply({required this.summary, this.nextExerciseId});
  final String summary;
  final String? nextExerciseId;
}

/// Strict validation of a model reply. Any failure → caller uses fallback.
class CoachReplyValidator {
  const CoachReplyValidator._();

  static const maxSummaryChars = 280;
  static final _forbidden = RegExp(
    r'(%\s*\d|\d+\s*%|hazırsın|garanti|kesin kazan|eğitimci olarak|öğretmenin olarak|'
    r'ses tel|nodül|hastalık|teşhis|doktor|puanın|skorun)',
    caseSensitive: false,
  );
  static final _praise = RegExp(
    r'(harika|mükemmel|doğru söyledin|başardın|tebrik)',
    caseSensitive: false,
  );

  static (CoachReply?, CoachRejection?) validate(
    Object? raw,
    CoachInput input,
  ) {
    if (raw is! Map<String, Object?> || raw['schemaVersion'] != 1) {
      return (null, CoachRejection.malformed);
    }
    const allowedKeys = {'schemaVersion', 'summary', 'nextExerciseId'};
    for (final k in raw.keys) {
      if (k.toLowerCase().contains('score') ||
          k.toLowerCase().contains('puan')) {
        return (null, CoachRejection.scoreField);
      }
      if (!allowedKeys.contains(k)) return (null, CoachRejection.malformed);
    }
    final summary = raw['summary'];
    final next = raw['nextExerciseId'];
    if (summary is! String || summary.trim().isEmpty) {
      return (null, CoachRejection.malformed);
    }
    if (next != null && next is! String) {
      return (null, CoachRejection.malformed);
    }
    if (summary.length > maxSummaryChars) return (null, CoachRejection.tooLong);
    if (next != null && !input.allowedExerciseIds.contains(next)) {
      return (null, CoachRejection.unknownExercise);
    }
    if (_forbidden.hasMatch(summary)) {
      return (null, CoachRejection.forbiddenClaim);
    }
    if (!input.measured && _praise.hasMatch(summary)) {
      return (null, CoachRejection.praiseOnInvalid);
    }
    return (
      CoachReply(summary: summary.trim(), nextExerciseId: next as String?),
      null,
    );
  }
}
