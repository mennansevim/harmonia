import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'exercise_protocol.dart';

/// Stable identity for the complete, validated exercise protocol.
///
/// This binds comparable evidence to the exact stimulus and aid policy. It is
/// not a content-rights signature and does not authenticate an audio file.
abstract final class ExerciseProtocolFingerprint {
  static const measurementKey = 'protocolFingerprint';
  static const algorithm = 'exercise-protocol-v1-sha256';

  static String compute(ExerciseProtocol protocol) {
    final canonical = jsonEncode(protocol.toJson());
    return '$algorithm:${sha256.convert(utf8.encode(canonical))}';
  }

  static bool isValid(String value) =>
      RegExp('^$algorithm:[a-f0-9]{64}\$').hasMatch(value);
}
