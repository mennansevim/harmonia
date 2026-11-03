import 'package:flutter/widgets.dart';

import '../../application/practice_reminder.dart';
import '../../application/result_history.dart';
import '../../infrastructure/audio/orphan_audio_cleaner.dart';
import '../audio/trainer_audio.dart';
import '../state/trainer_store.dart';

/// App-wide trainer services, placed above the navigator. Widgets using
/// [of] rebuild when the store changes, including the const tab bodies.
class TrainerScope extends InheritedNotifier<TrainerStore> {
  const TrainerScope({
    super.key,
    required TrainerStore store,
    required this.audio,
    this.reminders,
    this.history,
    this.purgeTempAudio,
    this.liveAudio = true,
    required super.child,
  }) : super(notifier: store);

  TrainerStore get store => notifier!;
  final TrainerAudio audio;
  final PracticeReminderCoordinator? reminders;
  final ResultHistoryRepository? history;

  /// "Delete my data" for recordings still in the temp folder.
  final Future<OrphanCleanupReport> Function()? purgeTempAudio;

  /// False in widget tests: choir screens must not open real microphones.
  final bool liveAudio;

  static TrainerScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TrainerScope>()!;

  /// Lookup without a rebuild dependency; safe in initState.
  static TrainerScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TrainerScope>()!;

  @override
  bool updateShouldNotify(covariant TrainerScope oldWidget) =>
      super.updateShouldNotify(oldWidget) ||
      audio != oldWidget.audio ||
      reminders != oldWidget.reminders;
}
