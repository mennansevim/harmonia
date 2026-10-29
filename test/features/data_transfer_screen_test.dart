import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/data_export.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/learning/daily_plan.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/settings/data_transfer_screen.dart';
import 'package:harmonia/features/common/ui/harmonia_ui.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

class _PendingHistory extends InMemoryResultHistory {
  final gate = Completer<List<ResultHistoryEntry>>();
  int loads = 0;
  @override
  Future<List<ResultHistoryEntry>> load() {
    loads++;
    return gate.future;
  }
}

class _FailingBatchHistory extends InMemoryResultHistory {
  @override
  Future<BatchRecordReport> recordAll(Iterable<ResultHistoryEntry> entries) =>
      Future.error(
        const HistoryStorageException(HistoryStorageFailure.unavailable),
      );
}

void main() {
  String? clipboard;
  bool clipboardFails = false;
  setUp(() {
    clipboard = null;
    clipboardFails = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (clipboardFails) {
              throw PlatformException(code: 'private', message: 'secret/path');
            }
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<void> pump(
    WidgetTester tester,
    ResultHistoryRepository h, {
    PracticePreferencesRepository? preferences,
    VoidCallback? onPreferencesImported,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataTransferScreen(
          history: h,
          profile: LearnerProfile(
            goal: PracticeGoal.foundations,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
          clock: () => DateTime.utc(2026, 10, 13, 12),
          preferences: preferences,
          onPreferencesImported: onPreferencesImported,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'local lesson shell never reports learning progress or auto copies',
    (tester) async {
      await pump(tester, InMemoryResultHistory());
      expect(find.byType(LessonScaffold), findsOneWidget);
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(find.text('Yerel'), findsOneWidget);
      expect(find.text('Ses kaydı içermez'), findsOneWidget);
      expect(clipboard, isNull);
    },
  );

  testWidgets('clipboard failure replaces stale success and allows retry', (
    tester,
  ) async {
    await pump(tester, InMemoryResultHistory());
    await tester.tap(find.byKey(const Key('export_copy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 sonuç'), findsOneWidget);
    clipboardFails = true;
    await tester.tap(find.byKey(const Key('export_copy')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Panoya kopyalama doğrulanamadı'),
      findsOneWidget,
    );
    expect(find.textContaining('0 sonuç'), findsNothing);
    expect(find.textContaining('secret/path'), findsNothing);
    expect(tester.takeException(), isNull);
    clipboardFails = false;
    await tester.tap(find.byKey(const Key('export_copy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 sonuç'), findsOneWidget);
  });

  testWidgets('pending export locks both actions and input then recovers', (
    tester,
  ) async {
    final h = _PendingHistory();
    await pump(tester, h);
    final copy = tester
        .widget<ChunkyButton>(find.byKey(const Key('export_copy')))
        .onPressed!;
    copy();
    copy();
    await tester.pump();
    expect(h.loads, 1);
    for (final key in ['export_copy', 'import_apply']) {
      expect(
        tester.widget<ChunkyButton>(find.byKey(Key(key))).onPressed,
        isNull,
      );
    }
    expect(
      tester.widget<TextField>(find.byKey(const Key('import_text'))).enabled,
      isFalse,
    );
    h.gate.completeError(
      const HistoryStorageException(HistoryStorageFailure.unavailable),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Geçmiş okunamadığı'), findsOneWidget);
    expect(
      tester
          .widget<ChunkyButton>(find.byKey(const Key('export_copy')))
          .onPressed,
      isNotNull,
    );
    expect(clipboard, isNull);
  });

  testWidgets('leaving before export load finishes never writes clipboard', (
    tester,
  ) async {
    final h = _PendingHistory();
    await pump(tester, h);
    await tester.tap(find.byKey(const Key('export_copy')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    h.gate.complete([]);
    await tester.pumpAndSettle();
    expect(clipboard, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'confirmation locks operations; cancel preserves input and history',
    (tester) async {
      final h = InMemoryResultHistory();
      await pump(tester, h);
      final text = LocalDataExport.encode(
        profile: null,
        entries: [entry('attempt-0001')],
        exportedAt: DateTime.utc(2026),
      );
      await tester.enterText(find.byKey(const Key('import_text')), text);
      final apply = tester
          .widget<ChunkyButton>(find.byKey(const Key('import_apply')))
          .onPressed!;
      apply();
      apply();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm_import')), findsOneWidget);
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('export_copy')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(await h.load(), isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('import_text')))
            .controller!
            .text,
        text,
      );
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('import_apply')))
            .onPressed,
        isNotNull,
      );
      expect(clipboard, isNull);
    },
  );

  testWidgets('dark reduced-motion transfer can validate at large text', (
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
        theme: HarmoniaTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: DataTransferScreen(
          history: InMemoryResultHistory(),
          profile: null,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('import_text')),
      '{"bad":true}',
    );
    await tester.ensureVisible(find.byKey(const Key('import_apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import_apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('import_status')), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    expect(tester.takeException(), isNull);
    expect(clipboard, isNull);
  });

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

  testWidgets(
    'portable preferences import but reminder and haptics stay local',
    (tester) async {
      final h = InMemoryResultHistory();
      final preferences = InMemoryPracticePreferences();
      var refreshes = 0;
      await preferences.saveReminderTime(
        PracticeReminderTime(hour: 9, minute: 15),
      );
      await preferences.saveHapticsEnabled(false);
      await pump(
        tester,
        h,
        preferences: preferences,
        onPreferencesImported: () => refreshes++,
      );
      final text = LocalDataExport.encode(
        profile: null,
        entries: const [],
        exportedAt: DateTime.utc(2026),
        preferences: const PortablePracticePreferences(
          dailyBudget: DailyBudget.fifteen,
          weeklyGoal: WeeklyPracticeGoal.four,
        ),
      );
      await tester.enterText(find.byKey(const Key('import_text')), text);
      await tester.tap(find.byKey(const Key('import_apply')));
      await tester.pumpAndSettle();
      expect(find.textContaining('bu cihaza özel kalır'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_import')));
      await tester.pumpAndSettle();
      expect(await preferences.loadDailyBudget(), DailyBudget.fifteen);
      expect(await preferences.loadWeeklyGoal(), WeeklyPracticeGoal.four);
      expect(
        await preferences.loadReminderTime(),
        PracticeReminderTime(hour: 9, minute: 15),
      );
      expect(await preferences.loadHapticsEnabled(), isFalse);
      expect(refreshes, 1);
    },
  );

  testWidgets('failed batch import reports that no prefix was added', (
    tester,
  ) async {
    final h = _FailingBatchHistory();
    await pump(tester, h);
    final text = LocalDataExport.encode(
      profile: null,
      entries: [entry('attempt-0001'), entry('attempt-0002')],
      exportedAt: DateTime.utc(2026),
    );
    await tester.enterText(find.byKey(const Key('import_text')), text);
    await tester.tap(find.byKey(const Key('import_apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('hiçbir sonuç eklenmedi'), findsOneWidget);
    expect(await h.load(), isEmpty);
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
