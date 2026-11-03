import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/learning/measured_exercise.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/exercise_protocol_fingerprint.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/domain/models/score_metric.dart';
import 'package:resonia/features/onboarding/starting_check_screen.dart';

class _BrokenHistory extends InMemoryResultHistory {
  @override
  Future<List<ResultHistoryEntry>> load() async =>
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
}

class _CountingHistory extends InMemoryResultHistory {
  int loads = 0;

  @override
  Future<List<ResultHistoryEntry>> load() {
    loads++;
    return super.load();
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

ExerciseResult _clean(MeasuredExercise exercise) => ExerciseResult(
  sessionId: 'starting-screen',
  exerciseId: exercise.exerciseId,
  skill: exercise.cohort.skill,
  target: const {},
  measurements: {
    ExerciseProtocolFingerprint.measurementKey:
        ?exercise.cohort.protocolFingerprint,
    'correct': 8,
    'missed': 0,
    'extra': 0,
    'late': 0,
    'early': 0,
    'meanAbsoluteOffsetMs': 10,
  },
  scores: ExerciseScores(accuracy: ScoreMetric.measured(100)),
  createdAt: DateTime(2026, 10, 22),
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
  testWidgets(
    'starts no audio, launches first check and reloads local result',
    (tester) async {
      final history = InMemoryResultHistory();
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StartingCheckScreen(
            goal: PracticeGoal.foundations,
            history: history,
            launcher: (exercise) => Scaffold(
              body: TextButton(
                key: const Key('finish_fake_check'),
                onPressed: () async {
                  opened.add(exercise.exerciseId);
                  await history.record(
                    ResultHistoryEntry(
                      attemptId: 'startcheck-0001',
                      result: _clean(exercise),
                    ),
                  );
                  if (tester.element(find.byKey(const Key('finish_fake_check')))
                      case final context) {
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                child: const Text('Bitir'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Konservatuvar seviyesi'), findsOneWidget);
      expect(
        find.text(
          '0/3 geçerli tur · 5 beceri henüz bu uygulamada ölçülemiyor.',
        ),
        findsOneWidget,
      );
      expect(opened, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const Key('starting_check_next')),
        200,
      );
      await tester.tap(find.byKey(const Key('starting_check_next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finish_fake_check')));
      await tester.pumpAndSettle();

      expect(opened, ['draft-perc-highlow-200']);
      await tester.scrollUntilVisible(
        find.byKey(const Key('starting_check_progress')),
        200,
      );
      expect(find.textContaining('1/3 geçerli tur'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('starting_check_next')),
        200,
      );
      expect(find.textContaining('Sıradaki:'), findsOneWidget);
    },
  );

  testWidgets('history failure is explicit and retryable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartingCheckScreen(
          goal: PracticeGoal.foundations,
          history: _BrokenHistory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Verilerin silinmedi'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.byKey(const Key('starting_check_next')), findsNothing);
  });

  testWidgets(
    'foreground return reloads once without restoring or opening a round',
    (tester) async {
      final history = _CountingHistory();
      await tester.pumpWidget(
        MaterialApp(
          home: StartingCheckScreen(
            goal: PracticeGoal.foundations,
            history: history,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(history.loads, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(history.loads, 1);

      final exercise = defaultMeasuredCatalog().first;
      await history.record(
        ResultHistoryEntry(
          attemptId: 'starting-foreground-1',
          result: _clean(exercise),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(history.loads, 2);
      expect(find.textContaining('1/3 geçerli tur'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(history.loads, 2);
    },
  );

  testWidgets('replacement history hides stale starting-check projection', (
    tester,
  ) async {
    final old = InMemoryResultHistory();
    final exercise = defaultMeasuredCatalog().first;
    await old.record(
      ResultHistoryEntry(attemptId: 'starting-old-1', result: _clean(exercise)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StartingCheckScreen(goal: PracticeGoal.foundations, history: old),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1/3 geçerli tur'), findsOneWidget);

    final next = _PendingHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: StartingCheckScreen(
          goal: PracticeGoal.foundations,
          history: next,
        ),
      ),
    );
    await tester.pump();

    expect(next.loads, 1);
    expect(find.textContaining('1/3 geçerli tur'), findsNothing);
    expect(find.text('Yerel sonuçların okunuyor.'), findsOneWidget);
    next.pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('0/3 geçerli tur'), findsOneWidget);
  });

  testWidgets('narrow large text remains usable without a level claim', (
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
        home: StartingCheckScreen(
          goal: PracticeGoal.conservatory,
          history: InMemoryResultHistory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('starting_check_progress')),
      200,
    );
    expect(find.textContaining('8 beceri henüz'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('starting_check_next')),
      200,
    );
    expect(tester.takeException(), isNull);
  });
}
