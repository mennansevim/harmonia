// Visual tour for design review, not a regression gate. Renders key screens
// with real Roboto/Material Icons fonts into PNG files:
//   flutter test test/trainer/screenshot_tour_test.dart \
//     --dart-define=TOUR_DIR=/absolute/output/dir
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/practice_reminder.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/trainer/app/trainer_app.dart';
import 'package:harmonia/trainer/audio/trainer_audio.dart';
import 'package:harmonia/trainer/domain/trainers.dart';
import 'package:harmonia/trainer/koro/koro_hub.dart';
import 'package:harmonia/trainer/practice/practice_setup.dart';
import 'package:harmonia/trainer/stats/stats_tab.dart';
import 'package:harmonia/trainer/state/trainer_store.dart';

const _dir = String.fromEnvironment('TOUR_DIR');

Future<void> _loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  testWidgets('screenshot tour', skip: _dir.isEmpty, (tester) async {
    await tester.runAsync(_loadFonts);
    final view = tester.view;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
    addTearDown(view.reset);

    final boundary = GlobalKey();
    var n = 0;
    Future<void> shot(String name) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$_dir/${(++n).toString().padLeft(2, '0')}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    Future<void> tap(Finder f, {int ms = 700}) async {
      await tester.tap(f.first, warnIfMissed: false);
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Finder key(String k) => find.byKey(Key(k));

    final store = TrainerStore(
      MemoryTrainerPersistence(),
      clock: () => DateTime(2026, 10, 29, 9),
    );
    await store.load();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: TrainerApp(
          store: store,
          audio: TrainerAudio.silent(),
          reminders: PracticeReminderCoordinator(
            preferences: InMemoryPracticePreferences(),
            platform: UnavailablePracticeReminderPlatform(),
          ),
          history: InMemoryResultHistory(),
          liveAudio: false,
          startupCleanup: () async {},
        ),
      ),
    );
    await shot('welcome');
    await tap(key('get_started'));
    await shot('intro_ear');
    await tap(key('ob_continue'));
    await shot('intro_gamified');
    await tap(key('ob_continue'));
    await tap(key('ob_continue'));
    await tap(key('opt_voice'));
    await tap(key('opt_piano'));
    await shot('survey_instrument');
    await tap(key('ob_continue'));
    await tap(key('opt_student'), ms: 900);
    await tap(key('opt_choir'));
    await tap(key('ob_continue'));
    await tap(key('opt_few'));
    await tap(key('ob_continue'));
    await shot('try_it');
    await tap(key('try_it'));
    await shot('sample_pitch');
    await tap(key('sample_opt_Re'), ms: 1200);
    await shot('sample_hint');
    await tap(find.text('Bunu atla'));
    await tap(key('sample_skip'));
    await shot('sample_skip_sheet');
    await tap(find.text('Kalanları atla'));
    await shot('great_job');
    await tap(key('ob_continue'));
    await tap(key('opt_koro'));
    await tap(key('opt_interval'));
    await tap(key('ob_continue'));
    await tap(key('opt_busy'));
    await tap(key('ob_continue'));
    await shot('minutes');
    await tap(key('ob_continue'));
    await tap(key('ob_continue'));
    await tap(key('opt_trust'));
    await tap(key('ob_continue'));
    await shot('potential');
    await tap(key('ob_continue'));
    await shot('reminder');
    await tap(key('reminder_skip'));
    await tap(key('ob_continue'), ms: 2000);
    await shot('building');
    await tester.pump(const Duration(seconds: 3));
    await shot('plan');
    await tap(key('ob_continue'));
    await shot('save');
    await tap(key('save_skip'));
    await shot('free');
    await tap(key('ob_continue'));
    await shot('all_set');
    await tap(key('ob_continue'));
    await tap(key('ob_continue'));
    await shot('six_ways');
    await tap(key('ob_continue'));
    await shot('notation');
    await tap(key('ob_continue'));
    await shot('prefs');
    await tap(key('ob_continue'));
    await shot('level_check');
    await tap(find.text('Atla, yeni başlıyorum'));
    await shot('today');
    await tap(find.text('Ana sayfaya git'));
    await shot('home');

    await tap(key('skill_interval'));
    await shot('trainer_sheet');
    await tap(key('sheet_learn'));
    await tap(find.text('Anladım'));
    await shot('interval_path');
    await tap(find.text('Giriş: Aralık Eğitimi'));
    await shot('lesson_slide');
    await tap(key('lesson_next'));
    await tap(key('lesson_next'));
    await tap(key('lesson_next'));
    await tap(key('lesson_next'));
    await tap(find.text('1. Oktav (P8)'));
    await shot('lesson_start');
    await tap(find.text('Derse başla'));
    await tap(key('lesson_next'));
    await shot('lesson_hear');
    await tap(key('lesson_next'));
    await shot('lesson_hook');
    await tap(key('lesson_next'), ms: 1200);
    await shot('quick_check_yes_no');
    await tap(find.bySemanticsLabel('Evet'), ms: 1200);
    await shot('quick_check_feedback');
    // Leave the lesson.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));

    await tap(key('skill_pitch'));
    await tap(key('sheet_practice'));
    await shot('practice_setup_pitch');
    await tap(key('practice_now'), ms: 400);
    await shot('quiz_identify_playing');
    await tap(find.bySemanticsLabel('Do'), ms: 300);
    await shot('quiz_feedback');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 3));

    nav.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const PracticeSetupScreen(trainer: TrainerKind.progression),
      ),
    );
    await shot('practice_setup_progressions');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));

    // Seed some evidence so the stats screens have data.
    for (final (k, item, ok) in [
      (TrainerKind.chord, 'maj', true),
      (TrainerKind.chord, 'maj', true),
      (TrainerKind.chord, 'min', false),
      (TrainerKind.chord, 'min', true),
      (TrainerKind.chord, 'dim', false),
      (TrainerKind.interval, 'P5', true),
    ]) {
      store.recordAnswer(k, item, ok);
    }
    await tap(key('tab_1'));
    await shot('stats_locked');
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const TrainerStatsScreen(trainer: TrainerKind.chord),
      ),
    );
    await shot('stats_chord');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));
    await tap(key('tab_2'));
    await shot('ranks');
    await tap(key('league_join'));
    await shot('ranks_joined');
    await tap(key('tab_3'));
    await shot('settings');
    await tap(key('tab_0'));
    nav.push(MaterialPageRoute<void>(builder: (_) => const KoroHub()));
    await shot('koro_hub');
    await tap(key('koro_range'));
    await shot('range_intro');
    await tap(find.bySemanticsLabel('Geri'));
    await tester.scrollUntilVisible(
      key('koro_voices'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tap(key('koro_voices'));
    await shot('voice_count');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 3));
  });
}
