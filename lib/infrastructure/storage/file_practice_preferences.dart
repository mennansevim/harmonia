import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/practice_preferences.dart';
import '../../domain/learning/daily_plan.dart';
import 'json_file_store.dart';

class FilePracticePreferences implements PracticePreferencesRepository {
  FilePracticePreferences({Future<Directory> Function()? directory})
    : _store = JsonFileStore(
        directory ?? getApplicationSupportDirectory,
        'practice_preferences',
        maxBytes: 4 * 1024,
      );

  final JsonFileStore _store;
  Future<void> _writes = Future<void>.value();

  Future<PracticePreferencesSnapshot> _loadSnapshot() async {
    await _writes;
    try {
      final json = await _store.read();
      return json == null
          ? const PracticePreferencesSnapshot()
          : PracticePreferencesCodec.decodeSnapshot(json);
    } catch (_) {
      return const PracticePreferencesSnapshot();
    }
  }

  Future<void> _update(
    PracticePreferencesSnapshot Function(PracticePreferencesSnapshot) change,
  ) {
    final run = _writes.then((_) async {
      PracticePreferencesSnapshot current;
      try {
        final json = await _store.read();
        current = json == null
            ? const PracticePreferencesSnapshot()
            : PracticePreferencesCodec.decodeSnapshot(json);
      } catch (_) {
        current = const PracticePreferencesSnapshot();
      }
      await _store.write(
        PracticePreferencesCodec.encodeSnapshot(change(current)),
      );
    });
    _writes = run.catchError((Object _) {});
    return run;
  }

  /// Missing, corrupt or unreadable → null (defaults); the corrupt file is
  /// left in place and replaced only by the user's next explicit choice.
  @override
  Future<DailyBudget?> loadDailyBudget() async {
    return (await _loadSnapshot()).dailyBudget;
  }

  @override
  Future<void> saveDailyBudget(DailyBudget budget) => _update(
    (value) => value.copyWith(dailyBudget: budget, replaceDailyBudget: true),
  );

  @override
  Future<WeeklyPracticeGoal?> loadWeeklyGoal() async =>
      (await _loadSnapshot()).weeklyGoal;

  @override
  Future<void> saveWeeklyGoal(WeeklyPracticeGoal? goal) => _update(
    (value) => value.copyWith(weeklyGoal: goal, replaceWeeklyGoal: true),
  );

  @override
  Future<PracticeReminderTime?> loadReminderTime() async =>
      (await _loadSnapshot()).reminderTime;

  @override
  Future<void> saveReminderTime(PracticeReminderTime? time) => _update(
    (value) => value.copyWith(reminderTime: time, replaceReminderTime: true),
  );

  @override
  Future<bool> loadHapticsEnabled() async =>
      (await _loadSnapshot()).hapticsEnabled;

  @override
  Future<void> saveHapticsEnabled(bool enabled) =>
      _update((value) => value.copyWith(hapticsEnabled: enabled));

  @override
  Future<PortablePracticePreferences> loadPortablePreferences() async {
    final value = await _loadSnapshot();
    return PortablePracticePreferences(
      dailyBudget: value.dailyBudget,
      weeklyGoal: value.weeklyGoal,
    );
  }

  @override
  Future<void> savePortablePreferences(PortablePracticePreferences value) =>
      _update(
        (current) => current.copyWith(
          dailyBudget: value.dailyBudget,
          replaceDailyBudget: true,
          weeklyGoal: value.weeklyGoal,
          replaceWeeklyGoal: true,
        ),
      );
}
