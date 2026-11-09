// P3: 3-star cut at 90%, gate attempt log, "consolidated" indicator, and the
// failed-gate suggestion. The 80% pass mark, lesson = always complete and the
// lock logic are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/placement.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/learn/session_end.dart';
import 'package:resonia/trainer/learn/skill_screen.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle;

Future<void> _toNextStep(WidgetTester tester) => tester.scrollUntilVisible(
  find.byKey(const Key('session_next')),
  200,
  scrollable: find.byType(Scrollable).first,
);

void main() {
  var now = DateTime(2026, 11, 9, 9);
  TrainerStore make([MemoryTrainerPersistence? p]) =>
      TrainerStore(p ?? MemoryTrainerPersistence(), clock: () => now);
  setUp(() => now = DateTime(2026, 11, 9, 9));

  final path = trainerPaths[TrainerKind.interval]!;
  final gate = path.nodes.firstWhere((n) => n.kind == NodeKind.checkpoint);
  final fin = path.nodes.firstWhere((n) => n.kind == NodeKind.finalExam);

  group('stars', () {
    test('cuts at 80% and 90%', () {
      expect(TrainerStore.starsFor(0.79), 1);
      expect(TrainerStore.starsFor(0.80), 2);
      expect(TrainerStore.starsFor(0.89), 2);
      expect(TrainerStore.starsFor(0.90), 3);
      expect(TrainerStore.starsFor(0.94), 3);
      expect(TrainerStore.starsFor(0.95), 3);
      expect(TrainerStore.threeStarAccuracy, 0.9);
    });

    test('three stars allow one miss in 10 or 12 and two in 20', () {
      expect(TrainerStore.starsFor(9 / 10), 3);
      expect(TrainerStore.starsFor(8 / 10), 2);
      expect(TrainerStore.starsFor(11 / 12), 3);
      expect(TrainerStore.starsFor(10 / 12), 2);
      expect(TrainerStore.starsFor(18 / 20), 3);
      expect(TrainerStore.starsFor(17 / 20), 2);
    });

    test('an early placement pass divides by the full length', () {
      const s = GateStop(12);
      expect(s.accuracy(10), closeTo(10 / 12, 1e-12));
      expect(TrainerStore.starsFor(s.accuracy(10)), 2);
      expect(TrainerStore.starsFor(s.accuracy(11)), 3);
      const f = GateStop(20);
      expect(TrainerStore.starsFor(f.accuracy(16)), 2);
      expect(TrainerStore.starsFor(f.accuracy(18)), 3);
    });

    test('the 80% pass mark and lesson = always complete are unchanged', () {
      final s = make();
      expect(s.completeNode(gate, 0.79), isFalse);
      expect(s.isComplete(gate.id), isFalse);
      expect(s.completeNode(gate, 0.80), isTrue);
      final lesson = path.nodes[1];
      expect(s.completeNode(lesson, 0.1), isTrue);
      expect(s.progressOf(lesson.id)!.stars, 1);
    });

    test('locks follow the previous node only, as before', () {
      final s = make();
      expect(s.isUnlocked(path.nodes[1]), isFalse);
      s.completeNode(path.nodes[0], 1);
      expect(s.isUnlocked(path.nodes[1]), isTrue);
      expect(s.isUnlocked(gate), isTrue);
    });
  });

  group('gate attempt log', () {
    test('keeps the last three attempts per gate, lessons are not logged', () {
      final s = make();
      for (var i = 0; i < 5; i++) {
        s.completeNode(gate, 0.9, correct: 10 + (i % 2), total: 12);
      }
      s.completeNode(path.nodes[1], 1, correct: 10, total: 10);
      expect(s.gateAttempts[gate.id], hasLength(3));
      expect(s.gateAttempts.containsKey(path.nodes[1].id), isFalse);
      expect(TrainerStore.maxGateAttempts, 3);
    });

    test('a failed attempt is logged too, and counts against the total', () {
      final s = make();
      expect(s.completeNode(gate, 7 / 12, correct: 7, total: 12), isFalse);
      expect(s.gateAttempts[gate.id]!.single.correct, 7);
      expect(s.isComplete(gate.id), isFalse);
    });

    test('without counts nothing is logged (callers that pass accuracy)', () {
      final s = make()..completeNode(gate, 1);
      expect(s.gateAttempts, isEmpty);
    });

    test(
      'persists, reloads, and an old save without the key loads empty',
      () async {
        final p = MemoryTrainerPersistence();
        final a = make(p)
          ..completeNode(gate, 11 / 12, correct: 11, total: 12)
          ..completeNode(fin, 1, correct: 20, total: 20);
        await a.flush();
        final b = make(p);
        await b.load();
        expect(b.gateAttempts[gate.id]!.single.total, 12);
        expect(b.gateAttempts[fin.id]!.single.correct, 20);
        expect(b.gateAttempts[gate.id]!.single.day, '2026-11-09');
        final old = make(
          MemoryTrainerPersistence({
            'onboardingDone': true,
            'nodes': {
              gate.id: {'stars': 2, 'review': false},
            },
          }),
        );
        await old.load();
        expect(old.gateAttempts, isEmpty);
        expect(old.progressOf(gate.id)!.stars, 2);
        expect(old.gateEvidence(gate.id), isNull);
      },
    );

    test('malformed entries are ignored; reset clears the log', () async {
      final s = make(
        MemoryTrainerPersistence({
          'onboardingDone': true,
          'gateAttempts': {
            gate.id: [
              [10, 12, '2026-11-01'],
              [13, 12, '2026-11-02'], // correct > total
              [5, 0, '2026-11-03'],
              'x',
            ],
            'bad': 'x',
          },
        }),
      );
      await s.load();
      expect(s.gateAttempts.keys, [gate.id]);
      expect(s.gateAttempts[gate.id], hasLength(1));
      await s.resetAll();
      expect(s.gateAttempts, isEmpty);
    });

    test('placement attempts count too (asked questions, not full length)', () {
      final s = make();
      const stop = GateStop(12);
      s.completeNode(
        gate,
        stop.accuracy(10),
        correct: 10,
        total: 10, // ended early after ten right answers
      );
      final e = s.gateEvidence(gate.id)!;
      expect((e.correct, e.questions), (10, 10));
      expect(s.progressOf(gate.id)!.stars, 2, reason: 'stars use 10/12');
    });
  });

  group('consolidated', () {
    GateEvidence ev(int days, int q, int c) =>
        GateEvidence(days: days, questions: q, correct: c);

    test('needs two days, 36 questions and 80% together', () {
      expect(ev(2, 36, 29).consolidated, isTrue); // 80.6%
      expect(ev(2, 36, 28).consolidated, isFalse); // 77.8%
      expect(ev(2, 35, 35).consolidated, isFalse);
      expect(ev(1, 60, 60).consolidated, isFalse);
      expect(ev(3, 40, 32).consolidated, isTrue); // exactly 80%
      expect(GateEvidence.minQuestions, 36);
    });

    test('three 12-question attempts on two days consolidate', () {
      final s = make();
      s.completeNode(gate, 10 / 12, correct: 10, total: 12);
      s.completeNode(gate, 11 / 12, correct: 11, total: 12);
      expect(s.gateEvidence(gate.id)!.consolidated, isFalse);
      now = now.add(const Duration(days: 1));
      s.completeNode(gate, 10 / 12, correct: 10, total: 12);
      final e = s.gateEvidence(gate.id)!;
      expect((e.days, e.questions, e.correct), (2, 36, 31));
      expect(e.consolidated, isTrue);
    });

    test('same-day attempts never consolidate', () {
      final s = make();
      for (var i = 0; i < 3; i++) {
        s.completeNode(gate, 1, correct: 12, total: 12);
      }
      expect(s.gateEvidence(gate.id)!.consolidated, isFalse);
    });

    test('it changes no lock and no star', () {
      final s = make();
      s.completeNode(gate, 10 / 12, correct: 10, total: 12);
      final before = (s.isUnlocked(path.nodes[1]), s.nextNode(path.trainer));
      now = now.add(const Duration(days: 1));
      s.completeNode(gate, 10 / 12, correct: 10, total: 12);
      s.completeNode(gate, 10 / 12, correct: 10, total: 12);
      expect(s.gateEvidence(gate.id)!.consolidated, isTrue);
      expect(s.progressOf(gate.id)!.stars, 2);
      expect((s.isUnlocked(path.nodes[1]), s.nextNode(path.trainer)), before);
    });
  });

  group('failed gate suggestion', () {
    Future<List<String>> show(
      WidgetTester tester, {
      required bool passed,
      bool english = false,
    }) async {
      final taps = <String>[];
      addTearDown(() => Lang.en = false);
      final store = memoryStore({'onboardingDone': true, 'setupDone': true});
      await store.load();
      const config = QuizConfig(
        trainer: TrainerKind.interval,
        pool: ['M3', 'P5'],
        length: 4,
      );
      final qs = QuizGenerator(config).session();
      final summary = QuizSummary([
        for (var i = 0; i < qs.length; i++) AnswerRecord(qs[i], i < 1),
      ]);
      await tester.pumpWidget(app(store));
      await settle(tester);
      Lang.en = english;
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => SessionEnd(
                summary: summary,
                node: gate,
                passed: passed,
                onDone: () => taps.add('done'),
                onReviewPrevious: () => taps.add('previous'),
                onRetryGate: () => taps.add('retry'),
              ),
            ),
          );
      await settle(tester);
      return taps;
    }

    testWidgets('names the previous lesson and offers to retry', (
      tester,
    ) async {
      final taps = await show(tester, passed: false);
      expect(find.text('Ara durak için %80 gerekiyor'), findsOneWidget);
      await _toNextStep(tester);
      expect(find.text('Önceki dersi tekrar et'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await tester.tap(find.byKey(const Key('retry_missed')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('session_retry_gate')));
      await tester.pump();
      expect(taps, ['previous', 'retry']);
      expect(find.textContaining('başarısız'), findsNothing);
    });

    testWidgets('English wording', (tester) async {
      await show(tester, passed: false, english: true);
      await _toNextStep(tester);
      expect(find.text('Repeat the previous lesson'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a passed gate gets neither', (tester) async {
      await show(tester, passed: true);
      expect(find.text('Önceki dersi tekrar et'), findsNothing);
      expect(find.byKey(const Key('session_retry_gate')), findsNothing);
    });
  });

  group('path badge', () {
    testWidgets('shows "confirmed on two separate days" on a 320 px screen', (
      tester,
    ) async {
      final store = memoryStore({
        'onboardingDone': true,
        'setupDone': true,
        'nodes': {
          for (final n in path.nodes.take(path.indexOf(gate.id) + 1))
            n.id: {'stars': 2, 'review': false},
        },
        'gateAttempts': {
          gate.id: [
            [10, 12, '2026-11-01'],
            [11, 12, '2026-11-02'],
            [10, 12, '2026-11-02'],
          ],
        },
      });
      await store.load();
      await tester.pumpWidget(app(store));
      await settle(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const SkillScreen(trainer: TrainerKind.interval),
            ),
          );
      await tester.pump();
      tester.view
        ..physicalSize = const Size(320, 700)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view.reset();
      });
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.scrollUntilVisible(
        find.byKey(Key('gate_consolidated_${gate.id}')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byTooltip('iki ayrı günde doğrulandı'), findsOneWidget);
      // A 1.3 px overflow on this 320 px screen exists without the badge
      // (checked with no attempts logged); the badge adds none (FittedBox).
      final e = tester.takeException();
      expect(e == null || '$e'.contains('1.3 pixels on the right'), isTrue);
    });
  });
}
