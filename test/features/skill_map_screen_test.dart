import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/learning/measured_exercise.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/exercise_protocol_fingerprint.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/domain/models/score_metric.dart';
import 'package:resonia/features/skill_map/skill_map_screen.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

class _Broken extends InMemoryResultHistory {
  @override
  Future<List<ResultHistoryEntry>> load() async =>
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
}

ExerciseResult _weeklyResult(
  MeasuredExercise exercise,
  DateTime createdAt, {
  bool valid = true,
}) => ExerciseResult(
  sessionId: 'weekly-widget-${createdAt.microsecondsSinceEpoch}',
  exerciseId: exercise.exerciseId,
  skill: exercise.cohort.skill,
  target: const {},
  measurements: {
    'correct': 6,
    ExerciseProtocolFingerprint.measurementKey:
        ?exercise.cohort.protocolFingerprint,
  },
  scores: valid
      ? ExerciseScores(accuracy: ScoreMetric.measured(75))
      : const ExerciseScores(),
  createdAt: createdAt,
  measurementStatus: valid
      ? MeasurementStatus.valid
      : MeasurementStatus.invalid,
  exerciseMode: exercise.cohort.mode,
  difficulty: exercise.cohort.difficulty,
  contentVersion: exercise.contentVersion,
  scoringVersion: exercise.cohort.scoringVersion,
  provenance: MeasurementProvenance(
    source: exercise.cohort.source,
    analyzerVersion: exercise.analyzerVersion,
  ),
);

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

  testWidgets('weekly report compares activity without claiming progress', (
    tester,
  ) async {
    final history = InMemoryResultHistory();
    final exercise = defaultMeasuredCatalog().first;
    for (final (id, result) in [
      ('weekly_current_01', _weeklyResult(exercise, DateTime(2026, 10, 22, 9))),
      (
        'weekly_invalid_1',
        _weeklyResult(exercise, DateTime(2026, 10, 21, 9), valid: false),
      ),
      ('weekly_previous1', _weeklyResult(exercise, DateTime(2026, 10, 15, 9))),
    ]) {
      await history.record(ResultHistoryEntry(attemptId: id, result: result));
    }
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMapScreen(
          goal: PracticeGoal.foundations,
          history: history,
          clock: () => DateTime(2026, 10, 22, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly_practice_report')),
      200,
    );

    expect(find.text('Haftalık çalışma özeti'), findsOneWidget);
    expect(
      find.text('Geçerli tur sayısı önceki 7 günle aynı (1).'),
      findsOneWidget,
    );
    expect(find.textContaining('1 ölçüm tamamlanamadı'), findsOneWidget);
    expect(find.textContaining('beceri artışı'), findsOneWidget);
    expect(find.textContaining('hazır oluş puanı değildir'), findsOneWidget);
  });
}
