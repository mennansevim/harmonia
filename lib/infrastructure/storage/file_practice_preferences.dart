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

  /// Missing, corrupt or unreadable → null (defaults); the corrupt file is
  /// left in place and replaced only by the user's next explicit choice.
  @override
  Future<DailyBudget?> loadDailyBudget() async {
    try {
      final json = await _store.read();
      return json == null ? null : PracticePreferencesCodec.decode(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDailyBudget(DailyBudget budget) =>
      _store.write(PracticePreferencesCodec.encode(budget));
}
