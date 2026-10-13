import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/data_export.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/settings/data_transfer_screen.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

void main() {
  String? clipboard;
  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> pump(WidgetTester tester, ResultHistoryRepository h) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataTransferScreen(
          history: h,
          profile: LearnerProfile(
            goal: PracticeGoal.foundations,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
          clock: () => DateTime.utc(2026, 10, 13, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('export copies a valid audio-free document', (tester) async {
    final h = InMemoryResultHistory();
    await h.record(entry('attempt-0001'));
    await pump(tester, h);
    await tester.tap(find.byKey(const Key('export_copy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 sonuç'), findsOneWidget);
    expect(LocalDataExport.decode(clipboard!).entries, hasLength(1));
  });

  testWidgets('import validates, confirms and reports outcomes', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    await h.record(entry('attempt-0001'));
    await pump(tester, h);
    final text = LocalDataExport.encode(
      profile: null,
      entries: [entry('attempt-0001'), entry('attempt-0002')],
      exportedAt: DateTime.utc(2026),
    );
    await tester.enterText(find.byKey(const Key('import_text')), text);
    await tester.tap(find.byKey(const Key('import_apply')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 sonuç bulundu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_import')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('import_status'))).data,
      startsWith('Eklendi: 1. Zaten vardı: 1.'),
    );
    expect(await h.load(), hasLength(2));
  });

  testWidgets('broken paste adds nothing and does not echo text', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    await pump(tester, h);
    await tester.enterText(find.byKey(const Key('import_text')), '{"a": 1}');
    await tester.tap(find.byKey(const Key('import_apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirm_import')), findsNothing);
    expect(find.textContaining('Hiçbir şey eklenmedi'), findsOneWidget);
    expect(await h.load(), isEmpty);
  });

  testWidgets('narrow, large text and guidelines', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final handle = tester.ensureSemantics();
    await pump(tester, InMemoryResultHistory());
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
