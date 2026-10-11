import '../models/exercise.dart';
import '../models/exercise_protocol.dart';
import '../models/exercise_result.dart';
import '../models/measurement_provenance.dart';
import '../models/score_metric.dart';
import 'event_rhythm_analyzer.dart';
import 'rhythm_analyzer.dart';

enum RhythmImitationStatus { measured, tooFewTaps, invalidInput }

enum BeatVerdict { onTime, early, late, missed, extra, anchor }

/// One row of the result timeline, in reference/user order.
class BeatTimelineEntry {
  const BeatTimelineEntry({
    required this.verdict,
    this.referenceIndex,
    this.userIndex,
    this.offsetMs,
  });
  final BeatVerdict verdict;
  final int? referenceIndex;
  final int? userIndex;
  final int? offsetMs;
}

class RhythmImitationOutcome {
  const RhythmImitationOutcome._({
    required this.status,
    this.analysis,
    this.timeline = const [],
    this.spanRatio,
    required this.referencePlays,
  });

  static const version = 'rhythm-imitation-1/first-tap-anchor';

  final RhythmImitationStatus status;

  /// Analysis of every event AFTER the anchor pair (see evaluator docs).
  final RhythmAnalysisResult? analysis;
  final List<BeatTimelineEntry> timeline;

  /// User span / reference span (first→last tap vs first→last onset).
  /// Diagnostic tempo hint only; not a tempo score.
  final double? spanRatio;
  final int referencePlays;

  bool get isMeasured => status == RhythmImitationStatus.measured;

  /// Hypothesis: >15 % span difference is worth telling the student.
  static const tempoHintThreshold = 0.15;
  bool get tempoDiffers =>
      spanRatio != null && (spanRatio! - 1).abs() > tempoHintThreshold;

  ExerciseResult toResult({
    required ConfiguredExercise exercise,
    required String sessionId,
    required DateTime createdAt,
    bool retentionCheck = false,
  }) {
    final a = analysis;
    final measured = isMeasured && a != null;
    return ExerciseResult(
      sessionId: sessionId,
      exerciseId: exercise.exercise.id,
      skill: Skill.rhythm,
      target: {
        'rhythmOnsetsBeats': exercise.protocol.rhythmOnsetsBeats,
        'tempoBpm': exercise.protocol.tempoBpm,
      },
      measurements: {
        'anchor': 'first_tap',
        'anchorTimingMeasured': false,
        'referencePlays': referencePlays,
        'retentionCheck': retentionCheck,
        'spanRatio': spanRatio,
        if (a != null) ...{
          'matched': a.matchedCount,
          'missed': a.missedCount,
          'extra': a.extraCount,
          'early': a.earlyCount,
          'late': a.lateCount,
          'meanOffsetMs': a.averageOffsetMs,
          'meanAbsoluteOffsetMs': a.averageAbsoluteOffsetMs,
        },
      },
      scores: measured
          ? ExerciseScores(
              overall: a.timingAccuracy,
              timing: a.timingAccuracy,
              accuracy: const ScoreMetric.notApplicable(),
              stability: const ScoreMetric.notApplicable(),
              memory: const ScoreMetric.notMeasured(),
            )
          : const ExerciseScores(),
      measurementStatus: measured
          ? MeasurementStatus.valid
          : MeasurementStatus.invalid,
      exerciseMode: exercise.exercise.mode,
      difficulty: exercise.exercise.difficulty,
      contentVersion: exercise.exercise.contentVersion,
      createdAt: createdAt,
      provenance: const MeasurementProvenance(
        source: MeasurementSource.touch,
        analyzerVersion: version,
      ),
    );
  }
}

/// Listen-then-repeat rhythm: there is no shared clock between the reference
/// playback and the answer, so the first tap is DEFINED as the first
/// reference onset. That anchor pair is shown but never timed or scored;
/// every later tap is aligned at the reference tempo with the existing
/// [EventRhythmAnalyzer] tolerances (unchanged rubric). No latency is
/// applied or inferred: in-time (count-in) tapping is a separate mode that
/// needs CAL-03.
class RhythmImitationEvaluator {
  const RhythmImitationEvaluator._();

  static const maxTaps = 256;

  static Future<RhythmImitationOutcome> evaluate({
    required ExerciseProtocol protocol,
    required List<Duration> tapTimestamps,
    int referencePlays = 1,
  }) async {
    final beatMs = 60000 / protocol.tempoBpm;
    final reference = [
      for (final beat in protocol.rhythmOnsetsBeats) (beat * beatMs).round(),
    ];
    RhythmImitationOutcome invalid(RhythmImitationStatus status) =>
        RhythmImitationOutcome._(
          status: status,
          referencePlays: referencePlays,
        );
    if (reference.length < 2 || tapTimestamps.length > maxTaps) {
      return invalid(RhythmImitationStatus.invalidInput);
    }
    for (var i = 1; i < tapTimestamps.length; i++) {
      if (tapTimestamps[i] < tapTimestamps[i - 1]) {
        return invalid(RhythmImitationStatus.invalidInput);
      }
    }
    if (tapTimestamps.length < 2) {
      return invalid(RhythmImitationStatus.tooFewTaps);
    }
    final first = tapTimestamps.first;
    final user = [
      for (final t in tapTimestamps)
        (t - first).inMicroseconds ~/ 1000 + reference.first,
    ];
    final request = RhythmAnalysisRequest(
      expectedOnsetsMs: reference.sublist(1),
      userOnsetsMs: user.sublist(1),
    );
    final analysis = await EventRhythmAnalyzer().analyze(request);
    // Same early/late deadband the analyzer uses for its counts.
    final deadband = request.onTimeToleranceMs < request.toleranceMs
        ? request.onTimeToleranceMs
        : request.toleranceMs;
    final timeline = <BeatTimelineEntry>[
      const BeatTimelineEntry(
        verdict: BeatVerdict.anchor,
        referenceIndex: 0,
        userIndex: 0,
      ),
      for (final step in analysis.alignment)
        BeatTimelineEntry(
          verdict: step.isExtra
              ? BeatVerdict.extra
              : step.isMissed
              ? BeatVerdict.missed
              : step.offsetMs! < -deadband
              ? BeatVerdict.early
              : step.offsetMs! > deadband
              ? BeatVerdict.late
              : BeatVerdict.onTime,
          referenceIndex: step.referenceIndex == null
              ? null
              : step.referenceIndex! + 1,
          userIndex: step.userIndex == null ? null : step.userIndex! + 1,
          offsetMs: step.offsetMs,
        ),
    ];
    final referenceSpan = reference.last - reference.first;
    final userSpan = user.last - user.first;
    return RhythmImitationOutcome._(
      status: RhythmImitationStatus.measured,
      analysis: analysis,
      timeline: List.unmodifiable(timeline),
      spanRatio: userSpan / referenceSpan,
      referencePlays: referencePlays,
    );
  }
}
