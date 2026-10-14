import 'dart:math' as math;

import '../models/exercise.dart';

/// 12-TET target metadata, not analysis of a recording or a student's score.
abstract final class TargetNoteTuning {
  /// Allows stored frequencies rounded to 2 decimals (e.g. C4=261.63).
  /// The tiny epsilon covers binary rounding, NOT acoustic/student tolerance.
  static const maxMetadataRoundingHz = 0.005000001;
  static final _name = RegExp(r'^([A-G])([#b]?)(-1|[0-9])$');
  static const _semitones = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  static int midiFor(String note) {
    final match = _name.firstMatch(note);
    if (match == null || match.end != note.length) {
      throw ArgumentError('Expected scientific target note');
    }
    final accidental = switch (match.group(2)) {
      '#' => 1,
      'b' => -1,
      _ => 0,
    };
    final midi =
        (int.parse(match.group(3)!) + 1) * 12 +
        _semitones[match.group(1)]! +
        accidental;
    if (midi < 0 || midi > 127) {
      throw ArgumentError('Target note outside MIDI range');
    }
    return midi;
  }

  static double frequencyFor(String note, {required double a4Hz}) {
    if (!a4Hz.isFinite || a4Hz <= 0) throw ArgumentError('Invalid A4 tuning');
    final frequency = a4Hz * math.pow(2, (midiFor(note) - 69) / 12);
    if (!frequency.isFinite || frequency <= 0) {
      throw ArgumentError('Invalid target frequency');
    }
    return frequency;
  }

  static void validate(TargetNote target, {required double a4Hz}) {
    final expected = frequencyFor(target.note, a4Hz: a4Hz);
    if (!target.frequencyHz.isFinite ||
        target.frequencyHz <= 0 ||
        (target.frequencyHz - expected).abs() > maxMetadataRoundingHz) {
      throw ArgumentError('Target label/frequency/A4 metadata conflict');
    }
  }
}
