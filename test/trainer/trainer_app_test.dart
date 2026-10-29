import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/practice_reminder.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/trainer/app/trainer_app.dart';
import 'package:harmonia/trainer/audio/trainer_audio.dart';
import 'package:harmonia/trainer/domain/curriculum.dart';
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

    expect(find.text('Tahmin etmeyi bırak'), findsOneWidget);
    await tapKey(tester, 'get_started');
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'ob_continue');
    }
    expect(find.text('Hangi enstrümanı çalıyorsun?'), findsOneWidget);
    await tapKey(tester, 'opt_voice');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'opt_student', settleMs: 900);
    expect(find.text('Neyi başarmak istiyorsun?'), findsOneWidget);
    await tapKey(tester, 'opt_choir');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'opt_few');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'try_it');

    // Skip all samples through the "No worries" sheet.
    await tapKey(tester, 'sample_skip');
    await tester.tap(find.text('Kalanları atla'));
    await settle(tester);
    expect(find.text('Harika iş!'), findsOneWidget);
    await tapKey(tester, 'ob_continue');

    await tapKey(tester, 'opt_koro');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'opt_consistency');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'ob_continue'); // minutes
    await tapKey(tester, 'ob_continue'); // marathon
    await tapKey(tester, 'opt_trust');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'ob_continue'); // potential
    await tapKey(tester, 'reminder_skip');
    await tapKey(tester, 'ob_continue'); // all done
    await settle(tester, 4800); // building
    expect(find.text('Tebrikler!'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Koro hazırlığı'), 200);
    expect(find.text('Koro hazırlığı'), findsOneWidget);
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'save_skip');
    expect(find.text('Beta boyunca her şey ücretsiz'), findsOneWidget);
    await tapKey(tester, 'ob_continue');
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, 'ob_continue');
    }
    await tapKey(tester, 'notation_letter');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'ob_continue'); // prefs
    expect(find.text('Kısa bir seviye kontrolü'), findsOneWidget);
    await tester.tap(find.text('Atla, yeni başlıyorum'));
    await settle(tester);
    expect(find.text('Bugünkü oturumun'), findsOneWidget);

    // Persisted step: the flow position is saved while onboarding.
    expect(store.answers['obStep'], 'today');
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);

    expect(store.onboardingDone, isTrue);
    expect(store.setupDone, isTrue);
    expect(find.text('Çalışmaya hazır mısın?'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('skill_koro')), 200);
    expect(find.byKey(const Key('skill_koro')), findsOneWidget);
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
    expect(find.textContaining('Her gün ne kadar'), findsOneWidget);
  });

  testWidgets('trainer sheet opens the learn path and practice setup', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);

    await tapKey(tester, 'skill_interval');
    expect(find.text('Nasıl çalışmak istersin?'), findsOneWidget);
    await tapKey(tester, 'sheet_learn');
    // First visit explains checkpoints.
    expect(find.text('Bu bölümü zaten biliyor musun?'), findsOneWidget);
    await tester.tap(find.text('Anladım'));
    await settle(tester);
    expect(find.text('Giriş: Aralık Eğitimi'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Geri').first);
    await settle(tester);

    await tapKey(tester, 'skill_chord');
    await tapKey(tester, 'sheet_practice');
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
    await tapKey(tester, 'sheet_practice');
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
      } else if (find.textContaining('Tekrar dene').evaluate().isNotEmpty) {
        await tester.tap(find.bySemanticsLabel('Sol').first);
        await settle(tester, 400);
      }
      if (find.text('İpuçları gizlensin mi?').evaluate().isNotEmpty) {
        await tester.tap(find.text('Kalsın'));
        await settle(tester, 400);
      }
      await settle(tester, 2400);
    }
    expect(find.byKey(const Key('session_results')), findsOneWidget);
    expect(store.trainerReps(TrainerKind.pitch), 8);
    await tapKey(tester, 'session_results');
    expect(find.text('Oturum tamamlandı!'), findsOneWidget);
    await tapKey(tester, 'session_done');
    // First activity of the day celebrates the streak.
    expect(find.text('1 günlük seri!'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await settle(tester);
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
    await tapKey(tester, 'sheet_practice');
    await tapKey(tester, 'practice_now');
    await tester.tap(find.bySemanticsLabel('Geri').first);
    await settle(tester);
    expect(find.text('Pratik bitsin mi?'), findsOneWidget);
    await settle(tester, 20000); // longer than the 15 s limit
    await tester.tap(find.text('Devam et'));
    await settle(tester);
    expect(find.text('Süre doldu'), findsNothing);
    expect(find.text('1 / 8'), findsOneWidget);
    expect(store.trainerReps(TrainerKind.pitch), 0);
    // Leave cleanly so no timers outlive the test.
    await tester.tap(find.bySemanticsLabel('Geri').first);
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
    final intro = trainerPaths[TrainerKind.pitch]!.nodes.first;
    expect(find.text(intro.title), findsWidgets);
    while (find.byKey(const Key('lesson_next')).evaluate().isNotEmpty) {
      await tapKey(tester, 'lesson_next');
    }
    expect(store.isComplete(intro.id), isTrue);
    // Today's session continues with lesson 1.
    expect(find.text('Derse başla'), findsOneWidget);
  });

  testWidgets('choir hub lists the workshop and opens the voice-count drill', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'skill_koro');
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
    expect(find.text('Deneyimini özelleştir'), findsOneWidget);
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.text('Tahmin etmeyi bırak'), findsOneWidget);
  });
}
