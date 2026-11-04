import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/clap_onset_detector.dart';
import 'package:resonia/trainer/koro/clap_rhythm.dart';

void main() {
  test('finds each synthetic clap within 10 ms, once', () {
    const onsets = [300, 600, 900, 1050, 1200, 1800];
    final track = renderClapTrack(onsets).samples;
    // Quiet room noise under the claps.
    final noise = math.Random(3);
    final input = [
      for (final s in track) s * 0.5 + (noise.nextDouble() - .5) * 0.002,
    ];
    final found = <int>[];
    final detector = ClapOnsetDetector(onClap: found.add);
    for (var i = 0; i < input.length; i += 1024) {
      detector.add(input.sublist(i, math.min(i + 1024, input.length)), 48000);
    }
    expect(found, hasLength(onsets.length));
    for (var i = 0; i < onsets.length; i++) {
      expect(found[i], closeTo(onsets[i], 10));
    }
  });

  test('a start-up click is learned as room sound, not a clap', () {
    final found = <int>[];
    final detector = ClapOnsetDetector(onClap: found.add);
    final pop = List<double>.filled(48000, 0.0);
    for (var i = 0; i < 480; i++) {
      pop[i] = 0.6 * math.exp(-i / 60);
    }
    final clap = renderClapTrack(const [500]).samples;
    for (var i = 0; i < clap.length && i < pop.length; i++) {
      pop[i] += clap[i] * 0.5;
    }
    detector.add(pop, 48000);
    expect(found, hasLength(1));
    expect(found.single, closeTo(500, 10));
  });

  test('silence and a steady hum are not claps', () {
    final found = <int>[];
    final detector = ClapOnsetDetector(onClap: found.add);
    detector.add(List.filled(48000, 0.0), 48000);
    detector.add([
      for (var i = 0; i < 48000; i++)
        0.2 * math.sin(2 * math.pi * 220 * i / 48000),
    ], 48000);
    // The hum's start is one onset at most; holding it adds nothing.
    expect(found.length, lessThanOrEqualTo(1));
  });
}
