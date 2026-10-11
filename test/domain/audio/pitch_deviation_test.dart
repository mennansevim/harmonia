import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/pitch_deviation.dart';

void main() {
  test('absolute signed cents and pitch-class residual are distinct', () {
    final up = PitchDeviation(detectedHz: 880, targetHz: 440);
    expect(up.absoluteCents, closeTo(1200, 1e-9));
    expect(up.octaveOffset, 1);
    expect(up.pitchClassCents, closeTo(0, 1e-9));
    final down = PitchDeviation(detectedHz: 220, targetHz: 440);
    expect(down.absoluteCents, closeTo(-1200, 1e-9));
    expect(down.octaveOffset, -1);
  });
  test('non-octave error remains signed', () {
    final result = PitchDeviation(detectedHz: 466.1637615, targetHz: 440);
    expect(result.absoluteCents, closeTo(100, 1e-5));
    expect(result.pitchClassCents, closeTo(100, 1e-5));
    expect(result.octaveOffset, 0);
  });
  test('extreme positive finite inputs do not overflow their ratio', () {
    final result = PitchDeviation(detectedHz: 1e300, targetHz: 1e-300);
    expect(result.absoluteCents.isFinite, isTrue);
    expect(result.pitchClassCents.isFinite, isTrue);
    expect(result.pitchClassCents.abs(), lessThanOrEqualTo(600));
  });
  test('invalid frequency comparisons throw, not zero-error evidence', () {
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => PitchDeviation(detectedHz: value, targetHz: 440),
        throwsArgumentError,
      );
      expect(
        () => PitchDeviation(detectedHz: 440, targetHz: value),
        throwsArgumentError,
      );
    }
  });
}
