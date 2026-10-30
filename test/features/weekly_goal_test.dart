import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/resonia_app.dart';
import 'package:resonia/app/app_channel.dart';
import 'package:resonia/app/app_services.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/profile_repository.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/learning/daily_plan.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/features/home/home_screen.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';

class _ControlledPreferences extends InMemoryPracticePreferences {
  final saves = <WeeklyPracticeGoal?>[];
  Completer<void>? pending;
  Object? failure;

  @override
  Future<void> saveWeeklyGoal(WeeklyPracticeGoal? goal) async {
    saves.add(goal);
    if (pending case final wait?) await wait.future;
    if (failure case final error?) throw error;
    await super.saveWeeklyGoal(goal);
  }
}

class _PendingReadsPreferences extends InMemoryPracticePreferences {
  final budget = Completer<DailyBudget?>();
  final goal = Completer<WeeklyPracticeGoal?>();

  @override
  Future<DailyBudget?> loadDailyBudget() => budget.future;

  @override
  Future<WeeklyPracticeGoal?> loadWeeklyGoal() => goal.future;
}

class _RetryableReadPreferences extends InMemoryPracticePreferences {
  int goalReads = 0;

  @override
  Future<DailyBudget?> loadDailyBudget() async => DailyBudget.fifteen;

  @override
  Future<WeeklyPracticeGoal?> loadWeeklyGoal() async {
    goalReads += 1;
    if (goalReads == 1) throw StateError('first read failed');
    return WeeklyPracticeGoal.four;
  }
}

Future<OrphanCleanupReport> _noSweep() async => const OrphanCleanupReport();

