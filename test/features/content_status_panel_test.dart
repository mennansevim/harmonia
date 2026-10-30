import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/features/common/content_status_panel.dart';
import 'package:resonia/features/history/history_screen.dart';

class _RecoverableHistory extends InMemoryResultHistory {
  int loads = 0;
  bool fails = true;
  @override
  Future<List<ResultHistoryEntry>> load() async {
    loads++;
    if (fails) {
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
    }
    return super.load();
  }
}

class _PendingHistory extends InMemoryResultHistory {
  final gate = Completer<List<ResultHistoryEntry>>();
  @override
  Future<List<ResultHistoryEntry>> load() => gate.future;
}

void main() {
  testWidgets('loading message has progress and no retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentStatusPanel(
            kind: ContentStatusKind.loading,
            message: 'Yükleniyor…',
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
  });
  testWidgets('empty message never offers a fake result or retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContentStatusPanel(
            kind: ContentStatusKind.empty,
            message: 'Henüz sonuç yok.',
          ),
        ),
      ),
    );
    expect(find.text('Henüz sonuç yok.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
  testWidgets('error retry is explicit user action, never automatic', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentStatusPanel(
            kind: ContentStatusKind.error,
            message: 'Veri korunuyor.',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(retries, 0);
    await tester.tap(find.text('Yeniden dene'));
    expect(retries, 1);
  });
  testWidgets('history corruption retry preserves data and reaches empty', (
    tester,
  ) async {
    final h = _RecoverableHistory();
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: h)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_error')), findsOneWidget);
    expect(find.textContaining('Dosya silinmedi'), findsOneWidget);
    expect(h.loads, 1);
    h.fails = false;
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    expect(h.loads, 2);
    expect(find.byKey(const Key('history_local_notice')), findsOneWidget);
  });
  testWidgets('history pending load never displays stale result', (
    tester,
  ) async {
    final h = _PendingHistory();
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(history: h)));
    await tester.pump();
    expect(find.text('Geçmiş yükleniyor…'), findsOneWidget);
    expect(find.byKey(const Key('history_empty')), findsNothing);
    h.gate.complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });
  testWidgets('narrow large text error meets tap label contrast guidelines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const LocalOnlyNotice(),
                ContentStatusPanel(
                  kind: ContentStatusKind.error,
                  message: 'Geçmiş korunuyor. Yeniden dene.',
                  onRetry: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
