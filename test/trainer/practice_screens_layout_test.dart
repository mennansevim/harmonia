import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/microphone_permission_recovery.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';
import 'package:resonia/trainer/app/trainer_app.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/koro/range_test.dart';
import 'package:resonia/trainer/koro/voice_count.dart';
import 'package:resonia/trainer/practice/practice_setup.dart';
import 'package:resonia/trainer/prepare/breath_screen.dart';
import 'package:resonia/trainer/settings/membership_screen.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import '../support/tour_fonts.dart';

// The first-run audit stops at the tabs. These screens have fixed layouts and
// must still fit a landscape phone and very large system text.
const profiles = [
  ('dar', Size(320, 568), 1.0),
  ('yatay', Size(844, 390), 1.0),
  ('yazi-2.0', Size(390, 844), 2.0),
];

class _DeniedProbe implements RangeProbe {
  @override
  Future<bool> requestPermission() async => false;
  @override
  Stream<double> get levelDb => const Stream.empty();
  @override
  Future<RangeTake> record(Duration duration) async =>
      const RangeTake.failed('');
  @override
  Future<void> close() async {}
}

class _Recovery implements MicrophonePermissionRecovery {
  int opened = 0;
  @override
  Future<bool> openAppSettings() async {
    opened++;
    return true;
  }
}

Future<TrainerStore> pumpHome(WidgetTester tester) async {
  final store = TrainerStore(
    MemoryTrainerPersistence(null),
    clock: () => DateTime(2026, 10, 29, 9),
  );
  await store.load();
  store
    ..onboardingDone = true
    ..setupDone = true;
  await tester.pumpWidget(
    TrainerApp(
      store: store,
      audio: TrainerAudio.silent(),
      reminders: PracticeReminderCoordinator(
        preferences: InMemoryPracticePreferences(),
        platform: const UnavailablePracticeReminderPlatform(),
      ),
      history: InMemoryResultHistory(),
      choir: ChoirStore(
        persistence: MemoryChoirPersistence(),
        mediaRoot: () async => Directory.systemTemp,
      ),
      purgeTempAudio: () async => const OrphanCleanupReport(),
      liveAudio: false,
      startupCleanup: () async {},
    ),
  );
  await settle(tester);
  return store;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> open(WidgetTester tester, Widget screen) async {
  Navigator.of(
    tester.element(find.byType(HomeShell)),
  ).push(MaterialPageRoute<void>(builder: (_) => screen));
  await settle(tester);
}

void main() {
  setUpAll(loadTourFonts);

  for (final (name, size, scale) in profiles) {
    testWidgets('practice screens fit: $name', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final failed = <String>[];
      var screen = '';
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => failed.add('$screen overflow');

      try {
        await pumpHome(tester);
        for (final (label, widget) in <(String, Widget)>[
          ('aralik', RangeTestScreen(probe: _DeniedProbe())),
          ('nefes', const BreathScreen()),
          ('ses-sayisi', const VoiceCountScreen()),
          ('uyelik', const MembershipScreen()),
          ('pratik', const PracticeSetupScreen(trainer: TrainerKind.pitch)),
        ]) {
          screen = label;
          await open(tester, widget);
          if (label == 'aralik') {
            await tester.tap(find.text('Başla'));
            await settle(tester);
            screen = 'aralik-izin';
            await settle(tester);
          }
          if (label == 'pratik') {
            await tester.ensureVisible(find.byKey(const Key('practice_now')));
            await tester.pump();
            await tester.tap(find.byKey(const Key('practice_now')));
            screen = 'quiz';
            await settle(tester);
          }
          tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .popUntil((r) => r.isFirst);
          await settle(tester);
        }
      } catch (e) {
        failed.add('$screen blocked: ${e.toString().split('\n').first}');
      } finally {
        FlutterError.onError = previous;
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(failed.toSet(), isEmpty);
    });
  }

  testWidgets('system text scale is capped at the audited maximum', (
    tester,
  ) async {
    // QA-DEF-006: iOS AX5 is about 3.1x.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 3.1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHome(tester);
    final context = tester.element(find.byType(HomeShell));
    expect(MediaQuery.textScalerOf(context).scale(10), 20);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tabs show new practice without a restart', (tester) async {
    // QA-DEF-010: the result said "added to Progress", Progress stayed at 0.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final store = await pumpHome(tester);
    await tester.tap(find.byKey(const Key('tab_2')));
    await settle(tester);
    expect(find.textContaining('0 XP'), findsWidgets);

    store.recordAnswer(TrainerKind.pitch, 'do', true);
    await settle(tester);

    expect(find.textContaining('SEVİYE 1 · 10 XP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('denied microphone offers the phone settings', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final recovery = _Recovery();
    await pumpHome(tester);
    await open(
      tester,
      RangeTestScreen(probe: _DeniedProbe(), recovery: recovery),
    );
    await tester.tap(find.text('Başla'));
    await settle(tester);

    expect(find.text('Mikrofon izni gerekli'), findsOneWidget);
    await tester.tap(find.text('Ayarları aç'));
    await settle(tester);
    expect(recovery.opened, 1);
    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
