import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/data_export.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';

import '../infrastructure/storage/file_result_history_test.dart' show entry;

final _profile = LearnerProfile(
  goal: PracticeGoal.choir,
  createdAt: DateTime.utc(2026, 10, 1),
);

String _export(List<ResultHistoryEntry> e, {LearnerProfile? profile}) =>
    LocalDataExport.encode(
      profile: profile ?? _profile,
      entries: e,
      exportedAt: DateTime.utc(2026, 10, 13, 18, 30, 42, 123),
    );

Map<String, Object?> _doc(String s) => jsonDecode(s) as Map<String, Object?>;

void main() {
  test('round-trip: versioned, minute precision, no audio fields', () {
    final text = _export([entry('attempt-0001'), entry('attempt-0002')]);
    final raw = _doc(text);
    expect(raw['format'], 'harmonia-local-export');
    expect(raw['exportedAt'], '2026-10-13T18:30:00.000Z');
    expect(text.toLowerCase(), isNot(contains('pcm')));
    expect(text.toLowerCase(), isNot(contains('.wav')));
    final doc = LocalDataExport.decode(text);
    expect(doc.profile!.goal, PracticeGoal.choir);
    expect(
      [for (final e in doc.entries) e.attemptId],
      ['attempt-0001', 'attempt-0002'],
    );
    expect(
      jsonEncode(doc.entries.first.toJson()),
      jsonEncode(entry('attempt-0001').toJson()),
    );
    expect(() => doc.entries.clear(), throwsUnsupportedError);
  });

  test('profile may be absent', () {
    final text = LocalDataExport.encode(
      profile: null,
      entries: const [],
      exportedAt: DateTime.utc(2026),
    );
    expect(LocalDataExport.decode(text).profile, isNull);
  });

  String reason(String text) {
    try {
      LocalDataExport.decode(text);
    } on LocalDataFormatException catch (e) {
      return e.reason;
    }
    return 'accepted';
  }

  test('strict: format, version, keys, types and duplicates', () {
    final good = _doc(_export([entry('attempt-0001')]));
    String with_(Map<String, Object?> m) => jsonEncode({...good, ...m});
    expect(reason('not json'), 'not_json');
    expect(reason('[]'), 'not_object');
    expect(reason(with_({'format': 'other'})), 'version');
    expect(reason(with_({'schemaVersion': 2})), 'version');
    expect(reason(with_({'extra': 1})), 'keys');
    expect(reason(jsonEncode({...good}..remove('results'))), 'keys');
    expect(reason(with_({'exportedAt': 'x'})), 'date');
    expect(
      reason(
        with_({
          'profile': {'goal': 'x'},
        }),
      ),
      'profile',
    );
    expect(reason(with_({'results': 'x'})), 'results');
    expect(
      reason(
        with_({
          'results': [1],
        }),
      ),
      'results',
    );
    expect(
      reason(
        with_({
          'results': [
            {'attemptId': 'bad id', 'result': {}},
          ],
        }),
      ),
      'results',
    );
    final r = (good['results'] as List).single;
    expect(
      reason(
        with_({
          'results': [r, r],
        }),
      ),
      'duplicate_attempt',
    );
  });

  test('a late bad entry rejects the whole document', () {
    final good = _doc(_export([entry('attempt-0001'), entry('attempt-0002')]));
    final results = [...good['results'] as List];
    final broken = {...results[1] as Map<String, Object?>}..remove('result');
    results[1] = broken;
    expect(reason(jsonEncode({...good, 'results': results})), 'results');
  });

  test('size budget is checked before parsing', () {
    final big = 'x' * (LocalDataExport.maxUtf8Bytes + 1);
    expect(reason(big), 'too_large');
  });

  test('errors never echo the pasted text', () {
    try {
      LocalDataExport.decode('{"secret": "my-private-note"');
    } on LocalDataFormatException catch (e) {
      expect(e.toString(), isNot(contains('my-private-note')));
    }
  });

  test('import goes through history rules: dedup, conflict kept', () async {
    final h = InMemoryResultHistory(capacity: 3);
    await h.record(entry('attempt-0001'));
    await h.record(entry('attempt-0002', score: 10));
    final doc = LocalDataExport.decode(
      _export([
        entry('attempt-0001'), // identical → duplicate
        entry('attempt-0002', score: 99), // different → conflict, kept
        entry('attempt-0003'), // new
        entry('attempt-0004'), // capacity reached
      ]),
    );
    final r = await LocalDataExport.importResults(doc, h);
    expect((r.recorded, r.duplicate, r.conflict, r.storageFull), (1, 1, 1, 1));
    final stored = await h.load();
    expect(stored, hasLength(3));
    expect(
      stored
          .firstWhere((e) => e.attemptId == 'attempt-0002')
          .result
          .scores
          .overall
          .value,
      10,
    );
  });
}
