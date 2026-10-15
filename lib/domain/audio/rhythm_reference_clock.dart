import '../models/exercise_protocol.dart';

/// Technical click-rendering budget, not a student timing tolerance.
class RhythmReferenceClock {
  static const maxOnsetMs = 30000;

  /// Rejects overflow and millisecond collisions before playback or scoring.
  /// Never clamps, drops beats or changes the reference tempo.
  static List<int>? onsetsMs(ExerciseProtocol protocol) {
    final beats = protocol.rhythmOnsetsBeats;
    if (beats.length < 2 || beats.length > 256) return null;
    final beatMs = 60000 / protocol.tempoBpm;
    if (!beatMs.isFinite || beatMs <= 0) return null;
    final result = <int>[];
    for (final beat in beats) {
      final ms = beat * beatMs;
      if (!ms.isFinite || ms < 0 || ms > maxOnsetMs) return null;
      final onset = ms.round();
      if (result.isNotEmpty && onset <= result.last) return null;
      result.add(onset);
    }
    return List.unmodifiable(result);
  }
}
