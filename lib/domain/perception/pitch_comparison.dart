import 'dart:math' as math;

import '../content/rhythm_patterns.dart';
import '../models/exercise.dart';
import '../models/exercise_result.dart';
import '../models/measurement_provenance.dart';
import '../models/score_metric.dart';

/// PERC-01 "which tone is higher?" — a perception task answered by tapping.
/// No microphone or DSP: the answer itself is the measurement. Production
/// (singing) is a different skill and is never inferred from this.
enum PitchAnswer { first, second }

class PitchComparisonItem {
  PitchComparisonItem({required this.firstHz, required this.secondHz}) {
    for (final hz in [firstHz, secondHz]) {
      if (!hz.isFinite || hz < 80 || hz > 1200) {
        throw ArgumentError('Tone outside 80–1200 Hz');
      }
    }
    if (firstHz == secondHz) throw ArgumentError('Tones must differ');
  }
  final double firstHz;
  final double secondHz;
  PitchAnswer get correct =>
      secondHz > firstHz ? PitchAnswer.second : PitchAnswer.first;
}

class PitchComparisonLevel {
  PitchComparisonLevel({
    required this.exerciseId,
    required this.title,
    required this.centsStep,
    this.contentVersion = 'draft-1',
    this.review = ContentReviewStatus.draftAwaitingEducator,
  }) {
    if (centsStep < 5 || centsStep > 1200) {
      throw ArgumentError('Invalid cents step');
    }
  }
  final String exerciseId;
  final String title;
  final double centsStep;
  final String contentVersion;
  final ContentReviewStatus review;
}

/// Draft levels (developer proposal; educator review pending).
final List<PitchComparisonLevel> draftPitchLevels = List.unmodifiable([
  PitchComparisonLevel(
    exerciseId: 'draft-perc-highlow-200',
    title: 'Tam ses farkı',
    centsStep: 200,
  ),
  PitchComparisonLevel(
    exerciseId: 'draft-perc-highlow-100',
    title: 'Yarım ses farkı',
    centsStep: 100,
  ),
  PitchComparisonLevel(
    exerciseId: 'draft-perc-highlow-50',
    title: 'Çeyrek ton farkı',
    centsStep: 50,
  ),
]);

class PitchComparisonRound {
  PitchComparisonRound._(this.level, this.items);

  static const itemCount = 8;

  /// Comfortable C4–A4 bases; exactly half the items have the second tone
  /// higher, in seeded random order, so "always answer 2" scores 50 %.
  factory PitchComparisonRound.generate(
    PitchComparisonLevel level,
    math.Random rng,
  ) {
    const bases = [261.63, 293.66, 329.63, 349.23, 392.0, 440.0];
    final ratio = math.pow(2, level.centsStep / 1200).toDouble();
    final secondHigher = [
      for (var i = 0; i < itemCount; i++) i < itemCount ~/ 2,
    ]..shuffle(rng);
    return PitchComparisonRound._(level, [
      for (final up in secondHigher)
        () {
          final base = bases[rng.nextInt(bases.length)];
          return up
              ? PitchComparisonItem(firstHz: base, secondHz: base * ratio)
              : PitchComparisonItem(firstHz: base * ratio, secondHz: base);
        }(),
    ]);
  }

  final PitchComparisonLevel level;
  final List<PitchComparisonItem> items;
}

enum PitchComparisonStatus { measured, incomplete }

class PitchComparisonOutcome {
  PitchComparisonOutcome({
    required this.round,
    required List<PitchAnswer?> answers,
    required List<int> plays,
  }) : answers = List.unmodifiable(answers),
       plays = List.unmodifiable(plays) {
    if (answers.length != round.items.length ||
        plays.length != round.items.length ||
        plays.any((p) => p < 0)) {
      throw ArgumentError('Answers/plays must match items');
    }
  }

  static const version = 'pitch-comparison-1';

  /// Probability of ≥7/8 by guessing ≈ 3.5 %; shown to the student.
  static const chanceLevelPercent = 50;

  final PitchComparisonRound round;
  final List<PitchAnswer?> answers;
  final List<int> plays;

  PitchComparisonStatus get status => answers.contains(null)
      ? PitchComparisonStatus.incomplete
      : PitchComparisonStatus.measured;
  int get correctCount => [
    for (var i = 0; i < answers.length; i++)
      if (answers[i] == round.items[i].correct) i,
  ].length;
  bool isCorrect(int i) => answers[i] == round.items[i].correct;

  /// Max listens of any pair; 1 means every pair was heard once.
  int get referencePlays => plays.fold(0, math.max);

  ExerciseResult toResult({
    required String sessionId,
    required DateTime createdAt,
    bool retentionCheck = false,
  }) {
    final measured = status == PitchComparisonStatus.measured;
    final total = round.items.length;
    return ExerciseResult(
      sessionId: sessionId,
      exerciseId: round.level.exerciseId,
      skill: Skill.pitch,
      target: {'centsStep': round.level.centsStep, 'items': total},
      measurements: {
        'dimension': 'perception',
        'correct': measured ? correctCount : null,
        'total': total,
        'referencePlays': referencePlays,
        'retentionCheck': retentionCheck,
      },
      scores: measured
          ? ExerciseScores(
              overall: ScoreMetric.measured(100 * correctCount / total),
              accuracy: ScoreMetric.measured(100 * correctCount / total),
              timing: const ScoreMetric.notApplicable(),
              stability: const ScoreMetric.notApplicable(),
              memory: const ScoreMetric.notApplicable(),
            )
          : const ExerciseScores(),
      measurementStatus: measured
          ? MeasurementStatus.valid
          : MeasurementStatus.invalid,
      contentVersion: round.level.contentVersion,
      createdAt: createdAt,
      provenance: const MeasurementProvenance(
        source: MeasurementSource.touch,
        analyzerVersion: version,
      ),
    );
  }
}
