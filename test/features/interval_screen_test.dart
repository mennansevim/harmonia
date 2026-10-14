import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/features/history/history_screen.dart';
import 'package:harmonia/features/interval/interval_screen.dart';

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
