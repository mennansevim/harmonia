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
import 'package:resonia/trainer/state/trainer_store.dart';

import '../support/tour_fonts.dart';
import '../support/visible_text_contrast.dart';

// Screen and system text sizes that stand in for different readers: a small
// phone, and large text as used by many older users. This is a layout and
// accessibility gate, not a test with real people of those ages.
const profiles = [
  ('standart', Size(390, 844), 1.0),
  ('kucuk-telefon', Size(320, 568), 1.0),
  ('yatay', Size(844, 390), 1.0),
  ('yazi-1.3', Size(390, 844), 1.3),
  ('yazi-1.6', Size(390, 844), 1.6),
  ('yazi-2.0', Size(390, 844), 2.0),
];

void main() {
  setUpAll(loadTourFonts);
  for (final (name, size, scale) in profiles) {
    testWidgets('first run and tabs stay usable: $name', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final overflows = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        final text = d.exceptionAsString();
        overflows.add(text.contains('overflowed') ? 'overflow' : text);
      };
      final handle = tester.ensureSemantics();
      final out = <String>[];

      Future<void> settle() async {
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          tester.takeException();
        }
      }

      Future<void> tap(String key) async {
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            f,
            200,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(f);
        await tester.pump();
        await tester.tap(f);
        await settle();
      }

      Future<void> audit(String screen) async {
        await settle();
        final failed = <String>[];
        for (final (label, g) in [
          ('tap', androidTapTargetGuideline),
          ('iostap', iOSTapTargetGuideline),
          ('label', labeledTapTargetGuideline),
          ('contrast', const VisibleTextContrastGuideline()),
        ]) {
          final e = await g.evaluate(tester);
          if (!e.passed) failed.add('$label: ${e.reason}');
        }
        if (overflows.isNotEmpty) failed.add('overflow');
        if (failed.isNotEmpty) out.add('$screen: ${failed.join(', ')}');
        overflows.clear();
      }

      final store = TrainerStore(
        MemoryTrainerPersistence(null),
        clock: () => DateTime(2026, 10, 29, 9),
      );
      await store.load();
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
      try {
        await audit('karsilama');
        await tap('get_started');
        await audit('isim');
        await tap('ob_continue');
        await audit('hedef');
        await tap('goal_choir');
        await audit('hedef-secili');
        await tap('ob_continue');
        await audit('seviye');
        await tap('level_beginner');
        await tap('ob_continue');
        await audit('sure');
        await tap('minutes_10');
        await tap('ob_continue');
        await audit('hazir');
        await tester.ensureVisible(find.text('Ana sayfaya git'));
        await tester.pump();
        await tester.tap(find.text('Ana sayfaya git'));
        await settle();
        await audit('bugun');
        for (final (key, label) in [
          ('tab_1', 'ses'),
          ('tab_koro', 'koro'),
          ('tab_2', 'ilerleme'),
          ('open_settings', 'ayarlar'),
        ]) {
          await tap(key);
          await audit(label);
        }
      } catch (e) {
        out.add('blocked: ${e.toString().split('\n').first}');
      }
      FlutterError.onError = previous;
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(out, isEmpty);
    });
  }
}
