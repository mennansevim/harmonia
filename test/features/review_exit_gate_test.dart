import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/features/interval/interval_screen.dart';
import 'package:resonia/features/pitch_comparison/pitch_comparison_screen.dart';

import '../support/fake_clip_player.dart';

class _CloseFailingPlayer extends FakeClipPlayer {
  @override
  Future<void> close() async {
    calls.add('close');
    throw StateError('close failed');
  }
}

void main() {
  Future<void> open(
    WidgetTester tester, {
    required Widget Function(BuildContext) page,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const Key('open_lesson'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: page)),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_lesson')));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 100);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }

  testWidgets(
    'active result replay is stopped and closed before route leaves',
    (tester) async {
      final player = FakeClipPlayer();
      await open(tester, page: (_) => PitchComparisonScreen(player: player));
      for (var i = 0; i < 8; i++) {
        player.end = Completer<void>();
        await tapVisible(tester, 'perc_play');
        player.end.complete();
        await tester.pump();
        await tapVisible(tester, 'perc_answer_second');
        await tapVisible(tester, 'perc_next');
      }
      await tester.pumpAndSettle();
      await tapVisible(tester, 'perc_review_0');
      player.end = Completer<void>();
      await tapVisible(tester, 'perc_review_0_reference');
      expect(find.text('Durdur'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lesson_close')));
      await tester.pumpAndSettle();

      expect(find.byType(PitchComparisonScreen), findsNothing);
      expect(player.calls, containsAllInOrder(['stop', 'close']));
    },
  );

  testWidgets('close failure blocks route release and explains recovery', (
    tester,
  ) async {
    final player = _CloseFailingPlayer();
    await open(tester, page: (_) => IntervalScreen(player: player));

    await tester.tap(find.byKey(const Key('lesson_close')));
    await tester.pumpAndSettle();

    expect(find.byType(IntervalScreen), findsOneWidget);
    expect(find.byKey(const Key('int_exit_status')), findsOneWidget);
    expect(find.textContaining('kapatıp yeniden aç'), findsOneWidget);
    expect(player.calls, contains('close'));
  });
}
