import '../models/exercise_result.dart';
import '../models/score_metric.dart';

/// A rhythm exercise's reference beats and the user's captured taps/claps,
/// both expressed as millisecond offsets from the exercise start.
class RhythmAnalysisRequest {
  const RhythmAnalysisRequest({
    required this.expectedOnsetsMs,
    required this.userOnsetsMs,
    this.toleranceMs = 120,
    this.onTimeToleranceMs = 10,
    this.latencyCompensationMs = 0,
  });

  final List<int> expectedOnsetsMs;
  final List<int> userOnsetsMs;

  /// Latency-calibrated window (ARCHITECTURE.md § Ritim motoru) within which
  /// a user onset counts as matching an expected beat.
  final int toleranceMs;
  final int onTimeToleranceMs;

  /// An independently calibrated input delay, never inferred from this answer.
  final int latencyCompensationMs;
}

/// One aligned step: matched (both indices), missed (reference only) or
/// extra (user only). Offsets are user − reference after latency handling.
class RhythmEventMatch {
  const RhythmEventMatch({this.referenceIndex, this.userIndex, this.offsetMs})
    : assert(referenceIndex != null || userIndex != null);
  final int? referenceIndex;
  final int? userIndex;
  final int? offsetMs;
  bool get isMatched => referenceIndex != null && userIndex != null;
  bool get isMissed => userIndex == null;
  bool get isExtra => referenceIndex == null;
}

/// Deterministic output of matching user onsets against expected beats.
///
/// Missing, extra, early and late beats are reported separately so the UI
/// and AI Coach can explain the specific timing mistake rather than a
/// single blended score (ARCHITECTURE.md § Ritim motoru).
class RhythmAnalysisResult {
  const RhythmAnalysisResult({
    required this.matchedCount,
    required this.missedCount,
    required this.extraCount,
    required this.earlyCount,
    required this.lateCount,
    required this.averageOffsetMs,
    required this.timingAccuracy,
    required this.averageAbsoluteOffsetMs,
    this.measurementStatus = MeasurementStatus.valid,
    this.alignment = const [],
  });

  final int matchedCount;
  final int missedCount;
  final int extraCount;
  final int earlyCount;
  final int lateCount;

  /// Mean signed offset (ms) of matched onsets from their expected beat.
  final double? averageOffsetMs;
  final double? averageAbsoluteOffsetMs;
  final MeasurementStatus measurementStatus;

  /// Reference-tempo score. Tempo-independent shape scoring is a later mode.
  final ScoreMetric timingAccuracy;

  /// Chronological alignment for per-beat explanation (timeline UI).
  final List<RhythmEventMatch> alignment;
}

/// Contract for rhythm/onset-matching engines. See [PitchAnalyzer] for the
/// same deterministic/testable requirement.
abstract class RhythmAnalyzer {
  Future<RhythmAnalysisResult> analyze(RhythmAnalysisRequest request);
}
