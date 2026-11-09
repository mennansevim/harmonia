// Compute-cost benchmark of the shipped pitch pipeline (desktop AOT).
// Numbers are for THIS machine, not a phone.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:resonia/domain/audio/live_pitch_tracker.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/audio/yin_pitch_frame_analyzer.dart';

Float64List voice(int sr, double seconds, double f0) {
  final n = (sr * seconds).round();
  final x = Float64List(n);
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    var s = 0.0;
    for (var k = 1; k <= 12; k++) {
      s += math.sin(2 * math.pi * f0 * k * t) / k;
    }
    x[i] = .1 * s;
  }
  return x;
}

double ms(Stopwatch s) => s.elapsedMicroseconds / 1000;

void main() {
  final b = StringBuffer();
  b.writeln(
    'cores: ${Platform.numberOfProcessors}, ${Platform.operatingSystemVersion}',
  );
  final det = YinPitchFrameAnalyzer();
  for (final (sr, f0) in [(48000, 110.0), (48000, 440.0), (16000, 110.0)]) {
    final size = det.recommendedFrameSamples(sr);
    final x = voice(sr, 1.0, f0);
    final frame = Float64List.sublistView(x, 0, size);
    for (var i = 0; i < 20; i++) {
      det.analyze(frame, sampleRateHz: sr);
    }
    final sw = Stopwatch()..start();
    const iters = 200;
    for (var i = 0; i < iters; i++) {
      det.analyze(frame, sampleRateHz: sr);
    }
    sw.stop();
    b.writeln(
      'YIN frame size=$size @${sr}Hz f0=${f0.round()}: ${(ms(sw) / iters).toStringAsFixed(2)} ms/frame',
    );
  }
  // Worst case: 10 s at 48 kHz silence-free voice.
  final long = voice(48000, 10, 196);
  final an = RecordingPitchAnalyzer();
  an.analyze(samples: long, sampleRateHz: 48000);
  final sw = Stopwatch()..start();
  RecordingPitchEvidence? ev;
  for (var i = 0; i < 3; i++) {
    ev = an.analyze(samples: long, sampleRateHz: 48000);
  }
  sw.stop();
  b.writeln(
    'RecordingPitchAnalyzer 10 s @48k (${ev!.frames.length} frames): ${(ms(sw) / 3).toStringAsFixed(0)} ms per recording',
  );
  // 3 s typical sing-back
  final short = voice(48000, 3, 196);
  final sw2 = Stopwatch()..start();
  for (var i = 0; i < 10; i++) {
    an.analyze(samples: short, sampleRateHz: 48000);
  }
  sw2.stop();
  b.writeln(
    'RecordingPitchAnalyzer 3 s @48k: ${(ms(sw2) / 10).toStringAsFixed(0)} ms per recording',
  );

  // Live tracker: stream 10 s at 48 kHz in 20 ms chunks.
  var hops = 0;
  final tracker = LivePitchTracker(onPitch: (_) => hops++);
  final live = voice(48000, 10, 196);
  final chunk = 960;
  final sw3 = Stopwatch()..start();
  for (var i = 0; i + chunk <= live.length; i += chunk) {
    tracker.add(Float64List.sublistView(live, i, i + chunk), 48000);
  }
  sw3.stop();
  b.writeln(
    'LivePitchTracker 10 s stream: ${ms(sw3).toStringAsFixed(0)} ms total for $hops hops = ${(ms(sw3) / hops).toStringAsFixed(2)} ms/hop; real-time budget 20 ms/hop → ${(100 * ms(sw3) / 10000).toStringAsFixed(1)}% of one core',
  );
  stdout.write(b);
}
