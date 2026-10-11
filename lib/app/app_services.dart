import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../application/result_history.dart';
import '../infrastructure/audio/orphan_audio_cleaner.dart';

/// App-wide local services, placed above the navigator so pushed routes see
/// them. Screens degrade gracefully when absent (tests, previews).
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.history,
    required this.cleanup,
    required super.child,
  });

  final ResultHistoryRepository history;

  /// Startup orphan-audio sweep result; null while running.
  final ValueListenable<OrphanCleanupReport?> cleanup;

  static AppServices? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppServices>();

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      history != oldWidget.history || cleanup != oldWidget.cleanup;
}
