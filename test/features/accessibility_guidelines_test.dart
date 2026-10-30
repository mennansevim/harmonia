import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/resonia_app.dart';
import 'package:resonia/application/profile_repository.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/features/audio_lab/audio_lab_screen.dart';
import 'package:resonia/features/history/history_screen.dart';
import 'package:resonia/features/interval/interval_screen.dart';
import 'package:resonia/features/pitch_comparison/pitch_comparison_screen.dart';
import 'package:resonia/features/rhythm_imitation/rhythm_imitation_screen.dart';
import 'package:resonia/features/single_tone_session/single_tone_session_screen.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_clip_player.dart';
import '../support/fake_recording_pitch_worker.dart';

Future<void> _guidelines(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

Widget _app({LearnerProfile? profile}) => ResoniaApp(
  profiles: InMemoryProfileRepository(profile),
  history: InMemoryResultHistory(),
  startupCleanup: () async => const OrphanCleanupReport(),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('onboarding meets a11y guidelines (${brightness.name})', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _guidelines(tester);
    });

    testWidgets('home meets a11y guidelines (${brightness.name})', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        _app(
          profile: LearnerProfile(
            goal: PracticeGoal.conservatory,
            createdAt: DateTime.utc(2026, 10, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _guidelines(tester);
    });
  }

  testWidgets('session, rhythm, lab and history meet a11y guidelines', (
    tester,
  ) async {
    for (final screen in <Widget>[
      SingleToneSessionScreen(
        backend: FakeRoutedAudioLabBackend(),
        worker: FakeRecordingPitchWorker(),
      ),
      RhythmImitationScreen(player: FakeClipPlayer()),
      AudioLabScreen(
        backend: FakeAudioLabBackend(),
        worker: FakeRecordingPitchWorker(),
      ),
      HistoryScreen(history: InMemoryResultHistory()),
      PitchComparisonScreen(player: FakeClipPlayer()),
      IntervalScreen(player: FakeClipPlayer()),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      await _guidelines(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
