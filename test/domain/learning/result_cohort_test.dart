import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/rhythm_imitation.dart';
import 'package:resonia/domain/content/rhythm_patterns.dart';
import 'package:resonia/domain/learning/daily_plan.dart';
import 'package:resonia/domain/learning/measured_exercise.dart';
import 'package:resonia/domain/learning/rhythm_next_step.dart';
import 'package:resonia/domain/learning/skill_graph.dart';
import 'package:resonia/domain/learning/today_planner.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/perception/interval_identification.dart';
import 'package:resonia/domain/perception/pitch_comparison.dart';

final day = DateTime(2026, 10, 15, 10);

ExerciseResult changed(ExerciseResult r, String field, Object value) {
  final json = r.toJson();
  if (field == 'source' || field == 'analyzerVersion') {
    json['provenance'] = {...r.provenance.toJson(), field: value};
  } else {
    json[field] = value;
  }
  return ExerciseResult.fromJson(json);
}

Future<List<ExerciseResult>> realOutcomes() async {
  final p = draftRhythmPatterns.last;
  final rhythm = await RhythmImitationEvaluator.evaluate(
    protocol: p.exercise.protocol,
    tapTimestamps: [
      for (final beat in p.exercise.protocol.rhythmOnsetsBeats)
        Duration(
          milliseconds: (beat * 60000 / p.exercise.protocol.tempoBpm).round(),
        ),
    ],
  );
  final pitch = PitchComparisonRound.generate(
    draftPitchLevels.first,
    Random(1),
  );
  final interval = IntervalRound.generate(draftIntervalLevels.first, Random(1));
  return [
    rhythm.toResult(exercise: p.exercise, sessionId: 'rhythm', createdAt: day),
    PitchComparisonOutcome(
      round: pitch,
      answers: [for (final item in pitch.items) item.correct],
      plays: List.filled(8, 1),
    ).toResult(sessionId: 'pitch', createdAt: day),
    IntervalOutcome(
      round: interval,
      answers: [for (final item in interval.items) item.degree],
      plays: List.filled(8, 1),
    ).toResult(sessionId: 'interval', createdAt: day),
  ];
}

void main() {
  late List<ExerciseResult> outcomes;
  late List<MeasuredExercise> catalog;
  setUp(() async {
    outcomes = await realOutcomes();
    catalog = [
      RhythmMeasuredExercise(draftRhythmPatterns.last),
      PitchComparisonMeasuredExercise(draftPitchLevels.first),
      IntervalMeasuredExercise(draftIntervalLevels.first),
    ];
  });

  test('all three real outcome codecs match their declared catalog cohort', () {
    for (var i = 0; i < catalog.length; i++) {
      final restored = ExerciseResult.fromJson(outcomes[i].toJson());
      expect(catalog[i].cohort.matches(restored), isTrue);
      expect(comparableResults([restored], catalog[i]), [restored]);
    }
    expect(catalog.first.cohort.difficulty, 2);
  });

  for (final entry in <String, Object>{
    'exerciseId': 'different-id',
    'skill': Skill.chord.name,
    'exerciseMode': ExerciseMode.recallExam.wireValue,
    'difficulty': 99,
    'contentVersion': 'future-content',
    'scoringVersion': 'future-scoring',
    'source': 'mock',
    'analyzerVersion': 'future-analyzer',
  }.entries) {
    test('${entry.key} mismatch cannot enter mastery or comparison', () {
      for (var i = 0; i < catalog.length; i++) {
        final mismatch = changed(outcomes[i], entry.key, entry.value);
        expect(comparableResults([mismatch], catalog[i]), isEmpty);
        expect(
          SkillStatusEvaluator.exerciseState(catalog[i], [mismatch, mismatch]),
          MasteryState.notMeasured,
        );
      }
      final rhythm = changed(outcomes.first, entry.key, entry.value);
      expect(
        RhythmNextStepPolicy.comparable([rhythm], draftRhythmPatterns.last),
        isEmpty,
      );
    });
  }

  test(
    'same-cohort invalid evidence stays available for retry guidance',
    () async {
      final p = draftRhythmPatterns.last;
      final invalid = await RhythmImitationEvaluator.evaluate(
        protocol: p.exercise.protocol,
        tapTimestamps: [],
      );
      final r = invalid.toResult(
        exercise: p.exercise,
        sessionId: 'invalid',
        createdAt: day,
      );
      expect(comparableResults([r], catalog.first), [r]);
      expect(
        SkillStatusEvaluator.exerciseState(catalog.first, [r]),
        MasteryState.notMeasured,
      );
      final next = RhythmNextStepPolicy.recommend(
        results: [r],
        patterns: [p],
        current: p,
        now: day,
      );
      expect(next.kind, NextStepKind.retryUnmeasured);
    },
  );

  test('mixed history keeps valid current evidence in chronological order', () {
    final first = outcomes.first;
    final later = changed(
      first,
      'createdAt',
      day.add(Duration(minutes: 1)).toIso8601String(),
    );
    final other = changed(first, 'scoringVersion', 'future');
    expect(comparableResults([later, other, first], catalog.first), [
      first,
      later,
    ]);
    expect(
      SkillStatusEvaluator.exerciseState(catalog.first, [later, other, first]),
      MasteryState.independent,
    );
  });

  test(
    'exam results cannot advance today route or fill daily learning plan',
    () {
      final exam = changed(
        outcomes[1],
        'exerciseMode',
        ExerciseMode.recallExam.wireValue,
      );
      final history = [exam, exam];
      final next = TodayPlanner.recommend(
        graph: draftSkillGraph,
        goal: PracticeGoal.foundations,
        results: history,
        now: day,
      );
      expect(next.kind, NextStepKind.start);
      expect(next.exercise!.exerciseId, exam.exerciseId);
      final plan = DailyPlanner.plan(
        graph: draftSkillGraph,
        goal: PracticeGoal.foundations,
        results: history,
        now: day,
        budget: DailyBudget.twelve,
      );
      final block = plan.blocks.firstWhere(
        (b) => b.exercise.exerciseId == exam.exerciseId,
      );
      expect(block.kind, PlanBlockKind.newItem);
      expect(block.roundsDoneToday, 0);
      expect(block.lastResult, isNull);
    },
  );
}
