import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/domain/learning/measured_exercise.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/models/score_metric.dart';

SkillNode _node(
  String id, {
  List<String> pre = const [],
  LearningRoute route = LearningRoute.core,
  MeasurementSupport support = MeasurementSupport.awaitingContent,
  List<String> exercises = const [],
}) => SkillNode(
  id: id,
  title: id,
  goal: 'g',
  stage: SkillStage.voiceAndPulse,
  route: route,
  dimension: SkillDimension.perception,
  support: support,
  prerequisites: pre,
  exerciseIds: exercises,
);

final _day = DateTime(2026, 10, 11, 10);
ExerciseResult _r(
  String exerciseId,
  DateTime at, {
  int missed = 0,
  int plays = 1,
  bool retention = false,
  String version = RhythmImitationOutcome.version,
}) => ExerciseResult(
  sessionId: 's',
  exerciseId: exerciseId,
  skill: Skill.rhythm,
  target: const {},
  measurements: {
    'missed': missed,
    'extra': 0,
    'late': 0,
    'early': 0,
    'meanAbsoluteOffsetMs': 20,
    'referencePlays': plays,
    'retentionCheck': retention,
  },
  scores: ExerciseScores(timing: ScoreMetric.measured(90)),
  createdAt: at,
  contentVersion: 'draft-1',
  provenance: MeasurementProvenance(
    source: MeasurementSource.touch,
    analyzerVersion: version,
  ),
);

MasteryState _state(String id, List<ExerciseResult> r) =>
    SkillStatusEvaluator.stateOf(draftSkillGraph[id], r);

void main() {
  group('graph validation', () {
    test('duplicate, unknown, cross-route and cyclic graphs are rejected', () {
      expect(
        () => SkillGraph([_node('a-a'), _node('a-a')]),
        throwsArgumentError,
      );
      expect(
        () => SkillGraph([
          _node('a-a', pre: ['b-b']),
        ]),
        throwsArgumentError,
      );
      expect(
        () => SkillGraph([
          _node('cons-x', route: LearningRoute.conservatory),
          _node('choir-y', route: LearningRoute.choir, pre: ['cons-x']),
        ]),
        throwsArgumentError,
      );
      expect(
        () => SkillGraph([
          _node('a-a', pre: ['b-b']),
          _node('b-b', pre: ['a-a']),
        ]),
        throwsArgumentError,
      );
    });

    test('measured skills must link exercises and vice versa', () {
      expect(
        () => _node('m-m', support: MeasurementSupport.measuredInApp),
        throwsArgumentError,
      );
      expect(() => _node('n-n', exercises: ['x']), throwsArgumentError);
    });

    test('draft graph: prerequisites come first; links resolve', () {
      final seen = <String>{};
      for (final n in draftSkillGraph.order) {
        expect(n.prerequisites.every(seen.contains), isTrue, reason: n.id);
        seen.add(n.id);
      }
      final patternIds = {
        for (final e in defaultMeasuredCatalog()) e.exerciseId,
      };
      for (final n in draftSkillGraph.nodes) {
        expect(patternIds.containsAll(n.exerciseIds), isTrue, reason: n.id);
        expect(n.review, ContentReviewStatus.draftAwaitingEducator);
      }
    });

    test('goal filters routes; foundations is core only', () {
      Set<LearningRoute> routes(PracticeGoal g) => {
        for (final n in draftSkillGraph.forGoal(g)) n.route,
      };
      expect(routes(PracticeGoal.foundations), {LearningRoute.core});
      expect(routes(PracticeGoal.conservatory), {
        LearningRoute.core,
        LearningRoute.conservatory,
      });
      expect(routes(PracticeGoal.choir), {
        LearningRoute.core,
        LearningRoute.choir,
      });
    });
  });

  group('evidence states', () {
    const q = 'draft-rhythm-quarters';

    test('unmeasurable skills stay not measured whatever the history', () {
      final lots = [
        for (var i = 0; i < 5; i++) _r(q, _day.add(Duration(minutes: i))),
      ];
      for (final id in ['pitch-match', 'harmonic-voices', 'transfer-choir']) {
        expect(_state(id, lots), MasteryState.notMeasured, reason: id);
      }
    });

    test('ladder: none → practicing → supported → independent → retained', () {
      expect(_state('pulse-tap', const []), MasteryState.notMeasured);
      expect(
        _state('pulse-tap', [_r(q, _day, missed: 1)]),
        MasteryState.practicing,
      );
      expect(_state('pulse-tap', [_r(q, _day)]), MasteryState.practicing);
      final supported = [
        _r(q, _day, plays: 3),
        _r(q, _day.add(const Duration(minutes: 1)), plays: 1),
      ];
      expect(_state('pulse-tap', supported), MasteryState.supported);
      final independent = [
        _r(q, _day),
        _r(q, _day.add(const Duration(minutes: 1))),
      ];
      expect(_state('pulse-tap', independent), MasteryState.independent);
      expect(
        _state('pulse-tap', [
          ...independent,
          _r(q, _day.add(const Duration(days: 1)), retention: true),
        ]),
        MasteryState.retained,
      );
    });

    test('a later sloppy attempt drops back to practicing', () {
      expect(
        _state('pulse-tap', [
          _r(q, _day),
          _r(q, _day.add(const Duration(minutes: 1))),
          _r(q, _day.add(const Duration(minutes: 2)), missed: 2),
        ]),
        MasteryState.practicing,
      );
    });

    test('unattempted linked exercise caps the skill at practicing', () {
      final eighths = [
        _r('draft-rhythm-eighths', _day),
        _r('draft-rhythm-eighths', _day.add(const Duration(minutes: 1))),
      ];
      expect(_state('rhythm-imitation', eighths), MasteryState.practicing);
    });

    test('results from another analyzer version do not count', () {
      expect(
        _state('pulse-tap', [
          _r(q, _day, version: 'old'),
          _r(q, _day.add(const Duration(minutes: 1)), version: 'old'),
        ]),
        MasteryState.notMeasured,
      );
    });
  });
}
