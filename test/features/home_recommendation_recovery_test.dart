import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/app_services.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/home/home_screen.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';

class _History extends InMemoryResultHistory {
  int loads = 0;
  int writes = 0;
  bool unavailable = true;
  Completer<List<ResultHistoryEntry>>? pending;

  @override
  Future<List<ResultHistoryEntry>> load() async {
    loads++;
    if (pending != null) return pending!.future;
    if (unavailable) throw StateError('private/path/do-not-render');
    return super.load();
  }

  @override
  Future<RecordOutcome> record(ResultHistoryEntry entry) async {
    writes++;
    return super.record(entry);
  }

  @override
  Future<void> clear() async {
    writes++;
    await super.clear();
  }

  @override
  Future<bool> delete(String attemptId) async {
    writes++;
    return super.delete(attemptId);
  }
}

Widget _app(_History history, ValueNotifier<OrphanCleanupReport?> cleanup) =>
    AppServices(
      history: history,
      cleanup: cleanup,
      child: MaterialApp(
        home: HomeScreen(
          profile: LearnerProfile(
            goal: PracticeGoal.foundations,
            createdAt: DateTime(2026, 10, 15),
          ),
          onOpenSettings: () {},
        ),
      ),
    );

void main() {
  late ValueNotifier<OrphanCleanupReport?> cleanup;
  setUp(() => cleanup = ValueNotifier(null));
  tearDown(() => cleanup.dispose());

  testWidgets(
    'home error retries explicitly without fake suggestion or writes',
    (tester) async {
      final history = _History();
      await tester.pumpWidget(_app(history, cleanup));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today_error')), findsOneWidget);
      expect(find.byKey(const Key('today_action')), findsNothing);
      expect(find.textContaining('Veri silinmedi'), findsOneWidget);
      expect(find.textContaining('private/path'), findsNothing);
      expect(history.loads, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(history.loads, 1);
      history.unavailable = false;
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(history.loads, 2);
      expect(find.byKey(const Key('today_error')), findsNothing);
      expect(find.byKey(const Key('today_card')), findsOneWidget);
      expect(find.textContaining('Başla: Tiz / pes'), findsOneWidget);
      expect(history.writes, 0);
    },
  );

  testWidgets('pending retry shows loading without stale action or retry', (
    tester,
  ) async {
    final history = _History();
    await tester.pumpWidget(_app(history, cleanup));
    await tester.pumpAndSettle();
    history.pending = Completer();
    await tester.tap(find.text('Yeniden dene'));
    await tester.pump();
    expect(find.byKey(const Key('today_loading')), findsOneWidget);
    expect(find.byKey(const Key('today_card')), findsNothing);
    expect(find.text('Yeniden dene'), findsNothing);
    expect(history.loads, 2);
    history.pending!.completeError(StateError('private late failure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_error')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(history.writes, 0);
  });

  testWidgets(
    'late load after disposal never updates UI or becomes unhandled',
    (tester) async {
      final history = _History()..pending = Completer();
      await tester.pumpWidget(_app(history, cleanup));
      await tester.pump();
      expect(find.byKey(const Key('today_loading')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      history.pending!.completeError(StateError('private late failure'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(history.writes, 0);
    },
  );

  testWidgets('replacing repository discards old pending recommendation', (
    tester,
  ) async {
    final old = _History()..pending = Completer();
    final next = _History()..unavailable = false;
    await tester.pumpWidget(_app(old, cleanup));
    await tester.pump();
    await tester.pumpWidget(_app(next, cleanup));
    await tester.pumpAndSettle();
    expect(next.loads, 1);
    expect(find.byKey(const Key('today_card')), findsOneWidget);
    old.pending!.completeError(StateError('stale repository failure'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_error')), findsNothing);
    expect(find.byKey(const Key('today_card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise return handles immediate refresh failure in place', (
    tester,
  ) async {
    final history = _History()..unavailable = false;
    await tester.pumpWidget(_app(history, cleanup));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('today_action')));
    await tester.pumpAndSettle();
    history.unavailable = true;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(history.loads, 2);
    expect(find.byKey(const Key('today_error')), findsOneWidget);
    expect(find.byKey(const Key('today_action')), findsNothing);
    expect(tester.takeException(), isNull);
    expect(history.writes, 0);
  });

  testWidgets('home retry remains usable at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final history = _History();
    await tester.pumpWidget(_app(history, cleanup));
    await tester.pumpAndSettle();
    final retry = find.text('Yeniden dene');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    expect(retry.hitTestable(), findsOneWidget);
    history.unavailable = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    // Retry changes this lazy list row's height; return to the home header
    // before asserting the recommendation rather than an offscreen child.
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_card')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(history.writes, 0);
  });
}
