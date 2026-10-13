import 'dart:convert';

import '../domain/models/learner_profile.dart';
import 'result_history.dart';

/// DATA-03 (local part): a versioned, audio-free copy of what this device
/// stores — goal and measured result summaries. No upload; the user moves
/// it (clipboard) themselves. Import is strict and never overwrites.
class LocalDataExport {
  const LocalDataExport._();

  static const format = 'harmonia-local-export';
  static const schemaVersion = 1;

  /// Bounded so a pasted document cannot exhaust memory.
  static const maxUtf8Bytes = 4 * 1024 * 1024;
  static const maxEntries = 5000;

  static String encode({
    required LearnerProfile? profile,
    required List<ResultHistoryEntry> entries,
    required DateTime exportedAt,
  }) {
    final t = exportedAt.toUtc();
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'schemaVersion': schemaVersion,
      // Minute precision: no finer device timing than needed.
      'exportedAt': DateTime.utc(
        t.year,
        t.month,
        t.day,
        t.hour,
        t.minute,
      ).toIso8601String(),
      'profile': profile?.toJson(),
      'results': [for (final e in entries) e.toJson()],
    });
  }

  /// Parses and validates the whole document before anything is applied.
  static LocalDataDocument decode(String text) {
    if (utf8.encode(text).length > maxUtf8Bytes) {
      throw const LocalDataFormatException('too_large');
    }
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      throw const LocalDataFormatException('not_json');
    }
    if (root is! Map<String, Object?>) {
      throw const LocalDataFormatException('not_object');
    }
    const keys = {
      'format',
      'schemaVersion',
      'exportedAt',
      'profile',
      'results',
    };
    if (root.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(root.containsKey)) {
      throw const LocalDataFormatException('keys');
    }
    if (root['format'] != format || root['schemaVersion'] != schemaVersion) {
      throw const LocalDataFormatException('version');
    }
    final exportedAt = DateTime.tryParse(root['exportedAt'] as String? ?? '');
    if (exportedAt == null) throw const LocalDataFormatException('date');
    final p = root['profile'];
    LearnerProfile? profile;
    if (p != null) {
      if (p is! Map<String, Object?>) {
        throw const LocalDataFormatException('profile');
      }
      try {
        profile = LearnerProfile.fromJson(p);
      } on FormatException {
        throw const LocalDataFormatException('profile');
      }
    }
    final rs = root['results'];
    if (rs is! List || rs.length > maxEntries) {
      throw const LocalDataFormatException('results');
    }
    final entries = <ResultHistoryEntry>[];
    final ids = <String>{};
    for (final r in rs) {
      if (r is! Map<String, Object?>) {
        throw const LocalDataFormatException('results');
      }
      final ResultHistoryEntry e;
      try {
        e = ResultHistoryEntry.fromJson(r);
      } on FormatException {
        throw const LocalDataFormatException('results');
      } on ArgumentError {
        throw const LocalDataFormatException('results');
      } on TypeError {
        throw const LocalDataFormatException('results');
      }
      if (!ids.add(e.attemptId)) {
        throw const LocalDataFormatException('duplicate_attempt');
      }
      entries.add(e);
    }
    return LocalDataDocument._(
      exportedAt: exportedAt.toUtc(),
      profile: profile,
      entries: entries,
    );
  }

  /// Adds results through the repository's own rules: duplicates are
  /// counted once, conflicting ids are never overwritten. The profile is
  /// not changed by import (goal stays a user choice in settings).
  static Future<ImportReport> importResults(
    LocalDataDocument doc,
    ResultHistoryRepository history,
  ) async {
    final counts = {for (final o in RecordOutcome.values) o: 0};
    for (final e in doc.entries) {
      final o = await history.record(e);
      counts[o] = counts[o]! + 1;
    }
    return ImportReport._(counts);
  }
}

class LocalDataDocument {
  LocalDataDocument._({
    required this.exportedAt,
    required this.profile,
    required List<ResultHistoryEntry> entries,
  }) : entries = List.unmodifiable(entries);
  final DateTime exportedAt;
  final LearnerProfile? profile;
  final List<ResultHistoryEntry> entries;
}

class ImportReport {
  ImportReport._(Map<RecordOutcome, int> counts)
    : counts = Map.unmodifiable(counts);
  final Map<RecordOutcome, int> counts;
  int get recorded => counts[RecordOutcome.recorded]!;
  int get duplicate => counts[RecordOutcome.duplicate]!;
  int get conflict => counts[RecordOutcome.conflict]!;
  int get storageFull => counts[RecordOutcome.storageFull]!;
}

/// Reason code only; never echoes the pasted text.
class LocalDataFormatException implements Exception {
  const LocalDataFormatException(this.reason);
  final String reason;
  @override
  String toString() => 'LocalDataFormatException($reason)';
}
