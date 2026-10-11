import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/features/history/history_screen.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

class _CorruptHistory extends InMemoryResultHistory {
  @override
  Future<List<ResultHistoryEntry>> load() async =>
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
}

void main() {
  Future<void> pump(WidgetTester tester, ResultHistoryRepository h) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: h)));
    await tester.pumpAndSettle();
  }

  testWidgets('empty history explains what will appear', (tester) async {
    await pump(tester, InMemoryResultHistory());
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
}
