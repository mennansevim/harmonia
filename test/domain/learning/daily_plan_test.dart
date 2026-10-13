import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/domain/learning/daily_plan.dart';
import 'package:harmonia/domain/learning/measured_exercise.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/perception/pitch_comparison.dart';

final _day = DateTime(2026, 10, 11, 10);

ExerciseResult _perc(
  int level,
  int minute, {
  int day = 0,
  int wrong = 0,
  bool retention = false,
}) {
  final round = PitchComparisonRound.generate(
    draftPitchLevels[level],
    Random(minute + day * 1000),
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
    createdAt: _day.add(Duration(days: day, minutes: minute)),
    retentionCheck: retention,
  );
}

Future<ExerciseResult> _rhythm(
  int pattern,
  int minute, {
  int day = 0,
  bool oneTap = false,
  bool retention = false,
}) async {
  final p = draftRhythmPatterns[pattern];
  final beatMs = 60000 / p.exercise.protocol.tempoBpm;
  final beats = p.exercise.protocol.rhythmOnsetsBeats;
  final o = await RhythmImitationEvaluator.evaluate(
    protocol: p.exercise.protocol,
    tapTimestamps: [
      for (final b in oneTap ? beats.take(1) : beats)
        Duration(milliseconds: (b * beatMs).round()),
    ],
  );
  return o.toResult(
    exercise: p.exercise,
    sessionId: 's',
    createdAt: _day.add(Duration(days: day, minutes: minute)),
    retentionCheck: retention,
  );
}

DailyPlan _plan(
  List<ExerciseResult> r, {
  DailyBudget budget = DailyBudget.twelve,
  int day = 0,
  PracticeGoal goal = PracticeGoal.foundations,
  List<MeasuredExercise>? catalog,
}) => DailyPlanner.plan(
  graph: draftSkillGraph,
  goal: goal,
  results: r,
  now: _day.add(Duration(days: day, hours: 2)),
  budget: budget,
  catalog: catalog,
);

List<String> _ids(DailyPlan p) => [
  for (final b in p.blocks) b.exercise.exerciseId,
];

