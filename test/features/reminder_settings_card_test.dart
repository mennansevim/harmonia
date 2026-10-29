import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/practice_reminder.dart';
import 'package:harmonia/features/settings/reminder_settings_card.dart';

class _Platform implements PracticeReminderPlatform {
  ReminderPermission current;
  ReminderPermission requested;
  int requests = 0, schedules = 0, cancels = 0, settings = 0;

  _Platform({
    required this.current,
    this.requested = ReminderPermission.authorized,
  });

  @override
  Future<ReminderPermission> permission() async => current;
  @override
  Future<ReminderPermission> requestPermission() async {
    requests++;
    current = requested;
    return current;
  }

  @override
  Future<void> scheduleDaily(PracticeReminderTime time) async => schedules++;
  @override
  Future<void> cancelDaily() async => cancels++;
  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required PracticeReminderCoordinator coordinator,
  Future<TimeOfDay?> Function(BuildContext, TimeOfDay)? picker,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? HarmoniaTheme.dark() : HarmoniaTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReminderSettingsCard(
            coordinator: coordinator,
            pickTime: picker,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unavailable production adapter exposes no fake action', (
    tester,
  ) async {
    final preferences = InMemoryPracticePreferences();
    await _pump(
      tester,
      coordinator: PracticeReminderCoordinator(
        preferences: preferences,
        platform: const UnavailablePracticeReminderPlatform(),
      ),
    );
    expect(find.byKey(const Key('reminder_unavailable')), findsOneWidget);
    expect(find.byKey(const Key('reminder_choose_time')), findsNothing);
    expect(await preferences.loadReminderTime(), isNull);
  });

  testWidgets('explicit time selection enables and disable cancels', (
    tester,
  ) async {
    final preferences = InMemoryPracticePreferences();
    final platform = _Platform(current: ReminderPermission.unknown);
    await _pump(
      tester,
      coordinator: PracticeReminderCoordinator(
        preferences: preferences,
        platform: platform,
      ),
      picker: (_, _) async => const TimeOfDay(hour: 18, minute: 45),
    );
    await tester.tap(find.byKey(const Key('reminder_choose_time')));
    await tester.pumpAndSettle();
    expect(find.text('Her gün 18:45 için ayarlı.'), findsOneWidget);
    expect(platform.requests, 1);
    expect(platform.schedules, 1);
    expect(
      await preferences.loadReminderTime(),
      PracticeReminderTime(hour: 18, minute: 45),
    );

    await tester.tap(find.byKey(const Key('reminder_disable')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kapalı.'), findsOneWidget);
    expect(platform.cancels, 1);
    expect(await preferences.loadReminderTime(), isNull);
  });

  testWidgets('denied permission is explained and never shown as enabled', (
    tester,
  ) async {
    final preferences = InMemoryPracticePreferences();
    final platform = _Platform(
      current: ReminderPermission.denied,
      requested: ReminderPermission.denied,
    );
    await _pump(
      tester,
      coordinator: PracticeReminderCoordinator(
        preferences: preferences,
        platform: platform,
      ),
      picker: (_, _) async => const TimeOfDay(hour: 9, minute: 0),
    );
    await tester.tap(find.byKey(const Key('reminder_choose_time')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bildirim izni verilmedi'), findsOneWidget);
    expect(find.textContaining('Her gün 09:00'), findsNothing);
    expect(platform.schedules, 0);
    expect(await preferences.loadReminderTime(), isNull);
    expect(find.byKey(const Key('reminder_open_settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder_open_settings')));
    await tester.pumpAndSettle();
    expect(platform.settings, 1);
    expect(find.textContaining('Bildirim ayarları açıldı'), findsOneWidget);
  });

  testWidgets('unavailable card fits dark 320px large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      dark: true,
      coordinator: PracticeReminderCoordinator(
        preferences: InMemoryPracticePreferences(),
        platform: const UnavailablePracticeReminderPlatform(),
      ),
    );
    expect(find.text('Çalışma hatırlatması'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
