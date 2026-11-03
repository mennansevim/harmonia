import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';
import 'package:resonia/trainer/app/trainer_app.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

TrainerStore memoryStore([Map<String, Object?>? doc]) => TrainerStore(
  MemoryTrainerPersistence(doc),
  clock: () => DateTime(2026, 10, 29, 9),
);

class _History extends InMemoryResultHistory {
  bool fail = false;
  int clears = 0;

  @override
  Future<void> clear() async {
    if (fail) throw StateError('storage private detail');
    clears++;
    await super.clear();
  }
}

/// Real file IO never completes inside the widget test's fake clock.
class _Choir extends ChoirStore {
  _Choir()
    : super(
        persistence: MemoryChoirPersistence(),
        mediaRoot: () async => Directory.systemTemp,
      );

  bool fail = false;
  int clears = 0;

  @override
  Future<void> clearAll() async {
    if (fail) throw StateError('storage private detail');
    clears++;
  }
}

class _Reminders implements PracticeReminderPlatform {
  int cancels = 0;

  @override
  Future<ReminderPermission> permission() async =>
      ReminderPermission.authorized;
  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.authorized;
  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {}
  @override
  Future<void> cancelDaily() async => cancels++;
  @override
  Future<bool> openSettings() async => false;
}

Widget app(
  TrainerStore store, {
  ResultHistoryRepository? history,
  PracticeReminderCoordinator? reminders,
  ChoirStore? choir,
  Future<OrphanCleanupReport> Function()? purgeTemp,
}) => TrainerApp(
  store: store,
  audio: TrainerAudio.silent(),
  reminders:
      reminders ??
      PracticeReminderCoordinator(
        preferences: InMemoryPracticePreferences(),
        platform: UnavailablePracticeReminderPlatform(),
      ),
  history: history ?? InMemoryResultHistory(),
  choir: choir ?? _Choir(),
  purgeTempAudio: purgeTemp ?? () async => const OrphanCleanupReport(),
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

    expect(find.text('Sesini ve kulağını\nher gün geliştir'), findsOneWidget);
    await tapKey(tester, 'get_started');
    expect(find.text('Vocalart\'ı nasıl kullanacaksın?'), findsOneWidget);
    await tapKey(tester, 'opt_singer');
    await tapKey(tester, 'ob_continue');
    // No voice-group question: the range step offers a measurement or a skip.
    expect(find.text('Ses aralığını ölçelim'), findsOneWidget);
    expect(find.text('Sesin hangi aralığa yakın?'), findsNothing);
    await tapKey(tester, 'ob_continue');
    expect(store.part, isNull);
    await tapKey(tester, 'opt_voice');
    await tapKey(tester, 'opt_chord');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'minutes_10');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'reminder_skip');
    expect(find.text('Planın kuruldu'), findsOneWidget);
    expect(find.text('Ölçülmedi · Ses sekmesinde ölç'), findsOneWidget);
    // A 10-minute day ends with a voice step; choir members are told where
    // their assignments live.
    expect(find.text('Rotanın sonunda bir ses adımı'), findsOneWidget);
    expect(find.text('Ödevlerin Koro sekmesinde'), findsOneWidget);

    // Persisted step: the flow position is saved while onboarding.
    expect(store.answers['obStep'], 'ready');
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester);

    expect(store.onboardingDone, isTrue);
    expect(store.setupDone, isTrue);
    expect(store.dailyMinutes, 10);
    // No notation step: Turkish defaults to solfège.
    expect(store.notation, NoteNotation.solfege);
    expect(store.lastTrainer, TrainerKind.chord.id);
    expect(find.text('Bugün'), findsWidgets);
    expect(find.byKey(const Key('daily_plan')), findsOneWidget);
    // The voice workshop is a tab for everyone; a choir singer also gets the
    // choir tab (the old check passed only because tests ran in English).
    expect(find.text('Koro'), findsOneWidget);
    await tapKey(tester, 'tab_1');
    expect(find.text('Ses Atölyesi'), findsOneWidget);
  });

  testWidgets('a solo learner can skip the vocal range step', (tester) async {
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'get_started');
    await tapKey(tester, 'opt_solo');
    await tapKey(tester, 'ob_continue');
    expect(find.text('Ses aralığını ölçelim'), findsOneWidget);
    expect(find.byKey(const Key('ob_measure_range')), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
    await tapKey(tester, 'ob_continue');
    expect(find.text('Önce neye odaklanalım?'), findsOneWidget);
    expect(store.answers['role'], 'solo');
    expect(store.voicePart, isNull);
  });

  testWidgets('a measured range turns the skip into continue', (tester) async {
    final store = memoryStore({'koroRange': '48-67'});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'get_started');
    await tapKey(tester, 'opt_solo');
    await tapKey(tester, 'ob_continue');
    expect(find.text('Ölçüldü: Do3 – Sol4'), findsOneWidget);
    expect(find.text('Devam'), findsOneWidget);
  });

  testWidgets('a run saved on the old notation step resumes at minutes', (
    tester,
  ) async {
    final store = memoryStore({
      'answers': {'obStep': 'notation'},
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    expect(find.text('Günde kaç dakika ayırabilirsin?'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
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
    expect(find.text('Başlarken'), findsWidgets);
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

  testWidgets('voice tab lists the workshop and opens the voice-count drill', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_1');
    expect(find.text('Ses Atölyesi'), findsWidgets);
    expect(find.text('Ses aralığı testi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('YAKINDA'), 200);
    expect(find.text('Aksak ritim'), findsOneWidget);
    expect(find.text('YAKINDA'), findsOneWidget);
    await tapKey(tester, 'koro_voices');
    expect(find.text('Kaç ses duyuyorsun?'), findsOneWidget);
    await tapKey(tester, 'voices_3', settleMs: 1500);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('progress and settings speak to every learner, not only '
      'choir singers', (tester) async {
    final store = memoryStore({
      'onboardingDone': true,
      'setupDone': true,
      'voicePart': 'alto',
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_2');
    expect(find.text('Çırak için 500 XP · bu hafta 0 XP'), findsOneWidget);
    // Two-letter day names, as on the Bugün week bar.
    for (final day in ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz']) {
      expect(find.text(day), findsOneWidget);
    }
    await tapKey(tester, 'tab_3');
    expect(find.text('SES'), findsOneWidget);
    expect(find.text('KORO'), findsNothing);
    expect(find.text('Çalışma aralığı: Alto'), findsOneWidget);
    expect(find.text('Çalışma aralığım'), findsOneWidget);
  });

  testWidgets('a settings row toggles from anywhere on the row', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_3');
    final before = store.hints;
    final title = find.text('Cevap ipuçları');
    await tester.ensureVisible(title);
    await tester.pump();
    await tester.tap(title);
    await settle(tester);
    expect(store.hints, !before);
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

  testWidgets('delete my data also clears results and reminders', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    final history = _History();
    final preferences = InMemoryPracticePreferences();
    await preferences.saveReminderTime(
      PracticeReminderTime(hour: 19, minute: 0),
    );
    final platform = _Reminders();
    final choir = _Choir();
    await tester.pumpWidget(
      app(
        store,
        history: history,
        choir: choir,
        reminders: PracticeReminderCoordinator(
          preferences: preferences,
          platform: platform,
        ),
      ),
    );
    await settle(tester);
    await tapKey(tester, 'tab_3');
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
    expect(history.clears, 1);
    expect(choir.clears, 1);
    expect(platform.cancels, 1);
    expect(await tester.runAsync(preferences.loadReminderTime), isNull);
  });

  testWidgets('a temp recording that survives keeps the delete open', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    var report = const OrphanCleanupReport(failures: 1);
    await tester.pumpWidget(app(store, purgeTemp: () async => report));
    await settle(tester);
    await tapKey(tester, 'tab_3');
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.textContaining('Veriler silinemedi'), findsOneWidget);
    expect(store.onboardingDone, isTrue);

    report = const OrphanCleanupReport(removedDirectories: 1);
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
  });

  testWidgets('a failed delete stays in settings and can be retried', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    final history = _History();
    final choir = _Choir()..fail = true;
    await tester.pumpWidget(app(store, history: history, choir: choir));
    await settle(tester);
    await tapKey(tester, 'tab_3');
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.byKey(const Key('get_started')), findsNothing);
    expect(find.byKey(const Key('delete_data')), findsOneWidget);
    expect(find.textContaining('Veriler silinemedi'), findsOneWidget);
    expect(store.onboardingDone, isTrue);

    choir.fail = false;
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1200);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
    expect(history.clears, 2);
    expect(choir.clears, 1);
  });
}
