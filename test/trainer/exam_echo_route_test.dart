// P4: the exam goal's route adds one repetition exercise (melody echo / clap
// the rhythm, alternating) when the day is longer than 5 minutes. Every other
// goal's route is unchanged; the step is practice ("done"), never XP, streak
// or mastery.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/home/daily_route.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

void main() {
  var now = DateTime(2026, 11, 9, 9);
  TrainerStore make([MemoryTrainerPersistence? p]) =>
      TrainerStore(p ?? MemoryTrainerPersistence(), clock: () => now);
  setUp(() => now = DateTime(2026, 11, 9, 9));

  group('exam echo step', () {
    test('only above 5 minutes: 3 and 5 have none, 10/15/20 have one', () {
      for (final m in [3, 5]) {
        expect(
          DailyRoute.plan(goal: PracticeGoal.exam, minutes: m).echoStep,
          isNull,
          reason: '$m',
        );
      }
      for (final m in [10, 15, 20]) {
        expect(
          DailyRoute.plan(goal: PracticeGoal.exam, minutes: m).echoStep,
          EchoStep.melody,
          reason: '$m',
        );
      }
      expect(echoStepMinMinutes, 5);
    });

    test('step sets: 3 → lesson; 5 → breath, lesson; 10 → + echo', () {
      DailyRoute r(int m) =>
          DailyRoute.plan(goal: PracticeGoal.exam, minutes: m);
      expect((r(3).breath, r(3).lesson, r(3).echoStep), (false, true, null));
      expect(r(3).stepCount, 1);
      expect((r(5).breath, r(5).echoStep), (true, null));
      expect(r(5).stepCount, 2);
      expect(
        (r(10).breath, r(10).lesson, r(10).voiceStep),
        (true, true, false),
      );
      expect(r(10).echoStep, isNotNull);
      expect(r(10).stepCount, 3);
    });

    test('the kind alternates, and stays today\'s once done today', () {
      EchoStep? pick(EchoStep? last, {bool today = false}) => DailyRoute.plan(
        goal: PracticeGoal.exam,
        minutes: 10,
        lastEcho: last,
        echoDoneToday: today,
      ).echoStep;
      expect(pick(null), EchoStep.melody);
      expect(pick(EchoStep.melody), EchoStep.clap);
      expect(pick(EchoStep.clap), EchoStep.melody);
      expect(pick(EchoStep.melody, today: true), EchoStep.melody);
      expect(pick(EchoStep.clap, today: true), EchoStep.clap);
    });

    test('no other goal changes, with or without an echo history', () {
      for (final g in PracticeGoal.values.where(
        (g) => g != PracticeGoal.exam,
      )) {
        for (final m in dailyMinuteChoices) {
          final base = DailyRoute.plan(goal: g, minutes: m);
          final withHistory = DailyRoute.plan(
            goal: g,
            minutes: m,
            lastEcho: EchoStep.clap,
          );
          expect(base.echoStep, isNull, reason: '$g $m');
          expect(withHistory.echoStep, isNull, reason: '$g $m');
          expect(withHistory.stepCount, base.stepCount, reason: '$g $m');
        }
      }
      // Pre-existing expectations, spelled out.
      DailyRoute r(PracticeGoal g, int m) =>
          DailyRoute.plan(goal: g, minutes: m);
      expect(r(PracticeGoal.ear, 10).stepCount, 2);
      expect(r(PracticeGoal.voice, 10).stepCount, 3);
      expect(r(PracticeGoal.stage, 3).stepCount, 1);
      expect(r(PracticeGoal.beginner, 3).stepCount, 1);
    });

    test('a save without a goal keeps the legacy route', () {
      for (final m in dailyMinuteChoices) {
        final legacy = DailyRoute.forMinutes(m);
        final r = routeFor({}, m, lastEcho: EchoStep.melody);
        expect(r.echoStep, isNull);
        expect(r.stepCount, legacy.stepCount);
        expect(r.goal, isNull);
      }
    });

    test('no 2/3/4-voice step and no voice step for exam, pending says so', () {
      for (final m in dailyMinuteChoices) {
        expect(
          DailyRoute.plan(goal: PracticeGoal.exam, minutes: m).voiceStep,
          isFalse,
        );
      }
      final text = PracticeGoal.exam.pendingContent!;
      expect(text, contains('Porte okuma'));
      expect(
        text,
        contains(
          'Makam melodileri, solfej ve dikte henüz hazır değil; 2/3/4 sesli '
          'tekrar kayıt bekliyor.',
        ),
      );
    });
  });

  group('store', () {
    test(
      'markEchoDone remembers kind and day, and survives a restart',
      () async {
        final p = MemoryTrainerPersistence();
        final a = make(p);
        expect(a.echoedToday, isFalse);
        a.markEchoDone(EchoStep.clap);
        await a.flush();
        final b = make(p);
        await b.load();
        expect((b.echoLast, b.echoedToday), (EchoStep.clap, true));
        now = now.add(const Duration(days: 1));
        expect(b.echoedToday, isFalse);
        expect(b.echoLast, EchoStep.clap, reason: 'tomorrow picks the other');
      },
    );

    test(
      'an old save without the keys loads, an unknown kind is ignored',
      () async {
        final old = make(MemoryTrainerPersistence({'onboardingDone': true}));
        await old.load();
        expect((old.echoLast, old.echoDay), (null, null));
        final odd = make(
          MemoryTrainerPersistence({
            'echoLast': 'banjo',
            'echoDay': '2026-11-09',
          }),
        );
        await odd.load();
        expect(odd.echoLast, isNull);
      },
    );

    test('doing the echo step changes no XP, streak, mastery or history', () {
      final s = make();
      s.recordAnswer(TrainerKind.interval, 'M3', true);
      List<Object?> snap() => [
        s.xp,
        s.streak,
        s.days.length,
        s.nodes.length,
        s.stats.length,
        s.memory['interval']!['M3']!.halfLifeDays,
        s.sessionToday,
        s.practicedToday,
        s.melodyEchoLevel,
        s.clapLevel,
      ];
      final before = snap();
      s
        ..markEchoDone(EchoStep.melody)
        ..markEchoDone(EchoStep.clap);
      expect(snap(), before);
    });

    test('a fresh day without any activity: echo alone is no practice day', () {
      final s = make()..markEchoDone(EchoStep.melody);
      expect(s.practicedToday, isFalse);
      expect(s.streak, 0);
      expect(s.days, isEmpty);
    });

    test('resetAll clears it; store.route uses the history', () async {
      final s = make(
        MemoryTrainerPersistence({
          'onboardingDone': true,
          'dailyMinutes': 10,
          'answers': {'goal': 'exam'},
        }),
      );
      await s.load();
      expect(s.route.echoStep, EchoStep.melody);
      s.markEchoDone(EchoStep.melody);
      expect(s.route.echoStep, EchoStep.melody, reason: 'done today');
      now = now.add(const Duration(days: 1));
      expect(s.route.echoStep, EchoStep.clap);
      await s.resetAll();
      expect((s.echoLast, s.echoDay), (null, null));
    });
  });

  group('home route card', () {
    Future<TrainerStore> pump(
      WidgetTester tester, {
      int minutes = 10,
      String goal = 'exam',
      Map<String, Object?> extra = const {},
    }) async {
      final store = memoryStore({
        'onboardingDone': true,
        'setupDone': true,
        'dailyMinutes': minutes,
        'answers': {'goal': goal},
        ...extra,
      });
      await store.load();
      await tester.pumpWidget(app(store));
      await settle(tester);
      return store;
    }

    testWidgets('10 minutes: breath, lesson and a melody echo step', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byKey(const Key('route_breath')), findsOneWidget);
      expect(find.byKey(const Key('route_lesson')), findsOneWidget);
      expect(find.byKey(const Key('route_echo')), findsOneWidget);
      expect(find.text('Tekrar alıştırması · melodi yankısı'), findsOneWidget);
      expect(find.text('taslak ölçüm · mikrofon isteğe bağlı'), findsOneWidget);
      expect(find.byKey(const Key('route_voice')), findsNothing);
      expect(
        find.textContaining('2/3/4 sesli tekrar kayıt bekliyor'),
        findsOneWidget,
      );
    });

    testWidgets('yesterday melody → today clap; 5 minutes has none', (
      tester,
    ) async {
      await pump(
        tester,
        extra: {'echoLast': 'melody', 'echoDay': '2026-11-08'},
      );
      expect(find.text('Tekrar alıştırması · alkışla ritim'), findsOneWidget);
    });

    testWidgets('5 minutes: no echo step', (tester) async {
      await pump(tester, minutes: 5);
      expect(find.byKey(const Key('route_echo')), findsNothing);
    });

    testWidgets('other goals show no echo step at 10 minutes', (tester) async {
      await pump(tester, goal: 'ear');
      expect(find.byKey(const Key('route_echo')), findsNothing);
    });

    testWidgets('melody echo without live audio says so instead of opening', (
      tester,
    ) async {
      await pump(tester);
      await tapKey(tester, 'route_echo');
      expect(find.text('Bu çalışma yalnız cihazda açılır.'), findsOneWidget);
    });

    testWidgets('done today reads "Bugün yapıldı", not "ölçüldü"', (
      tester,
    ) async {
      await pump(tester, extra: {'echoLast': 'clap', 'echoDay': '2026-10-29'});
      expect(find.text('Bugün yapıldı'), findsOneWidget);
      expect(find.textContaining('ölçüldü'), findsNothing);
    });

    testWidgets('English wording', (tester) async {
      final store = await pump(tester);
      Lang.en = true;
      addTearDown(() => Lang.en = false);
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      store.notifyListeners(); // rebuild the card in English
      await tester.pump();
      expect(find.text('Repeat practice · melody echo'), findsOneWidget);
      expect(
        find.text('draft measurement · microphone optional'),
        findsOneWidget,
      );
    });
  });
}
