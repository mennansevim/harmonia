// Visual tour for design review, not a regression gate. Renders key screens
// with the app's real fonts into PNG files:
//   flutter test test/trainer/screenshot_tour_test.dart \
//     --dart-define=TOUR_DIR=/absolute/output/dir
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/trainer/app/trainer_app.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/learn/session_end.dart';
import 'package:resonia/trainer/practice/practice_setup.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/settings/membership_screen.dart';
import 'package:resonia/trainer/stats/stats_tab.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import '../support/tour_fonts.dart';

const _dir = String.fromEnvironment('TOUR_DIR');

void main() {
  testWidgets('screenshot tour', skip: _dir.isEmpty, (tester) async {
    await tester.runAsync(loadTourFonts);
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
      // Off-screen list items are not built: drag the page until it is.
      for (var i = 0; i < 12 && f.hitTestable().evaluate().isEmpty; i++) {
        await tester.drag(
          find.byType(Scrollable).hitTestable().first,
          const Offset(0, -250),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
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
    await shot('ob_name');
    await tester.enterText(key('ob_name'), 'Ayşe');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('ob_name_typed');
    await tap(key('ob_continue'));
    await tap(key('goal_choir'));
    await shot('ob_goal');
    await tap(key('ob_continue'));
    await tap(key('level_beginner'));
    await shot('ob_level');
    await tap(key('ob_continue'));
    await tap(key('minutes_10'));
    await shot('ob_minutes');
    await tap(key('ob_continue'));
    await shot('ob_ready');
    await tap(find.text('Ana sayfaya git'));
    await shot('home');

    await tap(key('quick_interval'));
    await shot('skill_interval');
    await tap(key('skill_next'));
    await shot('intro_slide');
    await tap(key('lesson_next'));
    await tap(key('lesson_next'));
    await tap(key('skill_next'));
    await shot('lesson_overview');
    await tap(key('lesson_next'));
    await shot('lesson_listen');
    await tap(key('lesson_next'));
    await shot('lesson_sing');
    await tap(key('lesson_next'), ms: 1200);
    await shot('lesson_practice');
    // Leave the lesson.
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));

    // Today's route: the unmeasured breathing guide, mid-cycle.
    await tap(key('today_begin'));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await shot('breath');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));

    // Session end: measured vs not measured, details collapsed.
    const endConfig = QuizConfig(
      trainer: TrainerKind.interval,
      pool: ['m3', 'M3', 'P5'],
      length: 8,
    );
    final endQuestions = QuizGenerator(
      endConfig,
      random: math.Random(3),
    ).session();
    store.markBreathDone();
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => SessionEnd(
          summary: QuizSummary([
            for (var i = 0; i < endQuestions.length; i++)
              AnswerRecord(endQuestions[i], i != 2),
          ]),
          title: 'Aralıklar',
          retryConfig: endConfig,
          onDone: () {},
        ),
      ),
    );
    await shot('session_end');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));

    await tap(key('quick_pitch'));
    await tap(key('skill_free'));
    await shot('practice_setup_pitch');
    await tap(key('practice_now'), ms: 400);
    await shot('quiz_identify_playing');
    await tap(find.bySemanticsLabel('Sol'), ms: 300);
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
    await tap(key('tab_2'));
    await shot('progress');
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => const TrainerStatsScreen(trainer: TrainerKind.chord),
      ),
    );
    await shot('stats_chord');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));
    await tap(key('open_settings'));
    await shot('settings');
    nav.push(MaterialPageRoute<void>(builder: (_) => const MembershipScreen()));
    await shot('membership');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 1));

    await tap(key('tab_1'));
    await shot('voice_hub');
    await tap(key('koro_range'));
    await shot('range_intro');
    await tap(find.byTooltip('Geri').first);
    await tester.scrollUntilVisible(
      key('koro_voices'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tap(key('koro_voices'));
    await shot('voice_count');
    nav.popUntil((r) => r.isFirst);
    await tester.pump(const Duration(seconds: 3));
  });
}
