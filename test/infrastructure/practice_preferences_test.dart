import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/domain/learning/daily_plan.dart';
import 'package:resonia/infrastructure/storage/file_practice_preferences.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('prefs-'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('codec is strict', () {
    expect(
      PracticePreferencesCodec.decode(
        PracticePreferencesCodec.encode(DailyBudget.five),
      ),
      DailyBudget.five,
    );
    for (final bad in <Map<String, Object?>>[
      {'schemaVersion': 2, 'dailyBudgetMinutes': 5},
      {'schemaVersion': 1, 'dailyBudgetMinutes': 7},
      {'schemaVersion': 1, 'dailyBudgetMinutes': '5'},
      {'schemaVersion': 1, 'dailyBudgetMinutes': 5, 'x': 1},
      {'schemaVersion': 2, 'dailyBudgetMinutes': 5, 'weeklyGoalDays': 7},
    ]) {
      expect(() => PracticePreferencesCodec.decode(bad), throwsFormatException);
    }
    final migrated = PracticePreferencesCodec.decodeSnapshot({
      'schemaVersion': 1,
      'dailyBudgetMinutes': 12,
    });
    expect(migrated.dailyBudget, DailyBudget.twelve);
    expect(migrated.weeklyGoal, isNull);
    expect(migrated.reminderTime, isNull);
    final v2 = PracticePreferencesCodec.decodeSnapshot({
      'schemaVersion': 2,
      'dailyBudgetMinutes': 5,
      'weeklyGoalDays': 3,
    });
    expect(v2.dailyBudget, DailyBudget.five);
    expect(v2.weeklyGoal, WeeklyPracticeGoal.three);
    expect(v2.reminderTime, isNull);
    expect(v2.hapticsEnabled, isTrue);
    final v3 = PracticePreferencesCodec.decodeSnapshot({
      'schemaVersion': 3,
      'dailyBudgetMinutes': 5,
      'weeklyGoalDays': 3,
      'reminderHour': 19,
      'reminderMinute': 30,
    });
    expect(v3.hapticsEnabled, isTrue);
    for (final bad in <Map<String, Object?>>[
      {
        'schemaVersion': 4,
        'dailyBudgetMinutes': 5,
        'weeklyGoalDays': 3,
        'reminderHour': 9,
        'reminderMinute': null,
        'hapticsEnabled': true,
      },
      {
        'schemaVersion': 4,
        'dailyBudgetMinutes': 5,
        'weeklyGoalDays': 3,
        'reminderHour': 24,
        'reminderMinute': 0,
        'hapticsEnabled': true,
      },
      {
        'schemaVersion': 4,
        'dailyBudgetMinutes': 5,
        'weeklyGoalDays': 3,
        'reminderHour': null,
        'reminderMinute': null,
        'hapticsEnabled': 'yes',
      },
    ]) {
      expect(
        () => PracticePreferencesCodec.decodeSnapshot(bad),
        throwsFormatException,
      );
    }
  });

  test('file: missing → null, saved survives a new instance', () async {
    final a = FilePracticePreferences(directory: () async => dir);
    expect(await a.loadDailyBudget(), isNull);
    await a.saveDailyBudget(DailyBudget.fifteen);
    final b = FilePracticePreferences(directory: () async => dir);
    expect(await b.loadDailyBudget(), DailyBudget.fifteen);
  });

  test(
    'file: corrupt document falls back to defaults, kept until next save',
    () async {
      final f = File('${dir.path}/practice_preferences.json');
      await f.writeAsString('{not json');
      final p = FilePracticePreferences(directory: () async => dir);
      expect(await p.loadDailyBudget(), isNull);
      expect(await f.readAsString(), '{not json');
      await p.saveDailyBudget(DailyBudget.twelve);
      expect(await p.loadDailyBudget(), DailyBudget.twelve);
    },
  );

  test('file clear removes every preference, even a corrupt file', () async {
    final p = FilePracticePreferences(directory: () async => dir);
    await p.saveDailyBudget(DailyBudget.five);
    await p.saveWeeklyGoal(WeeklyPracticeGoal.four);
    await p.saveReminderTime(PracticeReminderTime(hour: 19, minute: 0));
    await p.saveHapticsEnabled(false);
    await p.clear();
    final f = File('${dir.path}/practice_preferences.json');
    expect(await f.exists(), isFalse);
    final restored = FilePracticePreferences(directory: () async => dir);
    expect(await restored.loadDailyBudget(), isNull);
    expect(await restored.loadWeeklyGoal(), isNull);
    expect(await restored.loadReminderTime(), isNull);
    expect(await restored.loadHapticsEnabled(), isTrue);

    await f.writeAsString('{not json');
    await restored.clear();
    expect(await f.exists(), isFalse);
    await restored.clear();
  });

  test(
    'file keeps daily budget and weekly goal through independent saves',
    () async {
      final p = FilePracticePreferences(directory: () async => dir);
      await p.saveDailyBudget(DailyBudget.five);
      await p.saveWeeklyGoal(WeeklyPracticeGoal.four);
      final restored = FilePracticePreferences(directory: () async => dir);
      expect(await restored.loadDailyBudget(), DailyBudget.five);
      expect(await restored.loadWeeklyGoal(), WeeklyPracticeGoal.four);

      await restored.saveWeeklyGoal(null);
      expect(await restored.loadWeeklyGoal(), isNull);
      expect(await restored.loadDailyBudget(), DailyBudget.five);
    },
  );

  test(
    'concurrent preference writes are serialized without lost fields',
    () async {
      final p = FilePracticePreferences(directory: () async => dir);
      await Future.wait([
        p.saveDailyBudget(DailyBudget.fifteen),
        p.saveWeeklyGoal(WeeklyPracticeGoal.three),
        p.saveReminderTime(PracticeReminderTime(hour: 19, minute: 30)),
        p.saveHapticsEnabled(false),
      ]);
      expect(await p.loadDailyBudget(), DailyBudget.fifteen);
      expect(await p.loadWeeklyGoal(), WeeklyPracticeGoal.three);
      expect(
        await p.loadReminderTime(),
        PracticeReminderTime(hour: 19, minute: 30),
      );
      expect(await p.loadHapticsEnabled(), isFalse);
    },
  );

  test('file reminder can be replaced and disabled independently', () async {
    final p = FilePracticePreferences(directory: () async => dir);
    await p.saveDailyBudget(DailyBudget.twelve);
    await p.saveReminderTime(PracticeReminderTime(hour: 8, minute: 5));
    final restored = FilePracticePreferences(directory: () async => dir);
    expect(
      await restored.loadReminderTime(),
      PracticeReminderTime(hour: 8, minute: 5),
    );
    await restored.saveReminderTime(null);
    expect(await restored.loadReminderTime(), isNull);
    expect(await restored.loadDailyBudget(), DailyBudget.twelve);
  });

  test('haptics defaults on and persists independently', () async {
    final p = FilePracticePreferences(directory: () async => dir);
    expect(await p.loadHapticsEnabled(), isTrue);
    await p.saveWeeklyGoal(WeeklyPracticeGoal.two);
    await p.saveHapticsEnabled(false);
    final restored = FilePracticePreferences(directory: () async => dir);
    expect(await restored.loadHapticsEnabled(), isFalse);
    expect(await restored.loadWeeklyGoal(), WeeklyPracticeGoal.two);
  });

  test('portable save is atomic and preserves device-only settings', () async {
    final p = FilePracticePreferences(directory: () async => dir);
    await p.saveReminderTime(PracticeReminderTime(hour: 8, minute: 10));
    await p.saveHapticsEnabled(false);
    await p.savePortablePreferences(
      const PortablePracticePreferences(
        dailyBudget: DailyBudget.fifteen,
        weeklyGoal: WeeklyPracticeGoal.five,
      ),
    );
    final portable = await p.loadPortablePreferences();
    expect(portable.dailyBudget, DailyBudget.fifteen);
    expect(portable.weeklyGoal, WeeklyPracticeGoal.five);
    expect(
      await p.loadReminderTime(),
      PracticeReminderTime(hour: 8, minute: 10),
    );
    expect(await p.loadHapticsEnabled(), isFalse);
  });
}
