import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/features/history/history_screen.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

class _CorruptHistory extends InMemoryResultHistory {
  int loads = 0;
  @override
  Future<List<ResultHistoryEntry>> load() async {
    loads++;
    throw const HistoryStorageException(HistoryStorageFailure.corrupt);
  }
}

class _PendingHistory extends InMemoryResultHistory {
  final pending = Completer<List<ResultHistoryEntry>>();
  int loads = 0;

  @override
  Future<List<ResultHistoryEntry>> load() {
    loads++;
    return pending.future;
  }
}

ResultHistoryEntry changed(String id, Map<String, Object?> changes) =>
    ResultHistoryEntry(
      attemptId: id,
      result: ExerciseResult.fromJson(
        entry(id).result.toJson()..addAll(changes),
      ),
    );

void main() {
  Future<void> pump(WidgetTester tester, ResultHistoryRepository h) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: h)));
    await tester.pumpAndSettle();
  }

  testWidgets('empty history explains what will appear', (tester) async {
    await pump(tester, InMemoryResultHistory());
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  testWidgets('foreground return reloads local history without a write', (
    tester,
  ) async {
    final history = InMemoryResultHistory();
    await pump(tester, history);
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    await history.record(entry('attempt-foreground'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_empty')), findsNothing);
    expect(find.byKey(const Key('delete_attempt-foreground')), findsOneWidget);
  });

  testWidgets('replacement repository cannot leave old attempts visible', (
    tester,
  ) async {
    final old = InMemoryResultHistory();
    await old.record(entry('attempt-old'));
    final next = _PendingHistory();
    await pump(tester, old);
    expect(find.byKey(const Key('delete_attempt-old')), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: next)));
    await tester.pump();

    expect(next.loads, 1);
    expect(find.byKey(const Key('delete_attempt-old')), findsNothing);
    expect(find.text('Geçmiş yükleniyor…'), findsOneWidget);
    next.pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  testWidgets('fewer than three valid attempts: progress unknown', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    await h.record(entry('attempt-0001'));
    await h.record(entry('attempt-0002'));
    await pump(tester, h);
    expect(find.textContaining('gelişim bilinmiyor'), findsOneWidget);
    expect(find.textContaining('Kaynak: dokunma'), findsNWidgets(2));
  });

  testWidgets('three valid attempts show a cohort trend; delete and clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = InMemoryResultHistory();
    for (final id in ['attempt-0001', 'attempt-0002', 'attempt-0003']) {
      await h.record(entry(id));
    }
    await pump(tester, h);
    expect(find.textContaining('eksik+fazla vuruş 0 → 0 → 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete_attempt-0001')),
      150,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_attempt-0001')));
    await tester.pumpAndSettle();
    expect((await h.load()).length, 2);
    await tester.tap(find.byKey(const Key('clear_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect((await h.load()).length, 2);
    await tester.tap(find.byKey(const Key('clear_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_clear_history')));
    await tester.pumpAndSettle();
    expect(await h.load(), isEmpty);
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('corrupt history explains the file was kept', (tester) async {
    await pump(tester, _CorruptHistory());
    expect(find.textContaining('Dosya silinmedi'), findsOneWidget);
  });

  testWidgets('pitch evidence is never presented as zero rhythm errors', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    for (var i = 0; i < 3; i++) {
      await h.record(
        changed('attempt-000$i', {
          'skill': 'pitch',
          'measurements': <String, Object?>{'centsDifference': 10},
        }),
      );
    }
    await pump(tester, h);
    expect(
      find.textContaining('sayısal gelişim henüz gösterilmiyor'),
      findsOneWidget,
    );
    expect(find.textContaining('eksik+fazla vuruş'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing or malformed evidence stays unknown without fake zeros',
    (tester) async {
      for (final measurements in <Map<String, Object?>>[
        {},
        {'matched': 1, 'missed': '0', 'extra': 0},
        {'matched': 1, 'missed': -1, 'extra': 0},
        {'dimension': 'perception', 'correct': 2},
        {'dimension': 'perception', 'correct': 3, 'total': 2},
      ]) {
        final h = InMemoryResultHistory();
        for (var i = 0; i < 3; i++) {
          await h.record(
            changed('attempt-000$i', {'measurements': measurements}),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            home: HistoryScreen(history: h),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('ölçüm alanları eksik; gelişim bilinmiyor'),
          findsOneWidget,
        );
        expect(find.textContaining('eksik+fazla vuruş'), findsNothing);
        expect(find.textContaining('null'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('same exercise id with different skills cannot form one cohort', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    await h.record(entry('attempt-0001'));
    await h.record(entry('attempt-0002'));
    await h.record(changed('attempt-0003', {'skill': 'pitch'}));
    await pump(tester, h);
    expect(find.textContaining('gelişim bilinmiyor'), findsNWidgets(2));
    expect(find.textContaining('eksik+fazla vuruş'), findsNothing);
  });

  testWidgets(
    'immediate repeat load failures need explicit retry and stay safe',
    (tester) async {
      final h = _CorruptHistory();
      await pump(tester, h);
      expect(h.loads, 1);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Yeniden dene'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('history_error')), findsOneWidget);
        expect(h.loads, i + 2);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('dark large-text help and return preserve local history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final h = InMemoryResultHistory();
    await h.record(entry('attempt-0001'));
    await tester.pumpWidget(
      MaterialApp(
        theme: HarmoniaTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HistoryScreen(history: h),
                ),
              ),
              child: const Text('Geçmişi aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Geçmişi aç'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('history_help')), 140);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Karşılaştırma nasıl yapılır?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ölçülemeyen değer sıfır hata'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear_history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('history_back')), 160);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_back')));
    await tester.pumpAndSettle();
    expect(find.text('Geçmişi aç'), findsOneWidget);
    expect((await h.load()).single.attemptId, 'attempt-0001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('trend follows result time without rewriting insertion order', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    for (final day in [3, 1, 2]) {
      await h.record(
        changed('attempt-000$day', {
          'createdAt': DateTime.utc(2026, 10, day).toIso8601String(),
          'measurements': <String, Object?>{
            'matched': day,
            'missed': 3 - day,
            'extra': 0,
          },
        }),
      );
    }
    await pump(tester, h);
    expect(find.textContaining('eksik+fazla vuruş 2 → 1 → 0'), findsOneWidget);
    expect((await h.load()).map((e) => e.attemptId), [
      'attempt-0003',
      'attempt-0001',
      'attempt-0002',
    ]);
  });
}
