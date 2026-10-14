import 'dart:convert';

import 'package:flutter/foundation.dart';

enum ErrorOrigin { framework, platform }

/// One unexpected error, reduced to non-personal fields: no message text
/// (it may contain paths or user input), only the type and the first
/// Harmonia source frame.
@immutable
class ErrorRecord {
  const ErrorRecord({
    required this.at,
    required this.origin,
    required this.type,
    this.location,
  });
  final DateTime at;
  final ErrorOrigin origin;
  final String type;
  final String? location;

  Map<String, Object?> toJson() => {
    'at': at.toIso8601String(),
    'origin': origin.name,
    'type': type,
    'location': location,
  };
}

/// OPS-01a: bounded in-memory log of this run's unexpected errors. Never
/// written to disk or sent anywhere; the user may copy a sanitized report.
class LocalErrorLog extends ChangeNotifier {
  LocalErrorLog({this.capacity = 50, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final int capacity;
  final DateTime Function() _clock;
  final List<ErrorRecord> _records = [];
  var _dropped = 0;

  List<ErrorRecord> get records => List.unmodifiable(_records);

  /// Errors not kept because the log was full (oldest dropped).
  int get dropped => _dropped;

  void record(Object error, StackTrace? stack, ErrorOrigin origin) {
    final t = _clock().toUtc();
    _records.add(
      ErrorRecord(
        at: DateTime.utc(t.year, t.month, t.day, t.hour, t.minute),
        origin: origin,
        type: _typeName(error),
        location: firstAppFrame(stack),
      ),
    );
    if (_records.length > capacity) {
      _records.removeAt(0);
      _dropped++;
    }
    notifyListeners();
  }

  String report({required String channel}) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': 'harmonia-error-report',
        'schemaVersion': 1,
        'channel': channel,
        'dropped': _dropped,
        'errors': [for (final r in _records) r.toJson()],
      });

  static String _typeName(Object error) {
    final name = error.runtimeType.toString();
    // Generic or private implementation names are reduced to a safe token.
    return RegExp(r'^[A-Za-z_][A-Za-z0-9_<>, ]{0,80}$').hasMatch(name)
        ? name
        : 'Error';
  }

  /// `lib/...dart:line` of the first frame in this app, if any.
  static String? firstAppFrame(StackTrace? stack) {
    if (stack == null) return null;
    final m = RegExp(
      r'package:harmonia/([A-Za-z0-9_/]+\.dart):(\d+)',
    ).firstMatch(stack.toString());
    return m == null ? null : 'lib/${m[1]}:${m[2]}';
  }
}
