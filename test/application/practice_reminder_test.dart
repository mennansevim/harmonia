import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';

class _Platform implements PracticeReminderPlatform {
  ReminderPermission current = ReminderPermission.unknown;
  ReminderPermission requested = ReminderPermission.authorized;
  Object? failure;
  Completer<void>? scheduleGate;
  int permissionRequests = 0, schedules = 0, cancels = 0;
  int settings = 0;
  PracticeReminderTime? lastTime;

  @override
  Future<ReminderPermission> permission() async => current;

  @override
  Future<ReminderPermission> requestPermission() async {
    permissionRequests++;
    current = requested;
    return requested;
  }

  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async {
    schedules++;
    lastTime = time;
    if (scheduleGate case final gate?) await gate.future;
    if (failure case final error?) throw error;
  }

  @override
  Future<void> cancelDaily() async {
    cancels++;
    if (failure case final error?) throw error;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

class _FailingPreferences extends InMemoryPracticePreferences {
  bool failSave = false;

  @override
  Future<void> saveReminderTime(PracticeReminderTime? time) async {
    if (failSave) throw StateError('storage private detail');
    await super.saveReminderTime(time);
  }
}

void main() {
  group('wipe', () {
    final time = PracticeReminderTime(hour: 18, minute: 45);

    test('cancels the schedule and forgets every preference', () async {
      final preferences = InMemoryPracticePreferences();
      await preferences.saveReminderTime(time);
      await preferences.saveWeeklyGoal(WeeklyPracticeGoal.three);
      final platform = _Platform()..current = ReminderPermission.denied;
      final coordinator = PracticeReminderCoordinator(
        preferences: preferences,
        platform: platform,
      );
      expect(await coordinator.wipe(), ReminderUpdateOutcome.disabled);
      expect(platform.cancels, 1);
      expect(await preferences.loadReminderTime(), isNull);
      expect(await preferences.loadWeeklyGoal(), isNull);
    });

    test('still clears preferences where reminders are unavailable', () async {
      final preferences = InMemoryPracticePreferences();
      await preferences.saveWeeklyGoal(WeeklyPracticeGoal.three);
      final coordinator = PracticeReminderCoordinator(
        preferences: preferences,
        platform: const UnavailablePracticeReminderPlatform(),
      );
      expect(await coordinator.wipe(), ReminderUpdateOutcome.disabled);
      expect(await preferences.loadWeeklyGoal(), isNull);
    });

    test('a failed cancel fails and never reschedules', () async {
      final preferences = InMemoryPracticePreferences();
      await preferences.saveReminderTime(time);
      final platform = _Platform()..failure = StateError('native detail');
      final coordinator = PracticeReminderCoordinator(
        preferences: preferences,
        platform: platform,
      );
      expect(await coordinator.wipe(), ReminderUpdateOutcome.failed);
      expect(platform.schedules, 0);
    });
  });

  test(
    'enable requests permission, verifies schedule, then persists',
    () async {
      final preferences = InMemoryPracticePreferences();
      final platform = _Platform();
      final coordinator = PracticeReminderCoordinator(
        preferences: preferences,
        platform: platform,
      );
      final time = PracticeReminderTime(hour: 18, minute: 45);
      expect(await coordinator.enable(time), ReminderUpdateOutcome.enabled);
      expect(platform.permissionRequests, 1);
      expect(platform.schedules, 1);
      expect(platform.lastTime, time);
      expect(await preferences.loadReminderTime(), time);
    },
  );

  test('denied or unavailable never stores a reminder', () async {
    for (final permission in [
      ReminderPermission.denied,
      ReminderPermission.unavailable,
    ]) {
      final preferences = InMemoryPracticePreferences();
      final platform = _Platform()
        ..current = permission
        ..requested = permission;
      final coordinator = PracticeReminderCoordinator(
        preferences: preferences,
        platform: platform,
      );
      final outcome = await coordinator.enable(
        PracticeReminderTime(hour: 9, minute: 0),
      );
      expect(
        outcome,
        permission == ReminderPermission.denied
            ? ReminderUpdateOutcome.denied
            : ReminderUpdateOutcome.unavailable,
      );
      expect(platform.schedules, 0);
      expect(await preferences.loadReminderTime(), isNull);
    }
  });

  test('native failure preserves the prior verified preference', () async {
    final preferences = InMemoryPracticePreferences();
    final old = PracticeReminderTime(hour: 8, minute: 0);
    await preferences.saveReminderTime(old);
    final platform = _Platform()
      ..current = ReminderPermission.authorized
      ..failure = StateError('native private detail');
    final coordinator = PracticeReminderCoordinator(
      preferences: preferences,
      platform: platform,
    );
    expect(
      await coordinator.enable(PracticeReminderTime(hour: 20, minute: 0)),
      ReminderUpdateOutcome.failed,
    );
    expect(await preferences.loadReminderTime(), old);
  });

  test('disable clears preference only after native cancel succeeds', () async {
    final preferences = InMemoryPracticePreferences();
    final time = PracticeReminderTime(hour: 7, minute: 30);
    await preferences.saveReminderTime(time);
    final platform = _Platform()..current = ReminderPermission.authorized;
    final coordinator = PracticeReminderCoordinator(
      preferences: preferences,
      platform: platform,
    );
    expect(await coordinator.disable(), ReminderUpdateOutcome.disabled);
    expect(platform.cancels, 1);
    expect(await preferences.loadReminderTime(), isNull);
  });

  test('storage failure rolls native state back to prior schedule', () async {
    final preferences = _FailingPreferences();
    final old = PracticeReminderTime(hour: 7, minute: 30);
    await preferences.saveReminderTime(old);
    preferences.failSave = true;
    final platform = _Platform()..current = ReminderPermission.authorized;
    final coordinator = PracticeReminderCoordinator(
      preferences: preferences,
      platform: platform,
    );
    expect(
      await coordinator.enable(PracticeReminderTime(hour: 20, minute: 15)),
      ReminderUpdateOutcome.failed,
    );
    expect(platform.schedules, 2);
    expect(platform.lastTime, old);
    expect(await preferences.loadReminderTime(), old);
  });

  test('pending update is single-flight', () async {
    final preferences = InMemoryPracticePreferences();
    final platform = _Platform()
      ..current = ReminderPermission.authorized
      ..scheduleGate = Completer<void>();
    final coordinator = PracticeReminderCoordinator(
      preferences: preferences,
      platform: platform,
    );
    final first = coordinator.enable(PracticeReminderTime(hour: 12, minute: 0));
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.busy, isTrue);
    expect(await coordinator.disable(), ReminderUpdateOutcome.busy);
    platform.scheduleGate!.complete();
    expect(await first, ReminderUpdateOutcome.enabled);
    expect(platform.schedules, 1);
    expect(platform.cancels, 0);
  });

  test('production fallback is explicitly unavailable', () async {
    final coordinator = PracticeReminderCoordinator(
      preferences: InMemoryPracticePreferences(),
      platform: const UnavailablePracticeReminderPlatform(),
    );
    expect(
      await coordinator.enable(PracticeReminderTime(hour: 10, minute: 15)),
      ReminderUpdateOutcome.unavailable,
    );
  });

  test('settings recovery is delegated and failure is fail-closed', () async {
    final platform = _Platform();
    final coordinator = PracticeReminderCoordinator(
      preferences: InMemoryPracticePreferences(),
      platform: platform,
    );
    expect(await coordinator.openSettings(), isTrue);
    expect(platform.settings, 1);
    expect(
      await PracticeReminderCoordinator(
        preferences: InMemoryPracticePreferences(),
        platform: const UnavailablePracticeReminderPlatform(),
      ).openSettings(),
      isFalse,
    );
  });
}
