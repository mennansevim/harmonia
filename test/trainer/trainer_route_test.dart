import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/trainer/domain/curriculum.dart';
import 'package:harmonia/trainer/domain/trainers.dart';
import 'package:harmonia/trainer/home/daily_route.dart';
import 'package:harmonia/trainer/learn/session_end.dart';
import 'package:harmonia/trainer/quiz/quiz.dart';
import 'package:harmonia/trainer/quiz/quiz_view.dart';
import 'package:harmonia/trainer/state/trainer_store.dart';
import 'package:harmonia/trainer/ui/kit.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

Map<String, Object?> _home({int minutes = 8}) => {
  'onboardingDone': true,
  'setupDone': true,
  'dailyMinutes': minutes,
};

void main() {
  group('DailyRoute', () {
    test('sizes the route by daily minutes', () {
      final short = DailyRoute.forMinutes(3);
      expect(short.breath, isFalse);
      expect(short.voiceStep, isFalse);
      expect(short.stepCount, 1);

      final five = DailyRoute.forMinutes(5);
      expect(five.breathSeconds, 60);
      expect(five.voiceStep, isFalse);
      expect(five.stepCount, 2);

      final long = DailyRoute.forMinutes(10);
      expect(long.breathSeconds, 120);
      expect(long.voiceStep, isTrue);
      expect(long.stepCount, 3);
    });
  });

  test('breath day persists, counts only today and resets', () async {
    final persistence = MemoryTrainerPersistence({'onboardingDone': true});
    final store = TrainerStore(
      persistence,
      clock: () => DateTime(2026, 10, 29, 9),
    );
    await store.load();
    expect(store.breathedToday, isFalse);
    store.markBreathDone();
    await store.flush();
    expect(store.breathedToday, isTrue);
    // Breathing is not practice evidence.
    expect(store.streak, 0);
    expect(store.xp, 0);
    expect(store.sessionToday, isFalse);

    final tomorrow = TrainerStore(
      persistence,
      clock: () => DateTime(2026, 10, 30, 9),
    );
    await tomorrow.load();
    expect(tomorrow.breathDay, '2026-10-29');
    expect(tomorrow.breathedToday, isFalse);

    await store.resetAll();
    expect(store.breathDay, isNull);
  });

  testWidgets('a 3-minute day is the lesson alone', (tester) async {
    final store = memoryStore(_home(minutes: 3));
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.byKey(const Key('route_lesson')), findsOneWidget);
    expect(find.byKey(const Key('route_breath')), findsNothing);
    expect(find.byKey(const Key('route_voice')), findsNothing);
    expect(find.text('Derse başla'), findsOneWidget);
    expect(find.textContaining('~3 dakika'), findsOneWidget);
  });

  testWidgets('a longer day is Nefes → lesson → Ses', (tester) async {
    final store = memoryStore(_home(minutes: 10));
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.byKey(const Key('route_breath')), findsOneWidget);
    expect(find.byKey(const Key('route_lesson')), findsOneWidget);
    expect(find.byKey(const Key('route_voice')), findsOneWidget);
    expect(find.text('Çalışmaya başla'), findsOneWidget);
  });

  testWidgets('finishing the breathing guide ticks the step, then the '
      'lesson opens', (tester) async {
    final store = memoryStore(_home(minutes: 5));
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'today_begin');
    expect(find.text('Nefesi hazırla'), findsOneWidget);
    expect(find.text('HAZIRLA · ADIM 1 / 2'), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);

    await settle(tester, 61000);
    expect(find.byKey(const Key('breath_continue')), findsOneWidget);
    expect(find.text('5 döngü'), findsOneWidget);
    expect(store.breathedToday, isTrue);
    expect(store.streak, 0);

    await tapKey(tester, 'breath_continue');
    final path = trainerPaths[TrainerKind.pitch]!;
    expect(find.text(path.introSlides.first.title), findsOneWidget);
  });

  testWidgets('pausing stops the clock and back leaves the route', (
    tester,
  ) async {
    final store = memoryStore(_home());
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'today_begin');
    await settle(tester, 3000);
    await tapKey(tester, 'breath_pause');
    final clock = tester
        .widget<Text>(find.byKey(const Key('breath_clock')))
        .data;
    await settle(tester, 5000);
    expect(
      tester.widget<Text>(find.byKey(const Key('breath_clock'))).data,
      clock,
    );
    expect(find.text('Devam et'), findsOneWidget);

    await tester.tap(find.byType(BackSquare));
    await settle(tester);
    expect(find.byKey(const Key('daily_plan')), findsOneWidget);
    expect(store.breathedToday, isFalse);
    expect(store.sessionToday, isFalse);
  });

  testWidgets('results separate measured from unmeasured and the retry is '
      'not recorded', (tester) async {
    final store = memoryStore(_home());
    await store.load();
    store.markBreathDone();
    await tester.pumpWidget(app(store));
    await settle(tester);

    const config = QuizConfig(
      trainer: TrainerKind.pitch,
      pool: ['0', '7'],
      length: 4,
    );
    final questions = QuizGenerator(config).session();
    final summary = QuizSummary([
      for (var i = 0; i < questions.length; i++)
        AnswerRecord(questions[i], i > 0),
    ]);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => SessionEnd(
              summary: summary,
              title: 'Perde',
              retryConfig: config,
              onDone: () {},
            ),
          ),
        );
    await settle(tester);

    expect(find.byKey(const Key('session_score')), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('/ 4 ilk deneme'), findsOneWidget);
    expect(find.text('ÖLÇÜLDÜ'), findsOneWidget);
    expect(find.text('1 soruda karıştı'), findsOneWidget);
    expect(find.byKey(const Key('evidence_breath')), findsOneWidget);
    expect(find.text('ÖLÇÜLMEDİ'), findsOneWidget);
    // Free practice has no sing step to report.
    expect(find.byKey(const Key('evidence_sing')), findsNothing);

    final before = store.trainerReps(TrainerKind.pitch);
    await tapKey(tester, 'retry_missed');
    final retry = tester.widget<QuizView>(find.byType(QuizView));
    expect(retry.record, isFalse);
    expect(retry.questions, hasLength(3));
    final missed = questions.first.type == QuestionType.yesNo
        ? questions.first.target
        : questions.first.answer;
    for (final q in retry.questions) {
      expect(q.type == QuestionType.yesNo ? q.target : q.answer, missed);
    }
    expect(store.trainerReps(TrainerKind.pitch), before);
    expect(store.xp, 0);
  });

  testWidgets('membership preview sells nothing', (tester) async {
    final store = memoryStore(_home());
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_3');
    await tapKey(tester, 'settings_membership');
    expect(find.text('Önce değeri gör'), findsOneWidget);
    expect(find.text('Fiyat henüz belirlenmedi'), findsOneWidget);
    final cta = tester.widget<BigButton>(
      find.byKey(const Key('membership_cta')),
    );
    expect(cta.onPressed, isNull);
    expect(find.textContaining('₺'), findsNothing);

    await tester.tap(find.text('Plus'));
    await settle(tester);
    expect(find.text('Plus · gerçek eğitimci'), findsOneWidget);
    expect(find.textContaining('yapay zekâ metni'), findsOneWidget);
  });
}
