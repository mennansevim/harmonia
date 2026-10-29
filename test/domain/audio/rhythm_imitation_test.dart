import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/event_rhythm_analyzer.dart';
import 'package:harmonia/domain/audio/rhythm_analyzer.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_protocol.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/score_metric.dart';

final _quarters = draftRhythmPatterns.first; // [0,1,2,3] @ 80 bpm = 750 ms
List<Duration> _taps(List<int> ms, {int start = 12345}) => [
  for (final m in ms) Duration(milliseconds: start + m),
];

Future<RhythmImitationOutcome> _eval(List<Duration> taps, [RhythmPattern? p]) =>
    RhythmImitationEvaluator.evaluate(
      protocol: (p ?? _quarters).exercise.protocol,
      tapTimestamps: taps,
    );

void main() {
  test('alignment lists matched, missed and extra in order', () async {
    final r = await EventRhythmAnalyzer().analyze(
      const RhythmAnalysisRequest(
        expectedOnsetsMs: [0, 500, 1000],
        userOnsetsMs: [5, 700, 1010],
      ),
    );
    expect(
      r.alignment.map(
        (e) => e.isMatched
            ? 'm${e.referenceIndex}'
            : e.isMissed
            ? 'x${e.referenceIndex}'
            : '+${e.userIndex}',
      ),
      ['m0', 'x1', '+1', 'm2'],
    );
  });

  test('accurate imitation from any start time is fully on time', () async {
    final o = await _eval(_taps([0, 752, 1498, 2251], start: 98765));
    expect(o.isMeasured, isTrue);
    expect(o.timeline.first.verdict, BeatVerdict.anchor);
    expect(
      o.timeline.skip(1).map((e) => e.verdict),
      everyElement(BeatVerdict.onTime),
    );
    expect(o.analysis!.timingAccuracy.value, 100);
    expect(o.tempoDiffers, isFalse);
  });

  test('much slower tapping flags tempo and loses matches', () async {
    final o = await _eval(_taps([0, 900, 1800, 2700]));
    expect(o.spanRatio, closeTo(1.2, 0.01));
    expect(o.tempoDiffers, isTrue);
    expect(o.analysis!.missedCount, greaterThan(0));
    expect(o.analysis!.timingAccuracy.value, lessThan(100));
  });

  test('slight drag within tolerance is reported late, not missed', () async {
    final o = await _eval(_taps([0, 800, 1580, 2340]));
    expect(o.analysis!.lateCount, 3);
    expect(o.analysis!.missedCount, 0);
    expect(
      o.timeline.skip(1).map((e) => e.verdict),
      everyElement(BeatVerdict.late),
    );
    expect(o.tempoDiffers, isFalse);
  });

  test('same tap count with wrong rhythm is not success', () async {
    // Four taps, but the eighth-note figure instead of even quarters.
    final o = await _eval(_taps([0, 375, 750, 1125]));
    expect(o.analysis!.missedCount + o.analysis!.extraCount, greaterThan(0));
    expect(o.analysis!.timingAccuracy.value, lessThan(60));
  });

  test('missing and extra beats appear in the timeline', () async {
    final missing = await _eval(_taps([0, 750, 2250]));
    expect(
      missing.timeline.map((e) => e.verdict),
      contains(BeatVerdict.missed),
    );
    final extra = await _eval(_taps([0, 750, 1100, 1500, 2250]));
    expect(extra.timeline.map((e) => e.verdict), contains(BeatVerdict.extra));
    expect(extra.analysis!.extraCount, 1);
  });

  test(
    'guided segment surrounds first error and is never persistable',
    () async {
      final measured = await _eval(_taps([0, 750, 2250]));
      final segment = RhythmGuidedSegment.fromOutcome(
        outcome: measured,
        protocol: _quarters.exercise.protocol,
      );
      expect(segment, isNotNull);
      expect(segment!.referenceIndexes, [1, 2, 3]);
      expect(segment.onsetsMs, [0, 750, 1500]);
      expect(segment.focusPosition, 1);
      expect(segment.focusVerdict, BeatVerdict.missed);

      final guided = await RhythmImitationEvaluator.evaluateGuided(
        referenceOnsetsMs: segment.onsetsMs,
        tapTimestamps: _taps([0, 750, 1500]),
      );
      expect(guided.isMeasured, isTrue);
      expect(guided.guided, isTrue);
      expect(
        () => guided.toResult(
          exercise: _quarters.exercise,
          sessionId: 'guided',
          createdAt: DateTime.utc(2026, 10, 20),
        ),
        throwsStateError,
      );
    },
  );

  test('clean imitation does not suggest a guided segment', () async {
    final measured = await _eval(_taps([0, 750, 1500, 2250]));
    expect(
      RhythmGuidedSegment.fromOutcome(
        outcome: measured,
        protocol: _quarters.exercise.protocol,
      ),
      isNull,
    );
  });

  test('one tap is too few; out-of-order taps are invalid', () async {
    expect((await _eval(_taps([0]))).status, RhythmImitationStatus.tooFewTaps);
    expect((await _eval(const [])).status, RhythmImitationStatus.tooFewTaps);
    expect(
      (await _eval([
        const Duration(milliseconds: 10),
        const Duration(milliseconds: 5),
      ])).status,
      RhythmImitationStatus.invalidInput,
    );
  });

  test('invalid outcome becomes an unscored invalid result', () async {
    final o = await _eval(_taps([0]));
    final r = o.toResult(
      exercise: _quarters.exercise,
      sessionId: 's',
      createdAt: DateTime.utc(2026, 10, 11),
    );
    expect(r.measurementStatus, MeasurementStatus.invalid);
    expect(r.scores.hasMeasurements, isFalse);
  });

  test(
    'measured result keeps anchor unmeasured and memory not measured',
    () async {
      final o = await _eval(_taps([0, 760, 1500, 2240]));
      final r = o.toResult(
        exercise: _quarters.exercise,
        sessionId: 's',
        createdAt: DateTime.utc(2026, 10, 11),
      );
      expect(r.skill, Skill.rhythm);
      expect(r.scores.timing.isMeasured, isTrue);
      expect(r.scores.memory.status, ScoreMetricStatus.notMeasured);
      expect(r.scores.accuracy.status, ScoreMetricStatus.notApplicable);
      expect(r.measurements['anchorTimingMeasured'], isFalse);
      expect(r.contentVersion, 'draft-1');
    },
  );

  test('draft patterns are learning-only and cannot be exam content', () {
    for (final p in draftRhythmPatterns) {
      expect(p.review, ContentReviewStatus.draftAwaitingEducator);
      expect(p.exercise.exercise.mode, ExerciseMode.learning);
      expect(p.exercise.protocol.rhythmOnsetsBeats.length, greaterThan(1));
    }
    expect(
      () => RhythmPattern(
        title: 't',
        description: 'd',
        exercise: ConfiguredExercise(
          exercise: const Exercise(
            id: 'x',
            skill: Skill.rhythm,
            title: 't',
            difficulty: 1,
            mode: ExerciseMode.recallExam,
          ),
          protocol: ExerciseProtocol(
            mode: ExerciseMode.recallExam,
            notes: const [],
            rhythmOnsetsBeats: const [0, 1],
          ),
        ),
      ),
      throwsArgumentError,
    );
  });
}
