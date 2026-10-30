import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_services.dart';
import '../../application/practice_reminder.dart';
import '../../application/result_history.dart';
import '../../choir/app/choir_scope.dart';
import '../../choir/data/choir_store.dart';
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
    this.choir,
  });

  final TrainerStore? store;
  final TrainerAudio? audio;
  final PracticeReminderCoordinator? reminders;
  final ResultHistoryRepository? history;
  final bool liveAudio;
  final Future<void> Function()? startupCleanup;
  final ChoirStore? choir;

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
  // A test that injects its own trainer store gets a throwaway choir store.
  late final ChoirStore _choir =
      widget.choir ??
      ChoirStore(
        persistence: widget.store == null
            ? FileChoirPersistence()
            : MemoryChoirPersistence(),
        mediaRoot: widget.store == null
            ? getApplicationSupportDirectory
            : getTemporaryDirectory,
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
    if (!_choir.loaded) _choir.load();
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
    _choir.dispose();
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
      child: ChoirScope.live(
        store: _choir,
        child: MaterialApp(
          title: 'Resonia',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigator,
          theme: trainerTheme(),
          themeMode: ThemeMode.light,
          // English first: a device in any other language falls back to it.
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              if (!_store.loaded) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: TrainerBadge(
                      color: TC.primary,
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
    ),
  );
}
