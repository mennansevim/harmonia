import '../domain/learning/daily_plan.dart';

/// SHELL-04: small on-device practice preferences (no account, no upload).
/// Convenience only: a failed read falls back to defaults, never blocks.
abstract interface class PracticePreferencesRepository {
  Future<DailyBudget?> loadDailyBudget();
  Future<void> saveDailyBudget(DailyBudget budget);
}

class InMemoryPracticePreferences implements PracticePreferencesRepository {
  DailyBudget? _budget;
  @override
  Future<DailyBudget?> loadDailyBudget() async => _budget;
  @override
  Future<void> saveDailyBudget(DailyBudget budget) async => _budget = budget;
}

/// Strict document codec shared by storage adapters.
abstract final class PracticePreferencesCodec {
  static const schemaVersion = 1;

  static Map<String, Object?> encode(DailyBudget budget) => {
    'schemaVersion': schemaVersion,
    'dailyBudgetMinutes': budget.minutes,
  };

  static DailyBudget decode(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion || json.length != 2) {
      throw const FormatException('Unsupported preferences');
    }
    final m = json['dailyBudgetMinutes'];
    final match = DailyBudget.values.where((b) => b.minutes == m);
    if (match.length != 1) throw const FormatException('Invalid budget');
    return match.single;
  }
}
