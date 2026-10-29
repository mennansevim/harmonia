import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/features/history/history_screen.dart';
import 'package:harmonia/features/learning/micro_lesson_screen.dart';
import 'package:harmonia/features/pitch_comparison/pitch_comparison_screen.dart';
import 'package:harmonia/features/common/ui/answer_comparison_card.dart';

import '../support/fake_clip_player.dart';

void main() {
  testWidgets('round flow fits 320px/1.8× and states the chance level', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final player = FakeClipPlayer();
    final history = InMemoryResultHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: PitchComparisonScreen(player: player, history: history),
      ),
    );
    Future<void> tap(String key) async {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    for (var i = 0; i < 8; i++) {
      await tap('perc_play');
      player.end.complete();
      await tester.pump();
      player.end = Completer();
      await tap('perc_answer_second');
      await tester.scrollUntilVisible(
        find.byKey(const Key('perc_feedback')),
        100,
      );
      await tap('perc_next');
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('perc_summary_text')),
      100,
    );
    expect(find.text('8 sorudan 4 doğru.'), findsOneWidget);
    expect(find.textContaining('Şans düzeyi %50'), findsOneWidget);
    final cards = tester
        .widgetList<AnswerComparisonCard>(find.byType(AnswerComparisonCard))
        .toList();
    expect(cards, hasLength(8));
    expect(
      cards.every((card) => card.selected == 'İkinci ses daha tiz'),
      isTrue,
    );
    expect(cards.where((card) => card.selected == card.correct), hasLength(4));
    final beforeLesson = await history.load();
    final playsBeforeLesson = player.calls.length;
    await tap('perc_concept_review');
    await tester.pumpAndSettle();
    expect(find.byType(MicroLessonScreen), findsOneWidget);
    expect(find.textContaining('öğrenme kanıtı değildir'), findsOneWidget);
    expect(player.calls.length, playsBeforeLesson);
    expect((await history.load()).single, same(beforeLesson.single));
    await tester.tap(find.byKey(const Key('lesson_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('perc_summary')), findsOneWidget);
    final playsBeforeReview = player.calls.length;
    final beforeReview = await history.load();
    await tap('perc_review_0');
    await tester.pumpAndSettle();
    expect(find.text(cards.first.reference), findsOneWidget);
    expect(player.calls.length, playsBeforeReview);
    expect((await history.load()).single, same(beforeReview.single));
    await tap('perc_review_0_reference');
    expect(find.text('Durdur'), findsOneWidget);
    expect(player.calls.length, playsBeforeReview + 2);
    player.end.complete();
    await tester.pumpAndSettle();
    expect((await history.load()).single, same(beforeReview.single));
    await tap('perc_guided_retry');
    expect(find.byKey(const Key('perc_guided_label')), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect((await history.load()).single, same(beforeReview.single));
    for (var i = 0; i < 4; i++) {
      player.end = Completer<void>();
      await tap('perc_play');
      player.end.complete();
      await tester.pump();
      await tap('perc_answer_first');
      await tap('perc_next');
    }
    await tester.pumpAndSettle();
    expect(find.text('Hata tekrarı tamam'), findsOneWidget);
    expect(find.byKey(const Key('perc_guided_notice')), findsOneWidget);
    expect(
      find.textContaining('ölçüt veya ustalık kanıtı üretmez'),
      findsOneWidget,
    );
    expect(find.textContaining('Taslak ölçüt:'), findsNothing);
    expect((await history.load()).single, same(beforeReview.single));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: history)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('/8 doğru (dinleme)'),
      100,
    );
    expect(find.textContaining('4/8 doğru (dinleme)'), findsOneWidget);
  });
}
