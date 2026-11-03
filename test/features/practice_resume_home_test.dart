import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/app_services.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/learning/measured_exercise.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/exercise_protocol_fingerprint.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/domain/models/score_metric.dart';
import 'package:resonia/features/home/home_screen.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';

ExerciseResult _validResult(MeasuredExercise exercise) => ExerciseResult(
  sessionId: 'resume-home-session',
  exerciseId: exercise.exerciseId,
  skill: exercise.cohort.skill,
  target: const {},
  measurements: {
    'correct': 6,
    ExerciseProtocolFingerprint.measurementKey:
        ?exercise.cohort.protocolFingerprint,
  },
  scores: ExerciseScores(accuracy: ScoreMetric.measured(75)),
  createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
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
  testWidgets('Today opens a fresh round for the latest local exercise', (
    tester,
  ) async {
    final history = InMemoryResultHistory();
    final pitch = defaultMeasuredCatalog()
        .whereType<PitchComparisonMeasuredExercise>()
        .first;
    await history.record(
      ResultHistoryEntry(
        attemptId: 'resume_attempt_01',
        result: _validResult(pitch),
      ),
    );
    final cleanup = ValueNotifier<OrphanCleanupReport?>(null);
    addTearDown(cleanup.dispose);

    await tester.pumpWidget(
      AppServices(
        history: history,
        cleanup: cleanup,
        child: MaterialApp(
          home: HomeScreen(
            profile: LearnerProfile(
              goal: PracticeGoal.foundations,
              createdAt: DateTime(2026, 10, 22),
            ),
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('resume_practice_open')),
      300,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kaldığın sorudan değil'), findsOneWidget);
    expect(find.textContaining('otomatik açılmaz'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resume_practice_open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('perc_progress')), findsOneWidget);
    expect(find.text('Hangisi daha tiz?'), findsOneWidget);
  });

  testWidgets('Today does not invent a return target without history', (
    tester,
  ) async {
    final cleanup = ValueNotifier<OrphanCleanupReport?>(null);
    addTearDown(cleanup.dispose);
    await tester.pumpWidget(
      AppServices(
        history: InMemoryResultHistory(),
        cleanup: cleanup,
        child: MaterialApp(
          home: HomeScreen(
            profile: LearnerProfile(
              goal: PracticeGoal.foundations,
              createdAt: DateTime(2026, 10, 22),
            ),
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('resume_practice_card')), findsNothing);
  });
}
