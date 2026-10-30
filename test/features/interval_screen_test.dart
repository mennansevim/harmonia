import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/features/history/history_screen.dart';
import 'package:resonia/features/interval/interval_screen.dart';
import 'package:resonia/features/learning/micro_lesson_screen.dart';
import 'package:resonia/features/common/ui/answer_comparison_card.dart';

import '../support/fake_clip_player.dart';

void main() {
  testWidgets('round names degrees, reports confusion, fits 320px/1.8×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final player = FakeClipPlayer();
    final history = InMemoryResultHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalScreen(player: player, history: history),
      ),
    );
    Future<void> tap(String key) async {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 100);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
    }

    await tester.scrollUntilVisible(
      find.byKey(const Key('int_answer_mi')),
      100,
    );
    expect(find.textContaining("büyük 3'lü"), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tap('int_play');
      player.end.complete();
      await tester.pump();
      player.end = Completer();
      await tap('int_answer_sol');
      await tap('int_next');
    }
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('int_summary_text')),
      100,
    );
    expect(find.textContaining('Şans düzeyi yaklaşık %33'), findsOneWidget);
    expect(find.byKey(const Key('int_confusion')), findsOneWidget);
    final cards = tester
        .widgetList<AnswerComparisonCard>(find.byType(AnswerComparisonCard))
        .toList();
    expect(cards, hasLength(8));
    expect(cards.every((card) => card.selected == "sol · tam 5'li"), isTrue);
    expect(cards.where((card) => card.selected != card.correct), isNotEmpty);
    final beforeLesson = await history.load();
    final playsBeforeLesson = player.calls.length;
    await tap('int_concept_review');
    await tester.pumpAndSettle();
    expect(find.byType(MicroLessonScreen), findsOneWidget);
    expect(find.text('Tonik ve derece: önce do’yu yerleştir'), findsOneWidget);
    expect(player.calls.length, playsBeforeLesson);
    expect((await history.load()).single, same(beforeLesson.single));
    await tester.tap(find.byKey(const Key('lesson_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('int_summary')), findsOneWidget);
    final playsBeforeReview = player.calls.length;
    final beforeReview = await history.load();
    await tap('int_review_0');
    await tester.pumpAndSettle();
    expect(find.text(cards.first.reference), findsOneWidget);
    expect(player.calls.length, playsBeforeReview);
    expect((await history.load()).single, same(beforeReview.single));
    await tap('int_review_0_reference');
    expect(find.text('Durdur'), findsOneWidget);
    expect(player.calls.length, playsBeforeReview + 2);
    player.end.complete();
    await tester.pumpAndSettle();
    player.end = Completer();
    await tap('int_review_0_selected');
    expect(find.text('Durdur'), findsOneWidget);
    player.end.complete();
    await tester.pumpAndSettle();
    expect((await history.load()).single, same(beforeReview.single));
    final missed = cards.where((card) => card.selected != card.correct).length;
    await tap('int_guided_retry');
    expect(find.byKey(const Key('int_guided_label')), findsOneWidget);
    expect(find.text('1/$missed'), findsOneWidget);
    expect((await history.load()).single, same(beforeReview.single));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: history)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('/8 doğru (dinleme)'),
      100,
    );
    expect(find.textContaining('/8 doğru (dinleme)'), findsOneWidget);
  });
}
