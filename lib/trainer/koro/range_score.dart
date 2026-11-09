import 'dart:math' as math;

import 'range_ladder.dart';

/// RANGE-04: deterministic 0–100 score of one range test, from the ladder's
/// own judgements. Width weighs most, so a wide range counts more, but a wide
/// range sung loosely cannot beat a narrower clean one. Not a voice type and
/// not a teacher's assessment; octave-off, missed and unmeasured takes never
/// count as reached.

/// 36 semitones (three octaves) fills the width part; wider adds nothing.
const rangeScoreFullWidth = 36;
const rangeScoreWidthWeight = 0.60;
const rangeScoreAccuracyWeight = 0.25;
const rangeScoreFirstTryWeight = 0.15;

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
      accuracy: closeness / matched.length,
      firstTry: clean / matched.length * 100,
    );
  }

  final int semitones;

  /// Each part 0–100.
  final double width, accuracy, firstTry;

  double get total =>
      rangeScoreWidthWeight * width +
      rangeScoreAccuracyWeight * accuracy +
      rangeScoreFirstTryWeight * firstTry;

  int get points => total.round();

  RangeBand get band => rangeBandOf(semitones);
}

/// 1-based place of [points] among [history] (which includes it); ties share
/// the better place.
int personalRank(int points, List<int> history) =>
    1 + history.where((p) => p > points).length;
