import 'practice_preferences.dart';

enum ReminderPermission { unknown, denied, authorized, unavailable }

enum ReminderUpdateOutcome {
  enabled,
  disabled,
  denied,
  unavailable,
  failed,
  busy,
}

/// Native notification boundary. The app has no production implementation
/// until a notification plugin, permission copy and device matrix are chosen.
abstract interface class PracticeReminderPlatform {
  Future<ReminderPermission> permission();
  Future<ReminderPermission> requestPermission();
  Future<void> scheduleDaily(PracticeReminderTime time);
  Future<void> cancelDaily();
  Future<bool> openSettings();
}

class UnavailablePracticeReminderPlatform implements PracticeReminderPlatform {
  const UnavailablePracticeReminderPlatform();

  @override
  Future<ReminderPermission> permission() async =>
      ReminderPermission.unavailable;
  @override
  Future<ReminderPermission> requestPermission() async =>
      ReminderPermission.unavailable;
  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async =>
      throw UnsupportedError('Native reminder adapter is not installed');
  @override
  Future<void> cancelDaily() async =>
      throw UnsupportedError('Native reminder adapter is not installed');
  @override
  Future<bool> openSettings() async => false;
}

/// Coordinates an explicit opt-in. Persistence changes only after the native
/// schedule/cancel operation succeeds, so UI cannot claim an unverified alarm.
class PracticeReminderCoordinator {
  PracticeReminderCoordinator({
    required this.preferences,
    required this.platform,
  });

  final PracticePreferencesRepository preferences;
  final PracticeReminderPlatform platform;
  bool _busy = false;
  bool get busy => _busy;

  Future<PracticeReminderTime?> load() => preferences.loadReminderTime();
  Future<ReminderPermission> inspectPermission() => platform.permission();

  Future<bool> openSettings() async {
    try {
      return await platform.openSettings();
    } catch (_) {
      return false;
    }
  }

  Future<ReminderUpdateOutcome> enable(PracticeReminderTime time) async {
    if (_busy) return ReminderUpdateOutcome.busy;
    _busy = true;
    try {
      final previous = await preferences.loadReminderTime();
      var permission = await platform.permission();
      if (permission == ReminderPermission.unavailable) {
        return ReminderUpdateOutcome.unavailable;
      }
      if (permission != ReminderPermission.authorized) {
        permission = await platform.requestPermission();
      }
      if (permission == ReminderPermission.denied) {
        return ReminderUpdateOutcome.denied;
      }
      if (permission != ReminderPermission.authorized) {
        return ReminderUpdateOutcome.unavailable;
      }
      await platform.scheduleDaily(time);
      try {
        await preferences.saveReminderTime(time);
      } catch (_) {
        try {
          if (previous == null) {
            await platform.cancelDaily();
          } else {
            await platform.scheduleDaily(previous);
          }
        } catch (_) {
          // The adapter cannot prove rollback; never publish enabled locally.
        }
        return ReminderUpdateOutcome.failed;
      }
      return ReminderUpdateOutcome.enabled;
    } catch (_) {
      return ReminderUpdateOutcome.failed;
    } finally {
      _busy = false;
    }
  }

  Future<ReminderUpdateOutcome> disable() async {
    if (_busy) return ReminderUpdateOutcome.busy;
    _busy = true;
    try {
      final previous = await preferences.loadReminderTime();
      final permission = await platform.permission();
      if (permission == ReminderPermission.unavailable) {
        return ReminderUpdateOutcome.unavailable;
      }
      await platform.cancelDaily();
      try {
        await preferences.saveReminderTime(null);
      } catch (_) {
        if (previous != null) {
          try {
            await platform.scheduleDaily(previous);
          } catch (_) {
            // The adapter cannot prove rollback; retain the old local value.
          }
        }
        return ReminderUpdateOutcome.failed;
      }
      return ReminderUpdateOutcome.disabled;
    } catch (_) {
      return ReminderUpdateOutcome.failed;
    } finally {
      _busy = false;
    }
  }
}
