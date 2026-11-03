import '../../application/practice_reminder.dart';
import '../../application/reminder_planner.dart';
import '../../choir/data/choir_store.dart';
import '../state/trainer_store.dart';

/// Builds what the reminder planner may know from local stores only.
ReminderContext reminderContextFor(
  TrainerStore store, {
  required int chosenMinute,
  ChoirStore? choir,
}) {
  final now = store.now;
  final lastSent = <ReminderKind, DateTime>{};
  for (final (name, at) in store.reminderPlan) {
    final kind = ReminderKind.values.asNameMap()[name];
    if (kind == null || at.isAfter(now)) continue;
    final prev = lastSent[kind];
    if (prev == null || at.isAfter(prev)) lastSent[kind] = at;
  }
  final due = choir?.nextDue();
  return ReminderContext(
    now: now,
    chosenMinute: chosenMinute,
    dueCards: store.dueReview.length,
    streak: store.streak,
    practicedToday: store.practicedToday,
    lastPractice: store.lastPracticeDay,
    choirDue: due?.$2.dueAt?.toLocal(),
    choirTitle: due?.$2.title,
    rangeMeasured: store.koroRange != null,
    activeDays: store.activeDayCount,
    sessionMinutes: store.practiceMinutes,
    lastSent: lastSent,
  );
}

/// Rebuilds the reminder series when reminders are on; remembers what was
/// scheduled so delivered messages count for freshness next time.
Future<void> replanReminders(
  TrainerStore store,
  PracticeReminderCoordinator reminders, {
  ChoirStore? choir,
}) async {
  final time = await reminders.load();
  if (time == null) return;
  final plan = planReminders(
    reminderContextFor(
      store,
      chosenMinute: time.hour * 60 + time.minute,
      choir: choir,
    ),
  );
  if (!await reminders.replan(plan)) return;
  final now = store.now;
  store.reminderPlan
    ..removeWhere((e) => e.$2.isAfter(now))
    ..addAll([for (final r in plan) (r.kind.name, r.at)]);
  // Keep only the last month of history.
  store.reminderPlan.removeWhere(
    (e) => e.$2.isBefore(now.subtract(const Duration(days: 30))),
  );
  store.save();
}
