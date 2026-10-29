import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_services.dart';
import '../../application/practice_reminder.dart';
import '../../application/result_history.dart';
import '../../infrastructure/audio/orphan_audio_cleaner.dart';
import '../../infrastructure/notifications/flutter_practice_reminder_platform.dart';
import '../../infrastructure/storage/file_practice_preferences.dart';
import '../../infrastructure/storage/file_result_history.dart';
import '../audio/trainer_audio.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';
import 'scope.dart';

/// Ear-trainer app root: loading → onboarding → tabbed home.
class TrainerApp extends StatefulWidget {
  const TrainerApp({
    super.key,
    this.store,
    this.audio,
    this.reminders,
    this.history,
    this.liveAudio = true,
    this.startupCleanup,
  });

  final TrainerStore? store;
  final TrainerAudio? audio;
  final PracticeReminderCoordinator? reminders;
  final ResultHistoryRepository? history;
  final bool liveAudio;
  final Future<void> Function()? startupCleanup;

  @override
  State<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends State<TrainerApp> {
  late final TrainerStore _store =
      widget.store ?? TrainerStore(FileTrainerPersistence());
  late final TrainerAudio _audio = widget.audio ?? TrainerAudio();
  late final ResultHistoryRepository _history =
      widget.history ?? FileResultHistory();
  late final PracticeReminderCoordinator _reminders =
      widget.reminders ??
      PracticeReminderCoordinator(
        preferences: FilePracticePreferences(),
        platform: FlutterPracticeReminderPlatform(),
      );
  final _navigator = GlobalKey<NavigatorState>();
  final _cleanup = ValueNotifier<OrphanCleanupReport?>(null);

  @override
  void initState() {
    super.initState();
    if (!_store.loaded) {
      _store.load().then((_) => _audio.timbre = _store.timbre);
    } else {
      _audio.timbre = _store.timbre;
    }
    final sweep =
        widget.startupCleanup ??
        () async => _cleanup.value = await OrphanAudioCleaner(
          getTemporaryDirectory,
        ).run();
    sweep().catchError((Object _) {});
  }

  @override
  void dispose() {
    _audio.dispose();
    _cleanup.dispose();
    super.dispose();
  }

  void _onboardingFinished(bool begin) {
    if (!begin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigator.currentState;
      if (nav != null) startTodaySession(_store, nav);
    });
  }

  @override
  Widget build(BuildContext context) => TrainerScope(
    store: _store,
    audio: _audio,
    reminders: _reminders,
    history: _history,
    liveAudio: widget.liveAudio,
    child: AppServices(
      history: _history,
      cleanup: _cleanup,
      child: MaterialApp(
        title: 'Harmonia',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigator,
        theme: trainerTheme(),
        themeMode: ThemeMode.light,
        home: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            if (!_store.loaded) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: TrainerBadge(
                    color: TC.orange,
                    icon: Icons.music_note_rounded,
                    size: 84,
                  ),
                ),
              );
            }
            if (!_store.onboardingDone) {
              return OnboardingFlow(onFinished: _onboardingFinished);
            }
            return const HomeShell();
          },
        ),
      ),
    ),
  );
}
