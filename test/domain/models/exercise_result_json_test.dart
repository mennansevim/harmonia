import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_analyzer.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/scoring/pitch_exercise_scorer.dart';
import 'package:harmonia/infrastructure/audio/mock/mock_pitch_analyzer.dart';

Map<String, Object?> _wire(ExerciseResult r) =>
    jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>;

void main() {
  const exercise = Exercise(
    id: 'single-tone-c4',
    skill: Skill.pitch,
    title: 'C4',
    difficulty: 1,
    targetNote: TargetNote(note: 'C4', frequencyHz: 261.63),
  );

  test('every mock pitch scenario round-trips through JSON text', () async {
    for (final scenario in MockPitchScenario.values) {
      final analyzer = MockPitchAnalyzer()..setScenario(scenario);
      final pitch = await analyzer.analyze(
        const PitchAnalysisRequest(
          samples: [],
          sampleRateHz: 44100,
          targetFrequencyHz: 261.63,
        ),
      );
      final result = const PitchExerciseScorer().score(
        exercise: exercise,
        sessionId: 's-1',
        pitch: pitch,
        createdAt: DateTime.utc(2026, 10, 11, 8),
      );
      final back = ExerciseResult.fromJson(_wire(result));
      expect(
        jsonEncode(back.toJson()),
        jsonEncode(result.toJson()),
        reason: scenario.name,
      );
      expect(back.provenance.source, MeasurementSource.mock);
    }
  });

  test('rhythm results keep touch provenance and unmeasured memory', () async {
    final pattern = draftRhythmPatterns.first;
    final outcome = await RhythmImitationEvaluator.evaluate(
      protocol: pattern.exercise.protocol,
      tapTimestamps: const [
        Duration(milliseconds: 100),
        Duration(milliseconds: 850),
        Duration(milliseconds: 1600),
        Duration(milliseconds: 2350),
      ],
    );
    final r = outcome.toResult(
      exercise: pattern.exercise,
      sessionId: 's',
      createdAt: DateTime.utc(2026, 10, 11),
    );
    final back = ExerciseResult.fromJson(_wire(r));
    expect(back.provenance.source, MeasurementSource.touch);
    expect(back.scores.memory.isMeasured, isFalse);
    expect(jsonEncode(back.toJson()), jsonEncode(r.toJson()));
  });

  test('strict reader rejects schema, enum, metric and contract errors', () {
    final good = _wire(
      ExerciseResult(
        sessionId: 's',
        exerciseId: 'e',
        skill: Skill.pitch,
        target: const {},
        measurements: const {},
        scores: const ExerciseScores(),
        createdAt: DateTime.utc(2026),
        measurementStatus: MeasurementStatus.invalid,
      ),
    );
    expect(ExerciseResult.fromJson(good).isValid, isFalse);
    Map<String, Object?> mutate(void Function(Map<String, Object?>) f) {
      final copy = jsonDecode(jsonEncode(good)) as Map<String, Object?>;
      f(copy);
      return copy;
    }

    for (final bad in [
      mutate((m) => m['schemaVersion'] = 1),
      mutate((m) => m['skill'] = 'opera'),
      mutate((m) => m['exerciseMode'] = 'learning_mode'),
      mutate((m) => m['createdAt'] = 'soon'),
      mutate((m) => (m['provenance'] as Map)['source'] = 'cloud'),
      mutate(
        (m) => (m['scores'] as Map)['overall'] = {
          'status': 'measured',
          'value': null,
        },
      ),
      mutate(
        (m) => (m['scores'] as Map)['overall'] = {
          'status': 'not_measured',
          'value': 40,
        },
      ),
      // Invalid measurement cannot carry a measured score.
      mutate(
        (m) => (m['scores'] as Map)['overall'] = {
          'status': 'measured',
          'value': 40,
        },
      ),
      mutate((m) => m['difficulty'] = 0),
      mutate((m) => m.remove('errors')),
    ]) {
      expect(() => ExerciseResult.fromJson(bad), throwsFormatException);
    }
  });
}
