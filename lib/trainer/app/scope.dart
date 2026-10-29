import 'package:flutter/widgets.dart';

import '../../application/practice_reminder.dart';
import '../../application/result_history.dart';
import '../audio/trainer_audio.dart';
import '../state/trainer_store.dart';

/// App-wide trainer services, placed above the navigator.
class TrainerScope extends InheritedWidget {
  const TrainerScope({
    super.key,
    required this.store,
    required this.audio,
    this.reminders,
    this.history,
    this.liveAudio = true,
    required super.child,
  });

  final TrainerStore store;
  final TrainerAudio audio;
  final PracticeReminderCoordinator? reminders;
  final ResultHistoryRepository? history;

  /// False in widget tests: choir screens must not open real microphones.
  final bool liveAudio;

  static TrainerScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TrainerScope>()!;

  @override
  bool updateShouldNotify(TrainerScope old) =>
      store != old.store || audio != old.audio || reminders != old.reminders;
}
