import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/result_history.dart';
import 'json_file_store.dart';

/// One atomic JSON document; operations are serialized so two quick records
/// cannot lose each other. A corrupt document is reported, never rewritten.
class FileResultHistory implements ResultHistoryRepository {
  FileResultHistory({
    Future<Directory> Function()? directory,
    this.capacity = 1000,
  }) : _store = JsonFileStore(
         directory ?? getApplicationSupportDirectory,
         'result_history',
         maxBytes: 8 << 20,
       );

  static const schemaVersion = 1;
  final JsonFileStore _store;
  final int capacity;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<List<ResultHistoryEntry>> _read() async {
    final Map<String, Object?>? doc;
    try {
      doc = await _store.read();
    } on FormatException {
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
    } catch (_) {
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
    }
    if (doc == null) return [];
    final entries = doc['entries'];
    if (doc['schemaVersion'] != schemaVersion || entries is! List) {
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
    }
    try {
      return [
        for (final e in entries)
          if (e is Map<String, Object?>)
            ResultHistoryEntry.fromJson(e)
          else
            throw const FormatException('entry'),
      ];
    } on FormatException {
      throw const HistoryStorageException(HistoryStorageFailure.corrupt);
    }
  }

  Future<void> _write(List<ResultHistoryEntry> entries) async {
    try {
      await _store.write({
        'schemaVersion': schemaVersion,
        'entries': [for (final e in entries) e.toJson()],
      });
    } catch (_) {
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
    }
  }

  @override
  Future<List<ResultHistoryEntry>> load() =>
      _serial(() async => List.unmodifiable(await _read()));

  @override
  Future<RecordOutcome> record(ResultHistoryEntry entry) => _serial(() async {
    final entries = await _read();
    final outcome = classifyRecord(entries, entry, capacity);
    if (outcome == RecordOutcome.recorded) {
      await _write([...entries, entry]);
    }
    return outcome;
  });

  @override
  Future<BatchRecordReport> recordAll(Iterable<ResultHistoryEntry> incoming) =>
      _serial(() async {
        final current = await _read();
        final plan = planBatchRecords(
          existing: current,
          incoming: incoming,
          capacity: capacity,
        );
        if (plan.report.count(RecordOutcome.recorded) > 0) {
          // JsonFileStore replaces atomically; one failed write cannot expose a
          // prefix of this import/sync batch.
          await _write(plan.entries);
        }
        return plan.report;
      });

  @override
  Future<bool> delete(String attemptId) => _serial(() async {
    final entries = await _read();
    final kept = entries.where((e) => e.attemptId != attemptId).toList();
    if (kept.length == entries.length) return false;
    await _write(kept);
    return true;
  });

  @override
  Future<void> clear() => _serial(() async {
    try {
      await _store.delete();
    } catch (_) {
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
    }
  });
}
