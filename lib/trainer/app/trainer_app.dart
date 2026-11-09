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
import '../../domain/lang.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_flow.dart';
import '../state/trainer_store.dart';
import 'reminder_context.dart';
import '../ui/kit.dart';
import 'scope.dart';

/// Ear-trainer app root: loading → onboarding → tabbed home.
/// Largest system text scale the trainer honours.
const maxTextScale = 2.0;

class TrainerApp extends StatefulWidget {
  const TrainerApp({
    super.key,
    this.store,
    this.audio,
    this.reminders,
    this.history,
    this.liveAudio = true,
    this.startupCleanup,
    this.purgeTempAudio,
    this.choir,
  });

  final TrainerStore? store;
  final TrainerAudio? audio;
  final PracticeReminderCoordinator? reminders;
  final ResultHistoryRepository? history;
  final bool liveAudio;
  final Future<void> Function()? startupCleanup;
  final Future<OrphanCleanupReport> Function()? purgeTempAudio;
  final ChoirStore? choir;

  @override
  State<TrainerApp> createState() => _TrainerAppState();
}

class _TrainerAppState extends State<TrainerApp> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _language = _store.language;
    _store.addListener(_languageChanged);
    final sweep =
        widget.startupCleanup ??
        () async => _cleanup.value = await OrphanAudioCleaner(
          getTemporaryDirectory,
        ).run();
    sweep().catchError((Object _) {});
  }

  String? _language;

  /// Rebuilds the app only when the Settings language changes.
  void _languageChanged() {
    if (_store.language == _language) return;
    // WidgetsApp keeps its cached device locale when `locale` returns to
    // null without calling localeResolutionCallback, so set the wording here.
    final device = WidgetsBinding.instance.platformDispatcher.locales;
    final code =
        _store.language ?? (device.isEmpty ? 'en' : device.first.languageCode);
    Lang.en = code != 'tr';
    setState(() => _language = _store.language);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_languageChanged);
    _audio.dispose();
    _cleanup.dispose();
    _choir.dispose();
    super.dispose();
  }

  /// Leaving the app is when the plan is freshest: today's practice, due
  /// cards and choir work are known. Failures leave the old schedule.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused || !_store.loaded) return;
    replanReminders(
      _store,
      _reminders,
      choir: _choir,
    ).catchError((Object _) {});
  }

  void _onboardingFinished(bool begin) {
    if (!begin) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _navigator.currentState;
      if (nav != null) beginTodayRoute(_store, nav);
    });
  }

  @override
  Widget build(BuildContext context) => TrainerScope(
    store: _store,
    audio: _audio,
    reminders: _reminders,
    history: _history,
    purgeTempAudio:
        widget.purgeTempAudio ??
        OrphanAudioCleaner(getTemporaryDirectory).purge,
    liveAudio: widget.liveAudio,
    child: AppServices(
      history: _history,
      cleanup: _cleanup,
      child: ChoirScope.live(
        store: _choir,
        child: MaterialApp(
          title: 'Vocalart',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigator,
          theme: trainerTheme(),
          themeMode: ThemeMode.light,
          // Settings can pin a language; otherwise Turkish on a Turkish
          // device, English everywhere else.
          locale: _language == null ? null : Locale(_language!),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          localeResolutionCallback: (locale, _) {
            final turkish = locale?.languageCode == 'tr';
            Lang.en = !turkish;
            return Locale(turkish ? 'tr' : 'en');
          },
          // Layouts are audited up to 2x; iOS accessibility sizes reach about
          // 3x, which splits words mid-syllable.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: maxTextScale,
            child: child!,
          ),
          home: ListenableBuilder(
            listenable: _store,
            builder: (context, _) {
              if (!_store.loaded) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: TrainerBadge(
                      color: TC.primary,
                      icon: Ic.music2,
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
