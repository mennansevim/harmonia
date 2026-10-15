import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/skill_map/skill_map_screen.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

class _Broken extends InMemoryResultHistory {
  @override
  Future<List<ResultHistoryEntry>> load() async =>
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    PracticeGoal goal, {
    ResultHistoryRepository? history,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMapScreen(goal: goal, history: history),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('conservatory map shows its route, not choir skills', (
    tester,
  ) async {
    await pump(tester, PracticeGoal.conservatory);
    expect(find.textContaining('taslaktır'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_harmonic-voices')),
      300,
    );
    expect(find.byKey(const Key('skill_part-independence')), findsNothing);
    expect(find.text('Henüz ölçülmedi'), findsWidgets);
  });

  testWidgets('choir map shows part independence', (tester) async {
    await pump(tester, PracticeGoal.choir);
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_part-independence')),
      300,
    );
    expect(find.byKey(const Key('skill_harmonic-voices')), findsNothing);
  });

  testWidgets('history moves only measured skills', (tester) async {
    final h = InMemoryResultHistory();
    await h.record(entry('attempt-0001'));
    await pump(tester, PracticeGoal.foundations, history: h);
    // Fixture result uses a version the evaluator does not compare.
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_state_pulse-tap')),
      200,
    );
    final chip = tester.widget<Chip>(
      find.byKey(const Key('skill_state_pulse-tap')),
    );
    expect((chip.label as Text).data, 'Henüz ölçülmedi');
  });

  testWidgets('broken history is explained, not shown as progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, PracticeGoal.foundations, history: _Broken());
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_map_history_error')),
      100,
    );
    expect(find.byKey(const Key('skill_map_history_error')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('report: counts, unknown skills and one focus that opens', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMapScreen(
          goal: PracticeGoal.foundations,
          history: InMemoryResultHistory(),
          clock: () => DateTime(2026, 10, 11, 12),
          exerciseScreen: (e, retention) {
            opened.add(e.exerciseId);
            return const Scaffold(body: Text('egzersiz'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    Text t(String k) => tester.widget<Text>(find.byKey(Key(k)));
    expect(t('report_scope').data, contains('9 becerinin 4 tanesi'));
    expect(t('report_counts').data, contains('Henüz denenmedi: 4'));
    expect(t('report_unknown').data, startsWith('5 beceri'));
    expect(find.textContaining('%'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('report_focus_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report_focus_action')));
    await tester.pumpAndSettle();
    expect(opened, ['draft-perc-highlow-200']);
  });

  testWidgets('without history the report has no action', (tester) async {
    await pump(tester, PracticeGoal.foundations);
    expect(find.byKey(const Key('skill_report')), findsOneWidget);
    expect(find.byKey(const Key('report_focus_action')), findsNothing);
  });
}
