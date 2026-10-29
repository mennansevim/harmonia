import '../domain/learning/daily_plan.dart';

/// SHELL-04: small on-device practice preferences (no account, no upload).
/// Convenience only: a failed read falls back to defaults, never blocks.
abstract interface class PracticePreferencesRepository {
  Future<DailyBudget?> loadDailyBudget();
  Future<void> saveDailyBudget(DailyBudget budget);
  Future<WeeklyPracticeGoal?> loadWeeklyGoal();
  Future<void> saveWeeklyGoal(WeeklyPracticeGoal? goal);
  Future<PracticeReminderTime?> loadReminderTime();
  Future<void> saveReminderTime(PracticeReminderTime? time);
  Future<bool> loadHapticsEnabled();
  Future<void> saveHapticsEnabled(bool enabled);
  Future<PortablePracticePreferences> loadPortablePreferences();
  Future<void> savePortablePreferences(PortablePracticePreferences value);
}

/// Settings safe to move between devices. Reminder time and haptics stay on
/// the source device because notification permission/scheduling and tactile
/// feedback are device-specific choices.
class PortablePracticePreferences {
  const PortablePracticePreferences({this.dailyBudget, this.weeklyGoal});

  final DailyBudget? dailyBudget;
  final WeeklyPracticeGoal? weeklyGoal;

  Map<String, Object?> toJson() => {
    'dailyBudgetMinutes': dailyBudget?.minutes,
    'weeklyGoalDays': weeklyGoal?.days,
  };

  static PortablePracticePreferences fromJson(Map<String, Object?> json) {
    const keys = {'dailyBudgetMinutes', 'weeklyGoalDays'};
    if (json.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(json.containsKey)) {
      throw const FormatException('Invalid portable preferences');
    }
    final budget = json['dailyBudgetMinutes'];
    final goal = json['weeklyGoalDays'];
    return PortablePracticePreferences(
      dailyBudget: budget == null
          ? null
          : PracticePreferencesCodec.budget(budget),
      weeklyGoal: goal == null ? null : PracticePreferencesCodec.goal(goal),
    );
  }
}

class PracticeReminderTime {
  PracticeReminderTime({required this.hour, required this.minute}) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time');
    }
  }

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is PracticeReminderTime &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

enum WeeklyPracticeGoal {
  two(2),
  three(3),
  four(4),
  five(5);

  const WeeklyPracticeGoal(this.days);
  final int days;
}

class PracticePreferencesSnapshot {
  const PracticePreferencesSnapshot({
    this.dailyBudget,
    this.weeklyGoal,
    this.reminderTime,
    this.hapticsEnabled = true,
  });

  final DailyBudget? dailyBudget;
  final WeeklyPracticeGoal? weeklyGoal;
  final PracticeReminderTime? reminderTime;
  final bool hapticsEnabled;

  PracticePreferencesSnapshot copyWith({
    DailyBudget? dailyBudget,
    bool replaceDailyBudget = false,
    WeeklyPracticeGoal? weeklyGoal,
    bool replaceWeeklyGoal = false,
    PracticeReminderTime? reminderTime,
    bool replaceReminderTime = false,
    bool? hapticsEnabled,
  }) => PracticePreferencesSnapshot(
    dailyBudget: replaceDailyBudget ? dailyBudget : this.dailyBudget,
    weeklyGoal: replaceWeeklyGoal ? weeklyGoal : this.weeklyGoal,
    reminderTime: replaceReminderTime ? reminderTime : this.reminderTime,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
  );
}

class InMemoryPracticePreferences implements PracticePreferencesRepository {
  DailyBudget? _budget;
  WeeklyPracticeGoal? _weeklyGoal;
  PracticeReminderTime? _reminderTime;
  bool _hapticsEnabled = true;
  @override
  Future<DailyBudget?> loadDailyBudget() async => _budget;
  @override
  Future<void> saveDailyBudget(DailyBudget budget) async => _budget = budget;
  @override
  Future<WeeklyPracticeGoal?> loadWeeklyGoal() async => _weeklyGoal;
  @override
  Future<void> saveWeeklyGoal(WeeklyPracticeGoal? goal) async {
    _weeklyGoal = goal;
  }

  @override
  Future<PracticeReminderTime?> loadReminderTime() async => _reminderTime;
  @override
  Future<void> saveReminderTime(PracticeReminderTime? time) async {
    _reminderTime = time;
  }

