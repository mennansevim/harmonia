import 'dart:math' as math;

import '../../infrastructure/audio/pcm16_wav.dart';
import '../domain/trainers.dart';
import 'piano_notes.dart';

/// One recorded note ready to play: samples from its onset on, and how many
/// semitones it must be moved to sound the wanted note.
class PianoSource {
  const PianoSource(this.samples, this.sampleRateHz, this.shift);
  final List<double> samples;
  final int sampleRateHz;

  /// Wanted MIDI minus recorded MIDI; 0 or ±1.
  final int shift;
}

/// Renders single-note sounds from the cleared piano recordings
/// ([PianoNoteBank]). A spec is played from recordings only when every one
/// of its events is a single note the recordings can sound; otherwise
/// [render] returns null and the caller plays the whole spec on the synth,
/// so one question never mixes two instruments. Chords and harmonic
/// intervals are never built from single recordings here: they wait for
/// the pre-recorded 2/3/4-voice piano takes (AGENTS).
class PianoSampler {
  PianoSampler(this.bank);
  final PianoNoteBank bank;

  /// Recordings cover white keys; a black key borrows a neighbour moved by
  /// one semitone (about 6 % shorter or longer, inaudible as a timbre change).
  static const maxShift = 1;

  /// Fade at the end of each note's written length, like the synth's release.
  static const releaseSeconds = 0.12;

  /// Ease-in at each note's start. Short enough to keep the hammer's attack,
  /// long enough that a take starting mid-waveform does not click.
  static const fadeInSeconds = 0.005;

  /// Raised cosine 0 → 1: no corner at either end.
  static double _ease(double t) => 0.5 - 0.5 * math.cos(math.pi * t);

  final _sources = <int, Future<_Recorded?>>{};

  /// The source for [midi]: its own recording, else the white key above
  /// (moved down), else the one below (moved up). Null when none is cleared.
  Future<PianoSource?> sourceFor(int midi) async {
    for (final shift in const [0, -1, 1]) {
      if (shift.abs() > maxShift) continue;
      final rec = await (_sources[midi - shift] ??= _load(midi - shift));
      if (rec != null) return PianoSource(rec.samples, rec.rate, shift);
    }
    return null;
  }

  Future<_Recorded?> _load(int midi) async {
    if (PianoNoteBank.noteName(midi) == null) return null;
    final bytes = await bank.wav(midi);
    if (bytes == null) return null;
    try {
      final wav = Pcm16Wav.decode(bytes);
      return _Recorded(
        trimOnset(wav.samples, rate: wav.sampleRateHz),
        wav.sampleRateHz,
      );
    } catch (_) {
      return null;
    }
  }

  /// The recorded rendering of [spec], or null when it must stay synthetic.
  Future<Pcm16Wav?> render(SoundSpec spec) async {
    if (spec.events.isEmpty ||
        spec.events.any((e) => e.midiNotes.length != 1)) {
      return null;
    }
    final sources = <int, PianoSource>{};
    for (final e in spec.events) {
      final midi = e.midiNotes.single;
      if (sources.containsKey(midi)) continue;
      final source = await sourceFor(midi);
      if (source == null) return null;
      sources[midi] = source;
    }
    return mix(spec, sources);
  }

  /// Drops the silence before the attack (recordings start 0–0.4 s late),
  /// keeping 5 ms before the first sample above 5 % of the peak.
  static List<double> trimOnset(List<double> samples, {int rate = 48000}) {
    var peak = 0.0;
    for (final s in samples) {
      peak = math.max(peak, s.abs());
    }
    if (peak == 0) return samples;
    final first = samples.indexWhere((s) => s.abs() > 0.05 * peak);
    final from = math.max(0, first - rate * 5 ~/ 1000);
    return samples.sublist(from);
  }

  /// Places each event's note at its start, moved by its shift, cut with a
  /// short fade at its written length; peak-normalised to 0.8 like the synth.
  /// Null when sources disagree on sample rate.
  static Pcm16Wav? mix(SoundSpec spec, Map<int, PianoSource> sources) {
    final rates = sources.values.map((s) => s.sampleRateHz).toSet();
    if (rates.length != 1) return null;
    final rate = rates.single;
    final release = (releaseSeconds * rate).round();
    final fadeIn = (fadeInSeconds * rate).round();
    final total = ((spec.durationSeconds + releaseSeconds + 0.02) * rate)
        .ceil();
    final out = List<double>.filled(total, 0);
    for (final e in spec.events) {
      final source = sources[e.midiNotes.single]!;
      final step = math.pow(2, source.shift / 12).toDouble();
      final start = (e.startSeconds * rate).round();
      final src = source.samples;
      // Output samples the recording can feed; the release must end inside
      // it, so a short take is faded early rather than cut off (a click).
      final available = ((src.length - 2) / step).floor();
      final length = math.min(
        (e.durationSeconds * rate).round() + release,
        available,
      );
      if (length <= 0) continue;
      final hold = math.max(0, length - release);
      final fadeOut = length - hold;
      for (var i = 0; i < length; i++) {
        final at = start + i;
        if (at >= total) break;
        // Linear-interpolated read: moving pitch by [step].
        final pos = i * step;
        final j = pos.floor();
        var v = src[j] + (src[j + 1] - src[j]) * (pos - j);
        // Some takes begin mid-attack: a jump from silence to a loud sample
        // pops on a speaker, so every note eases in and out on a cosine.
        if (i < fadeIn) v *= _ease(i / fadeIn);
        if (i >= hold) v *= _ease(1 - (i - hold) / fadeOut);
        out[at] += v;
      }
    }
    var peak = 0.0;
    for (final s in out) {
      peak = math.max(peak, s.abs());
    }
    final scale = peak > 0 ? 0.8 / peak : 0.0;
    return Pcm16Wav(
      sampleRateHz: rate,
      samples: [for (final s in out) (s * scale).clamp(-1.0, 1.0)],
    );
  }
}

class _Recorded {
  const _Recorded(this.samples, this.rate);
  final List<double> samples;
  final int rate;
}
