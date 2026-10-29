import 'dart:math' as math;

import '../../infrastructure/audio/pcm16_wav.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';

/// Locally generated instrument colours. Additive synthesis only: no
/// recorded or licensed samples are bundled.
enum Timbre { piano, guitar, cello, clarinet, trumpet, sine }

extension TimbreInfo on Timbre {
  String get label => switch (this) {
    Timbre.piano => 'Piyano',
    Timbre.guitar => 'Gitar',
    Timbre.cello => 'Çello',
    Timbre.clarinet => 'Klarnet',
    Timbre.trumpet => 'Trompet',
    Timbre.sine => 'Sinüs',
  };
}

class _Voice {
  const _Voice(this.harmonics, this.decay, this.attack, this.release);

  /// (harmonic number, amplitude, extra decay per second)
  final List<(int, double, double)> harmonics;

  /// Base amplitude decay per second (0 = sustained).
  final double decay;
  final double attack;
  final double release;
}

const _voices = {
  Timbre.piano: _Voice(
    [
      (1, 1.0, 0),
      (2, 0.45, 1.2),
      (3, 0.22, 2.0),
      (4, 0.12, 2.8),
      (5, 0.06, 3.5),
    ],
    1.6,
    0.004,
    0.08,
  ),
  Timbre.guitar: _Voice(
    [(1, 1.0, 0), (2, 0.6, 2.0), (3, 0.35, 3.0), (4, 0.2, 4.0), (6, 0.08, 6)],
    2.6,
    0.002,
    0.05,
  ),
  Timbre.cello: _Voice(
    [(1, 1.0, 0), (2, 0.7, 0), (3, 0.5, 0), (4, 0.3, 0), (5, 0.18, 0)],
    0.15,
    0.06,
    0.12,
  ),
  Timbre.clarinet: _Voice(
    [(1, 1.0, 0), (3, 0.55, 0), (5, 0.3, 0), (7, 0.14, 0)],
    0.1,
    0.03,
    0.08,
  ),
  Timbre.trumpet: _Voice(
    [(1, 0.8, 0), (2, 0.9, 0), (3, 0.7, 0), (4, 0.5, 0), (5, 0.3, 0)],
    0.2,
    0.03,
    0.08,
  ),
  Timbre.sine: _Voice([(1, 1.0, 0)], 0.3, 0.01, 0.06),
};

class TrainerSynth {
  const TrainerSynth({this.sampleRateHz = 22050});
  final int sampleRateHz;

  Pcm16Wav render(SoundSpec spec, Timbre timbre) {
    final voice = _voices[timbre]!;
    final total = ((spec.durationSeconds + 0.25) * sampleRateHz).ceil();
    final out = List<double>.filled(total, 0);
    final nyquist = sampleRateHz / 2;
    for (final event in spec.events) {
      final start = (event.startSeconds * sampleRateHz).round();
      final length = (event.durationSeconds * sampleRateHz).round();
      final releaseSamples = (voice.release * sampleRateHz).round();
      final gain = 0.9 / math.sqrt(event.midiNotes.length.toDouble());
      for (final midi in event.midiNotes) {
        final f0 = midiToHz(midi);
        // Lower notes ring longer, like a real string.
        final decayScale = math.pow(f0 / 262, 0.35).toDouble();
        for (final (h, amp, extra) in voice.harmonics) {
          final f = f0 * h;
          if (f >= nyquist * 0.95) continue;
          final w = 2 * math.pi * f / sampleRateHz;
          final d = (voice.decay * decayScale + extra) / sampleRateHz;
          for (var i = 0; i < length + releaseSamples; i++) {
            final at = start + i;
            if (at >= total) break;
            final t = i / sampleRateHz;
            var env = math.exp(-d * i);
            if (t < voice.attack) env *= t / voice.attack;
            if (i > length) {
              env *= 1 - (i - length) / releaseSamples;
            }
            out[at] += gain * amp * env * math.sin(w * i);
          }
        }
      }
    }
    var peak = 0.0;
    for (final s in out) {
      peak = math.max(peak, s.abs());
    }
    final scale = peak > 0 ? 0.8 / peak : 0.0;
    return Pcm16Wav(
      sampleRateHz: sampleRateHz,
      samples: [for (final s in out) (s * scale).clamp(-1.0, 1.0)],
    );
  }
}
