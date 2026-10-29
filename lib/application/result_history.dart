import 'dart:convert';

import '../domain/models/exercise_result.dart';

class ResultHistoryEntry {
  ResultHistoryEntry({required this.attemptId, required this.result}) {
    if (!RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(attemptId)) {
      throw ArgumentError('Invalid attempt id');
    }
  }
  final String attemptId;
  final ExerciseResult result;

  Map<String, Object?> toJson() => {
    'attemptId': attemptId,
    'result': result.toJson(),
  };

  factory ResultHistoryEntry.fromJson(Map<String, Object?> json) {
    final id = json['attemptId'];
    final result = json['result'];
    if (id is! String || result is! Map<String, Object?>) {
      throw const FormatException('Invalid history entry');
    }
    try {
      return ResultHistoryEntry(
        attemptId: id,
        result: ExerciseResult.fromJson(result),
      );
    } on ArgumentError {
      throw const FormatException('Invalid attempt id');
    }
  }
}

enum RecordOutcome { recorded, duplicate, conflict, storageFull }

enum HistoryStorageFailure { corrupt, unavailable }

class HistoryStorageException implements Exception {
  const HistoryStorageException(this.failure);
  final HistoryStorageFailure failure;
  @override
  String toString() => 'HistoryStorageException(${failure.name})';
}

/// Local-only attempt history. An attempt id is recorded at most once:
/// the same id with identical content is a duplicate (no double count), with
/// different content a conflict (nothing overwritten). No silent pruning.
abstract interface class ResultHistoryRepository {
  Future<List<ResultHistoryEntry>> load();
  Future<RecordOutcome> record(ResultHistoryEntry entry);

  /// Applies a bounded group with the same dedup/conflict rules in one local
  /// storage commit. A storage failure must not leave a partial batch.
  Future<BatchRecordReport> recordAll(Iterable<ResultHistoryEntry> entries);
  Future<bool> delete(String attemptId);
  Future<void> clear();
}

class BatchRecordReport {
  BatchRecordReport._(Map<RecordOutcome, int> counts)
    : counts = Map.unmodifiable(counts);

  final Map<RecordOutcome, int> counts;
  int count(RecordOutcome outcome) => counts[outcome] ?? 0;
}

class BatchRecordPlan {
  BatchRecordPlan._({
    required List<ResultHistoryEntry> entries,
    required this.report,
  }) : entries = List.unmodifiable(entries);

  final List<ResultHistoryEntry> entries;
  final BatchRecordReport report;
}

/// Shared rule set for every implementation.
RecordOutcome classifyRecord(
  List<ResultHistoryEntry> existing,
  ResultHistoryEntry entry,
  int capacity,
) {
  for (final e in existing) {
    if (e.attemptId == entry.attemptId) {
      return jsonEncode(e.toJson()) == jsonEncode(entry.toJson())
          ? RecordOutcome.duplicate
          : RecordOutcome.conflict;
    }
  }
  return existing.length >= capacity
      ? RecordOutcome.storageFull
      : RecordOutcome.recorded;
}

/// Pure planning shared by memory/file adapters. Input order is retained and
/// capacity is explicit; duplicate/conflicting attempt ids never overwrite.
BatchRecordPlan planBatchRecords({
  required List<ResultHistoryEntry> existing,
  required Iterable<ResultHistoryEntry> incoming,
  required int capacity,
}) {
  if (capacity < 0 || existing.length > capacity) {
    throw ArgumentError('Invalid history capacity');
  }
  final working = List<ResultHistoryEntry>.of(existing);
  final counts = {for (final outcome in RecordOutcome.values) outcome: 0};
  for (final entry in incoming) {
    final outcome = classifyRecord(working, entry, capacity);
    counts[outcome] = counts[outcome]! + 1;
    if (outcome == RecordOutcome.recorded) working.add(entry);
  }
  return BatchRecordPlan._(
    entries: working,
    report: BatchRecordReport._(counts),
  );
}

class InMemoryResultHistory implements ResultHistoryRepository {
  InMemoryResultHistory({this.capacity = 1000});
  final int capacity;
  final List<ResultHistoryEntry> _entries = [];

  @override
  Future<List<ResultHistoryEntry>> load() async => List.unmodifiable(_entries);

  @override
  Future<RecordOutcome> record(ResultHistoryEntry entry) async {
    final outcome = classifyRecord(_entries, entry, capacity);
    if (outcome == RecordOutcome.recorded) _entries.add(entry);
    return outcome;
  }

  @override
  Future<BatchRecordReport> recordAll(
    Iterable<ResultHistoryEntry> entries,
  ) async {
    final plan = planBatchRecords(
      existing: _entries,
      incoming: entries,
      capacity: capacity,
    );
    _entries
      ..clear()
      ..addAll(plan.entries);
    return plan.report;
  }

  @override
  Future<bool> delete(String attemptId) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.attemptId == attemptId);
    return _entries.length != before;
  }

  @override
  Future<void> clear() async => _entries.clear();
}
