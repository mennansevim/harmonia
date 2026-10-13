import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/learning/daily_plan.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/perception/pitch_comparison.dart';
import 'package:harmonia/features/daily_plan/daily_plan_screen.dart';

final _now = DateTime(2026, 10, 11, 12);
var _attempt = 0;

ExerciseResult _perc(int level, DateTime at, {bool retention = false}) {
  final round = PitchComparisonRound.generate(
    draftPitchLevels[level],
    Random(at.millisecondsSinceEpoch),
  );
  return PitchComparisonOutcome(
    round: round,
    answers: [for (final i in round.items) i.correct],
    plays: List.filled(8, 1),
  ).toResult(sessionId: 's', createdAt: at, retentionCheck: retention);
}

Future<void> _add(ResultHistoryRepository h, ExerciseResult r) => h.record(
  ResultHistoryEntry(attemptId: 'attempt-${_attempt++}-x', result: r),
);

class _Broken extends InMemoryResultHistory {
  @override
  Future<List<ResultHistoryEntry>> load() async =>
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
}

void main() {
  final opened = <(String, bool)>[];

  Future<void> pump(
    WidgetTester tester,
    ResultHistoryRepository history, {
    List<ExerciseResult> Function()? onExercise,
  }) async {
    opened.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(
          goal: PracticeGoal.foundations,
          history: history,
          clock: () => _now,
          exerciseScreen: (e, retention) {
            opened.add((e.exerciseId, retention));
            return Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  key: const Key('fake_finish'),
                  onPressed: () async {
                    for (final r in onExercise?.call() ?? const []) {
                      await _add(history, r);
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('bitir'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('budget switch replans; free time is stated, not padded', (
    tester,
  ) async {
    await pump(tester, InMemoryResultHistory());
    expect(find.text('Plan: 8 / 12 dk'), findsOneWidget);
    expect(find.byKey(const Key('plan_block_1')), findsOneWidget);
    expect(find.byKey(const Key('plan_free')), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget_5')));
    await tester.pumpAndSettle();
    expect(find.text('Plan: 4 / 5 dk'), findsOneWidget);
    expect(find.byKey(const Key('plan_block_1')), findsNothing);
    expect(find.textContaining('eğitimci onayı'), findsOneWidget);
  });

  testWidgets('finishing a round updates progress on return', (tester) async {
    final h = InMemoryResultHistory();
    await pump(
      tester,
      h,
      onExercise: () => [_perc(0, _now.subtract(const Duration(minutes: 5)))],
    );
    Text progress() =>
        tester.widget<Text>(find.byKey(const Key('plan_progress_0')));
    expect(progress().data, 'Bugün: 0 / 2 geçerli tur.');
    await tester.tap(find.byKey(const Key('plan_start_0')));
    await tester.pumpAndSettle();
    expect(opened.single, ('draft-perc-highlow-200', false));
    await tester.tap(find.byKey(const Key('fake_finish')));
    await tester.pumpAndSettle();
    expect(progress().data, 'Bugün: 1 / 2 geçerli tur.');
    // Same plan for the rest of the day.
    expect(find.text('Plan: 8 / 12 dk'), findsOneWidget);
  });

  testWidgets('due check opens as a retention check and completes', (
    tester,
  ) async {
    final h = InMemoryResultHistory();
    final yesterday = _now.subtract(const Duration(days: 1));
    await _add(h, _perc(0, yesterday));
    await _add(h, _perc(0, yesterday.add(const Duration(minutes: 1))));
    await pump(
      tester,
      h,
      onExercise: () => [
        _perc(0, _now.subtract(const Duration(minutes: 1)), retention: true),
      ],
    );
    expect(find.textContaining('Kalıcılık kontrolü'), findsOneWidget);
    expect(find.textContaining('1 günlük tekrar aralığı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan_start_0')));
    await tester.pumpAndSettle();
    expect(opened.single, ('draft-perc-highlow-200', true));
    await tester.tap(find.byKey(const Key('fake_finish')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bugün tamamlandı'), findsOneWidget);
    expect(find.text('Bir tur daha'), findsOneWidget);
  });

  testWidgets('broken history is explained, not planned around', (
    tester,
  ) async {
    await pump(tester, _Broken());
    expect(find.byKey(const Key('plan_error')), findsOneWidget);
    expect(find.byKey(const Key('plan_block_0')), findsNothing);
  });

  testWidgets('route without measurable content says so', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DailyPlanScreen(
          goal: PracticeGoal.foundations,
          history: InMemoryResultHistory(),
          catalog: const [],
          clock: () => _now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan_no_content')), findsOneWidget);
  });

  testWidgets('narrow, large text and accessibility guidelines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final handle = tester.ensureSemantics();
    await pump(tester, InMemoryResultHistory());
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('plan_free')), 200);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('chosen budget is remembered on this device', (tester) async {
    final prefs = InMemoryPracticePreferences();
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: DailyPlanScreen(
            goal: PracticeGoal.foundations,
            history: InMemoryResultHistory(),
            preferences: prefs,
            clock: () => _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Plan: 8 / 12 dk'), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget_5')));
    await tester.pumpAndSettle();
    expect(await prefs.loadDailyBudget(), DailyBudget.five);
    await open();
    expect(find.text('Plan: 4 / 5 dk'), findsOneWidget);
  });
}
