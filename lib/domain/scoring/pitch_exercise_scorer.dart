import '../audio/pitch_analyzer.dart';
import '../models/exercise.dart';
import '../models/exercise_result.dart';
import '../models/score_metric.dart';

/// Turns a raw [PitchAnalysisResult] into the shared [ExerciseResult]
/// contract for single-tone ("dinle-söyle") exercises.
///
/// All thresholds here are the deterministic success/failure rules from
/// ARCHITECTURE.md § Pitch motoru. In particular, ADR-006 requires that an
/// octave mismatch is *never* silently treated as success, even when the
/// sung pitch class matches the target closely.
///
/// This class holds no state and does no I/O, so it is fully unit-testable
/// without a real microphone or DSP engine.
class PitchExerciseScorer {
  const PitchExerciseScorer({
    this.noteToleranceCents = 50,
    this.stabilityToleranceCents = 25,
    this.minVoicedRatio = 0.6,
  });

  /// Cents from target (ignoring octave) allowed before it counts as a
  /// wrong note rather than an accurate one.
  final double noteToleranceCents;

  /// Max acceptable pitch standard deviation (cents) before a correct note
  /// is flagged as unstable.
  final double stabilityToleranceCents;

  /// Minimum fraction of voiced frames required to trust the measurement
  /// at all; below this the input is treated as noise/silence.
  final double minVoicedRatio;

  ExerciseResult score({
    required Exercise exercise,
    required String sessionId,
    required PitchAnalysisResult pitch,
    required DateTime createdAt,
  }) {
    final target = exercise.targetNote;
    if (target == null ||
        !target.frequencyHz.isFinite ||
        target.frequencyHz <= 0 ||
        exercise.difficulty < 1) {
      throw ArgumentError('Single-tone exercises require a valid target');
    }

    final measurements = <String, Object?>{
      'frequency': pitch.detectedFrequencyHz,
      'centsDifference': pitch.centsDifference,
      'octaveOffset': pitch.octaveOffset,
      'voicedRatio': pitch.voicedRatio,
      'stabilityCents': pitch.stabilityCents,
    };

    ExerciseResult invalidResult(ExerciseErrorType type) => ExerciseResult(
      provenance: pitch.provenance,
      sessionId: sessionId,
      exerciseId: exercise.id,
      skill: exercise.skill,
      target: target.toJson(),
      measurements: measurements,
      measurementStatus: MeasurementStatus.invalid,
      exerciseMode: exercise.mode,
      difficulty: exercise.difficulty,
      contentVersion: exercise.contentVersion,
      scores: const ExerciseScores(
        timing: ScoreMetric.notApplicable(),
        memory: ScoreMetric.notApplicable(),
      ),
      errors: [
        ExerciseError(
          type: type,
          severity: ExerciseErrorSeverity.high,
          evidence: {'voicedRatio': measurements['voicedRatio']},
        ),
      ],
      createdAt: createdAt,
    );

    // Non-finite data must not create a bogus score or break JSON export.
    if (!pitch.voicedRatio.isFinite ||
        pitch.voicedRatio < 0 ||
        pitch.voicedRatio > 1 ||
        !pitch.stabilityCents.isFinite ||
        pitch.stabilityCents < 0 ||
        (pitch.detectedFrequencyHz != null &&
            (!pitch.detectedFrequencyHz!.isFinite ||
                pitch.detectedFrequencyHz! <= 0)) ||
        (pitch.centsDifference != null && !pitch.centsDifference!.isFinite)) {
      // Keep diagnostics JSON-safe, without disguising bad numbers as zero.
      for (final key in measurements.keys.toList()) {
        final value = measurements[key];
        if (value is double && !value.isFinite) measurements[key] = null;
      }
      return invalidResult(ExerciseErrorType.invalidSignal);
    }

    // No usable signal is an invalid measurement, not student failure.
    if (pitch.detectedFrequencyHz == null || pitch.centsDifference == null) {
      return invalidResult(ExerciseErrorType.missingVoice);
    }

    // Noise-dominated input: measurement is not trustworthy.
    if (pitch.isNoisy || pitch.voicedRatio < minVoicedRatio) {
      return invalidResult(ExerciseErrorType.noise);
    }

    final centsDifference = pitch.centsDifference!;
    final accuracy = _accuracyScore(centsDifference);
    final stability = _stabilityScore(pitch.stabilityCents);
    final errors = <ExerciseError>[];

    // ADR-006: a wrong octave is reported as an error and never counted as
    // success, regardless of how close the pitch class is.
    if (pitch.octaveOffset != 0) {
      errors.add(
        ExerciseError(
          type: ExerciseErrorType.wrongOctave,
          severity: ExerciseErrorSeverity.medium,
          evidence: {'octaveOffset': pitch.octaveOffset},
        ),
      );
    } else if (centsDifference.abs() > noteToleranceCents) {
      errors.add(
        ExerciseError(
          type: ExerciseErrorType.wrongNote,
          severity: centsDifference.abs() > noteToleranceCents * 2
              ? ExerciseErrorSeverity.high
              : ExerciseErrorSeverity.medium,
          evidence: {'centsDifference': centsDifference},
        ),
      );
    }

    if (pitch.stabilityCents > stabilityToleranceCents) {
      errors.add(
        ExerciseError(
          type: ExerciseErrorType.unstable,
          severity: ExerciseErrorSeverity.low,
          evidence: {'stabilityCents': pitch.stabilityCents},
        ),
      );
    }

    final hasOctaveError = errors.any(
      (e) => e.type == ExerciseErrorType.wrongOctave,
    );
    final hasNoteError = errors.any(
      (e) => e.type == ExerciseErrorType.wrongNote,
    );

    // Octave/note errors cap the overall score even if the raw accuracy
    // number looks reasonable, so the UI never presents them as a pass.
    final overall = (hasOctaveError || hasNoteError)
        ? (accuracy * 0.5).clamp(0, 49).toDouble()
        : ((accuracy * 0.6) + (stability * 0.4)).clamp(0, 100).toDouble();

    return ExerciseResult(
      provenance: pitch.provenance,
      sessionId: sessionId,
      exerciseId: exercise.id,
      skill: exercise.skill,
      exerciseMode: exercise.mode,
      difficulty: exercise.difficulty,
      contentVersion: exercise.contentVersion,
      target: target.toJson(),
      measurements: measurements,
      scores: ExerciseScores(
        overall: ScoreMetric.measured(overall),
        accuracy: ScoreMetric.measured(accuracy),
        timing: const ScoreMetric.notApplicable(),
        stability: ScoreMetric.measured(stability),
        memory: const ScoreMetric.notApplicable(),
      ),
      errors: errors,
      createdAt: createdAt,
    );
  }

  double _accuracyScore(double centsDifference) =>
      (100 - centsDifference.abs()).clamp(0, 100).toDouble();

  double _stabilityScore(double stabilityCents) =>
      (100 - (stabilityCents * 2)).clamp(0, 100).toDouble();
}
