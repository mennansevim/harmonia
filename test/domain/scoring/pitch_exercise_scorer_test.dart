import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_analyzer.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/score_metric.dart';
import 'dart:convert';
import 'package:harmonia/domain/scoring/pitch_exercise_scorer.dart';

void main() {
  const exercise = Exercise(
    id: 'single-tone-c4',
    skill: Skill.pitch,
    title: 'Tek Ses: Do (C4)',
    difficulty: 1,
    targetNote: TargetNote(note: 'C4', frequencyHz: 261.63),
  );

  const scorer = PitchExerciseScorer();
  final createdAt = DateTime(2026, 1, 1);

  ExerciseResult scoreFor(PitchAnalysisResult pitch) => scorer.score(
    exercise: exercise,
    sessionId: 'session-1',
    pitch: pitch,
    createdAt: createdAt,
  );

  test('an accurate, stable note is reported as success with no errors', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: 262.5,
      centsDifference: 6,
      octaveOffset: 0,
      voicedRatio: 0.95,
      stabilityCents: 8,
      isNoisy: false,
    );

    final result = scoreFor(pitch);

    expect(result.isSuccess, isTrue);
    expect(result.errors, isEmpty);
    expect(result.scores.overall.value, greaterThan(80));
    expect(result.scores.timing.status, ScoreMetricStatus.notApplicable);
    expect(result.scores.memory.status, ScoreMetricStatus.notApplicable);
  });

  test('a wrong note within the same octave is flagged as wrong_note', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: 233,
      centsDifference: -200,
      octaveOffset: 0,
      voicedRatio: 0.9,
      stabilityCents: 10,
      isNoisy: false,
    );

    final result = scoreFor(pitch);

    expect(result.isSuccess, isFalse);
    expect(result.errors.single.type, ExerciseErrorType.wrongNote);
    // A note error should never be scored as a pass.
    expect(result.scores.overall.value, lessThan(50));
  });

  test('ADR-006: a correct pitch class in the wrong octave is still an error, '
      'never success', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: 131,
      centsDifference: 4,
      octaveOffset: -1,
      voicedRatio: 0.92,
      stabilityCents: 9,
      isNoisy: false,
    );

    final result = scoreFor(pitch);

    expect(result.isSuccess, isFalse);
    expect(result.errors.single.type, ExerciseErrorType.wrongOctave);
    expect(result.scores.overall.value, lessThan(50));
  });

  test('a noise-dominated signal is flagged as noise, not a pitch error', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: 240,
      centsDifference: -30,
      octaveOffset: 0,
      voicedRatio: 0.3,
      stabilityCents: 60,
      isNoisy: true,
    );

    final result = scoreFor(pitch);

    expect(result.isSuccess, isFalse);
    expect(result.errors.single.type, ExerciseErrorType.noise);
    expect(result.measurementStatus, MeasurementStatus.invalid);
    expect(result.scores.hasMeasurements, isFalse);
    expect(result.scores.overall.value, isNull);
  });

  test('no detected pitch at all is flagged as missing_voice', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: null,
      centsDifference: null,
      octaveOffset: 0,
      voicedRatio: 0.02,
      stabilityCents: 0,
      isNoisy: false,
    );

    final result = scoreFor(pitch);

    expect(result.isSuccess, isFalse);
    expect(result.errors.single.type, ExerciseErrorType.missingVoice);
    expect(result.measurementStatus, MeasurementStatus.invalid);
    expect(result.scores.hasMeasurements, isFalse);
    expect(result.scores.memory.value, isNull);
  });

  test('a correct but wavering pitch is flagged as unstable', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: 263,
      centsDifference: 10,
      octaveOffset: 0,
      voicedRatio: 0.85,
      stabilityCents: 45,
      isNoisy: false,
    );

    final result = scoreFor(pitch);

    expect(result.isSuccess, isFalse);
    expect(result.errors.single.type, ExerciseErrorType.unstable);
    // Instability alone should not drag overall below a pass by itself the
    // way a note/octave error does, but must still be surfaced as an error.
    expect(result.scores.stability.value, lessThan(50));
  });

  test('measurements always mirror the raw pitch analysis', () {
    const pitch = PitchAnalysisResult(
      detectedFrequencyHz: 262.5,
      centsDifference: 6,
      octaveOffset: 0,
      voicedRatio: 0.95,
      stabilityCents: 8,
      isNoisy: false,
    );

    final result = scoreFor(pitch);

    expect(result.measurements['frequency'], 262.5);
    expect(result.measurements['centsDifference'], 6);
    expect(result.measurements['octaveOffset'], 0);
    expect(result.target, {'note': 'C4', 'frequency': 261.63});
  });

  test('non-finite pitch data cannot produce scores and remains JSON-safe', () {
    final result = scoreFor(
      const PitchAnalysisResult(
        detectedFrequencyHz: double.nan,
        centsDifference: double.infinity,
        octaveOffset: 0,
        voicedRatio: double.nan,
        stabilityCents: 8,
        isNoisy: false,
      ),
    );
    expect(result.isValid, isFalse);
    expect(result.errors.single.type, ExerciseErrorType.invalidSignal);
    expect(result.scores.hasMeasurements, isFalse);
    expect(() => jsonEncode(result.toJson()), returnsNormally);
  });

  test('out-of-range quality data is invalid, not a learner error', () {
    final result = scoreFor(
      const PitchAnalysisResult(
        detectedFrequencyHz: 261.63,
        centsDifference: 0,
        octaveOffset: 0,
        voicedRatio: 1.1,
        stabilityCents: 8,
        isNoisy: false,
      ),
    );
    expect(result.isValid, isFalse);
    expect(result.scores.hasMeasurements, isFalse);
  });

  test('scorer preserves difficulty, mode and content version', () {
    final result = scorer.score(
      exercise: const Exercise(
        id: 'exam',
        skill: Skill.pitch,
        title: 'Exam',
        difficulty: 3,
        mode: ExerciseMode.recallExam,
        contentVersion: '2026-v1',
        targetNote: TargetNote(note: 'C4', frequencyHz: 261.63),
      ),
      sessionId: 'exam-session',
      createdAt: createdAt,
      pitch: const PitchAnalysisResult(
        detectedFrequencyHz: 261.63,
        centsDifference: 0,
        octaveOffset: 0,
        voicedRatio: 0.9,
        stabilityCents: 8,
        isNoisy: false,
      ),
    );
    expect(result.difficulty, 3);
    expect(result.exerciseMode, ExerciseMode.recallExam);
    expect(result.contentVersion, '2026-v1');
  });

  test('missing target is rejected in release-compatible validation', () {
    expect(
      () => scorer.score(
        exercise: const Exercise(
          id: 'bad',
          skill: Skill.pitch,
          title: 'Bad',
          difficulty: 1,
        ),
        sessionId: 's',
        createdAt: createdAt,
        pitch: const PitchAnalysisResult(
          detectedFrequencyHz: null,
          centsDifference: null,
          octaveOffset: 0,
          voicedRatio: 0,
          stabilityCents: 0,
          isNoisy: false,
        ),
      ),
      throwsArgumentError,
    );
  });
}