  @override
  Future<bool> loadHapticsEnabled() async => _hapticsEnabled;
  @override
  Future<void> saveHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
  }

  @override
  Future<PortablePracticePreferences> loadPortablePreferences() async =>
      PortablePracticePreferences(
        dailyBudget: _budget,
        weeklyGoal: _weeklyGoal,
      );

  @override
  Future<void> savePortablePreferences(
    PortablePracticePreferences value,
  ) async {
    _budget = value.dailyBudget;
    _weeklyGoal = value.weeklyGoal;
  }
}

/// Strict document codec shared by storage adapters.
abstract final class PracticePreferencesCodec {
  static const schemaVersion = 4;

  static Map<String, Object?> encode(DailyBudget budget) => {
    'schemaVersion': schemaVersion,
    'dailyBudgetMinutes': budget.minutes,
    'weeklyGoalDays': null,
    'reminderHour': null,
    'reminderMinute': null,
    'hapticsEnabled': true,
  };

  static Map<String, Object?> encodeSnapshot(
    PracticePreferencesSnapshot value,
  ) => {
    'schemaVersion': schemaVersion,
    'dailyBudgetMinutes': value.dailyBudget?.minutes,
    'weeklyGoalDays': value.weeklyGoal?.days,
    'reminderHour': value.reminderTime?.hour,
    'reminderMinute': value.reminderTime?.minute,
    'hapticsEnabled': value.hapticsEnabled,
  };

  static PracticePreferencesSnapshot decodeSnapshot(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version == 1 && json.length == 2) {
      return PracticePreferencesSnapshot(
        dailyBudget: budget(json['dailyBudgetMinutes']),
      );
    }
    if (version == 2 && json.length == 3) {
      final budgetValue = json['dailyBudgetMinutes'];
      final goalValue = json['weeklyGoalDays'];
      return PracticePreferencesSnapshot(
        dailyBudget: budgetValue == null ? null : budget(budgetValue),
        weeklyGoal: goalValue == null ? null : goal(goalValue),
      );
    }
    if (version == 3 && json.length == 5) {
      return _decodeCurrent(json, hapticsEnabled: true);
    }
    if (version != schemaVersion || json.length != 6) {
      throw const FormatException('Unsupported preferences');
    }
    final hapticsEnabled = json['hapticsEnabled'];
    if (hapticsEnabled is! bool) {
      throw const FormatException('Invalid haptics preference');
    }
    return _decodeCurrent(json, hapticsEnabled: hapticsEnabled);
  }

  static PracticePreferencesSnapshot _decodeCurrent(
    Map<String, Object?> json, {
    required bool hapticsEnabled,
  }) {
    final budgetValue = json['dailyBudgetMinutes'];
    final goalValue = json['weeklyGoalDays'];
    final reminderHour = json['reminderHour'];
    final reminderMinute = json['reminderMinute'];
    if ((reminderHour == null) != (reminderMinute == null)) {
      throw const FormatException('Incomplete reminder time');
    }
    return PracticePreferencesSnapshot(
      dailyBudget: budgetValue == null ? null : budget(budgetValue),
      weeklyGoal: goalValue == null ? null : goal(goalValue),
      reminderTime: reminderHour == null
          ? null
          : _reminder(reminderHour, reminderMinute),
      hapticsEnabled: hapticsEnabled,
    );
  }

  static DailyBudget decode(Map<String, Object?> json) {
    final budget = decodeSnapshot(json).dailyBudget;
    if (budget == null) throw const FormatException('Missing budget');
    return budget;
  }

  static DailyBudget budget(Object? value) {
    final match = DailyBudget.values.where((b) => b.minutes == value);
    if (match.length != 1) throw const FormatException('Invalid budget');
    return match.single;
  }

  static WeeklyPracticeGoal goal(Object? value) {
    final match = WeeklyPracticeGoal.values.where((g) => g.days == value);
    if (match.length != 1) throw const FormatException('Invalid weekly goal');
    return match.single;
  }

  static PracticeReminderTime _reminder(Object? hour, Object? minute) {
    if (hour is! int ||
        minute is! int ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException('Invalid reminder time');
    }
    return PracticeReminderTime(hour: hour, minute: minute);
  }
}
