import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';
import 'package:resonia/application/reminder_planner.dart';
import 'package:resonia/infrastructure/notifications/flutter_practice_reminder_platform.dart';
import 'package:resonia/trainer/app/reminder_context.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

final now = DateTime(2026, 11, 3, 10); // Tuesday morning

ReminderContext ctx({
  int dueCards = 0,
  int streak = 0,
  bool practicedToday = false,
  DateTime? lastPractice,
  DateTime? choirDue,
  bool rangeMeasured = true,
  int activeDays = 0,
  List<int> sessionMinutes = const [],
  Map<ReminderKind, DateTime> lastSent = const {},
}) => ReminderContext(
  now: now,
  chosenMinute: 19 * 60,
  dueCards: dueCards,
  streak: streak,
  practicedToday: practicedToday,
  lastPractice: lastPractice,
  choirDue: choirDue,
  choirTitle: 'Gloria',
  rangeMeasured: rangeMeasured,
  activeDays: activeDays,
  sessionMinutes: sessionMinutes,
  lastSent: lastSent,
);

class _Platform implements PracticeReminderPlatform, PlannedReminderPlatform {
  ReminderPermission current = ReminderPermission.authorized;
  List<PlannedReminder>? plan;
  @override
  Future<ReminderPermission> permission() async => current;
  @override
  Future<ReminderPermission> requestPermission() async => current;
  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {}
  @override
  Future<void> cancelDaily() async {}
  @override
  Future<bool> openSettings() async => true;
  @override
  Future<void> schedulePlan(List<PlannedReminder> plan) async =>
      this.plan = plan;
}

class _Driver implements PracticeNotificationDriver, PlannedNotificationDriver {
  List<PlannedReminder>? plan;
  @override
  Future<bool> initialize() async => true;
  @override
  Future<bool?> notificationsEnabled() async => true;
  @override
  Future<bool?> requestNotificationsPermission() async => true;
  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {}
  @override
  Future<void> cancelDaily() async {}
  @override
  Future<bool?> openSettings() async => true;
  @override
  Future<void> schedulePlan(List<PlannedReminder> plan) async =>
      this.plan = plan;
}

