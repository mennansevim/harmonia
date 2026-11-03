import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/review_memory.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/learn/review_cards.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import 'trainer_app_test.dart' show app, settle, tapKey;

final t0 = DateTime(2026, 11, 3, 9);

ItemMemory mem(double h, {double daysAgo = 0}) => ItemMemory(
  halfLifeDays: h,
  lastSeen: t0.subtract(Duration(minutes: (daysAgo * 24 * 60).round())),
);

void main() {
  group('half-life memory', () {
    test('recall halves after one half-life and is due below target', () {
      expect(mem(2).recall(t0), 1);
      expect(mem(2, daysAgo: 2).recall(t0), closeTo(0.5, 1e-9));
      // Due once 2^(−Δ/h) < 0.85, i.e. after about 0.234·h.
      expect(mem(10, daysAgo: 2).isDue(t0), isFalse);
      expect(mem(10, daysAgo: 2.5).isDue(t0), isTrue);
    });

    test('a spaced correct answer doubles, a massed one does not', () {
      final spaced = mem(2, daysAgo: 1.5).answered(true, t0);
      expect(spaced.halfLifeDays, 4);
      expect(spaced.reps, 1);
      final massed = mem(2, daysAgo: 0.01).answered(true, t0);
      expect(massed.halfLifeDays, 2);
      expect(massed.reps, 0);
      expect(mem(60, daysAgo: 40).answered(true, t0).halfLifeDays, 60);
    });

    test('a wrong answer halves, never below the floor', () {
      final w = mem(4, daysAgo: 1).answered(false, t0);
      expect(w.halfLifeDays, 2);
      expect(w.lapses, 1);
      expect(mem(0.5).answered(false, t0).halfLifeDays, minHalfLifeDays);
      expect(ItemMemory.first(false, t0).halfLifeDays, minHalfLifeDays);
      expect(ItemMemory.first(true, t0).halfLifeDays, startHalfLifeDays);
    });

    test('json round-trips and rejects out-of-range values', () {
      final m = ItemMemory(halfLifeDays: 3, lastSeen: t0, reps: 2, lapses: 1);
      final back = ItemMemory.fromJson(m.toJson())!;
      expect(back.halfLifeDays, 3);
      expect(back.lastSeen, t0);
      expect(back.reps, 2);
      expect(ItemMemory.fromJson([999, 0, 0, 0]), isNull);
      expect(ItemMemory.fromJson([1, 0, -1, 0]), isNull);
      expect(ItemMemory.fromJson('x'), isNull);
    });

    test('due cards: most forgotten first, trainers interleaved, capped', () {
      final memory = {
        'interval': {
          'M3': mem(1, daysAgo: 3),
          'P5': mem(1, daysAgo: 2),
          'm3': mem(1, daysAgo: 1),
          'P4': mem(30, daysAgo: 1), // not due
        },
        'chord': {'maj': mem(1, daysAgo: 2.5)},
      };
      final due = dueCards(memory, t0);
      expect(due.map((c) => c.item), ['M3', 'maj', 'P5', 'm3']);
      expect(dueCards(memory, t0, max: 2), hasLength(2));
    });

    test('days until due follow the half-life', () {
      expect(daysUntilDue(mem(10), t0), 3); // 0.234·10 → 3
      expect(daysUntilDue(mem(1, daysAgo: 5), t0), 0);
    });
  });

  group('store', () {
    TrainerStore make(MemoryTrainerPersistence p, DateTime Function() clock) =>
        TrainerStore(p, clock: clock);

    test('answers build memory that survives a restart', () async {
      var now = t0;
      final p = MemoryTrainerPersistence();
      final a = make(p, () => now)
        ..recordAnswer(TrainerKind.interval, 'M3', true);
      await a.load();
      a.recordAnswer(TrainerKind.interval, 'M3', true);
      expect(a.memory['interval']!['M3']!.halfLifeDays, startHalfLifeDays);
      expect(a.dueReview, isEmpty);
      now = t0.add(const Duration(days: 2));
      expect(a.dueReview.single.item, 'M3');
      final b = make(p, () => now);
      await b.load();
      expect(b.memory['interval']!['M3']!.halfLifeDays, startHalfLifeDays);
      expect(b.dueReview.single.item, 'M3');
    });

    test(
      'memory of another model version is dropped, not reinterpreted',
      () async {
        final p = MemoryTrainerPersistence({
          'memoryModel': 'other-model',
          'memory': {
            'interval': {
              'M3': [5, t0.millisecondsSinceEpoch, 1, 0],
            },
          },
        });
        final s = make(p, () => t0);
        await s.load();
        expect(s.memory, isEmpty);
      },
    );

    test('a finished round ticks today and resets with my data', () async {
      final s = make(MemoryTrainerPersistence(), () => t0);
      await s.load();
      s.recordAnswer(TrainerKind.interval, 'M3', true);
      expect(s.reviewedToday, isFalse);
      s.markReviewDone();
      expect(s.reviewedToday, isTrue);
      await s.resetAll();
      expect(s.memory, isEmpty);
      expect(s.reviewedToday, isFalse);
    });

    test('a review question asks only about met items', () async {
      final s = make(MemoryTrainerPersistence(), () => t0);
      await s.load();
      for (final i in ['M3', 'P5', 'm3']) {
        s.recordAnswer(TrainerKind.interval, i, true);
      }
      final qs = reviewQuestions(s, const [ReviewCard('interval', 'M3', 0.4)]);
      expect(qs.single.type, QuestionType.identify);
      expect(qs.single.answer, 'M3');
      expect(qs.single.options.toSet(), {'M3', 'P5', 'm3'});
      // One met item: a pick-the-sound question instead.
      final lone = make(MemoryTrainerPersistence(), () => t0);
      await lone.load();
      lone.recordAnswer(TrainerKind.chord, 'maj', false);
      final q = reviewQuestions(lone, const [ReviewCard('chord', 'maj', 0.2)]);
      expect(q.single.type, QuestionType.find);
      expect(q.single.target, 'maj');
    });
  });

  testWidgets('Today shows due cards and opens the review round', (
    tester,
  ) async {
    final store = TrainerStore(
      MemoryTrainerPersistence({
        'onboardingDone': true,
        'setupDone': true,
        'memoryModel': memoryModelVersion,
        'memory': {
          'interval': {
            'M3': [
              1,
              t0.subtract(const Duration(days: 3)).millisecondsSinceEpoch,
              1,
              0,
            ],
            'P5': [
              1,
              t0.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
              1,
              0,
            ],
          },
        },
      }),
      clock: () => t0,
    );
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('route_review')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tekrar kartları'), findsOneWidget);
    expect(find.text('2 kart · ~1 dk · karışık'), findsOneWidget);
    await tapKey(tester, 'route_review');
    expect(find.text('TEKRAR KARTLARI'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('the end screen tells when each card returns', (tester) async {
    final store = TrainerStore(
      MemoryTrainerPersistence({'onboardingDone': true, 'setupDone': true}),
      clock: () => t0,
    );
    await store.load();
    store.recordAnswer(TrainerKind.interval, 'M3', true);
    final q = reviewQuestions(store, const [ReviewCard('interval', 'M3', 0.3)]);
    await tester.pumpWidget(app(store));
    await settle(tester);
    Navigator.of(tester.element(find.byType(Scaffold).first)).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReviewEnd(summary: QuizSummary([AnswerRecord(q.single, true)])),
      ),
    );
    await settle(tester);
    expect(find.text('1 kartın 1 tanesini hatırladın'), findsOneWidget);
    expect(find.text('Sonraki: bugün'), findsNothing);
    expect(find.textContaining('Sonraki:'), findsOneWidget);
  });
}