Future<void> _pump(
  WidgetTester tester,
  PracticePreferencesRepository preferences,
) async {
  await tester.pumpWidget(
    ResoniaApp(
      profiles: InMemoryProfileRepository(
        LearnerProfile(
          goal: PracticeGoal.foundations,
          createdAt: DateTime.utc(2026, 10, 20),
        ),
      ),
      history: InMemoryResultHistory(),
      preferences: preferences,
      startupCleanup: _noSweep,
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('weekly_goal_3')), 300);
  await tester.ensureVisible(find.byKey(const Key('weekly_goal_3')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preference read failure retries explicitly', (tester) async {
    final oldPreferences = InMemoryPracticePreferences();
    await oldPreferences.saveDailyBudget(DailyBudget.five);
    await oldPreferences.saveWeeklyGoal(WeeklyPracticeGoal.two);
    final newPreferences = _RetryableReadPreferences();
    final current = ValueNotifier<PracticePreferencesRepository>(
      oldPreferences,
    );
    final cleanup = ValueNotifier<OrphanCleanupReport?>(
      const OrphanCleanupReport(),
    );
    addTearDown(current.dispose);
    addTearDown(cleanup.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<PracticePreferencesRepository>(
        valueListenable: current,
        builder: (context, preferences, _) => AppServices(
          history: InMemoryResultHistory(),
          cleanup: cleanup,
          preferences: preferences,
          child: MaterialApp(
            home: HomeScreen(
              profile: LearnerProfile(
                goal: PracticeGoal.foundations,
                createdAt: DateTime.utc(2026, 10, 20),
              ),
              channel: AppChannel.beta,
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    current.value = newPreferences;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('retry_preferences')),
      300,
    );
    await tester.ensureVisible(find.byKey(const Key('retry_preferences')));
    await tester.pumpAndSettle();
    expect(find.text('0/2 gün'), findsNothing);
    expect(find.byKey(const Key('weekly_goal_error')), findsOneWidget);
    expect(newPreferences.goalReads, 1);

    await tester.tap(find.byKey(const Key('retry_preferences')));
    await tester.pumpAndSettle();

    expect(newPreferences.goalReads, 2);
    expect(find.text('0/4 gün'), findsOneWidget);
    expect(find.byKey(const Key('weekly_goal_error')), findsNothing);
    expect(find.byKey(const Key('retry_preferences')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacement read failure keeps the previous store hidden', (
    tester,
  ) async {
    final oldPreferences = InMemoryPracticePreferences();
    await oldPreferences.saveDailyBudget(DailyBudget.five);
    await oldPreferences.saveWeeklyGoal(WeeklyPracticeGoal.two);
    final newPreferences = _PendingReadsPreferences();
    final current = ValueNotifier<PracticePreferencesRepository>(
      oldPreferences,
    );
    final cleanup = ValueNotifier<OrphanCleanupReport?>(
      const OrphanCleanupReport(),
    );
    addTearDown(current.dispose);
    addTearDown(cleanup.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<PracticePreferencesRepository>(
        valueListenable: current,
        builder: (context, preferences, _) => AppServices(
          history: InMemoryResultHistory(),
          cleanup: cleanup,
          preferences: preferences,
          child: MaterialApp(
            home: HomeScreen(
              profile: LearnerProfile(
                goal: PracticeGoal.foundations,
                createdAt: DateTime.utc(2026, 10, 20),
              ),
              channel: AppChannel.beta,
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Günlük çalışma rotası: 5 dakikanın 0 dakikası'),
      findsOneWidget,
    );

    current.value = newPreferences;
    await tester.pump();
    newPreferences.budget.complete(DailyBudget.fifteen);
    newPreferences.goal.completeError(StateError('new store read failed'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Günlük çalışma rotası: 15 dakikanın 0 dakikası'),
      findsOneWidget,
    );
    expect(find.text('0/2 gün'), findsNothing);
    expect(find.text('0/4 gün'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('recent_practice')),
      300,
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Çalışma tercihleri tam yüklenemedi. Güvenli varsayılanlar kullanılıyor.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending replacement store hides preferences from the previous store',
    (tester) async {
      final oldPreferences = InMemoryPracticePreferences();
      await oldPreferences.saveDailyBudget(DailyBudget.five);
      await oldPreferences.saveWeeklyGoal(WeeklyPracticeGoal.two);
      final newPreferences = _PendingReadsPreferences();
      final current = ValueNotifier<PracticePreferencesRepository>(
        oldPreferences,
      );
      final cleanup = ValueNotifier<OrphanCleanupReport?>(
        const OrphanCleanupReport(),
      );
      addTearDown(current.dispose);
      addTearDown(cleanup.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<PracticePreferencesRepository>(
          valueListenable: current,
          builder: (context, preferences, _) => AppServices(
            history: InMemoryResultHistory(),
            cleanup: cleanup,
            preferences: preferences,
            child: MaterialApp(
              home: HomeScreen(
                profile: LearnerProfile(
                  goal: PracticeGoal.foundations,
                  createdAt: DateTime.utc(2026, 10, 20),
                ),
                channel: AppChannel.beta,
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 5 dakikanın 0 dakikası'),
        findsOneWidget,
      );

      current.value = newPreferences;
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 12 dakikanın 0 dakikası'),
        findsOneWidget,
      );
      expect(find.text('0/2 gün'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_none')),
        300,
      );
      expect(find.text('Haftalık hedef yükleniyor…'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('weekly_goal_none')))
            .onSelected,
        isNull,
      );

      newPreferences.budget.complete(DailyBudget.fifteen);
      newPreferences.goal.complete(WeeklyPracticeGoal.four);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 15 dakikanın 0 dakikası'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_4')),
        300,
      );
      expect(find.text('0/4 gün'), findsOneWidget);
      expect(find.text('Haftalık hedef yükleniyor…'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('weekly_goal_none')))
            .onSelected,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending save from replaced preference store cannot publish or fail new UI',
    (tester) async {
      final oldPreferences = _ControlledPreferences();
      await oldPreferences.saveWeeklyGoal(WeeklyPracticeGoal.two);
      oldPreferences
        ..saves.clear()
        ..pending = Completer<void>()
        ..failure = StateError('private old-store failure');
      final newPreferences = InMemoryPracticePreferences();
      await newPreferences.saveWeeklyGoal(WeeklyPracticeGoal.four);
      final current = ValueNotifier<PracticePreferencesRepository>(
        oldPreferences,
      );
      final cleanup = ValueNotifier<OrphanCleanupReport?>(
        const OrphanCleanupReport(),
      );
      addTearDown(current.dispose);
      addTearDown(cleanup.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<PracticePreferencesRepository>(
          valueListenable: current,
          builder: (context, preferences, _) => AppServices(
            history: InMemoryResultHistory(),
            cleanup: cleanup,
            preferences: preferences,
            child: MaterialApp(
              home: HomeScreen(
                profile: LearnerProfile(
                  goal: PracticeGoal.foundations,
                  createdAt: DateTime.utc(2026, 10, 20),
                ),
                channel: AppChannel.beta,
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_3')),
        300,
      );
      await tester.ensureVisible(find.byKey(const Key('weekly_goal_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekly_goal_3')));
      await tester.pump();
      expect(find.text('Haftalık hedef kaydediliyor…'), findsOneWidget);

      current.value = newPreferences;
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_4')),
        300,
      );
      await tester.ensureVisible(find.byKey(const Key('weekly_goal_4')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('weekly_goal_4')))
            .selected,
        isTrue,
      );
      expect(find.text('Haftalık hedef kaydediliyor…'), findsNothing);

      oldPreferences.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('weekly_goal_4')))
            .selected,
        isTrue,
      );
      expect(find.byKey(const Key('weekly_goal_error')), findsNothing);
      expect(find.textContaining('private old-store failure'), findsNothing);
      expect(await newPreferences.loadWeeklyGoal(), WeeklyPracticeGoal.four);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacement preference store wins over late reads from the old store',
    (tester) async {
      final oldPreferences = _PendingReadsPreferences();
      final newPreferences = InMemoryPracticePreferences();
      await newPreferences.saveDailyBudget(DailyBudget.fifteen);
      await newPreferences.saveWeeklyGoal(WeeklyPracticeGoal.four);
      final current = ValueNotifier<PracticePreferencesRepository>(
        oldPreferences,
      );
      final cleanup = ValueNotifier<OrphanCleanupReport?>(
        const OrphanCleanupReport(),
      );
      addTearDown(current.dispose);
      addTearDown(cleanup.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<PracticePreferencesRepository>(
          valueListenable: current,
          builder: (context, preferences, _) => AppServices(
            history: InMemoryResultHistory(),
            cleanup: cleanup,
            preferences: preferences,
            child: MaterialApp(
              home: HomeScreen(
                profile: LearnerProfile(
                  goal: PracticeGoal.foundations,
                  createdAt: DateTime.utc(2026, 10, 20),
                ),
                channel: AppChannel.beta,
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      current.value = newPreferences;
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 15 dakikanın 0 dakikası'),
        findsOneWidget,
      );

      oldPreferences.budget.complete(DailyBudget.five);
      oldPreferences.goal.complete(WeeklyPracticeGoal.two);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 15 dakikanın 0 dakikası'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_4')),
        300,
      );
      expect(find.text('0/4 gün'), findsOneWidget);
      expect(find.text('0/2 gün'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preference revision refreshes today without resetting selected tab',
    (tester) async {
      final preferences = InMemoryPracticePreferences();
      await preferences.saveDailyBudget(DailyBudget.five);
      await preferences.saveWeeklyGoal(WeeklyPracticeGoal.two);
      final revision = ValueNotifier<int>(0);
      final cleanup = ValueNotifier<OrphanCleanupReport?>(
        const OrphanCleanupReport(),
      );
      addTearDown(revision.dispose);
      addTearDown(cleanup.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<int>(
          valueListenable: revision,
          builder: (context, value, _) => AppServices(
            history: InMemoryResultHistory(),
            cleanup: cleanup,
            preferences: preferences,
            preferencesRevision: value,
            child: MaterialApp(
              home: HomeScreen(
                profile: LearnerProfile(
                  goal: PracticeGoal.foundations,
                  createdAt: DateTime.utc(2026, 10, 20),
                ),
                channel: AppChannel.beta,
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 5 dakikanın 0 dakikası'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_2')),
        300,
      );
      expect(find.text('0/2 gün'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab_practice')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await preferences.savePortablePreferences(
        const PortablePracticePreferences(
          dailyBudget: DailyBudget.fifteen,
          weeklyGoal: WeeklyPracticeGoal.four,
        ),
      );
      revision.value++;
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      await tester.tap(find.byKey(const Key('tab_today')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Günlük çalışma rotası: 15 dakikanın 0 dakikası'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly_goal_4')),
        300,
      );
      expect(find.text('0/4 gün'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('voluntary goal can be selected, changed and disabled locally', (
    tester,
  ) async {
    final preferences = InMemoryPracticePreferences();
    await _pump(tester, preferences);

    await tester.tap(find.byKey(const Key('weekly_goal_3')));
    await tester.pumpAndSettle();
    expect(await preferences.loadWeeklyGoal(), WeeklyPracticeGoal.three);
    expect(find.text('0/3 gün'), findsOneWidget);
    expect(
      find.textContaining('beceri puanı veya sınav sonucu değildir'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('weekly_goal_none')));
    await tester.pumpAndSettle();
    expect(await preferences.loadWeeklyGoal(), isNull);
    expect(find.textContaining('zorunlu değildir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending is single-flight; failure preserves previous goal', (
    tester,
  ) async {
    final preferences = _ControlledPreferences();
    await preferences.saveWeeklyGoal(WeeklyPracticeGoal.two);
    preferences
      ..pending = Completer<void>()
      ..failure = StateError('private path');
    await _pump(tester, preferences);

    await tester.tap(find.byKey(const Key('weekly_goal_4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('weekly_goal_5')));
    await tester.pump();
    expect(preferences.saves, [
      WeeklyPracticeGoal.two,
      WeeklyPracticeGoal.four,
    ]);
    expect(find.text('Haftalık hedef kaydediliyor…'), findsOneWidget);

    preferences.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly_goal_error')), findsOneWidget);
    expect(find.textContaining('Önceki seçimin korundu'), findsOneWidget);
    expect(await preferences.loadWeeklyGoal(), WeeklyPracticeGoal.two);
    expect(find.text('0/2 gün'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