void main() {
  test('the production platform hands the plan to its driver', () async {
    final driver = _Driver();
    final platform = FlutterPracticeReminderPlatform(driver: driver);
    final plan = planReminders(ctx(lastPractice: now));
    await platform.schedulePlan(plan);
    expect(driver.plan, same(plan));
  });

  group('time', () {
    test('the chosen time until enough practice starts are known', () {
      expect(reminderMinute(ctx(sessionMinutes: [600, 610])), 19 * 60);
    });

    test('then 30 minutes before the usual start, within day hours', () {
      expect(
        reminderMinute(ctx(sessionMinutes: [1200, 1210, 1190, 1205, 1215])),
        1205 - 30,
      );
      expect(reminderMinute(ctx(sessionMinutes: [60, 70, 80, 90, 100])), 480);
    });
  });

  group('plan', () {
    test('a week of daily reminders, then two weekly ones', () {
      final plan = planReminders(ctx(lastPractice: now));
      expect(plan, hasLength(dailyDays + weeklyAfter));
      expect(plan.first.at, DateTime(2026, 11, 3, 19));
      expect(plan[dailyDays - 1].at, DateTime(2026, 11, 9, 19));
      expect(plan[dailyDays].kind, ReminderKind.weekly);
      expect(plan[dailyDays].at, DateTime(2026, 11, 16, 19));
      expect(plan.last.at, DateTime(2026, 11, 23, 19));
    });

    test('after practice today the plan starts tomorrow', () {
      final plan = planReminders(ctx(practicedToday: true, lastPractice: now));
      expect(plan.first.at, DateTime(2026, 11, 4, 19));
    });

    test('only true messages are candidates', () {
      final plain = planReminders(ctx(lastPractice: now));
      expect(
        plain.take(dailyDays).map((r) => r.kind).toSet(),
        isNot(contains(ReminderKind.streak)),
      );
      expect(
        plain.take(dailyDays).map((r) => r.kind),
        isNot(contains(ReminderKind.choir)),
      );
      // A streak is offered only while it can still be kept.
      final streak = planReminders(
        ctx(streak: 5, lastPractice: now.subtract(const Duration(days: 1))),
      );
      expect(streak.first.kind, ReminderKind.streak);
      expect(
        streak.skip(1).take(dailyDays - 1).map((r) => r.kind),
        isNot(contains(ReminderKind.streak)),
      );
    });

    test('a near choir deadline leads, then does not repeat every day', () {
      final plan = planReminders(
        ctx(
          dueCards: 6,
          lastPractice: now,
          choirDue: DateTime(2026, 11, 5, 12),
        ),
      );
      expect(plan[0].kind, ReminderKind.choir);
      expect(plan[0].title, 'Koro ödevine 2 gün kaldı');
      expect(plan[1].kind, isNot(ReminderKind.choir));
      final kinds = plan.take(dailyDays).map((r) => r.kind).toList();
      for (var i = 1; i < kinds.length; i++) {
        expect(kinds[i], isNot(kinds[i - 1]), reason: 'day $i repeats');
      }
    });

    test('a kind sent yesterday yields to a fresh one', () {
      final plan = planReminders(
        ctx(
          dueCards: 6,
          lastPractice: now,
          lastSent: {
            ReminderKind.review: now.subtract(const Duration(days: 1)),
          },
        ),
      );
      expect(plan.first.kind, ReminderKind.routine);
    });

    test('after three idle days the come-back message appears', () {
      final plan = planReminders(
        ctx(lastPractice: now.subtract(const Duration(days: 1))),
      );
      expect(
        plan.take(dailyDays).map((r) => r.kind),
        contains(ReminderKind.comeBack),
      );
    });

    test('texts are plain: no guilt words, no counts for the future', () {
      final words = RegExp(
        'kaybet|üzül|son şans|lose|last chance|sad',
        caseSensitive: false,
      );
      for (final k in ReminderKind.values) {
        final (title, body) = reminderText(
          k,
          ctx(dueCards: 4, streak: 4),
          choirIn: 1,
        );
        expect(words.hasMatch('$title $body'), isFalse, reason: k.name);
      }
      expect(
        reminderText(ReminderKind.review, ctx(dueCards: 4)).$2,
        isNot(contains('4')),
      );
    });
  });

  group('coordinator and store', () {
    test('replans only when reminders are on and allowed', () async {
      final platform = _Platform();
      final prefs = InMemoryPracticePreferences();
      final c = PracticeReminderCoordinator(
        preferences: prefs,
        platform: platform,
      );
      final store = TrainerStore(MemoryTrainerPersistence(), clock: () => now);
      await store.load();

      await replanReminders(store, c);
      expect(platform.plan, isNull, reason: 'reminders are off');

      await prefs.saveReminderTime(PracticeReminderTime(hour: 19, minute: 0));
      platform.current = ReminderPermission.denied;
      await replanReminders(store, c);
      expect(platform.plan, isNull, reason: 'permission denied');

      platform.current = ReminderPermission.authorized;
      await replanReminders(store, c);
      expect(platform.plan, hasLength(dailyDays + weeklyAfter));
      expect(store.reminderPlan, hasLength(dailyDays + weeklyAfter));
    });

    test('delivered reminders count for freshness after a restart', () async {
      var t = now;
      final p = MemoryTrainerPersistence();
      final store = TrainerStore(p, clock: () => t);
      await store.load();
      store.recordAnswer(TrainerKind.interval, 'M3', true);
      store.recordSession();
      store.reminderPlan.add((
        'routine',
        now.subtract(const Duration(hours: 20)),
      ));
      store.save();
      await pumpEventQueue();
      final again = TrainerStore(p, clock: () => t);
      await again.load();
      expect(again.practiceMinutes, [600]);
      final c = reminderContextFor(again, chosenMinute: 1140);
      expect(c.lastSent[ReminderKind.routine], isNotNull);
      expect(c.practicedToday, isTrue);
      expect(c.lastPractice, DateTime(2026, 11, 3));
      t = now.add(const Duration(days: 1));
      expect(
        reminderContextFor(again, chosenMinute: 1140).practicedToday,
        isFalse,
      );
    });
  });
}
