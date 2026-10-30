import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/choir.dart';
import 'midi_section.dart';
import 'smf_reader.dart';

/// What a singer hears: their part forward, the rest behind it. A practice
/// tempo is a re-render, not a time-stretch, so pitch never moves.
class PartMix {
  const PartMix({
    this.ownPart,
    this.ownGain = 1,
    this.othersGain = 0.45,
    this.metronomeGain = 0,
    this.tempoFactor = 1,
    this.countInBars = 0,
  }) : assert(tempoFactor > 0);

  /// Null plays every part at [othersGain].
  final ChoirPart? ownPart;
  final double ownGain;
  final double othersGain;
  final double metronomeGain;
  final double tempoFactor;
  final int countInBars;
}

class RenderedPart {
  const RenderedPart({
    required this.samples,
    required this.sampleRateHz,
    required this.countInSamples,
  });

  final Int16List samples;
  final int sampleRateHz;

  /// Leading clicks; a mixed take starts after them.
  final int countInSamples;

  Duration get duration => Duration(
    microseconds:
        samples.length * Duration.microsecondsPerSecond ~/ sampleRateHz,
  );
}

class RenderTooLong implements Exception {
  const RenderTooLong(this.seconds);
  final double seconds;
}

/// Bounds memory on a phone; matches the longest take an assignment allows.
const maxRenderSeconds = 660.0;
const choirSampleRateHz = 44100;

/// Renders [section] of [file] to mono PCM16 on one sample clock. Pure and
/// isolate-safe. Uses generated tones only: no sample bank is shipped, so
/// this is a practice guide, not a piano recording (MIDI-03).
RenderedPart renderPart({
  required MidiFile file,
  required MidiSection section,
  required Map<int, ChoirPart> trackParts,
  required PartMix mix,
  int sampleRateHz = choirSampleRateHz,
}) {
  final startSeconds = file.secondsAt(section.startTick);
  double at(int tick) =>
      (file.secondsAt(tick) - startSeconds) / mix.tempoFactor;

  final signature = _signatureAt(file, section.startTick);
  final firstBeat =
      _beatSeconds(file, signature, section.startTick) / mix.tempoFactor;
  final countInBeats = mix.countInBars * signature.numerator;
  final countIn = countInBeats * firstBeat;
  final body = at(section.endTick);
  final total = countIn + body + 0.6;
  if (total > maxRenderSeconds) throw RenderTooLong(total);

  final out = Float32List((total * sampleRateHz).ceil());
  for (final track in file.tracks) {
    final part = trackParts[track.index];
    final own = mix.ownPart != null && part == mix.ownPart;
    final gain = own ? mix.ownGain : mix.othersGain;
    if (gain <= 0) continue;
    final table = own ? _leadTable : _softTable;
    for (final note in track.notes) {
      if (note.startTick < section.startTick ||
          note.startTick >= section.endTick) {
        continue;
      }
      final begin = countIn + at(note.startTick);
      final clippedEnd = note.endTick < section.endTick
          ? note.endTick
          : section.endTick;
      _addNote(
        out,
        table: table,
        key: note.key,
        startSeconds: begin,
        lengthSeconds: countIn + at(clippedEnd) - begin,
        gain: gain * (0.45 + 0.55 * note.velocity / 127),
        sampleRateHz: sampleRateHz,
      );
    }
  }

  for (var i = 0; i < countInBeats; i++) {
    _addClick(
      out,
      i * firstBeat,
      i % signature.numerator == 0,
      1,
      sampleRateHz,
    );
  }
  if (mix.metronomeGain > 0) {
    for (final (tick, accent) in _beats(file, section)) {
      _addClick(
        out,
        countIn + at(tick),
        accent,
        mix.metronomeGain,
        sampleRateHz,
      );
    }
  }

  var peak = 0.0;
  for (final s in out) {
    final v = s.abs();
    if (v > peak) peak = v;
  }
  final scale = peak > 0 ? 0.85 * 32767 / peak : 0.0;
  final samples = Int16List(out.length);
  for (var i = 0; i < out.length; i++) {
    samples[i] = (out[i] * scale).round();
  }
  return RenderedPart(
    samples: samples,
    sampleRateHz: sampleRateHz,
    countInSamples: (countIn * sampleRateHz).round(),
  );
}

