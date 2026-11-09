import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/koro/range_ladder.dart';
import 'package:resonia/trainer/koro/range_score.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

double _hz(int midi, [double cents = 0]) =>
    440.0 * math.pow(2, (midi - 69 + cents / 100) / 12).toDouble();

/// Up from A3 through [up] notes, then down through [down] notes; each step
/// is the list of takes for that note (null = unmeasured, NaN = miss).
RangeLadder _run(List<List<double?>> takes) {
  var l = RangeLadder.start(57);
  for (final note in takes) {
    for (final cents in note) {
      final hz = cents == null
          ? null
          : cents.isNaN
          ? _hz(l.currentMidi, 70) // 70 cents off: a measured miss
          : _hz(l.currentMidi, cents);
      l = l.record(hz);
    }
  }
  return l;
}

void main() {
  test('width weighs most, then accuracy, then first try', () {
    expect(
      rangeScoreWidthWeight +
          rangeScoreAccuracyWeight +
          rangeScoreFirstTryWeight,
      closeTo(1, 1e-9),
    );
    expect(rangeScoreWidthWeight, greaterThan(rangeScoreAccuracyWeight));
    expect(rangeScoreAccuracyWeight, greaterThan(rangeScoreFirstTryWeight));
  });

  test('a clean run scores its parts', () {
    // A3 B3 C4 matched, then two misses on D4; down: G3 matched, two misses.
    final l = _run([
      [0],
      [0],
      [0],
      [double.nan, double.nan],
      [0],
      [double.nan, double.nan],
    ]);
    expect(l.done, isTrue);
    final s = RangeScore.of(l)!;
    expect(s.semitones, 5); // G3–C4
    expect(s.width, closeTo(5 / 36 * 100, 1e-9));
    expect(s.accuracy, closeTo(100, 1e-9));
    expect(s.firstTry, 100);
    expect(s.points, (0.6 * 5 / 36 * 100 + 25 + 15).round());
    expect(s.band, RangeBand.narrow);
  });

  test('a measured miss costs first try, an unmeasured take does not', () {
    final l = _run([
      [double.nan, 0], // A3 on the second try after a real miss
      [null, 0], // B3 after an unmeasured take
      [double.nan, double.nan],
      [0], // G3
      [double.nan, double.nan],
    ]);
    final s = RangeScore.of(l)!;
    expect(s.firstTry, closeTo(2 / 3 * 100, 1e-9));
  });

  test('looser takes lower accuracy, never the reached range', () {
    final tight = RangeScore.of(
      _run([
        [0],
        [0],
        [double.nan, double.nan],
        [double.nan, double.nan],
      ]),
    )!;
    final loose = RangeScore.of(
      _run([
        [30],
        [-30],
        [double.nan, double.nan],
        [double.nan, double.nan],
      ]),
    )!;
    expect(loose.semitones, tight.semitones);
    expect(loose.accuracy, closeTo(70, 1e-9));
    expect(loose.points, lessThan(tight.points));
  });

  test('no range, no score', () {
    expect(
      RangeScore.of(
        _run([
          [double.nan, double.nan],
          [double.nan, double.nan],
        ]),
      ),
      isNull,
    );
  });

  test('width is capped at three octaves', () {
    const s = RangeScore(semitones: 48, width: 100, accuracy: 0, firstTry: 0);
    expect(s.points, 60);
    expect(
      math.min(1, 48 / rangeScoreFullWidth) * 100,
      100,
      reason: 'wider adds nothing',
    );
  });

  test('reference bands follow the published spans', () {
    expect(rangeBandOf(11), RangeBand.narrow);
    expect(rangeBandOf(12), RangeBand.typical);
    expect(rangeBandOf(18), RangeBand.typical);
    expect(rangeBandOf(19), RangeBand.wide);
    expect(rangeBandOf(23), RangeBand.singer);
  });

  test('personal rank: ties share the better place', () {
    expect(personalRank(70, [70]), 1);
    expect(personalRank(60, [55, 70, 60, 80]), 3);
    expect(personalRank(70, [70, 70, 50]), 1);
  });

  test('the store keeps the last scores and survives a reload', () async {
    final p = MemoryTrainerPersistence();
    final store = TrainerStore(p);
    await store.load();
    for (var i = 0; i < TrainerStore.maxRangeScores + 5; i++) {
      store.addRangeScore(i);
    }
    store
      ..addRangeScore(140)
      ..save();
    await store.flush();
    expect(store.rangeScores.length, TrainerStore.maxRangeScores);
    expect(store.rangeScores.last, 100, reason: 'clamped to 0–100');
    final again = TrainerStore(p);
    await again.load();
    expect(again.rangeScores, store.rangeScores);
  });
}
