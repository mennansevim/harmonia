import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/domain/learning/daily_plan.dart';
import 'package:harmonia/infrastructure/storage/file_practice_preferences.dart';

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
    ]) {
      expect(() => PracticePreferencesCodec.decode(bad), throwsFormatException);
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
}
