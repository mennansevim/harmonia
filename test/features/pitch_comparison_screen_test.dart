import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/features/history/history_screen.dart';
import 'package:harmonia/features/pitch_comparison/pitch_comparison_screen.dart';

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
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: history)));
    await tester.pumpAndSettle();
    expect(find.textContaining('4/8 doğru (dinleme)'), findsOneWidget);
  });
}
