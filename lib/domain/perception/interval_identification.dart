import 'dart:math' as math;

import '../content/rhythm_patterns.dart';
import '../models/exercise.dart';
import '../models/exercise_result.dart';
import '../models/measurement_provenance.dart';
import '../models/score_metric.dart';

/// INT-01a: movable-do degree hearing (ADR-024). Each item plays a tonic
/// context, then do and a target degree ascending; the student names the
/// degree. The tonic changes every item, so absolute note names never help.
/// Perception only: singing (production) is never inferred from this.
enum SolfegeDegree { re, mi, fa, sol, la, ti, doHigh }

extension SolfegeDegreeInfo on SolfegeDegree {
  /// Major-scale semitones above do.
  int get semitones => switch (this) {
    SolfegeDegree.re => 2,
    SolfegeDegree.mi => 4,
    SolfegeDegree.fa => 5,
    SolfegeDegree.sol => 7,
    SolfegeDegree.la => 9,
    SolfegeDegree.ti => 11,
    SolfegeDegree.doHigh => 12,
  };

  String get syllable => switch (this) {
    SolfegeDegree.re => 're',
    SolfegeDegree.mi => 'mi',
    SolfegeDegree.fa => 'fa',
    SolfegeDegree.sol => 'sol',
    SolfegeDegree.la => 'la',
    SolfegeDegree.ti => 'ti',
    SolfegeDegree.doHigh => "do'",
  };

  /// Turkish interval name above do (draft wording, educator review).
  String get intervalName => switch (this) {
    SolfegeDegree.re => "büyük 2'li",
    SolfegeDegree.mi => "büyük 3'lü",
    SolfegeDegree.fa => "tam 4'lü",
    SolfegeDegree.sol => "tam 5'li",
    SolfegeDegree.la => "büyük 6'lı",
    SolfegeDegree.ti => "büyük 7'li",
    SolfegeDegree.doHigh => "tam 8'li",
  };
}

class IntervalLevel {
  IntervalLevel({
    required this.exerciseId,
    required this.title,
    required List<SolfegeDegree> options,
    this.contentVersion = 'draft-1',
    this.review = ContentReviewStatus.draftAwaitingEducator,
  }) : options = List.unmodifiable(options) {
    if (options.length < 2 || options.toSet().length != options.length) {
      throw ArgumentError('Need at least two distinct options');
    }
  }
  final String exerciseId;
  final String title;
  final List<SolfegeDegree> options;
  final String contentVersion;
  final ContentReviewStatus review;
}

final List<IntervalLevel> draftIntervalLevels = List.unmodifiable([
  IntervalLevel(
    exerciseId: 'draft-int-do-re-mi-sol',
    title: 're · mi · sol',
    options: [SolfegeDegree.re, SolfegeDegree.mi, SolfegeDegree.sol],
  ),
  IntervalLevel(
    exerciseId: 'draft-int-do-to-la',
    title: 're → la',
    options: [
      SolfegeDegree.re,
      SolfegeDegree.mi,
      SolfegeDegree.fa,
      SolfegeDegree.sol,
      SolfegeDegree.la,
    ],
  ),
  IntervalLevel(
    exerciseId: 'draft-int-full-scale',
    title: "re → do'",
    options: SolfegeDegree.values,
  ),
]);

class IntervalItem {
  IntervalItem({required this.tonicHz, required this.degree}) {
    if (!tonicHz.isFinite || tonicHz < 100 || tonicHz > 600) {
      throw ArgumentError('Tonic outside 100–600 Hz');
    }
  }
  final double tonicHz;
  final SolfegeDegree degree;
  double hzOf(int semitones) => tonicHz * math.pow(2, semitones / 12);
  double get targetHz => hzOf(degree.semitones);
}

class IntervalRound {
  IntervalRound._(this.level, this.items);
  static const itemCount = 8;

  /// Options are spread as evenly as possible over 8 items, shuffled; the
  /// tonic is drawn per item from comfortable keys (A3–G4).
  factory IntervalRound.generate(IntervalLevel level, math.Random rng) {
    const tonics = [220.0, 246.94, 261.63, 293.66, 329.63, 349.23, 392.0];
    final pool = <SolfegeDegree>[
      for (var i = 0; i < itemCount; i++)
        level.options[i % level.options.length],
    ]..shuffle(rng);
    return IntervalRound._(level, [
      for (final d in pool)
        IntervalItem(tonicHz: tonics[rng.nextInt(tonics.length)], degree: d),
    ]);
  }

  final IntervalLevel level;
  final List<IntervalItem> items;
}

class IntervalOutcome {
  IntervalOutcome({
    required this.round,
    required List<SolfegeDegree?> answers,
    required List<int> plays,
  }) : answers = List.unmodifiable(answers),
       plays = List.unmodifiable(plays) {
    if (answers.length != round.items.length ||
        plays.length != round.items.length) {
      throw ArgumentError('Answers/plays must match items');
    }
  }

  static const version = 'interval-movable-do-1';

  final IntervalRound round;
  final List<SolfegeDegree?> answers;
  final List<int> plays;

  bool get complete => !answers.contains(null);
  int get correctCount => [
    for (var i = 0; i < answers.length; i++)
      if (answers[i] == round.items[i].degree) i,
  ].length;
  int get referencePlays => plays.fold(0, math.max);
  double get chancePercent => 100 / round.level.options.length;

  /// "heard→answered" counts for wrong answers, e.g. {"sol→fa": 2}.
  Map<String, int> get confusions {
    final out = <String, int>{};
    for (var i = 0; i < answers.length; i++) {
      final a = answers[i];
      final d = round.items[i].degree;
      if (a != null && a != d) {
        final key = '${d.syllable}→${a.syllable}';
        out[key] = (out[key] ?? 0) + 1;
      }
    }
    return out;
  }

  ExerciseResult toResult({
    required String sessionId,
    required DateTime createdAt,
    bool retentionCheck = false,
  }) {
    final total = round.items.length;
    return ExerciseResult(
      sessionId: sessionId,
      exerciseId: round.level.exerciseId,
      skill: Skill.interval,
      target: {
        'solfege': 'movable_do',
        'options': [for (final o in round.level.options) o.syllable],
        'items': total,
      },
      measurements: {
        'dimension': 'perception',
        'correct': complete ? correctCount : null,
        'total': total,
        'chancePercent': chancePercent,
        'confusions': complete ? confusions : null,
        'referencePlays': referencePlays,
        'retentionCheck': retentionCheck,
      },
      scores: complete
          ? ExerciseScores(
              overall: ScoreMetric.measured(100 * correctCount / total),
              accuracy: ScoreMetric.measured(100 * correctCount / total),
              timing: const ScoreMetric.notApplicable(),
              stability: const ScoreMetric.notApplicable(),
              memory: const ScoreMetric.notApplicable(),
            )
          : const ExerciseScores(),
      measurementStatus: complete
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
