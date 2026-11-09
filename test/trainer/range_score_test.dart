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
  storeVersionTests();
  test('the score is accuracy and first try only; width is descriptive', () {
    expect(
      rangeScoreAccuracyWeight + rangeScoreFirstTryWeight,
      closeTo(1, 1e-9),
    );
    // The old .25 : .15 ratio, normalised.
    expect(rangeScoreAccuracyWeight, closeTo(0.625, 1e-12));
    expect(rangeScoreFirstTryWeight, closeTo(0.375, 1e-12));
    expect(rangeScoreModelVersion, 'match-1');
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
    expect(s.points, 100, reason: 'width 5 does not lower a clean match');
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
    // closeness 70 → (70−60)/40·100
    expect(loose.accuracy, closeTo(25, 1e-9));
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

  test('width never changes the points', () {
    const narrow = RangeScore(
      semitones: 6,
      width: 17,
      accuracy: 80,
      firstTry: 50,
    );
    const wide = RangeScore(
      semitones: 48,
      width: 100,
      accuracy: 80,
      firstTry: 50,
    );
    expect(wide.points, narrow.points);
    expect(wide.total, closeTo(0.625 * 80 + 0.375 * 50, 1e-9));
  });

  test('a wide loose run no longer beats a narrow clean one', () {
    const loose = RangeScore(
      semitones: 36,
      width: 100,
      accuracy: 0,
      firstTry: 0,
    );
    const clean = RangeScore(
      semitones: 14,
      width: 14 / 36 * 100,
      accuracy: 100,
      firstTry: 100,
    );
    expect(loose.points, 0);
    expect(clean.points, 100);
    expect(loose.points, lessThan(clean.points));
  });

  test('accuracy spreads over 0–100 from the 40-cent edge to exact', () {
    RangeScore at(double cents) => RangeScore.of(
      _run([
        [cents],
        [cents],
        [double.nan, double.nan],
        [double.nan, double.nan],
      ]),
    )!;
    expect(at(0).accuracy, closeTo(100, 1e-9));
    expect(at(20).accuracy, closeTo(50, 1e-6));
    expect(at(39).accuracy, closeTo(2.5, 1e-6));
  });

  test('an octave-off, missed or unmeasured take still never counts', () {
    // Only unmeasured / missed takes: no range, no score.
    expect(
      RangeScore.of(
        _run([
          [null, null],
          [double.nan, double.nan],
        ]),
      ),
      isNull,
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

void storeVersionTests() {
  test(
    'scores of another formula version are dropped, the rest kept',
    () async {
      final p = MemoryTrainerPersistence({
        'onboardingDone': true,
        'xp': 90,
        'koroRange': '53-69',
        'rangeScores': [62, 80],
      });
      final old = TrainerStore(p);
      await old.load();
      expect(
        old.rangeScores,
        isEmpty,
        reason: 'no rangeScoreModel → old scale',
      );
      expect(old.xp, 90);
      expect(old.koroRange, '53-69');
      final wrong = TrainerStore(
        MemoryTrainerPersistence({
          'rangeScoreModel': 'width-weighted',
          'rangeScores': [62],
        }),
      );
      await wrong.load();
      expect(wrong.rangeScores, isEmpty);
      final current = TrainerStore(
        MemoryTrainerPersistence({
          'rangeScoreModel': rangeScoreModelVersion,
          'rangeScores': [62, 80],
        }),
      );
      await current.load();
      expect(current.rangeScores, [62, 80]);
    },
  );
}
