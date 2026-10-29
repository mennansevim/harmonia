import 'dart:convert';

import '../domain/models/learner_profile.dart';
import 'practice_preferences.dart';
import 'result_history.dart';

/// DATA-03 (local part): a versioned, audio-free copy of what this device
/// stores — goal and measured result summaries. No upload; the user moves
/// it (clipboard) themselves. Import is strict and never overwrites.
class LocalDataExport {
  const LocalDataExport._();

  static const format = 'harmonia-local-export';
  static const schemaVersion = 2;

  /// Bounded so a pasted document cannot exhaust memory.
  static const maxUtf8Bytes = 4 * 1024 * 1024;
  static const maxEntries = 5000;

  static String encode({
    required LearnerProfile? profile,
    required List<ResultHistoryEntry> entries,
    required DateTime exportedAt,
    PortablePracticePreferences? preferences,
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
      'preferences': preferences?.toJson(),
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
    const v1Keys = {
      'format',
      'schemaVersion',
      'exportedAt',
      'profile',
      'results',
    };
    const v2Keys = {...v1Keys, 'preferences'};
    final version = root['schemaVersion'];
    final keys = version == 1 ? v1Keys : v2Keys;
    if (root.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(root.containsKey)) {
      throw const LocalDataFormatException('keys');
    }
    if (root['format'] != format ||
        (version != 1 && version != schemaVersion)) {
      throw const LocalDataFormatException('version');
    }
    final rawDate = root['exportedAt'];
    if (rawDate is! String) throw const LocalDataFormatException('date');
    final exportedAt = DateTime.tryParse(rawDate);
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
    PortablePracticePreferences? preferences;
    if (version == schemaVersion) {
      final rawPreferences = root['preferences'];
      if (rawPreferences != null) {
        if (rawPreferences is! Map<String, Object?>) {
          throw const LocalDataFormatException('preferences');
        }
        try {
          preferences = PortablePracticePreferences.fromJson(rawPreferences);
        } on FormatException {
          throw const LocalDataFormatException('preferences');
        }
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
      preferences: preferences,
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
    final report = await history.recordAll(doc.entries);
    return ImportReport._(report.counts);
  }
}

class LocalDataDocument {
  LocalDataDocument._({
    required this.exportedAt,
    required this.profile,
    required this.preferences,
    required List<ResultHistoryEntry> entries,
  }) : entries = List.unmodifiable(entries);
  final DateTime exportedAt;
  final LearnerProfile? profile;
  final PortablePracticePreferences? preferences;
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
