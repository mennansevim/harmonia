import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/features/daily_plan/daily_plan_screen.dart';

class _History extends InMemoryResultHistory {
  int loads = 0;
  bool unavailable = true;
  Completer<List<ResultHistoryEntry>>? pending;
  @override
  Future<List<ResultHistoryEntry>> load() async {
    loads++;
    if (pending != null) return pending!.future;
    if (unavailable) {
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
    }
    return super.load();
  }
}

void main() {
  testWidgets(
    'failed plan retries explicitly without clearing history or budget',
    (tester) async {
      final history = _History();
      await tester.pumpWidget(
        MaterialApp(
          home: DailyPlanScreen(
            goal: PracticeGoal.foundations,
            history: history,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plan_error')), findsOneWidget);
      expect(find.textContaining('Veri silinmedi'), findsOneWidget);
      expect(history.loads, 1);
      await tester.tap(find.byKey(const Key('budget_5')));
      await tester.pumpAndSettle();
      expect(history.loads, 2);
      history.unavailable = false;
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(history.loads, 3);
      expect(find.byKey(const Key('plan_error')), findsNothing);
      expect(find.textContaining('/ 5 dk'), findsOneWidget);
      expect(await history.load(), isEmpty);
    },
  );
  testWidgets('pending retry hides stale plan and ignores repeated taps', (
    tester,
  ) async {
    final history = _History();
    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(goal: PracticeGoal.foundations, history: history),
      ),
    );
    await tester.pumpAndSettle();
    history.pending = Completer();
    await tester.tap(find.text('Yeniden dene'));
    await tester.pump();
    expect(find.byKey(const Key('plan_loading')), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
    expect(find.byKey(const Key('plan_minutes')), findsNothing);
    expect(history.loads, 2);
    history.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan_minutes')), findsOneWidget);
  });
  testWidgets('leaving during retry cannot update disposed UI', (tester) async {
    final history = _History();
    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(goal: PracticeGoal.foundations, history: history),
      ),
    );
    await tester.pumpAndSettle();
    history.pending = Completer();
    await tester.tap(find.text('Yeniden dene'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    history.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(history.loads, 2);
  });
  testWidgets('foreground return hides the stale plan until reload completes', (
    tester,
  ) async {
    final history = _History()..unavailable = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(goal: PracticeGoal.foundations, history: history),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan_minutes')), findsOneWidget);
    history.pending = Completer();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(history.loads, 2);
    expect(find.byKey(const Key('plan_loading')), findsOneWidget);
    expect(find.byKey(const Key('plan_minutes')), findsNothing);
    history.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan_minutes')), findsOneWidget);
  });
  testWidgets('replacement repository cannot leave the old plan visible', (
    tester,
  ) async {
    final old = _History()..unavailable = false;
    final next = _History()..pending = Completer();
    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(goal: PracticeGoal.foundations, history: old),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan_minutes')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(goal: PracticeGoal.foundations, history: next),
      ),
    );
    await tester.pump();

    expect(next.loads, 1);
    expect(find.byKey(const Key('plan_loading')), findsOneWidget);
    expect(find.byKey(const Key('plan_minutes')), findsNothing);
    next.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan_minutes')), findsOneWidget);
  });
}