TimeSignature _signatureAt(MidiFile file, int tick) {
  var current = file.timeSignatures.first;
  for (final s in file.timeSignatures) {
    if (s.tick > tick) break;
    current = s;
  }
  return current;
}

double _beatSeconds(MidiFile file, TimeSignature sig, int tick) {
  final beatTicks = file.ticksPerQuarter * 4 ~/ sig.denominator;
  return file.secondsAt(tick + beatTicks) - file.secondsAt(tick);
}

/// Each beat as (tick, is it the bar's first), following signature changes.
Iterable<(int, bool)> _beats(MidiFile file, MidiSection section) sync* {
  final starts = file.measureStarts();
  for (var m = section.fromMeasure; m <= section.toMeasure; m++) {
    final bar = starts[m - 1];
    final sig = _signatureAt(file, bar);
    final beatTicks = math.max(1, file.ticksPerQuarter * 4 ~/ sig.denominator);
    for (var b = 0; b < sig.numerator; b++) {
      final tick = bar + b * beatTicks;
      if (tick >= section.endTick) return;
      yield (tick, b == 0);
    }
  }
}

const _tableSize = 2048;

Float32List _wave(List<double> amplitudes) {
  final table = Float32List(_tableSize + 1);
  for (var i = 0; i <= _tableSize; i++) {
    final phase = 2 * math.pi * i / _tableSize;
    var v = 0.0;
    for (var h = 0; h < amplitudes.length; h++) {
      v += amplitudes[h] * math.sin((h + 1) * phase);
    }
    table[i] = v;
  }
  return table;
}

/// The singer's own line is brighter so it stands out by colour too, which
/// helps those who cannot tell parts apart by loudness alone.
final _leadTable = _wave(const [1, 0.55, 0.3, 0.16, 0.08]);
final _softTable = _wave(const [1, 0.3, 0.1]);

void _addNote(
  Float32List out, {
  required Float32List table,
  required int key,
  required double startSeconds,
  required double lengthSeconds,
  required double gain,
  required int sampleRateHz,
}) {
  final hz = 440 * math.pow(2, (key - 69) / 12).toDouble();
  final step = hz * _tableSize / sampleRateHz;
  final start = (startSeconds * sampleRateHz).round();
  final attack = (0.012 * sampleRateHz).round();
  final release = (0.09 * sampleRateHz).round();
  final hold = math.max(attack, (lengthSeconds * sampleRateHz).round());
  final end = math.min(out.length, start + hold + release);
  final decayPerSample = math.exp(-0.5 / sampleRateHz);
  var level = gain;
  var phase = 0.0;
  for (var at = start; at < end; at++) {
    final i = at - start;
    var env = level;
    if (i < attack) env *= i / attack;
    if (i > hold) env *= 1 - (i - hold) / release;
    final index = phase.toInt();
    final frac = phase - index;
    out[at] += env * (table[index] + (table[index + 1] - table[index]) * frac);
    phase += step;
    if (phase >= _tableSize) phase -= _tableSize;
    level *= decayPerSample;
  }
}

void _addClick(
  Float32List out,
  double seconds,
  bool accent,
  double gain,
  int sampleRateHz,
) {
  final start = (seconds * sampleRateHz).round();
  final length = (0.03 * sampleRateHz).round();
  final w = 2 * math.pi * (accent ? 1800 : 1200) / sampleRateHz;
  for (var i = 0; i < length && start + i < out.length; i++) {
    out[start + i] += gain * 1.1 * (1 - i / length) * math.sin(w * i);
  }
}
