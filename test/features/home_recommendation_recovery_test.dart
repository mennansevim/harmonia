import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/app_services.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/features/home/home_screen.dart';
import 'package:resonia/features/home/skill_path.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';

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

Widget _app(
  _History history,
  ValueNotifier<OrphanCleanupReport?> cleanup, {
  bool dark = false,
}) => AppServices(
  history: history,
  cleanup: cleanup,
  child: MaterialApp(
    theme: dark ? ResoniaTheme.dark() : ResoniaTheme.light(),
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
    'pending skeleton is static, announced once and contains no measured actions',
    (tester) async {
      final history = _History()..pending = Completer();
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_app(history, cleanup));
        await tester.pumpAndSettle();
        final loading = find.byKey(const Key('today_loading'));
        expect(loading, findsOneWidget);
        expect(
          tester.getSemantics(loading).label,
          contains('Öneri ve beceri yolu henüz hazır değil'),
        );
        for (final key in [
          'today_card',
          'today_action',
          'open_daily_plan',
          'recent_practice',
        ]) {
          expect(find.byKey(Key(key)), findsNothing);
        }
        expect(find.byType(SkillPath), findsNothing);
        expect(
          find.descendant(
            of: loading,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: loading,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        await tester.pump(const Duration(seconds: 10));
        expect(history.loads, 1);
        expect(history.writes, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
        history.pending!.complete([]);
        await tester.pumpAndSettle();
        expect(loading, findsNothing);
        expect(find.byKey(const Key('today_card')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'refresh hides old path while pending and after failure; explicit retry recovers',
    (tester) async {
      final history = _History()..unavailable = false;
      await tester.pumpWidget(_app(history, cleanup));
      await tester.pumpAndSettle();
      expect(find.byType(SkillPath), findsOneWidget);
      await tester.tap(find.byKey(const Key('today_action')));
      await tester.pumpAndSettle();
      history.pending = Completer();
      await tester.tap(find.byKey(const Key('lesson_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today_loading')), findsOneWidget);
      expect(find.byType(SkillPath), findsNothing);
      expect(find.byKey(const Key('today_card')), findsNothing);
      history.pending!.completeError(StateError('private refresh failure'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today_error')), findsOneWidget);
      expect(find.byType(SkillPath), findsNothing);
      expect(find.textContaining('private refresh'), findsNothing);
      history.pending = null;
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(find.byType(SkillPath), findsOneWidget);
      expect(find.byKey(const Key('today_card')), findsOneWidget);
      expect(history.writes, 0);
    },
  );

  testWidgets(
    'replacement repository hides old loaded path until its own evidence arrives',
    (tester) async {
      final old = _History()..unavailable = false;
      final next = _History()..pending = Completer();
      await tester.pumpWidget(_app(old, cleanup));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(next, cleanup));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today_loading')), findsOneWidget);
      expect(find.byType(SkillPath), findsNothing);
      next.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(SkillPath), findsOneWidget);
      expect(next.loads, 1);
      expect(old.writes + next.writes, 0);
    },
  );

  testWidgets(
    'foreground return refreshes once but system interruption does not',
    (tester) async {
      final history = _History()..unavailable = false;
      await tester.pumpWidget(_app(history, cleanup));
      await tester.pumpAndSettle();
      expect(history.loads, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(history.loads, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(history.loads, 2);
      expect(find.byKey(const Key('today_card')), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(history.loads, 2);
      expect(history.writes, 0);
    },
  );

  testWidgets(
    'foreground refresh hides stale recommendation until evidence arrives',
    (tester) async {
      final history = _History()..unavailable = false;
      await tester.pumpWidget(_app(history, cleanup));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today_card')), findsOneWidget);

      history.pending = Completer();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(history.loads, 2);
      expect(find.byKey(const Key('today_loading')), findsOneWidget);
      expect(find.byKey(const Key('today_card')), findsNothing);
      expect(find.byType(SkillPath), findsNothing);

      history.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('today_loading')), findsNothing);
      expect(find.byKey(const Key('today_card')), findsOneWidget);
      expect(history.writes, 0);
    },
  );

  testWidgets('static skeleton fits large text in both reduced-motion themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    for (final dark in [false, true]) {
      final history = _History()..pending = Completer();
      await tester.pumpWidget(_app(history, cleanup, dark: dark));
      await tester.pumpAndSettle();
      expect(find.text('Bugün hazırlanıyor'), findsOneWidget);
      expect(find.byType(SkillPath), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      history.pending!.completeError(StateError('late disposal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

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
      expect(find.text('Tam ses farkı · ~2 dk'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('lesson_close')));
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
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 1200),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_card')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(history.writes, 0);
  });
}
