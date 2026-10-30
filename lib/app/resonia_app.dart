import 'package:flutter/material.dart';

import '../application/app_shell_controller.dart';
import '../application/error_log.dart';
import '../application/profile_repository.dart';
import '../application/practice_preferences.dart';
import '../application/practice_reminder.dart';
import '../application/result_history.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/guest_onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import 'package:path_provider/path_provider.dart';

import '../infrastructure/audio/orphan_audio_cleaner.dart';
import '../infrastructure/notifications/flutter_practice_reminder_platform.dart';
import '../infrastructure/storage/file_profile_repository.dart';
import '../infrastructure/storage/file_practice_preferences.dart';
import '../infrastructure/storage/file_result_history.dart';
import 'app_channel.dart';
import 'app_services.dart';
import 'theme/resonia_theme.dart';

/// App shell: loading → guest goal selection → home. No account required.
class ResoniaApp extends StatefulWidget {
  const ResoniaApp({
    super.key,
    this.profiles,
    this.history,
    this.startupCleanup,
    this.preferences,
    this.channel,
    this.errorLog,
  });

  /// Defaults to the on-device JSON profile; tests inject in-memory storage.
  final ProfileRepository? profiles;

  /// Defaults to the on-device attempt history (never uploaded).
  final ResultHistoryRepository? history;

  /// Defaults to sweeping orphan audio temp dirs left by a crash/kill.
  final Future<OrphanCleanupReport> Function()? startupCleanup;

  /// Defaults to on-device practice preferences (daily plan budget).
  final PracticePreferencesRepository? preferences;

  /// Defaults to the build-time channel (RESONIA_CHANNEL).
  final AppChannel? channel;

  /// This run's unexpected errors (main installs the handlers).
  final LocalErrorLog? errorLog;

  @override
  State<ResoniaApp> createState() => _ResoniaAppState();
}

class _ResoniaAppState extends State<ResoniaApp> {
  late final AppShellController _shell;
  late final ResultHistoryRepository _history =
      widget.history ?? FileResultHistory();
  late final PracticePreferencesRepository _preferences =
      widget.preferences ?? FilePracticePreferences();
  late final PracticeReminderCoordinator _reminders =
      PracticeReminderCoordinator(
        preferences: _preferences,
        platform: FlutterPracticeReminderPlatform(),
      );
  final _hapticsEnabled = ValueNotifier<bool>(true);
  final _preferencesRevision = ValueNotifier<int>(0);
  final _cleanup = ValueNotifier<OrphanCleanupReport?>(null);
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _shell = AppShellController(widget.profiles ?? FileProfileRepository())
      ..load();
    _preferences.loadHapticsEnabled().then((enabled) {
      if (mounted) _hapticsEnabled.value = enabled;
    }, onError: (Object _) {});
    // Runs before any audio screen exists, so every match is an orphan.
    final sweep =
        widget.startupCleanup ?? OrphanAudioCleaner(getTemporaryDirectory).run;
    sweep().then(
      (report) {
        if (mounted) _cleanup.value = report;
      },
      onError: (Object _) {
        if (mounted) _cleanup.value = const OrphanCleanupReport(failures: 1);
      },
    );
  }

  @override
  void dispose() {
    _shell.dispose();
    _cleanup.dispose();
    _hapticsEnabled.dispose();
    _preferencesRevision.dispose();
    super.dispose();
  }

  void _preferencesImported() => _preferencesRevision.value++;

  void _openSettings() => _navigator.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(
        controller: _shell,
        history: _history,
        channel: widget.channel ?? AppChannel.current,
        errorLog: widget.errorLog,
        reminders: _reminders,
        preferences: _preferences,
        hapticsEnabled: _hapticsEnabled,
        onPreferencesImported: _preferencesImported,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ResoniaHapticsScope(
    enabled: _hapticsEnabled,
    child: ValueListenableBuilder<int>(
      valueListenable: _preferencesRevision,
      builder: (context, revision, _) => AppServices(
        history: _history,
        cleanup: _cleanup,
        preferences: _preferences,
        preferencesRevision: revision,
        child: _app(),
      ),
    ),
  );

  Widget _app() => MaterialApp(
    title: 'Resonia',
    navigatorKey: _navigator,
    theme: ResoniaTheme.light(),
    darkTheme: ResoniaTheme.dark(),
    home: ListenableBuilder(
      listenable: _shell,
      builder: (context, _) => switch (_shell.phase) {
        AppShellPhase.loading => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Yükleniyor'),
          ),
        ),
        AppShellPhase.error => _StartupError(
          failure: _shell.failure,
          onRetry: _shell.load,
          onStartOver: _shell.deleteLocalProfile,
        ),
        AppShellPhase.onboarding => GuestOnboardingScreen(
          preferences: _preferences,
          onComplete: _shell.chooseGoal,
        ),
        AppShellPhase.ready => HomeScreen(
          profile: _shell.profile!,
          onOpenSettings: _openSettings,
          channel: widget.channel ?? AppChannel.current,
        ),
      },
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({
    required this.failure,
    required this.onRetry,
    required this.onStartOver,
  });

  final ProfileStorageFailure? failure;
  final VoidCallback onRetry;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(ResoniaSpacing.lg),
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              failure == ProfileStorageFailure.corrupt
                  ? 'Bu cihazdaki Resonia profili okunamadı.'
                  : 'Cihaz depolamasına şu an erişilemedi.',
              key: const Key('startup_error'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: ResoniaSpacing.md),
          FilledButton(
            key: const Key('startup_retry'),
            onPressed: onRetry,
            child: const Text('Yeniden dene'),
          ),
          if (failure == ProfileStorageFailure.corrupt) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            const Text(
              'Sorun sürerse yerel profili silip hedefini yeniden seçebilirsin. Başka veri etkilenmez.',
            ),
            TextButton(
              key: const Key('startup_start_over'),
              onPressed: onStartOver,
              child: const Text('Profili sil ve yeniden başla'),
            ),
          ],
        ],
      ),
    ),
  );
}
