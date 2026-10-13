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

/// Two synthetic tones (600 ms each, 300 ms silence between). Local only.
Pcm16Wav renderTonePair(
  double firstHz,
  double secondHz, {
  int sampleRateHz = 48000,
}) {
  final a = Pcm16Wav.tone(
    frequencyHz: firstHz,
    sampleRateHz: sampleRateHz,
    durationSeconds: 0.6,
  );
  final b = Pcm16Wav.tone(
    frequencyHz: secondHz,
    sampleRateHz: sampleRateHz,
    durationSeconds: 0.6,
  );
  return Pcm16Wav(
    sampleRateHz: sampleRateHz,
    samples: [
      ...a.samples,
      ...List.filled((0.3 * sampleRateHz).round(), 0.0),
      ...b.samples,
      ...List.filled((0.2 * sampleRateHz).round(), 0.0),
    ],
  );
}

/// Synthetic tones played one after another: (Hz, seconds) with silence gaps
/// (seconds) after each tone. Local only.
Pcm16Wav renderToneSequence(
  List<(double, double)> tones, {
  List<double>? gapsAfter,
  int sampleRateHz = 48000,
}) {
  if (tones.isEmpty || tones.length > 16) {
    throw ArgumentError('Need 1–16 tones');
  }
  final gaps = gapsAfter ?? List.filled(tones.length, 0.1);
  if (gaps.length != tones.length || gaps.any((g) => g < 0 || g > 2)) {
    throw ArgumentError('Gaps must match tones (0–2 s)');
  }
  final samples = <double>[];
  for (var i = 0; i < tones.length; i++) {
    final (hz, seconds) = tones[i];
    samples.addAll(
      Pcm16Wav.tone(
        frequencyHz: hz,
        sampleRateHz: sampleRateHz,
        durationSeconds: seconds,
      ).samples,
    );
    samples.addAll(List.filled((gaps[i] * sampleRateHz).round(), 0.0));
  }
  return Pcm16Wav(sampleRateHz: sampleRateHz, samples: samples);
}
