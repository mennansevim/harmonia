import 'dart:math' as math;

import 'range_ladder.dart';

/// RANGE-04: deterministic 0–100 match score of one range test, from the
/// ladder's own judgements. The reached range (width) is DESCRIPTIVE only and
/// is not part of the score: a wider range is not a better voice, and a
/// loosely sung wide range must not outscore a clean narrower one. The score
/// is how precisely the notes that were reached were matched (accuracy, first
/// try). Not a voice type, not a skill grade and not a teacher's assessment;
/// octave-off, missed and unmeasured takes never count as reached.

/// 36 semitones (three octaves) is the full scale of the descriptive [width]
/// bar; wider adds nothing. Not scored.
const rangeScoreFullWidth = 36;

/// Weights of the match score (the earlier .25 : .15 accuracy : first-try
/// ratio, normalised to 1).
const rangeScoreAccuracyWeight = 0.625;
const rangeScoreFirstTryWeight = 0.375;

/// A matched take has closeness 60–100 (within [rangeToleranceCents]·0.4 =
/// 40 cents); accuracy rescales that band to 0–100 so it can spread.
const rangeScoreClosenessFloor = rangePassMark;

/// Stored scores follow this formula; a different version's scores are
/// dropped, not mixed (see TrainerStore).
const rangeScoreModelVersion = 'match-1';

/// Published reference spans (semitones), not a ranking against users:
/// untrained adults commonly sing 12–18 (voicescience.org summary), non-singers
/// averaged about 18 and singers about 23 in the modal register (JSHR 1972,
/// 35 non-singers, 8 singers).
const rangeTypicalLow = 12;
const rangeTypicalHigh = 18;
const rangeSingerAverage = 23;

enum RangeBand {
  /// Under [rangeTypicalLow].
  narrow,

  /// [rangeTypicalLow]–[rangeTypicalHigh]: typical untrained adult.
  typical,

  /// Above typical, below the singers' average.
  wide,

  /// At or above [rangeSingerAverage].
  singer,
}

RangeBand rangeBandOf(int semitones) => semitones < rangeTypicalLow
    ? RangeBand.narrow
    : semitones <= rangeTypicalHigh
    ? RangeBand.typical
    : semitones < rangeSingerAverage
    ? RangeBand.wide
    : RangeBand.singer;

class RangeScore {
  const RangeScore({
    required this.semitones,
    required this.width,
    required this.accuracy,
    required this.firstTry,
  });

  /// Null without a range (fewer than two reached notes).
  static RangeScore? of(RangeLadder ladder) {
    final bounds = ladder.bounds;
    if (bounds == null) return null;
    final matched = [
      for (final a in ladder.log)
        if (a.judgement.match == RangeMatch.matched) a,
    ];
    if (matched.isEmpty) return null;
    final closeness = [
      for (final a in matched) a.judgement.closeness ?? 0,
    ].fold(0.0, (s, c) => s + c);
    // First try: no MEASURED miss before the match on that note. An
    // unmeasured take is the recorder's fault, not the singer's.
    var clean = 0;
    for (final m in matched) {
      final misses = ladder.log.where(
        (a) =>
            a.targetMidi == m.targetMidi &&
            a.direction == m.direction &&
            a.attempt < m.attempt &&
            a.judgement.match != RangeMatch.unmeasured,
      );
      if (misses.isEmpty) clean++;
    }
    return RangeScore(
      semitones: bounds.semitones,
      width: math.min(1, bounds.semitones / rangeScoreFullWidth) * 100,
      accuracy: math.max(
        0,
        math.min(
          100,
          (closeness / matched.length - rangeScoreClosenessFloor) /
              (100 - rangeScoreClosenessFloor) *
              100,
        ),
      ),
      firstTry: clean / matched.length * 100,
    );
  }

  final int semitones;

  /// Each part 0–100. [width] is descriptive and not in [total].
  final double width, accuracy, firstTry;

  double get total =>
      rangeScoreAccuracyWeight * accuracy + rangeScoreFirstTryWeight * firstTry;

  int get points => total.round();

  RangeBand get band => rangeBandOf(semitones);
}

/// 1-based place of [points] among [history] (which includes it); ties share
/// the better place.
int personalRank(int points, List<int> history) =>
    1 + history.where((p) => p > points).length;
