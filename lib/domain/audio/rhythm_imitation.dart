import '../models/exercise.dart';
import '../models/attempt_assistance_evidence.dart';
import '../models/exercise_protocol.dart';
import '../models/exercise_protocol_fingerprint.dart';
import '../models/exercise_result.dart';
import '../models/measurement_provenance.dart';
import '../models/score_metric.dart';
import 'event_rhythm_analyzer.dart';
import 'rhythm_analyzer.dart';
import 'rhythm_reference_clock.dart';

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
    this.guided = false,
    this.referenceOnsetsMs = const [],
    this.userOnsetsMs = const [],
    this.tempoFitted = false,
  });

  /// v2 (2026-11-10, user decision: echoes were too hard to pass): wider
  /// windows below and a gentle tempo fit. v1 results form their own cohort.
  static const version = 'rhythm-imitation-2/first-tap-anchor-tempo-fit';

  final RhythmImitationStatus status;

  /// Analysis of every event AFTER the anchor pair (see evaluator docs).
  final RhythmAnalysisResult? analysis;
  final List<BeatTimelineEntry> timeline;

  /// User span / reference span (first→last tap vs first→last onset).
  /// Diagnostic tempo hint only; not a tempo score.
  final double? spanRatio;
  final int referencePlays;
  final bool guided;

  /// The compared reference onsets and anchored taps (first tap = first
  /// onset), for drawing the timeline only. Empty unless measured; the anchor
  /// is a definition, so it is never a timing measurement.
  final List<int> referenceOnsetsMs, userOnsetsMs;

  /// True when the taps were scaled to the reference span before matching
  /// (see [tempoFitMin]); [userOnsetsMs] are then the scaled taps.
  final bool tempoFitted;

  /// Echo windows. Listen-then-repeat has no shared clock and touch adds
  /// its own jitter, so a tap within ±[onTimeToleranceMs] is on time (v1:
  /// 10 ms) and within ±[matchToleranceMs] still the same beat (v1: 120 ms).
  /// Wider than [RhythmAnalysisDefaults]; used only by this exercise.
  static const matchToleranceMs = 160;
  static const onTimeToleranceMs = 50;

  /// When every beat was tapped and the overall speed is within this
  /// ratio of the reference, taps are scaled to the reference span first,
  /// so a steady but slightly slow/fast echo is not read as a row of late or
  /// early beats. [spanRatio] still reports the speed.
  static const tempoFitMin = 0.8, tempoFitMax = 1.25;

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
    if (guided) {
      throw StateError('Guided rhythm repetitions are not scored or stored');
    }
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
        ExerciseProtocolFingerprint.measurementKey:
            ExerciseProtocolFingerprint.compute(exercise.protocol),
        'anchor': 'first_tap',
        'anchorTimingMeasured': false,
        'referencePlays': referencePlays,
        AttemptAssistanceEvidence.measurementKey:
            AttemptAssistanceEvidence.forProtocol(
              exercise.protocol,
              referencePlaysCompleted: referencePlays,
            ).toJson(),
        'retentionCheck': retentionCheck,
        'spanRatio': spanRatio,
        'tempoFitted': tempoFitted,
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

/// A short, deterministic excerpt around the first visible rhythm error.
/// It reuses the measured pattern and exists only for guided repetition.
class RhythmGuidedSegment {
  const RhythmGuidedSegment({
    required this.referenceIndexes,
    required this.onsetsMs,
    required this.focusPosition,
    required this.focusVerdict,
  });

  final List<int> referenceIndexes;
  final List<int> onsetsMs;
  final int focusPosition;
  final BeatVerdict focusVerdict;

