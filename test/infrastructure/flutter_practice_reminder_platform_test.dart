import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';
import 'package:resonia/infrastructure/notifications/flutter_practice_reminder_platform.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('permission remains non-prompting until explicit request', () async {
    final driver = _FakeDriver(enabled: false, requested: false);
    final platform = FlutterPracticeReminderPlatform(driver: driver);

    expect(await platform.permission(), ReminderPermission.unknown);
    expect(driver.requestCalls, 0);

    expect(await platform.requestPermission(), ReminderPermission.denied);
    expect(driver.requestCalls, 1);
    expect(await platform.permission(), ReminderPermission.denied);
    expect(driver.initializeCalls, 1);
  });

  test(
    'authorized driver schedules and cancels the exact requested time',
    () async {
      final driver = _FakeDriver(enabled: true, requested: true);
      final platform = FlutterPracticeReminderPlatform(driver: driver);
      final time = PracticeReminderTime(hour: 19, minute: 35);

      expect(await platform.permission(), ReminderPermission.authorized);
      await platform.scheduleDaily(time);
      await platform.cancelDaily();
      expect(await platform.openSettings(), isTrue);

      expect(driver.scheduled, time);
      expect(driver.cancelCalls, 1);
      expect(driver.settingsCalls, 1);
    },
  );

  test(
    'initialization failure stays unavailable and never calls OS work',
    () async {
      final driver = _FakeDriver(
        initialized: false,
        enabled: true,
        requested: true,
      );
      final platform = FlutterPracticeReminderPlatform(driver: driver);

      expect(await platform.permission(), ReminderPermission.unavailable);
      expect(
        platform.scheduleDaily(PracticeReminderTime(hour: 8, minute: 0)),
        throwsStateError,
      );
      expect(driver.permissionCalls, 0);
      expect(driver.scheduleCalls, 0);
    },
  );

  test('next daily occurrence preserves wall-clock hour on the next day', () {
    tz_data.initializeTimeZones();
    final location = tz.getLocation('America/New_York');
    final now = tz.TZDateTime(location, 2026, 3, 7, 20);

    final next = nextDailyOccurrence(now: now, hour: 19, minute: 15);

    expect(next.year, 2026);
    expect(next.month, 3);
    expect(next.day, 8);
    expect(next.hour, 19);
    expect(next.minute, 15);
  });
}

class _FakeDriver implements PracticeNotificationDriver {
  _FakeDriver({
    this.initialized = true,
    required this.enabled,
    required this.requested,
  });

  final bool initialized;
  bool enabled;
  final bool requested;
  int initializeCalls = 0;
  int permissionCalls = 0;
  int requestCalls = 0;
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int settingsCalls = 0;
  PracticeReminderTime? scheduled;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return initialized;
  }

  @override
  Future<bool?> notificationsEnabled() async {
    permissionCalls++;
    return enabled;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    requestCalls++;
    enabled = requested;
    return requested;
  }

  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {
    scheduleCalls++;
    scheduled = time;
  }

  @override
  Future<void> cancelDaily() async {
    cancelCalls++;
  }

  @override
  Future<bool?> openSettings() async {
    settingsCalls++;
    return true;
  }
}
