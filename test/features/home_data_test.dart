import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/learning/skill_graph.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/perception/pitch_comparison.dart';
import 'package:resonia/features/home/home_data.dart';

ExerciseResult _perc(int level, DateTime at, {int wrong = 0}) {
  final round = PitchComparisonRound.generate(
    draftPitchLevels[level],
    Random(at.millisecondsSinceEpoch),
  );
  return PitchComparisonOutcome(
    round: round,
    answers: [
      for (var i = 0; i < 8; i++)
        i < wrong
            ? (round.items[i].correct == PitchAnswer.first
                  ? PitchAnswer.second
                  : PitchAnswer.first)
            : round.items[i].correct,
    ],
    plays: List.filled(8, 1),
  ).toResult(sessionId: 's', createdAt: at);
}

final _now = DateTime(2026, 10, 14, 20);

void main() {
  test('recent activity counts unique days, not correctness or attempts', () {
    final days = HomeData.recentPracticeOf([
      _perc(0, _now, wrong: 8),
      _perc(0, _now),
      _perc(0, DateTime(2026, 10, 12, 10)),
    ], _now);
    expect(days, hasLength(7));
    expect(days.where((d) => d.practiced), hasLength(2));
    expect(days.first.date, DateTime(2026, 10, 8));
    expect(days.last.practiced, isTrue);
    expect(() => days.clear(), throwsUnsupportedError);
  });

  test(
    'recent activity uses calendar boundaries and ignores future evidence',
    () {
      final now = DateTime(2026, 11, 2, 12);
      final days = HomeData.recentPracticeOf([
        _perc(0, DateTime(2026, 10, 26, 23)), // outside window
        _perc(0, DateTime(2026, 10, 27)),
        _perc(0, now.toUtc()), // same instant
        _perc(0, DateTime(2026, 11, 2, 13)), // later today
        _perc(0, DateTime(2026, 11, 3)),
      ], now);
      expect(days.first.date, DateTime(2026, 10, 27));
      expect(days.where((d) => d.practiced), hasLength(2));
    },
  );

  test('recent activity excludes invalid, demo, unknown and old cohorts', () {
    final source = _perc(0, _now).toJson();
    ExerciseResult changed(String key, Object? value) =>
        ExerciseResult.fromJson({...source, key: value});
    final days = HomeData.recentPracticeOf([
      ExerciseResult.fromJson({
        ...source,
        'measurementStatus': 'invalid',
        'scores': const ExerciseScores().toJson(),
      }),
      changed('contentVersion', 'old'),
      changed('exerciseId', 'unknown'),
      for (final origin in ['mock', 'synthetic', 'unverified'])
        changed('provenance', {
          'source': origin,
          'analyzerVersion': PitchComparisonOutcome.version,
        }),
    ], _now);
    expect(days.any((d) => d.practiced), isFalse);
  });

  test('recent activity respects supplied catalog including empty one', () {
    final days = HomeData.recentPracticeOf([_perc(0, _now)], _now, catalog: []);
    expect(days.any((d) => d.practiced), isFalse);
    final data = HomeData.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.foundations,
      results: [_perc(0, _now)],
      now: _now,
    );
    expect(data.recentPractice.last.practiced, isTrue);
  });

  test('streak counts consecutive local days; survives until tomorrow', () {
    DateTime d(int back, [int h = 10]) => DateTime(2026, 10, 14 - back, h);
    expect(HomeData.streakOf(const [], _now), (0, false));
    expect(HomeData.streakOf([_perc(0, d(0))], _now), (1, true));
    // Yesterday + day before, nothing today yet: streak still 2.
    expect(HomeData.streakOf([_perc(0, d(1)), _perc(0, d(2))], _now), (
      2,
      false,
    ));
    // A gap breaks it.
    expect(HomeData.streakOf([_perc(0, d(0)), _perc(0, d(2))], _now), (
      1,
      true,
    ));
    // Two days ago only: broken.
    expect(HomeData.streakOf([_perc(0, d(2))], _now), (0, false));
  });

  test('path follows the route; unmeasurable skills have no exercise', () {
    final data = HomeData.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.foundations,
      results: const [],
      now: _now,
    );
    expect(data.path.first.node.id, 'pitch-high-low');
    expect(data.path.first.nextExercise!.exerciseId, 'draft-perc-highlow-200');
    final engine = data.path.firstWhere((p) => p.node.id == 'pitch-match');
    expect(engine.measurable, isFalse);
    expect(engine.nextExercise, isNull);
    expect(engine.state, MasteryState.notMeasured);
    expect(data.step.node!.id, 'pitch-high-low');
  });

  test('mastered first level moves the node to the next level', () {
    final data = HomeData.build(
      graph: draftSkillGraph,
      goal: PracticeGoal.foundations,
      results: [
        _perc(0, _now.subtract(const Duration(minutes: 9))),
        _perc(0, _now.subtract(const Duration(minutes: 5))),
      ],
      now: _now,
    );
    expect(data.path.first.nextExercise!.exerciseId, 'draft-perc-highlow-100');
    expect(data.practicedToday, isTrue);
    expect(data.streakDays, 1);
  });
}
