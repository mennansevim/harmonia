import 'package:flutter/material.dart';

import '../application/app_shell_controller.dart';
import '../application/profile_repository.dart';
import '../application/result_history.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/goal_selection_screen.dart';
import '../features/settings/settings_screen.dart';
import 'package:path_provider/path_provider.dart';

import '../infrastructure/audio/orphan_audio_cleaner.dart';
import '../infrastructure/storage/file_profile_repository.dart';
import '../infrastructure/storage/file_result_history.dart';
import 'app_services.dart';
import 'theme/harmonia_theme.dart';

/// App shell: loading → guest goal selection → home. No account required.
class HarmoniaApp extends StatefulWidget {
  const HarmoniaApp({
    super.key,
    this.profiles,
    this.history,
    this.startupCleanup,
  });

  /// Defaults to the on-device JSON profile; tests inject in-memory storage.
  final ProfileRepository? profiles;

  /// Defaults to the on-device attempt history (never uploaded).
  final ResultHistoryRepository? history;

  /// Defaults to sweeping orphan audio temp dirs left by a crash/kill.
  final Future<OrphanCleanupReport> Function()? startupCleanup;

  @override
  State<HarmoniaApp> createState() => _HarmoniaAppState();
}

class _HarmoniaAppState extends State<HarmoniaApp> {
  late final AppShellController _shell;
  late final ResultHistoryRepository _history =
      widget.history ?? FileResultHistory();
  final _cleanup = ValueNotifier<OrphanCleanupReport?>(null);
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _shell = AppShellController(widget.profiles ?? FileProfileRepository())
      ..load();
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
    super.dispose();
  }

  void _openSettings() => _navigator.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(controller: _shell, history: _history),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      AppServices(history: _history, cleanup: _cleanup, child: _app());

  Widget _app() => MaterialApp(
    title: 'Harmonia',
    navigatorKey: _navigator,
    theme: HarmoniaTheme.light(),
    darkTheme: HarmoniaTheme.dark(),
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
        AppShellPhase.onboarding => GoalSelectionScreen(
          saving: _shell.saving,
          errorText: _shell.failure == null
              ? null
              : 'Seçim kaydedilemedi. Yeniden dene.',
          onSelected: _shell.chooseGoal,
        ),
        AppShellPhase.ready => HomeScreen(
          profile: _shell.profile!,
          onOpenSettings: _openSettings,
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
        padding: const EdgeInsets.all(HarmoniaSpacing.lg),
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              failure == ProfileStorageFailure.corrupt
                  ? 'Bu cihazdaki Harmonia profili okunamadı.'
                  : 'Cihaz depolamasına şu an erişilemedi.',
              key: const Key('startup_error'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          FilledButton(
            key: const Key('startup_retry'),
            onPressed: onRetry,
            child: const Text('Yeniden dene'),
          ),
          if (failure == ProfileStorageFailure.corrupt) ...[
            const SizedBox(height: HarmoniaSpacing.sm),
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