  static RhythmGuidedSegment? fromOutcome({
    required RhythmImitationOutcome outcome,
    required ExerciseProtocol protocol,
  }) {
    if (!outcome.isMeasured || outcome.guided) return null;
    final errorIndex = outcome.timeline.indexWhere(
      (entry) =>
          entry.verdict != BeatVerdict.anchor &&
          entry.verdict != BeatVerdict.onTime,
    );
    if (errorIndex < 0) return null;
    final error = outcome.timeline[errorIndex];
    final reference = RhythmReferenceClock.onsetsMs(protocol);
    if (reference == null || reference.length < 2) return null;

    var focus = error.referenceIndex;
    if (focus == null) {
      // An extra tap has no reference index. Anchor the excerpt to the next
      // expected beat after the latest preceding reference event.
      var previous = 0;
      for (var i = errorIndex - 1; i >= 0; i--) {
        final candidate = outcome.timeline[i].referenceIndex;
        if (candidate != null) {
          previous = candidate;
          break;
        }
      }
      focus = (previous + 1).clamp(0, reference.length - 1);
    }

    var start = (focus - 1).clamp(0, reference.length - 1);
    var end = (focus + 1).clamp(0, reference.length - 1);
    if (end == start) {
      if (end < reference.length - 1) {
        end++;
      } else {
        start--;
      }
    }
    final indexes = [for (var i = start; i <= end; i++) i];
    final origin = reference[start];
    return RhythmGuidedSegment(
      referenceIndexes: List.unmodifiable(indexes),
      onsetsMs: List.unmodifiable([
        for (final i in indexes) reference[i] - origin,
      ]),
      focusPosition: focus - start,
      focusVerdict: error.verdict,
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
  // Exact integer microseconds on native and JavaScript runtimes.
  static const maxTimestampUs = 9007199254740991;

  static Future<RhythmImitationOutcome> evaluate({
    required ExerciseProtocol protocol,
    required List<Duration> tapTimestamps,
    int referencePlays = 1,
  }) async {
    final reference = RhythmReferenceClock.onsetsMs(protocol);
    if (reference == null) {
      return RhythmImitationOutcome._(
        status: RhythmImitationStatus.invalidInput,
        referencePlays: referencePlays,
      );
    }
    return _evaluateReference(
      reference: reference,
      tapTimestamps: tapTimestamps,
      referencePlays: referencePlays,
      maxReferencePlays: protocol.maxReferencePlays,
      guided: false,
    );
  }

  static Future<RhythmImitationOutcome> evaluateGuided({
    required List<int> referenceOnsetsMs,
    required List<Duration> tapTimestamps,
    int referencePlays = 1,
    int maxReferencePlays = 3,
  }) => _evaluateReference(
    reference: referenceOnsetsMs,
    tapTimestamps: tapTimestamps,
    referencePlays: referencePlays,
    maxReferencePlays: maxReferencePlays,
    guided: true,
  );

  static Future<RhythmImitationOutcome> _evaluateReference({
    required List<int> reference,
    required List<Duration> tapTimestamps,
    required int referencePlays,
    required int maxReferencePlays,
    required bool guided,
  }) async {
    RhythmImitationOutcome invalid(RhythmImitationStatus status) =>
        RhythmImitationOutcome._(
          status: status,
          referencePlays: referencePlays,
          guided: guided,
        );
    if (reference.length < 2 ||
        reference.length > maxTaps ||
        reference.first != 0 ||
        reference.any((onset) => onset < 0) ||
        [
          for (var i = 1; i < reference.length; i++)
            reference[i] <= reference[i - 1],
        ].contains(true) ||
        referencePlays < 1 ||
        referencePlays > maxReferencePlays ||
        tapTimestamps.length > maxTaps) {
      return invalid(RhythmImitationStatus.invalidInput);
    }
    for (var i = 0; i < tapTimestamps.length; i++) {
      final micros = tapTimestamps[i].inMicroseconds;
      if (micros < 0 ||
          micros > maxTimestampUs ||
          (i > 0 && tapTimestamps[i] < tapTimestamps[i - 1])) {
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
    final referenceSpan = reference.last - reference.first;
    final userSpan = user.last - user.first;
    final ratio = userSpan / referenceSpan;
    final fit =
        user.length == reference.length &&
        userSpan > 0 &&
        ratio >= RhythmImitationOutcome.tempoFitMin &&
        ratio <= RhythmImitationOutcome.tempoFitMax;
    final compared = fit
        ? [
            for (final u in user)
              ((u - user.first) / ratio).round() + user.first,
          ]
        : user;
    final request = RhythmAnalysisRequest(
      expectedOnsetsMs: reference.sublist(1),
      userOnsetsMs: compared.sublist(1),
      toleranceMs: RhythmImitationOutcome.matchToleranceMs,
      onTimeToleranceMs: RhythmImitationOutcome.onTimeToleranceMs,
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
    return RhythmImitationOutcome._(
      status: RhythmImitationStatus.measured,
      analysis: analysis,
      timeline: List.unmodifiable(timeline),
      spanRatio: ratio,
      referencePlays: referencePlays,
      guided: guided,
      referenceOnsetsMs: List.unmodifiable(reference),
      userOnsetsMs: List.unmodifiable(compared),
      tempoFitted: fit,
    );
  }
}
