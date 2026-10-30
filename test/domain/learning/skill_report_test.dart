import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/learning/rhythm_next_step.dart';
import 'package:resonia/domain/learning/skill_graph.dart';
import 'package:resonia/domain/learning/skill_report.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/perception/pitch_comparison.dart';

final _day = DateTime(2026, 10, 11, 10);

ExerciseResult _perc(int level, int minute, {int plays = 1}) {
  final round = PitchComparisonRound.generate(
    draftPitchLevels[level],
    Random(minute),
  );
  return PitchComparisonOutcome(
    round: round,
    answers: [for (final i in round.items) i.correct],
    plays: List.filled(8, plays),
  ).toResult(
    sessionId: 's',
    createdAt: _day.add(Duration(minutes: minute)),
  );
}

SkillReport _report(
  List<ExerciseResult> r, {
  PracticeGoal goal = PracticeGoal.foundations,
}) => SkillReport.build(
  graph: draftSkillGraph,
  goal: goal,
  results: r,
  now: _day.add(const Duration(hours: 1)),
);

void main() {
  test('new learner: measurable skills untried, the rest unknown', () {
    final r = _report(const []);
    expect(r.measurableCount, 4);
    expect(r.count(MasteryState.notMeasured), 4);
    expect(r.unknownCount, 5);
    expect(r.unmeasurable[MeasurementSupport.awaitingEngine], 3);
    expect(r.unmeasurable[MeasurementSupport.awaitingContent], 2);
    expect(r.focus.kind, NextStepKind.start);
    expect(r.focus.node!.id, 'pitch-high-low');
  });

  test('evidence moves only the measured skill; focus moves on', () {
    final r = _report([_perc(0, 1), _perc(0, 2), _perc(1, 3), _perc(1, 4)]);
    expect(r.count(MasteryState.independent), 1);
    expect(r.count(MasteryState.notMeasured), 3);
    expect(r.unknownCount, 5);
    expect(r.focus.node!.id, 'pulse-tap');
  });

  test('replaying references keeps it at supported, not independent', () {
    final r = _report([
      _perc(0, 1, plays: 2),
      _perc(0, 2, plays: 2),
      _perc(1, 3, plays: 2),
      _perc(1, 4, plays: 2),
    ]);
    expect(r.count(MasteryState.supported), 1);
    expect(r.count(MasteryState.independent), 0);
  });

  test('route skills that need an educator are unknown, not weak', () {
    final r = _report(const [], goal: PracticeGoal.conservatory);
    expect(r.unmeasurable[MeasurementSupport.educatorObserved], 1);
    expect(r.unknownCount, 8);
    expect(r.count(MasteryState.practicing), 0);
  });

  test('maps are immutable', () {
    final r = _report(const []);
    expect(() => r.measured.clear(), throwsUnsupportedError);
    expect(() => r.unmeasurable.clear(), throwsUnsupportedError);
  });
}
