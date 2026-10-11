import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/models/score_metric.dart';
import 'package:harmonia/domain/perception/pitch_comparison.dart';
import 'package:harmonia/infrastructure/audio/click_track.dart';

final _l200 = draftPitchLevels[0];

PitchComparisonOutcome _outcome(
  PitchComparisonRound round, {
  int wrong = 0,
  int plays = 1,
  bool incomplete = false,
}) => PitchComparisonOutcome(
  round: round,
  answers: [
    for (var i = 0; i < round.items.length; i++)
      if (incomplete && i == 0)
        null
      else if (i < wrong)
        round.items[i].correct == PitchAnswer.first
            ? PitchAnswer.second
            : PitchAnswer.first
      else
        round.items[i].correct,
  ],
  plays: List.filled(round.items.length, plays),
);

void main() {
  test('rounds are balanced, seeded and exact in interval size', () {
    final a = PitchComparisonRound.generate(_l200, Random(7));
    final b = PitchComparisonRound.generate(_l200, Random(7));
    expect(a.items, hasLength(8));
    expect(
      a.items.where((i) => i.correct == PitchAnswer.second).length,
      4,
      reason: '"always 2" must score 50 %',
    );
    for (var i = 0; i < 8; i++) {
      expect(a.items[i].firstHz, b.items[i].firstHz);
      final cents =
          1200 * (log(a.items[i].secondHz / a.items[i].firstHz) / ln2).abs();
      expect(cents, closeTo(200, 1e-6));
    }
  });

  test('always answering the same button scores exactly chance', () {
    final r = PitchComparisonRound.generate(_l200, Random(3));
    final o = PitchComparisonOutcome(
      round: r,
      answers: List.filled(8, PitchAnswer.second),
      plays: List.filled(8, 1),
    );
    expect(o.correctCount, 4);
  });

  test('result: perception dimension, accuracy measured, touch source', () {
    final r = PitchComparisonRound.generate(_l200, Random(1));
    final res = _outcome(
      r,
      wrong: 1,
    ).toResult(sessionId: 's', createdAt: DateTime.utc(2026, 10, 11));
    expect(res.measurements['dimension'], 'perception');
    expect(res.measurements['correct'], 7);
    expect(res.scores.accuracy.value, 87.5);
    expect(res.scores.timing.status, ScoreMetricStatus.notApplicable);
    expect(res.provenance.source, MeasurementSource.touch);
    expect(ExerciseResult.fromJson(res.toJson()).measurements['correct'], 7);
  });

  test('incomplete round is invalid and unscored', () {
    final r = PitchComparisonRound.generate(_l200, Random(1));
    final res = _outcome(
      r,
      incomplete: true,
    ).toResult(sessionId: 's', createdAt: DateTime.utc(2026, 10, 11));
    expect(res.isValid, isFalse);
    expect(res.scores.hasMeasurements, isFalse);
  });

  test('skill state: two rounds ≥7/8 at both linked levels', () {
    ExerciseResult res(
      PitchComparisonLevel l,
      int min, {
      int wrong = 0,
      int plays = 1,
    }) => _outcome(
      PitchComparisonRound.generate(l, Random(min)),
      wrong: wrong,
      plays: plays,
    ).toResult(sessionId: 's', createdAt: DateTime(2026, 10, 11, 10, min));
    final node = draftSkillGraph['pitch-high-low'];
    MasteryState st(List<ExerciseResult> r) =>
        SkillStatusEvaluator.stateOf(node, r);
    final l100 = draftPitchLevels[1];
    expect(
      st([res(_l200, 1), res(_l200, 2)]),
      MasteryState.practicing,
      reason: '100-cent level not attempted',
    );
    expect(
      st([res(_l200, 1), res(_l200, 2), res(l100, 3), res(l100, 4, wrong: 2)]),
      MasteryState.practicing,
    );
    expect(
      st([res(_l200, 1), res(_l200, 2), res(l100, 3, plays: 2), res(l100, 4)]),
      MasteryState.supported,
    );
    expect(
      st([res(_l200, 1), res(_l200, 2), res(l100, 3), res(l100, 4, wrong: 1)]),
      MasteryState.independent,
    );
  });

  test('tone pair renders two tones separated by silence', () {
    final wav = renderTonePair(261.63, 293.66, sampleRateHz: 8000);
    expect(wav.samples.length, (0.6 + 0.3 + 0.6 + 0.2) * 8000);
    final gap = wav.samples.sublist(4800 + 100, 4800 + 2300);
    expect(gap.every((s) => s == 0), isTrue);
  });
}
