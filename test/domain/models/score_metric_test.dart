import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/score_metric.dart';

void main() {
  test('measured zero differs from missing and inapplicable evidence', () {
    expect(ScoreMetric.measured(0).toJson(), {
      'status': 'measured',
      'value': 0.0,
    });
    expect(const ScoreMetric.notMeasured().toJson(), {
      'status': 'not_measured',
      'value': null,
    });
    expect(const ScoreMetric.notApplicable().toJson(), {
      'status': 'not_applicable',
      'value': null,
    });
  });

  test('non-finite and out-of-range scores are rejected at runtime', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1.0,
      100.01,
    ]) {
      expect(() => ScoreMetric.measured(value), throwsArgumentError);
    }
  });

  ExerciseResult result({
    MeasurementStatus status = MeasurementStatus.valid,
    ExerciseScores scores = const ExerciseScores(),
  }) => ExerciseResult(
    sessionId: 's',
    exerciseId: 'e',
    skill: Skill.pitch,
    target: const {},
    measurements: const {},
    scores: scores,
    measurementStatus: status,
    createdAt: DateTime(2026, 10, 11),
  );

  test('empty error list without measurement is not success', () {
    expect(result().isSuccess, isFalse);
    expect(result(status: MeasurementStatus.invalid).isSuccess, isFalse);
  });

  test('invalid results cannot carry scored evidence', () {
    expect(
      () => result(
        status: MeasurementStatus.invalid,
        scores: ExerciseScores(accuracy: ScoreMetric.measured(80)),
      ),
      throwsArgumentError,
    );
  });

  test('v2 JSON preserves status and provenance with null values', () {
    final payload =
        jsonDecode(jsonEncode(result().toJson())) as Map<String, dynamic>;
    expect(payload['schemaVersion'], 2);
    expect(payload['measurementStatus'], 'valid');
    expect(payload['exerciseMode'], 'learning');
    expect(payload['difficulty'], 1);
    expect(payload['scoringVersion'], '2');
    expect(payload['scores']['timing'], {
      'status': 'not_measured',
      'value': null,
    });
  });
}