void main() {
  test('new learner: one new item per skill, two rounds, within budget', () {
    final p = _plan(const []);
    expect(p.status, DailyPlanStatus.planned);
    expect(_ids(p), ['draft-perc-highlow-200', 'draft-rhythm-quarters']);
    expect(p.blocks.every((b) => b.kind == PlanBlockKind.newItem), isTrue);
    expect(p.blocks.map((b) => b.rounds), [2, 2]);
    expect(p.plannedMinutes, 8);
    expect(p.freeMinutes, 4);
    expect(p.complete, isFalse);
  });

  test('5 min allows a single new item; 15 min never exceeds two new', () {
    final five = _plan(const [], budget: DailyBudget.five);
    expect(_ids(five), ['draft-perc-highlow-200']);
    expect(five.plannedMinutes, lessThanOrEqualTo(5));
    final fifteen = _plan(const [], budget: DailyBudget.fifteen);
    expect(
      fifteen.blocks.where((b) => b.kind == PlanBlockKind.newItem),
      hasLength(2),
    );
    for (final b in DailyBudget.values) {
      expect(
        _plan(const [], budget: b).plannedMinutes,
        lessThanOrEqualTo(b.minutes),
      );
    }
  });

  test('a weak sibling holds back the next level of the same skill', () {
    final p = _plan([_perc(0, 1, day: -1, wrong: 3)]);
    expect(p.blocks.first.kind, PlanBlockKind.weakRepeat);
    expect(p.blocks.first.exercise.exerciseId, 'draft-perc-highlow-200');
    expect(p.blocks.first.lastResult!.measurements['correct'], 5);
    expect(_ids(p), isNot(contains('draft-perc-highlow-100')));
  });

  test('mastered yesterday: 1-day check first, single round, flagged', () {
    final p = _plan([_perc(0, 1, day: -1), _perc(0, 2, day: -1)]);
    final check = p.blocks.first;
    expect(check.kind, PlanBlockKind.retentionCheck);
    expect(check.exercise.exerciseId, 'draft-perc-highlow-200');
    expect(check.rounds, 1);
    expect(check.retention, isTrue);
    expect(check.reviewIntervalDays, 1);
    // The mastered level unlocks the next one as a new item.
    expect(_ids(p), contains('draft-perc-highlow-100'));
  });

  test('queue widens 1 → 3 → 7 → 14 days after passed checks', () {
    final history = [
      _perc(0, 1, day: -20),
      _perc(0, 2, day: -20),
      _perc(0, 3, day: -19, retention: true),
    ];
    // One passed check: next due 3 days after it (day -16).
    expect(
      _plan(history, day: -17).blocks.map((b) => b.retention),
      isNot(contains(true)),
    );
    var p = _plan(history, day: -16);
    expect(p.blocks.first.reviewIntervalDays, 3);
    history.add(_perc(0, 4, day: -16, retention: true));
    p = _plan(history, day: -10);
    expect(p.blocks.where((b) => b.retention), isEmpty);
    expect(p.nextReviewDay, DateTime(2026, 10, 2));
    p = _plan(history, day: -9);
    expect(p.blocks.first.reviewIntervalDays, 7);
    history.add(_perc(0, 5, day: -9, retention: true));
    history.add(_perc(0, 6, day: 5, retention: true));
    p = _plan(history, day: 19);
    expect(p.blocks.first.reviewIntervalDays, 14);
  });

  test('a failed check turns the item into a weak repeat', () {
    final p = _plan([
      _perc(0, 1, day: -3),
      _perc(0, 2, day: -3),
      _perc(0, 3, day: -2, wrong: 4, retention: true),
    ]);
    final b = p.blocks.firstWhere(
      (b) => b.exercise.exerciseId == 'draft-perc-highlow-200',
    );
    expect(b.kind, PlanBlockKind.weakRepeat);
  });

  test(
    'most overdue check comes first; session order check→weak→new',
    () async {
      final p = _plan([
        _perc(0, 1, day: -5),
        _perc(0, 2, day: -5),
        await _rhythm(0, 3, day: -2),
        await _rhythm(0, 4, day: -2),
        _perc(1, 5, day: -1, wrong: 3),
      ], budget: DailyBudget.fifteen);
      expect(p.blocks.map((b) => b.kind).toList(), [
        PlanBlockKind.retentionCheck,
        PlanBlockKind.retentionCheck,
        PlanBlockKind.weakRepeat,
        PlanBlockKind.newItem,
        PlanBlockKind.newItem,
      ]);
      expect(p.blocks.first.exercise.exerciseId, 'draft-perc-highlow-200');
      expect(p.plannedMinutes, lessThanOrEqualTo(15));
    },
  );

  test('plan is fixed for the day; today only marks progress', () async {
    final before = [_perc(0, 1, day: -1, wrong: 3)];
    final morning = _plan(before);
    final today = [
      ...before,
      _perc(0, 30), // clean round today
    ];
    final later = _plan(today);
    expect(_ids(later), _ids(morning));
    final b = later.blocks.first;
    expect(b.roundsDoneToday, 1);
    expect(b.done, isFalse);
    final done = _plan([...today, _perc(0, 31)]);
    expect(done.blocks.first.done, isTrue);
  });

  test('a check is only done by a retention-flagged round today', () {
    final h = [_perc(0, 1, day: -1), _perc(0, 2, day: -1)];
    expect(_plan([...h, _perc(0, 30)]).blocks.first.done, isFalse);
    expect(
      _plan([...h, _perc(0, 30, retention: true)]).blocks.first.done,
      isTrue,
    );
  });

  test('invalid rounds never count as progress', () async {
    final h = [_perc(0, 1, day: -1, wrong: 3), await _rhythm(0, 2, day: -1)];
    final p = _plan([...h, await _rhythm(0, 30, oneTap: true)]);
    final rhythm = p.blocks.firstWhere(
      (b) => b.exercise.exerciseId == 'draft-rhythm-quarters',
    );
    expect(rhythm.kind, PlanBlockKind.weakRepeat);
    expect(rhythm.roundsDoneToday, 0);
  });

  test(
    'everything mastered and nothing due → nothingDue with next day',
    () async {
      final catalog = [
        for (final e in defaultMeasuredCatalog())
          if (e is! IntervalMeasuredExercise) e,
      ];
      final all = <ExerciseResult>[
        for (var l = 0; l < 2; l++) ...[
          _perc(l, 1 + l * 3, day: -3),
          _perc(l, 2 + l * 3, day: -3),
          _perc(l, 3 + l * 3, day: -2, retention: true),
        ],
        for (var r = 0; r < 3; r++) ...[
          await _rhythm(r, 10 + r * 3, day: -3),
          await _rhythm(r, 11 + r * 3, day: -3),
          await _rhythm(r, 12 + r * 3, day: -2, retention: true),
        ],
      ];
      final p = _plan(all, catalog: catalog);
      expect(p.status, DailyPlanStatus.nothingDue);
      expect(p.blocks, isEmpty);
      expect(p.complete, isFalse);
      expect(p.nextReviewDay, DateTime(2026, 10, 12));
    },
  );

  test('route without measurable exercises reports it honestly', () {
    final p = DailyPlanner.plan(
      graph: SkillGraph([
        SkillNode(
          id: 'only-content',
          title: 'x',
          goal: 'x',
          stage: SkillStage.voiceAndPulse,
          route: LearningRoute.core,
          dimension: SkillDimension.perception,
          support: MeasurementSupport.awaitingContent,
        ),
      ]),
      goal: PracticeGoal.foundations,
      results: const [],
      now: _day,
      budget: DailyBudget.twelve,
    );
    expect(p.status, DailyPlanStatus.noMeasuredContent);
    expect(p.blocks, isEmpty);
  });

  test('blocks are immutable', () {
    final p = _plan(const []);
    expect(() => p.blocks.removeLast(), throwsUnsupportedError);
  });
}
