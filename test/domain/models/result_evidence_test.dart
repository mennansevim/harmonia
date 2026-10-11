import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_analyzer.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/models/skill_progress.dart';
import 'package:harmonia/domain/models/score_metric.dart';
import 'package:harmonia/domain/scoring/pitch_exercise_scorer.dart';
import 'package:harmonia/infrastructure/audio/mock/mock_pitch_analyzer.dart';

void main() {
  test(
    'mock and analyzer versions cannot enter a microphone progress cohort',
    () {
      final progress = SkillProgress.initial(
        userId: 'u',
        skill: Skill.pitch,
        now: DateTime(2026),
        measurementSource: MeasurementSource.microphone,
        analyzerVersion: 'engine-1',
      );
      for (final origin in [
        const MeasurementProvenance(),
        const MeasurementProvenance(
          source: MeasurementSource.mock,
          analyzerVersion: 'engine-1',
        ),
        const MeasurementProvenance(
          source: MeasurementSource.microphone,
          analyzerVersion: 'engine-2',
        ),
      ]) {
        final r = ExerciseResult(
          sessionId: 's',
          exerciseId: 'e',
          skill: Skill.pitch,
          target: {},
          measurements: {},
          scores: ExerciseScores(accuracy: ScoreMetric.measured(90)),
          createdAt: DateTime(2026),
          provenance: origin,
        );
        expect(() => progress.withResult(r), throwsArgumentError);
      }
      final r = ExerciseResult(
        sessionId: 's',
        exerciseId: 'e',
        skill: Skill.pitch,
        target: {},
        measurements: {},
        scores: ExerciseScores(accuracy: ScoreMetric.measured(90)),
        createdAt: DateTime(2026),
        provenance: const MeasurementProvenance(
          source: MeasurementSource.microphone,
          analyzerVersion: 'engine-1',
        ),
      );
      final updated = progress.withResult(r);
      expect(updated.accuracyAvg, 90);
      expect(updated.measurementSource, MeasurementSource.microphone);
      expect(updated.analyzerVersion, 'engine-1');
    },
  );
  ExerciseResult result({
    Map<String, Object?> target = const {},
    Map<String, Object?> measurements = const {},
    List<ExerciseError> errors = const [],
  }) => ExerciseResult(
    sessionId: 's',
    exerciseId: 'e',
    skill: Skill.pitch,
    target: target,
    measurements: measurements,
    errors: errors,
    scores: const ExerciseScores(),
    createdAt: DateTime(2026),
  );
  test('result snapshots nested input maps lists and error evidence', () {
    final nested = <String, Object?>{'cents': 4.0};
    final frames = <Object?>[nested];
    final errors = [
      ExerciseError(
        type: ExerciseErrorType.unstable,
        severity: ExerciseErrorSeverity.low,
        evidence: {'frames': frames},
      ),
    ];
    final target = <String, Object?>{'note': 'C4'};
    final r = result(
      target: target,
      measurements: {'frames': frames},
      errors: errors,
    );
    target.clear();
    nested['cents'] = 100;
    frames.clear();
    errors.clear();
    expect(r.target['note'], 'C4');
    expect(r.measurements['frames'], [
      {'cents': 4.0},
    ]);
    expect(r.errors.single.evidence['frames'], [
      {'cents': 4.0},
    ]);
    expect(() => r.target.clear(), throwsUnsupportedError);
    expect(
      () => (r.measurements['frames'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => r.errors.clear(), throwsUnsupportedError);
    expect(() => r.errors.single.evidence.clear(), throwsUnsupportedError);
    jsonEncode(r.toJson());
  });
  test('non JSON evidence is rejected rather than corrupting export', () {
    for (final value in [
      double.nan,
      double.infinity,
      DateTime(2026),
      Object(),
    ]) {
      expect(() => result(measurements: {'value': value}), throwsArgumentError);
    }
  });
  test('legacy evidence is unverified never automatically microphone', () {
    expect(result().provenance.source, MeasurementSource.unverified);
  });
  test(
    'every mock scenario keeps mock origin through valid or invalid scoring',
    () async {
      final analyzer = MockPitchAnalyzer(simulatedLatency: Duration.zero);
      for (final scenario in MockPitchScenario.values) {
        analyzer.setScenario(scenario);
        final pitch = await analyzer.analyze(
          const PitchAnalysisRequest(
            samples: [],
            sampleRateHz: 48000,
            targetFrequencyHz: 261.63,
          ),
        );
        final r = const PitchExerciseScorer().score(
          exercise: const Exercise(
            id: 'c4',
            skill: Skill.pitch,
            title: 'C4',
            difficulty: 1,
            targetNote: TargetNote(note: 'C4', frequencyHz: 261.63),
          ),
          sessionId: 's',
          pitch: pitch,
          createdAt: DateTime(2026),
        );
        expect(r.provenance.source, MeasurementSource.mock);
        expect(r.toJson()['provenance'], {
          'source': 'mock',
          'analyzerVersion': 'mock-pitch-1',
        });
      }
    },
  );
}
