// End-to-end user journeys on a simulator or device, with the production
// wiring of `TrainerApp` (file storage, real audio playback, real plugins):
//   flutter test integration_test -d <device-id>
// Proves the app flows hold together on a platform; it does not open the
// microphone and is not device/mic/human QA (see AUDIO_TESTING.md).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/infrastructure/storage/file_practice_preferences.dart';
import 'package:resonia/trainer/app/trainer_app.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Starts from a clean install: removes every JSON store the app keeps.
Future<void> wipeAppData() async {
  final dir = await getApplicationSupportDirectory();
  if (!await dir.exists()) return;
  await for (final entry in dir.list()) {
    if (entry is File && entry.path.endsWith('.json')) await entry.delete();
  }
}

/// A returning user: the app finds this document on disk at launch.
Future<void> seedStore(Map<String, Object?> doc) =>
    FileTrainerPersistence().write(doc);

/// Launches the app as `main()` does. A new key models a cold restart: the
/// old tree (and its audio) is disposed and state is re-read from disk.
Future<void> launch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(TrainerApp(key: UniqueKey()));
  await settle(tester, 1500);
}

/// Real-time waits: timers, audio and file IO run on the device clock.
Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
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

Future<Map<String, Object?>?> storedDoc() => FileTrainerPersistence().read();

const _returning = {'onboardingDone': true, 'setupDone': true};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(wipeAppData);

  testWidgets('new singer onboards, tours the tabs and is remembered', (
    tester,
  ) async {
    await launch(tester);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
    await tapKey(tester, 'get_started');
    await tapKey(tester, 'ob_continue'); // Name is optional.
    await tapKey(tester, 'goal_choir');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'level_beginner');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'minutes_10');
    await tapKey(tester, 'ob_continue');
    // No microphone or notification prompt during onboarding (WIDE-01).
    expect(find.text('Planın kuruldu'), findsOneWidget);
    await tester.tap(find.text('Ana sayfaya git'));
    await settle(tester, 1000);

    expect(find.byKey(const Key('daily_plan')), findsOneWidget);
    await tapKey(tester, 'tab_1');
    expect(find.text('Ses Atölyesi'), findsWidgets);
    await tapKey(tester, 'tab_2');
    await tapKey(tester, 'tab_3');
    expect(find.byKey(const Key('settings_part')), findsOneWidget);
    await tapKey(tester, 'tab_0');

    final doc = await storedDoc();
    expect(doc?['onboardingDone'], isTrue);
    expect(doc?['dailyMinutes'], 10);

    await launch(tester);
    expect(find.byKey(const Key('get_started')), findsNothing);
    expect(find.byKey(const Key('daily_plan')), findsOneWidget);
  });

  testWidgets('quitting mid-onboarding resumes at the same step', (
    tester,
  ) async {
    await launch(tester);
    await tapKey(tester, 'get_started');
    await tapKey(tester, 'opt_singer');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'ob_continue');
    await launch(tester);
    expect(find.byKey(const Key('get_started')), findsNothing);
    expect(find.byKey(const Key('opt_voice')), findsOneWidget);
  });

  testWidgets('today lesson finishes the intro and survives a restart', (
    tester,
  ) async {
    await seedStore(_returning);
    await launch(tester);
    await tapKey(tester, 'today_begin');
    // Today's route opens with the unmeasured breathing guide; skip it.
    await tapKey(tester, 'breath_skip');
    final path = trainerPaths[TrainerKind.pitch]!;
    final intro = path.nodes.first;
    for (var i = 0; i < 20; i++) {
      if (find.text(path.nodes[1].title).evaluate().isNotEmpty) break;
      await tapKey(tester, 'lesson_next', settleMs: 900);
    }
    expect(find.text(path.nodes[1].title), findsOneWidget);

    await launch(tester);
    final store = TrainerStore(FileTrainerPersistence());
    await store.load();
    expect(store.isComplete(intro.id), isTrue);
  });

  testWidgets('free pitch practice plays real audio to the results', (
    tester,
  ) async {
    await seedStore(_returning);
    await launch(tester);
    await tapKey(tester, 'skill_pitch');
    await tapKey(tester, 'skill_free');
    await tapKey(tester, 'practice_now', settleMs: 1500);
    for (var q = 0; q < 8; q++) {
      expect(find.byKey(const Key('quiz_status')), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Do').first);
      await settle(tester, 500);
      if (find.text('Sonraki soru').evaluate().isNotEmpty) {
        await tester.tap(find.text('Sonraki soru'));
      } else if (find.text('Devam').evaluate().isNotEmpty) {
        await tester.tap(find.text('Devam'));
      } else if (find.textContaining('Bir daha dinle').evaluate().isNotEmpty) {
        await tester.tap(find.bySemanticsLabel('Sol').first);
      }
      await settle(tester, 2500);
    }
    expect(find.byKey(const Key('session_done')), findsOneWidget);
    await tapKey(tester, 'session_done');

    await launch(tester);
    final store = TrainerStore(FileTrainerPersistence());
    await store.load();
    expect(store.trainerReps(TrainerKind.pitch), 8);
    expect(store.streak, 1);
  });

  testWidgets('voice tab opens range intro and the voice-count drill', (
    tester,
  ) async {
    await seedStore(_returning);
    await launch(tester);
    await tapKey(tester, 'tab_1');
    await tapKey(tester, 'koro_range');
    // Intro only: starting would ask for the microphone.
    expect(find.byKey(const Key('range_title')), findsOneWidget);
    await tester.tap(find.byTooltip('Geri').first);
    await settle(tester);
    await tapKey(tester, 'koro_voices');
    expect(find.text('Kaç ses duyuyorsun?'), findsOneWidget);
    await tapKey(tester, 'voices_3', settleMs: 2000);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('deleting data returns to welcome and clears the disk', (
    tester,
  ) async {
    await seedStore(_returning);
    await FilePracticePreferences().saveHapticsEnabled(false);
    final support = await getApplicationSupportDirectory();
    final history = File('${support.path}/result_history.json');
    await history.writeAsString('{}');
    final media = await Directory(
      '${support.path}/choir_media',
    ).create(recursive: true);
    await File('${media.path}/take.wav').writeAsString('audio');
    final leftover = await (await getTemporaryDirectory()).createTemp(
      'choir-take-',
    );
    await File('${leftover.path}/take.wav').writeAsString('audio');
    await launch(tester);
    await tapKey(tester, 'tab_3');
    await tapKey(tester, 'delete_data');
    await tester.tap(find.text('Sil'));
    await settle(tester, 1500);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
    expect((await storedDoc())?['onboardingDone'], isNot(true));
    expect(await history.exists(), isFalse);
    expect(
      await File('${support.path}/practice_preferences.json').exists(),
      isFalse,
    );
    expect(await media.exists(), isFalse);
    expect(await leftover.exists(), isFalse);

    await launch(tester);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
  });
}
