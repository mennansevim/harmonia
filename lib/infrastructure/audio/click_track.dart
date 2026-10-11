import 'dart:math' as math;

import 'pcm16_wav.dart';

/// Synthetic reference clicks (1 kHz, 30 ms exponential decay) placed on the
/// exact sample of each onset. Generated locally; no licensed audio.
Pcm16Wav renderClickTrack(
  List<int> onsetsMs, {
  int sampleRateHz = 48000,
  int tailMs = 400,
}) {
  if (onsetsMs.isEmpty || onsetsMs.length > 256) {
    throw ArgumentError('Click track needs 1–256 onsets');
  }
  for (var i = 0; i < onsetsMs.length; i++) {
    if (onsetsMs[i] < 0 || (i > 0 && onsetsMs[i] <= onsetsMs[i - 1])) {
      throw ArgumentError('Onsets must be non-negative and increasing');
    }
  }
  if (onsetsMs.last > 30000) throw ArgumentError('Click track over 30 s');
  final clickSamples = (0.03 * sampleRateHz).round();
  final length = ((onsetsMs.last + tailMs) * sampleRateHz / 1000).ceil();
  final samples = List<double>.filled(length, 0);
  for (final onset in onsetsMs) {
    final start = (onset * sampleRateHz / 1000).round();
    for (var i = 0; i < clickSamples && start + i < length; i++) {
      final t = i / sampleRateHz;
      samples[start + i] +=
          0.5 * math.exp(-t / 0.006) * math.sin(2 * math.pi * 1000 * t);
    }
  }
  return Pcm16Wav(
    sampleRateHz: sampleRateHz,
    samples: [for (final s in samples) s.clamp(-1.0, 1.0)],
  );
}
