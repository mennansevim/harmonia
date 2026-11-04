import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/live_pitch_tracker.dart';

List<double> _sine(double hz, int rate, double seconds, {double amp = 0.3}) => [
  for (var i = 0; i < rate * seconds; i++)
    amp * math.sin(2 * math.pi * hz * i / rate),
];

void main() {
  test('tracks a steady 48 kHz tone every 20 ms', () {
    final out = <double?>[];
    final tracker = LivePitchTracker(onPitch: out.add);
    final tone = _sine(220, 48000, 1);
    // Uneven chunks, as the recorder delivers them.
    for (var i = 0; i < tone.length; i += 1777) {
      tracker.add(tone.sublist(i, math.min(i + 1777, tone.length)), 48000);
    }
    // 1 s at 16 kHz, first frame after 64 ms, then one per 20 ms hop.
    expect(out.length, inInclusiveRange(46, 50));
    for (final hz in out) {
      expect(hz, isNotNull);
      expect(1200 * math.log(hz! / 220) / math.ln2, closeTo(0, 10));
    }
  });

  test('silence reports no pitch, and reset starts a new window', () {
    final out = <double?>[];
    final tracker = LivePitchTracker(onPitch: out.add);
    tracker.add(List.filled(48000 ~/ 2, 0.0), 48000);
    expect(out, isNotEmpty);
    expect(out.every((hz) => hz == null), isTrue);
    out.clear();
    tracker
      ..reset()
      ..add(_sine(330, 48000, 0.05), 48000);
    expect(out, isEmpty);
  });
}
