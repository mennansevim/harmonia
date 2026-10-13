import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/perception/interval_identification.dart';
import 'package:harmonia/infrastructure/audio/click_track.dart';

final _a = draftIntervalLevels[0];
final _b = draftIntervalLevels[1];

IntervalOutcome _o(
  IntervalRound r, {
  int wrong = 0,
  int plays = 1,
  bool incomplete = false,
}) => IntervalOutcome(
  round: r,
  answers: [
    for (var i = 0; i < 8; i++)
      if (incomplete && i == 0)
        null
      else if (i < wrong)
        r.level.options.firstWhere((o) => o != r.items[i].degree)
      else
        r.items[i].degree,
  ],
  plays: List.filled(8, plays),
);

void main() {
  test('options are spread evenly; tonic varies; degrees are exact', () {
    final r = IntervalRound.generate(_a, Random(4));
    final counts = <SolfegeDegree, int>{};
    for (final i in r.items) {
      counts[i.degree] = (counts[i.degree] ?? 0) + 1;
      final semis = 12 * log(i.targetHz / i.tonicHz) / ln2;
      expect(semis, closeTo(i.degree.semitones, 1e-9));
    }
    expect(counts.values.toList()..sort(), [2, 3, 3]);
    expect(
      {for (final i in r.items) i.tonicHz}.length,
      greaterThan(1),
      reason: 'movable do: key changes between items',
    );
  });

  test('same seed gives the same round', () {
    final x = IntervalRound.generate(_b, Random(9));
    final y = IntervalRound.generate(_b, Random(9));
    for (var i = 0; i < 8; i++) {
      expect(x.items[i].degree, y.items[i].degree);
      expect(x.items[i].tonicHz, y.items[i].tonicHz);
    }
  });

  test('result: interval skill, movable-do target, confusions', () {
    final r = IntervalRound.generate(_a, Random(2));
    final o = _o(r, wrong: 2);
    final res = o.toResult(
      sessionId: 's',
      createdAt: DateTime.utc(2026, 10, 11),
    );
    expect(res.skill, Skill.interval);
    expect(res.target['solfege'], 'movable_do');
    expect(res.measurements['correct'], 6);
    expect(
      (res.measurements['confusions'] as Map).values.fold<int>(
        0,
        (a, b) => a + (b as int),
      ),
      2,
    );
    expect(res.measurements['chancePercent'], closeTo(33.3, 0.1));
    expect(ExerciseResult.fromJson(res.toJson()).measurements['correct'], 6);
  });

  test('incomplete round is invalid and unscored', () {
    final r = IntervalRound.generate(_a, Random(2));
    final res = _o(
      r,
      incomplete: true,
    ).toResult(sessionId: 's', createdAt: DateTime.utc(2026));
    expect(res.isValid, isFalse);
    expect(res.scores.hasMeasurements, isFalse);
  });

  test('tonic-degree skill needs both linked levels', () {
    ExerciseResult res(IntervalLevel l, int m, {int wrong = 0}) => _o(
      IntervalRound.generate(l, Random(m)),
      wrong: wrong,
    ).toResult(sessionId: 's', createdAt: DateTime(2026, 10, 11, 10, m));
    final node = draftSkillGraph['tonic-degree'];
    expect(
      SkillStatusEvaluator.stateOf(node, [res(_a, 1), res(_a, 2)]),
      MasteryState.practicing,
    );
    expect(
      SkillStatusEvaluator.stateOf(node, [
        res(_a, 1),
        res(_a, 2),
        res(_b, 3),
        res(_b, 4, wrong: 1),
      ]),
      MasteryState.independent,
    );
    expect(
      SkillStatusEvaluator.stateOf(node, [
        res(_a, 1),
        res(_a, 2),
        res(_b, 3),
        res(_b, 4, wrong: 2),
      ]),
      MasteryState.practicing,
    );
  });

  test('labels use movable-do syllables and Turkish interval names', () {
    expect(SolfegeDegree.sol.syllable, 'sol');
    expect(SolfegeDegree.mi.intervalName, "büyük 3'lü");
    expect(SolfegeDegree.doHigh.semitones, 12);
  });

  test('tone sequence validates and concatenates with gaps', () {
    final w = renderToneSequence(
      [(261.63, 0.1), (329.63, 0.1)],
      gapsAfter: [0.05, 0],
      sampleRateHz: 8000,
    );
    expect(w.samples.length, 800 + 400 + 800);
    expect(() => renderToneSequence(const []), throwsArgumentError);
    expect(
      () => renderToneSequence([(261.63, 0.1)], gapsAfter: [3]),
      throwsArgumentError,
    );
  });
}
