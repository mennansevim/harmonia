import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../application/practice_preferences.dart';
import '../../application/practice_reminder.dart';

/// Narrow driver so permission and scheduling policy can be tested without
/// invoking an operating-system notification channel.
abstract interface class PracticeNotificationDriver {
  Future<bool> initialize();
  Future<bool?> notificationsEnabled();
  Future<bool?> requestNotificationsPermission();
  Future<void> scheduleDaily(PracticeReminderTime time);
  Future<void> cancelDaily();
  Future<bool?> openSettings();
}

/// Production adapter. Permission is requested only through [requestPermission],
/// which the coordinator calls after an explicit user action.
class FlutterPracticeReminderPlatform implements PracticeReminderPlatform {
  FlutterPracticeReminderPlatform({PracticeNotificationDriver? driver})
    : _driver = driver ?? FlutterLocalNotificationDriver();

  final PracticeNotificationDriver _driver;
  Future<bool>? _initialization;
  bool _knownDenied = false;

  Future<bool> _ready() =>
      _initialization ??= _driver.initialize().catchError((Object _) => false);

  @override
  Future<ReminderPermission> permission() async {
    if (!await _ready()) return ReminderPermission.unavailable;
    try {
      final enabled = await _driver.notificationsEnabled();
      if (enabled == null) return ReminderPermission.unavailable;
      if (enabled) return ReminderPermission.authorized;
      return _knownDenied
          ? ReminderPermission.denied
          : ReminderPermission.unknown;
    } catch (_) {
      return ReminderPermission.unavailable;
    }
  }

  @override
  Future<ReminderPermission> requestPermission() async {
    if (!await _ready()) return ReminderPermission.unavailable;
    try {
      final enabled = await _driver.requestNotificationsPermission();
      if (enabled == null) return ReminderPermission.unavailable;
      _knownDenied = !enabled;
      return enabled
          ? ReminderPermission.authorized
          : ReminderPermission.denied;
    } catch (_) {
      return ReminderPermission.unavailable;
    }
  }

  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {
    if (!await _ready()) {
      throw StateError('Notification adapter unavailable');
    }
    await _driver.scheduleDaily(time);
  }

  @override
  Future<void> cancelDaily() async {
    if (!await _ready()) {
      throw StateError('Notification adapter unavailable');
    }
    await _driver.cancelDaily();
  }

  @override
  Future<bool> openSettings() async {
    if (!await _ready()) return false;
    try {
      return await _driver.openSettings() ?? false;
    } catch (_) {
      return false;
    }
  }
}

class FlutterLocalNotificationDriver implements PracticeNotificationDriver {
  FlutterLocalNotificationDriver({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const reminderId = 1701;
  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_resonia'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return initialized == true;
  }

  @override
  Future<bool?> notificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final options = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return options?.isEnabled;
    }
    return null;
  }

  @override
  Future<bool?> requestNotificationsPermission() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          Future<bool?>.value();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          Future<bool?>.value();
    }
    return Future<bool?>.value();
  }

  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {
    tz_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    final scheduled = nextDailyOccurrence(
      now: tz.TZDateTime.now(tz.local),
      hour: time.hour,
      minute: time.minute,
    );
    await _plugin.zonedSchedule(
      id: reminderId,
      title: 'Bugünkü kısa çalışman hazır',
      body: 'Kulak ve ritim çalışmana kaldığın yerden devam et.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'practice_reminders_v1',
          'Çalışma hatırlatmaları',
          channelDescription: 'Kullanıcının seçtiği günlük çalışma saati',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'practice-reminder',
    );
  }

  @override
  Future<void> cancelDaily() => _plugin.cancel(id: reminderId);

  @override
  Future<bool?> openSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.openAppNotificationSettings() ??
          Future<bool?>.value();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.openAppNotificationSettings() ??
          Future<bool?>.value();
    }
    return Future<bool?>.value();
  }
}

@visibleForTesting
tz.TZDateTime nextDailyOccurrence({
  required tz.TZDateTime now,
  required int hour,
  required int minute,
}) {
  var candidate = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!candidate.isAfter(now)) {
    candidate = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return candidate;
}
