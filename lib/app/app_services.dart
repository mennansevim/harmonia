import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../application/practice_preferences.dart';
import '../application/result_history.dart';
import '../infrastructure/audio/orphan_audio_cleaner.dart';

/// App-wide local services, placed above the navigator so pushed routes see
/// them. Screens degrade gracefully when absent (tests, previews).
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.history,
    required this.cleanup,
    this.preferences,
    required super.child,
  });

  final ResultHistoryRepository history;

  /// Startup orphan-audio sweep result; null while running.
  final ValueListenable<OrphanCleanupReport?> cleanup;

  /// On-device practice preferences (daily budget); optional.
  final PracticePreferencesRepository? preferences;

  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>();

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      history != oldWidget.history ||
      cleanup != oldWidget.cleanup ||
      preferences != oldWidget.preferences;
}
