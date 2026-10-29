import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/practice_reminder.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/trainer/app/trainer_app.dart';
import 'package:harmonia/trainer/audio/trainer_audio.dart';
import 'package:harmonia/trainer/domain/curriculum.dart';
import 'package:harmonia/trainer/domain/music.dart';
import 'package:harmonia/trainer/domain/trainers.dart';
import 'package:harmonia/trainer/state/trainer_store.dart';

TrainerStore memoryStore([Map<String, Object?>? doc]) => TrainerStore(
  MemoryTrainerPersistence(doc),
  clock: () => DateTime(2026, 10, 29, 9),
);

Widget app(TrainerStore store) => TrainerApp(
  store: store,
  audio: TrainerAudio.silent(),
  reminders: PracticeReminderCoordinator(
    preferences: InMemoryPracticePreferences(),
    platform: UnavailablePracticeReminderPlatform(),
  ),
  history: InMemoryResultHistory(),
  liveAudio: false,
  startupCleanup: () async {},
);

Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    // Surface layout/build errors at the step that caused them.
    final e = tester.takeException();
    if (e != null) fail('Unexpected exception while settling: $e');
  }
}

Future<void> tapKey(
  WidgetTester tester,
  String key, {
  int settleMs = 600,
}) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester, settleMs);
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  testWidgets('first run walks the whole onboarding into the home tabs', (
    tester,
  ) async {
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);

    expect(find.text('Koronda daha\ngüvenle söyle'), findsOneWidget);
    await tapKey(tester, 'get_started');
    expect(find.text('Harmonia\'yı nasıl kullanacaksın?'), findsOneWidget);
    await tapKey(tester, 'opt_singer');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'opt_tenor');
    await tapKey(tester, 'ob_continue');
    expect(store.part, VoicePart.tenor);
    await tapKey(tester, 'opt_koro');
    await tapKey(tester, 'opt_chord');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'notation_letter');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'minutes_10');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'reminder_skip');
    expect(find.text('Planın kuruldu'), findsOneWidget);
    expect(find.text('Tenor'), findsOneWidget);

    // Persisted step: the flow position is saved while onboarding.
    expect(store.answers['obStep'], 'ready');
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);

    expect(store.onboardingDone, isTrue);
    expect(store.setupDone, isTrue);
    expect(store.dailyMinutes, 10);
    expect(store.lastTrainer, TrainerKind.chord.id);
    expect(find.text('Bugün'), findsWidgets);
    expect(find.byKey(const Key('daily_plan')), findsOneWidget);
    // Choir is a first-class tab.
    await tapKey(tester, 'tab_1');
    expect(find.text('Koro Atölyesi'), findsOneWidget);
  });

  testWidgets('resumes onboarding at the saved step after a restart', (
    tester,
  ) async {
    final store = memoryStore({
      'answers': {'obStep': 'minutes'},
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.textContaining('Günde kaç dakika'), findsOneWidget);
  });

  testWidgets('trainer sheet opens the learn path and practice setup', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);

    await tapKey(tester, 'skill_interval');
    expect(find.text('BASAMAK 1'), findsOneWidget);
    expect(find.text('Başlarken'), findsOneWidget);
    expect(find.text('Sıradaki: Başlarken'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri').first);
    await settle(tester);

    await tapKey(tester, 'skill_chord');
    await tapKey(tester, 'skill_free');
    expect(find.text('AKORLAR'), findsOneWidget);
    expect(find.byKey(const Key('practice_now')), findsOneWidget);
  });

  testWidgets('a practice quiz records answers and ends on the results', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);

    await tapKey(tester, 'skill_pitch');
    await tapKey(tester, 'skill_free');
    await tapKey(tester, 'practice_now');
    // Pool is Do + Sol by default; answer every question with "Do".
    for (var q = 0; q < 8; q++) {
      expect(find.byKey(const Key('quiz_status')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Do').first);
      await settle(tester, 400);
      if (find.text('Sonraki soru').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sonraki soru'));
        await settle(tester, 400);
      } else if (find.text('Devam').evaluate().isNotEmpty) {
        await tester.tap(find.text('Devam'));
        await settle(tester, 400);
      } else if (find.textContaining('Bir daha dinle').evaluate().isNotEmpty) {
        await tester.tap(find.bySemanticsLabel('Sol').first);
        await settle(tester, 400);
      }
      await settle(tester, 2400);
    }
    expect(find.byKey(const Key('session_done')), findsOneWidget);
    expect(store.trainerReps(TrainerKind.pitch), 8);
    expect(find.text('Serbest çalışma bitti'), findsOneWidget);
    // The day streak is shown inline, no celebration modal.
    expect(find.text('1 gün üst üste çalıştın'), findsOneWidget);
    await tapKey(tester, 'session_done');
    expect(store.streak, 1);
  });

  testWidgets('question clock pauses while the exit dialog is open', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'skill_pitch');
    await tapKey(tester, 'skill_free');
    await tapKey(tester, 'practice_now');
    await tester.tap(find.byTooltip('Geri').first);
    await settle(tester);
    expect(find.text('Pratik bitsin mi?'), findsOneWidget);
    await settle(tester, 20000); // longer than the 15 s limit
    await tester.tap(find.text('Devam et'));
    await settle(tester);
    expect(find.text('Süre doldu'), findsNothing);
    expect(find.text('1 / 8'), findsOneWidget);
    expect(store.trainerReps(TrainerKind.pitch), 0);
    // Leave cleanly so no timers outlive the test.
    await tester.tap(find.byTooltip('Geri').first);
    await settle(tester);
    await tester.tap(find.text('Oturumu bitir'));
    await settle(tester, 1500);
  });

  testWidgets('intro node completes and unlocks the first lesson', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'today_begin');
    // Today's route opens with the unmeasured breathing guide; skip it.
    await tapKey(tester, 'breath_skip');
    final path = trainerPaths[TrainerKind.pitch]!;
    final intro = path.nodes.first;
    expect(find.text(path.introSlides.first.title), findsOneWidget);
    while (find.byKey(const Key('lesson_next')).evaluate().isNotEmpty &&
        !store.isComplete(intro.id)) {
      await tapKey(tester, 'lesson_next');
    }
    expect(store.isComplete(intro.id), isTrue);
    // Today's session continues with lesson 1's overview.
    expect(find.text(path.nodes[1].title), findsOneWidget);
    expect(find.text('BASAMAK 1'), findsOneWidget);
  });

  testWidgets('choir hub lists the workshop and opens the voice-count drill', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_1');
    expect(find.text('Koro Atölyesi'), findsWidgets);
    expect(find.text('Ses aralığı testi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('KAYIT BEKLENİYOR'), 200);
    expect(find.text('Aksak ritim'), findsOneWidget);
    expect(find.text('KAYIT BEKLENİYOR'), findsOneWidget);
    await tapKey(tester, 'koro_voices');
    expect(find.text('Kaç ses duyuyorsun?'), findsOneWidget);
    await tapKey(tester, 'voices_3', settleMs: 1500);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('settings reset returns to the welcome screen', (tester) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_3');
    expect(find.byKey(const Key('settings_part')), findsOneWidget);
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
  });
}
