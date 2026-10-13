import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/domain/learning/rhythm_next_step.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/learning/today_planner.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/perception/interval_identification.dart';
import 'package:harmonia/domain/perception/pitch_comparison.dart';

final _day = DateTime(2026, 10, 11, 10);

ExerciseResult _perc(
  int level,
  int minute, {
  int wrong = 0,
  bool retention = false,
  int dayOffset = 0,
}) {
  final round = PitchComparisonRound.generate(
    draftPitchLevels[level],
    Random(minute),
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
  ).toResult(
    sessionId: 's',
    createdAt: _day.add(Duration(days: dayOffset, minutes: minute)),
    retentionCheck: retention,
  );
}

Future<ExerciseResult> _rhythm(int pattern, int minute) async {
  final p = draftRhythmPatterns[pattern];
  final beatMs = 60000 / p.exercise.protocol.tempoBpm;
  final o = await RhythmImitationEvaluator.evaluate(
    protocol: p.exercise.protocol,
    tapTimestamps: [
      for (final b in p.exercise.protocol.rhythmOnsetsBeats)
        Duration(milliseconds: (b * beatMs).round()),
    ],
  );
  return o.toResult(
    exercise: p.exercise,
    sessionId: 's',
    createdAt: _day.add(Duration(minutes: minute)),
  );
}

TodayStep _rec(
  List<ExerciseResult> r, {
  PracticeGoal goal = PracticeGoal.foundations,
  DateTime? now,
}) => TodayPlanner.recommend(
  graph: draftSkillGraph,
  goal: goal,
  results: r,
  now: now ?? _day.add(const Duration(hours: 2)),
);

void main() {
  test('new learner starts with the first measurable skill in the route', () {
    final s = _rec(const []);
    expect(s.kind, NextStepKind.start);
    expect(s.node!.id, 'pitch-high-low');
    expect(s.exercise!.exerciseId, 'draft-perc-highlow-200');
  });

  test('perception repeat cites last score; mastery moves to next level', () {
    var s = _rec([_perc(0, 1, wrong: 3)]);
    expect(s.kind, NextStepKind.repeat);
    expect(s.lastResult!.measurements['correct'], 5);
    s = _rec([_perc(0, 1), _perc(0, 2, wrong: 1)]);
    expect(s.kind, NextStepKind.nextPattern);
    expect(s.exercise!.exerciseId, 'draft-perc-highlow-100');
  });

  test('after both tone levels, the route continues to pulse', () {
    final s = _rec([_perc(0, 1), _perc(0, 2), _perc(1, 3), _perc(1, 4)]);
    expect(s.node!.id, 'pulse-tap');
  });

  test('next day: due retention check comes first', () async {
    final history = [_perc(0, 1), _perc(0, 2), await _rhythm(0, 5)];
    final s = _rec(history, now: _day.add(const Duration(days: 1)));
    expect(s.kind, NextStepKind.delayedCheck);
    expect(s.exercise!.exerciseId, 'draft-perc-highlow-200');
    // Passing it the next day removes the check.
    final passed = [...history, _perc(0, 9, retention: true, dayOffset: 1)];
    final after = _rec(
      passed,
      now: _day.add(const Duration(days: 1, hours: 1)),
    );
    expect(after.kind, isNot(NextStepKind.delayedCheck));
  });

  test('foundations never recommends route-only skills', () async {
    final all = <ExerciseResult>[
      for (var l = 0; l < 2; l++) ...[_perc(l, l * 2 + 1), _perc(l, l * 2 + 2)],
      for (var p = 0; p < 3; p++) ...[
        await _rhythm(p, 10 + p * 2),
        await _rhythm(p, 11 + p * 2),
      ],
      for (var l = 0; l < 2; l++)
        for (var k = 0; k < 2; k++) _interval(l, 30 + l * 2 + k),
    ];
    final s = _rec(all);
    expect(s.kind, NextStepKind.allDone);
  });

  test(
    'after tone pairs and pulse, the route reaches movable-do degrees',
    () async {
      final s = _rec([
        _perc(0, 1),
        _perc(0, 2),
        _perc(1, 3),
        _perc(1, 4),
        await _rhythm(0, 5),
        await _rhythm(0, 6),
      ]);
      expect(s.node!.id, 'tonic-degree');
      expect(s.exercise!.exerciseId, 'draft-int-do-re-mi-sol');
    },
  );
}

ExerciseResult _interval(int level, int minute) {
  final r = IntervalRound.generate(draftIntervalLevels[level], Random(minute));
  return IntervalOutcome(
    round: r,
    answers: [for (final i in r.items) i.degree],
    plays: List.filled(8, 1),
  ).toResult(
    sessionId: 's',
    createdAt: _day.add(Duration(minutes: minute)),
  );
}
