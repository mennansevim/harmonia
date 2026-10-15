import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/harmonia_app.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';

Future<OrphanCleanupReport> _noSweep() async => const OrphanCleanupReport();

Future<void> _pump(WidgetTester tester, {bool dark = false}) async {
  if (dark) {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }
  await tester.pumpWidget(
    HarmoniaApp(
      profiles: InMemoryProfileRepository(
        LearnerProfile(
          goal: PracticeGoal.conservatory,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ),
      history: InMemoryResultHistory(),
      preferences: InMemoryPracticePreferences(),
      startupCleanup: _noSweep,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('tabs meet tap, label and contrast guidelines dark=$dark', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, dark: dark);
      for (final tab in ['tab_today', 'tab_practice', 'tab_profile']) {
        await tester.tap(find.byKey(Key(tab)));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
    });
  }

  testWidgets('today path and tabs fit 320px at 1.8× text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester);
    await tester.scrollUntilVisible(find.text('Ses ve puls'), 300);
    await tester.scrollUntilVisible(find.text('Tek ses eşleme'), 300);
    expect(tester.takeException(), isNull);
    for (final tab in ['tab_practice', 'tab_progress', 'tab_profile']) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('unmeasurable path node explains itself, nothing opens', (
    tester,
  ) async {
    await _pump(tester);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(RegExp('^Tek ses eşleme')),
      300,
    );
    await tester.ensureVisible(
      find.bySemanticsLabel(RegExp('^Tek ses eşleme')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Tek ses eşleme')));
    await tester.pumpAndSettle();
    expect(find.text('Yakında: ses tanıma'), findsWidgets);
    expect(find.textContaining('Ses tanıma gerçek kayıtlarla'), findsOneWidget);
  });

  testWidgets('focus node opens the recommended exercise', (tester) async {
    await _pump(tester);
    final node = find.bySemanticsLabel(RegExp('Bugünkü öneri\$'));
    await tester.scrollUntilVisible(node, 300);
    await tester.ensureVisible(node);
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('perc_level_picker')), findsOneWidget);
  });
}
