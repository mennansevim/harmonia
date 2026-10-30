import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/app_channel.dart';
import 'package:resonia/app/resonia_app.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/profile_repository.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';

Future<OrphanCleanupReport> _noSweep() async => const OrphanCleanupReport();

Future<void> _pump(WidgetTester tester, AppChannel channel) async {
  // Tall view so the lazy home list builds every tile.
  tester.view.physicalSize = const Size(800, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ResoniaApp(
      profiles: InMemoryProfileRepository(
        LearnerProfile(
          goal: PracticeGoal.foundations,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ),
      history: InMemoryResultHistory(),
      preferences: InMemoryPracticePreferences(),
      startupCleanup: _noSweep,
      channel: channel,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('parse is strict; default build is dev', () {
    expect(AppChannel.parse('beta'), AppChannel.beta);
    expect(AppChannel.parse('dev'), AppChannel.dev);
    expect(() => AppChannel.parse('prod'), throwsArgumentError);
    expect(AppChannel.current, AppChannel.dev);
  });

  testWidgets('beta hides lab, simulations and placeholders', (tester) async {
    await _pump(tester, AppChannel.beta);
    await tester.tap(find.byKey(const Key('tab_practice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_pitch_comparison')), findsOneWidget);
    for (final k in [
      'open_audio_lab',
      'open_single_tone',
      'open_chord_placeholders',
    ]) {
      expect(find.byKey(Key(k), skipOffstage: false), findsNothing);
    }
    expect(find.text('Simülasyon', skipOffstage: false), findsNothing);
    expect(
      find.byKey(const Key('open_daily_plan'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('tab_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('about_channel')),
      200,
    );
    expect(find.textContaining('beta sürümüdür'), findsOneWidget);
  });

  testWidgets('dev keeps developer tools', (tester) async {
    await _pump(tester, AppChannel.dev);
    await tester.tap(find.byKey(const Key('tab_practice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_audio_lab')), findsOneWidget);
    expect(
      find.byKey(const Key('open_single_tone'), skipOffstage: false),
      findsOneWidget,
    );
  });
}
