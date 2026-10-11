import 'dart:math' as math;

/// Comparison happens AFTER raw frequency detection; it never changes the f0.
class PitchDeviation {
  PitchDeviation({required double detectedHz, required double targetHz}) {
    if (!detectedHz.isFinite ||
        detectedHz <= 0 ||
        !targetHz.isFinite ||
        targetHz <= 0) {
      throw ArgumentError('Pitch comparison requires finite positive Hz');
    }
    // Difference of logs avoids overflow/underflow in detectedHz / targetHz.
    absoluteCents =
        1200 * (math.log(detectedHz) - math.log(targetHz)) / math.ln2;
    octaveOffset = (absoluteCents / 1200).round();
    pitchClassCents = absoluteCents - 1200 * octaveOffset;
  }

  /// Signed cents; keeps octave errors rather than folding to the target.
  late final double absoluteCents;
  late final int octaveOffset;

  /// Nearest-octave residual. Half-octave ties round away from zero.
  late final double pitchClassCents;
}
