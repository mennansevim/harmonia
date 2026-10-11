import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/features/rhythm_imitation/rhythm_imitation_screen.dart';

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
    expect(find.text('3 vuruş alındı.'), findsOneWidget);
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
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('Eksik'), findsOneWidget);
    expect(find.text('Doğru!'), findsNothing);
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
    final chip = tester.widget<ChoiceChip>(
      find.byKey(
        Key('rhythm_pattern_${draftRhythmPatterns[1].exercise.exercise.id}'),
      ),
    );
    expect(chip.selected, isTrue);
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
}
