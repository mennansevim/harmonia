import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/harmonia_app.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/learning/daily_plan.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/common/ui/harmonia_ui.dart';
import 'package:harmonia/features/onboarding/guest_onboarding_screen.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';

class _Preferences extends InMemoryPracticePreferences {
  int writes = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> saveDailyBudget(DailyBudget budget) async {
    writes++;
    await gate?.future;
    if (fail) throw StateError('private/path');
    await super.saveDailyBudget(budget);
  }
}

void main() {
  Future<void> tap(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    _Preferences prefs,
    Future<bool> Function(PracticeGoal) complete, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: dark ? HarmoniaTheme.dark() : HarmoniaTheme.light(),
        home: GuestOnboardingScreen(preferences: prefs, onComplete: complete),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'goal_conservatory');
  }

  testWidgets(
    'each explicit budget is saved before goal; choosing alone writes nothing',
    (tester) async {
      for (final budget in DailyBudget.values) {
        final prefs = _Preferences();
        var goals = 0;
        await pump(tester, prefs, (goal) async {
          goals++;
          expect(await prefs.loadDailyBudget(), budget);
          return true;
        });
        await tap(tester, 'onboarding_budget_${budget.minutes}');
        expect(prefs.writes, 0);
        expect(goals, 0);
        await tap(tester, 'onboarding_finish');
        expect(prefs.writes, 1);
        expect(goals, 1);
      }
    },
  );

  testWidgets(
    'skip preserves existing preference even after changing the draft',
    (tester) async {
      final prefs = _Preferences();
      await prefs.saveDailyBudget(DailyBudget.fifteen);
      var goals = 0;
      await pump(tester, prefs, (_) async {
        goals++;
        return true;
      });
      await tap(tester, 'onboarding_budget_5');
      await tap(tester, 'onboarding_skip_budget');
      expect(await prefs.loadDailyBudget(), DailyBudget.fifteen);
      expect(prefs.writes, 1);
      expect(goals, 1);
    },
  );

  testWidgets('preference failure is safe and skip can still finish goal', (
    tester,
  ) async {
    final prefs = _Preferences()..fail = true;
    var goals = 0;
    await pump(tester, prefs, (_) async {
      goals++;
      return true;
    });
    await tap(tester, 'onboarding_finish');
    expect(find.textContaining('Süre kaydedilemedi'), findsOneWidget);
    expect(find.textContaining('private/path'), findsNothing);
    expect(goals, 0);
    await tap(tester, 'onboarding_skip_budget');
    expect(goals, 1);
    expect(prefs.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial profile failure keeps saved budget and retry does not resave',
    (tester) async {
      final prefs = _Preferences();
      var succeeds = false, goals = 0;
      await pump(tester, prefs, (_) async {
        goals++;
        return succeeds;
      });
      await tap(tester, 'onboarding_budget_15');
      await tap(tester, 'onboarding_finish');
      expect(
        find.textContaining('Süre tercihin kaydedildi; hedef kaydedilemedi'),
        findsOneWidget,
      );
      succeeds = true;
      await tap(tester, 'onboarding_finish');
      expect(prefs.writes, 1);
      expect(goals, 2);
      expect(await prefs.loadDailyBudget(), DailyBudget.fifteen);
    },
  );

  testWidgets(
    'pending write locks controls, double invoke and disposal cannot save a late profile',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = _Preferences()..gate = Completer<void>();
      var goals = 0;
      await pump(tester, prefs, (_) async {
        goals++;
        return true;
      });
      final finish = tester
          .widget<ChunkyButton>(find.byKey(const Key('onboarding_finish')))
          .onPressed!;
      finish();
      finish();
      await tester.pump();
      expect(prefs.writes, 1);
      expect(
        tester
            .widget<ChunkyButton>(
              find.byKey(const Key('onboarding_skip_budget')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('onboarding_back')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<AnswerOption>(find.byKey(const Key('onboarding_budget_5')))
            .onTap,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      prefs.gate!.complete();
      await tester.pumpAndSettle();
      expect(goals, 0);
      expect(await prefs.loadDailyBudget(), DailyBudget.twelve);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system back preserves draft duration without writing a goal', (
    tester,
  ) async {
    final prefs = _Preferences();
    var goals = 0;
    await pump(tester, prefs, (_) async {
      goals++;
      return true;
    });
    await tap(tester, 'onboarding_budget_5');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    await tap(tester, 'goal_choir');
    expect(
      tester
          .widget<AnswerOption>(find.byKey(const Key('onboarding_budget_5')))
          .state,
      OptionState.selected,
    );
    expect(prefs.writes, 0);
    expect(goals, 0);
  });

  testWidgets('saved onboarding duration reaches the actual daily plan', (
    tester,
  ) async {
    final prefs = _Preferences();
    final history = InMemoryResultHistory();
    final profiles = InMemoryProfileRepository();
    await tester.pumpWidget(
      HarmoniaApp(
        profiles: profiles,
        preferences: prefs,
        history: history,
        startupCleanup: () async => const OrphanCleanupReport(),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'goal_conservatory');
    expect(await profiles.load(), isNull);
    await tap(tester, 'onboarding_budget_5');
    await tap(tester, 'onboarding_finish');
    expect((await profiles.load())!.goal, PracticeGoal.conservatory);
    await tap(tester, 'open_daily_plan');
    expect(
      tester
          .widget<SegmentedButton<DailyBudget>>(
            find.byKey(const Key('plan_budget')),
          )
          .selected,
      {DailyBudget.five},
    );
    expect(await history.load(), isEmpty);
  });

  testWidgets('duration step fits dark reduced-motion 320px large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final prefs = _Preferences();
    await pump(tester, prefs, (_) async => true, dark: true);
    await tap(tester, 'onboarding_budget_15');
    await tap(tester, 'onboarding_finish');
    expect(await prefs.loadDailyBudget(), DailyBudget.fifteen);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'duration choices meet tap label and contrast guidelines in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        for (final dark in [false, true]) {
          await pump(tester, _Preferences(), (_) async => true, dark: dark);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
