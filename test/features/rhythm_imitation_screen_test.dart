import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/content/rhythm_patterns.dart';
import 'package:resonia/features/common/ui/resonia_ui.dart';
import 'package:resonia/features/learning/micro_lesson_screen.dart';
import 'package:resonia/features/rhythm_imitation/rhythm_imitation_screen.dart';

import '../support/fake_clip_player.dart';

void main() {
  testWidgets('listen → tap with engine timestamps → explained timeline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final player = FakeClipPlayer();
    await tester.pumpWidget(
      MaterialApp(home: RhythmImitationScreen(player: player)),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_draft_label')),
      100,
    );
    expect(find.textContaining('eğitimci onayı bekliyor'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_listen')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_listen')));
    await tester.pump();
    expect(find.text('Dinle… (dokunuşlar değerlendirilmez)'), findsOneWidget);
    expect(player.lastBytes, greaterThan(44));
    player.end.complete();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_tap_pad')),
      100,
    );
    await tester.pumpAndSettle();
    final pad = tester.getCenter(find.byKey(const Key('rhythm_tap_pad')));
    // One missing beat: taps at 0, 750, 2250 ms (reference 0/750/1500/2250).
    for (final ms in [0, 750, 2250]) {
      final g = await tester.createGesture();
      await g.down(pad, timeStamp: Duration(milliseconds: 10000 + ms));
      await g.up(timeStamp: Duration(milliseconds: 10050 + ms));
      await tester.pump();
    }
    expect(find.textContaining('3/4 vuruş.'), findsOneWidget);
    expect(find.byKey(const Key('rhythm_finish')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_result_summary')),
      100,
    );
    expect(
      find.text('4 vuruşun 3 tanesi eşleşti (ilki başlangıç), 1 eksik.'),
      findsOneWidget,
    );
    // The result replaces the tap pad; per-beat chips live in details.
    expect(find.byKey(const Key('rhythm_tap_pad')), findsNothing);
    expect(find.byKey(const Key('rhythm_listen')), findsNothing);
    expect(find.byKey(const Key('rhythm_alignment')), findsOneWidget);
    expect(find.text('Başlangıç'), findsNothing);
    expect(find.byKey(const Key('rhythm_retry')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_details')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_details')));
    await tester.pumpAndSettle();
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('Eksik'), findsOneWidget);
    expect(find.text('Doğru!'), findsNothing);
    final playsBeforeLesson = player.calls.length;
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_concept_review')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_concept_review')));
    await tester.pumpAndSettle();
    expect(find.byType(MicroLessonScreen), findsOneWidget);
    expect(find.text('Hedef boyutu: Üretim'), findsOneWidget);
    expect(player.calls.length, playsBeforeLesson);
    await tester.tap(find.byKey(const Key('lesson_close')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_start_guided')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_start_guided')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rhythm_guided_label')), findsOneWidget);
    expect(find.text('Zor bölümü dinle, sonra tekrar et'), findsOneWidget);
    expect(find.byKey(const Key('rhythm_exit_guided')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('result shows one next step; preselected pattern from id', (
    tester,
  ) async {
    final player = FakeClipPlayer();
    final history = InMemoryResultHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: RhythmImitationScreen(
          player: player,
          history: history,
          initialPatternId: draftRhythmPatterns[1].exercise.exercise.id,
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('rhythm_level_picker')),
        matching: find.text(draftRhythmPatterns[1].title),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_listen')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_listen')));
    await tester.pump();
    player.end.complete();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_tap_pad')),
      100,
    );
    await tester.pumpAndSettle();
    final pad = tester.getCenter(find.byKey(const Key('rhythm_tap_pad')));
    for (final ms in [0, 750]) {
      final g = await tester.createGesture();
      await g.down(pad, timeStamp: Duration(milliseconds: 5000 + ms));
      await g.up(timeStamp: Duration(milliseconds: 5050 + ms));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_next_step')),
      100,
    );
    expect(find.textContaining('Aynı deseni tekrar et'), findsOneWidget);
    expect(find.textContaining('vuruş eksikti'), findsOneWidget);
    expect((await history.load()), hasLength(1));
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_apply_next')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_apply_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rhythm_next_step')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('targeted repeat ends with one primary action, no repeats', (
    tester,
  ) async {
    final player = FakeClipPlayer();
    await tester.pumpWidget(
      MaterialApp(home: RhythmImitationScreen(player: player)),
    );
    Future<void> answer(List<int> ms, int base) async {
      await tester.scrollUntilVisible(
        find.byKey(const Key('rhythm_listen')),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rhythm_listen')));
      await tester.pump();
      player.end.complete();
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('rhythm_tap_pad')),
        100,
      );
      await tester.pumpAndSettle();
      final pad = tester.getCenter(find.byKey(const Key('rhythm_tap_pad')));
      for (final t in ms) {
        final g = await tester.createGesture();
        await g.down(pad, timeStamp: Duration(milliseconds: base + t));
        await g.up(timeStamp: Duration(milliseconds: base + t + 40));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }

    await answer([0, 750, 2250], 10000);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_start_guided')),
      100,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rhythm_start_guided')));
    await tester.pumpAndSettle();
    player.end = Completer();
    // Excerpt 0/750/1500 ms, answered slightly late.
    await answer([0, 800, 1560], 20000);
    expect(find.text('Hedefli tekrar bitti — puanlanmadı.'), findsOneWidget);
    expect(find.textContaining('Hedefli tekrar —'), findsNothing);
    expect(find.byKey(const Key('rhythm_alignment_snap')), findsNothing);
    expect(find.byKey(const Key('rhythm_details')), findsNothing);
    expect(find.byKey(const Key('rhythm_beat_chips')), findsNothing);
    expect(find.byKey(const Key('rhythm_tap_pad')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rhythm_next_pattern')),
      100,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rhythm_exit_guided')), findsOneWidget);
    expect(find.byType(ChunkyButton), findsOneWidget);
    await tester.tap(find.byKey(const Key('rhythm_next_pattern')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rhythm_guided_label')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('rhythm_level_picker')),
        matching: find.text(draftRhythmPatterns[1].title),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
