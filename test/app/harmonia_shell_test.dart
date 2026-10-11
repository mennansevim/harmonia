import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/harmonia_app.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';

import '../application/app_shell_controller_test.dart'
    show FlakyProfileRepository;

void _narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 1.8;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('guest onboarding → home with honest module statuses', (
    tester,
  ) async {
    final repo = InMemoryProfileRepository();
    await tester.pumpWidget(
      HarmoniaApp(
        profiles: repo,
        history: InMemoryResultHistory(),
        startupCleanup: _noSweep,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    expect(find.textContaining('Hesap açman gerekmez'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal_conservatory')));
    await tester.pumpAndSettle();
    expect(find.text('Konservatuvar hazırlığı'), findsOneWidget);
    expect(find.text('Bugünkü öneri'), findsOneWidget);
    expect(find.textContaining('Ritimle başla'), findsOneWidget);
    expect(find.textContaining('Taslak ölçüt'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tek ses: dinle ve söyle'), 200);
    expect(find.text('Ses ve ortam kontrolü'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kayıt bekleniyor'), 200);
    expect(find.text('Simülasyon'), findsOneWidget);
    expect(find.text('Kayıt bekleniyor'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Günlük çalışma rotası'), 200);
    expect(find.text('Henüz yok'), findsWidgets);
    expect(find.text('Doğru!'), findsNothing);
    expect((await repo.load())!.goal, PracticeGoal.conservatory);
  });

  testWidgets('today card follows history and opens the suggested pattern', (
    tester,
  ) async {
    final history = InMemoryResultHistory();
    final first = draftRhythmPatterns.first;
    for (final (i, start) in [(1, 0), (2, 60000)]) {
      final outcome = await RhythmImitationEvaluator.evaluate(
        protocol: first.exercise.protocol,
        tapTimestamps: [
          for (final ms in [0, 750, 1500, 2250])
            Duration(milliseconds: start + ms),
        ],
      );
      await history.record(
        ResultHistoryEntry(
          attemptId: 'attempt-000$i',
          result: outcome.toResult(
            exercise: first.exercise,
            sessionId: 's$i',
            createdAt: DateTime.now().toUtc(),
          ),
        ),
      );
    }
    await tester.pumpWidget(
      HarmoniaApp(
        startupCleanup: _noSweep,
        history: history,
        profiles: InMemoryProfileRepository(
          LearnerProfile(
            goal: PracticeGoal.foundations,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Yeni desen: Sekizlik çifti'), findsOneWidget);
    await tester.tap(find.byKey(const Key('today_action')));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.byKey(
        Key('rhythm_pattern_${draftRhythmPatterns[1].exercise.exercise.id}'),
      ),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('home opens the goal-filtered skill map', (tester) async {
    await tester.pumpWidget(
      HarmoniaApp(
        startupCleanup: _noSweep,
        history: InMemoryResultHistory(),
        profiles: InMemoryProfileRepository(
          LearnerProfile(
            goal: PracticeGoal.choir,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_skill_map')));
    await tester.pumpAndSettle();
    expect(find.text('Beceri haritası'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_part-independence')),
      300,
    );
  });

  testWidgets('home opens local history through app services', (tester) async {
    await tester.pumpWidget(
      HarmoniaApp(
        startupCleanup: _noSweep,
        profiles: InMemoryProfileRepository(
          LearnerProfile(
            goal: PracticeGoal.conservatory,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
        ),
        history: InMemoryResultHistory(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  for (final (report, visible) in [
    (const OrphanCleanupReport(removedDirectories: 2), false),
    (const OrphanCleanupReport(failures: 1), true),
  ]) {
    testWidgets('startup cleanup warning visible=$visible in settings', (
      tester,
    ) async {
      var swept = 0;
      await tester.pumpWidget(
        HarmoniaApp(
          profiles: InMemoryProfileRepository(
            LearnerProfile(
              goal: PracticeGoal.conservatory,
              createdAt: DateTime.utc(2026, 10, 1),
            ),
          ),
          history: InMemoryResultHistory(),
          startupCleanup: () async {
            swept++;
            return report;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(swept, 1);
      await tester.tap(find.byKey(const Key('open_settings')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('open_history_settings')),
        200,
      );
      expect(
        find.byKey(const Key('cleanup_warning')),
        visible ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('returning user lands on home; demo opens labelled', (
    tester,
  ) async {
    await tester.pumpWidget(
      HarmoniaApp(
        startupCleanup: _noSweep,
        history: InMemoryResultHistory(),
        profiles: InMemoryProfileRepository(
          LearnerProfile(
            goal: PracticeGoal.foundations,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Temel duyma ve ses'), findsOneWidget);
    await _tapVisible(tester, find.text('Tek ses sonuç örnekleri'));
    expect(find.text('Mikrofon girişi henüz simüle ediliyor'), findsOneWidget);
  });

  testWidgets('settings: no purchase, change goal, delete with confirm', (
    tester,
  ) async {
    final repo = InMemoryProfileRepository(
      LearnerProfile(
        goal: PracticeGoal.conservatory,
        createdAt: DateTime.utc(2026, 10, 1),
      ),
    );
    await tester.pumpWidget(
      HarmoniaApp(
        profiles: repo,
        history: InMemoryResultHistory(),
        startupCleanup: _noSweep,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('subscription_status')),
      200,
    );
    expect(find.textContaining('satın alma veya abonelik yok'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('change_goal')), -200);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change_goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_choir')));
    await tester.pumpAndSettle();
    expect(find.text('Koro hazırlığı'), findsOneWidget);
    expect((await repo.load())!.goal, PracticeGoal.choir);

    await _tapVisible(tester, find.byKey(const Key('delete_profile')));
    expect(find.textContaining('geri alınamaz'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(await repo.load(), isNotNull);
    await _tapVisible(tester, find.byKey(const Key('delete_profile')));
    await tester.tap(find.byKey(const Key('confirm_delete_profile')));
    await tester.pumpAndSettle();
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    expect(await repo.load(), isNull);
  });

  testWidgets('corrupt profile shows retry and explicit start-over', (
    tester,
  ) async {
    final repo = FlakyProfileRepository()
      ..loadFailure = ProfileStorageFailure.corrupt;
    await tester.pumpWidget(
      HarmoniaApp(
        profiles: repo,
        history: InMemoryResultHistory(),
        startupCleanup: _noSweep,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('profili okunamadı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup_error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('startup_start_over')));
    await tester.pumpAndSettle();
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
  });

  testWidgets('onboarding, home and settings fit 320px at 1.8× text', (
    tester,
  ) async {
    _narrow(tester);
    await tester.pumpWidget(
      HarmoniaApp(
        profiles: InMemoryProfileRepository(),
        history: InMemoryResultHistory(),
        startupCleanup: _noSweep,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _tapVisible(tester, find.byKey(const Key('goal_choir')));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Günlük çalışma rotası'), 200);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hakkında'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark theme renders the shell', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      HarmoniaApp(
        profiles: InMemoryProfileRepository(),
        history: InMemoryResultHistory(),
        startupCleanup: _noSweep,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Ne için çalışıyorsun?'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(context.resultColors, HarmoniaResultColors.dark);
    expect(tester.takeException(), isNull);
  });

  test('result tokens never reuse success for octave or error for invalid', () {
    for (final c in [HarmoniaResultColors.light, HarmoniaResultColors.dark]) {
      expect(c.wrongOctave, isNot(c.correct));
      expect(c.notMeasured, isNot(c.incorrect));
      expect(c.notMeasured, isNot(c.correct));
    }
  });

  test('light result tokens meet 4.5:1 text contrast on white', () {
    double lum(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final l1 = lum(a), l2 = lum(b);
      return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) /
          (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
    }

    const l = HarmoniaResultColors.light;
    const d = HarmoniaResultColors.dark;
    for (final c in [
      l.correct,
      l.nearMiss,
      l.incorrect,
      l.wrongOctave,
      l.notMeasured,
    ]) {
      expect(contrast(c, const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5));
    }
    for (final c in [
      d.correct,
      d.nearMiss,
      d.incorrect,
      d.wrongOctave,
      d.notMeasured,
    ]) {
      expect(contrast(c, const Color(0xFF121212)), greaterThanOrEqualTo(4.5));
    }
  });
}

Future<OrphanCleanupReport> _noSweep() async => const OrphanCleanupReport();
