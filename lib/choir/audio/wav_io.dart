import 'dart:typed_data';

/// Mono PCM16 WAV for choir takes. Unlike the short-clip `Pcm16Wav`, this
/// holds whole-work lengths; it uses packed lists and has no 120 s cap.
class WavData {
  const WavData({required this.samples, required this.sampleRateHz});
  final Int16List samples;
  final int sampleRateHz;

  int get durationMs => samples.length * 1000 ~/ sampleRateHz;
}

/// Reads a recorder's file. A crashed or just-stopped recorder may leave a
/// data size of zero or past the end of file; the bytes present are used.
/// Anything other than mono PCM16 throws [FormatException].
WavData readWav(Uint8List bytes) {
  if (bytes.length < 44 ||
      _tag(bytes, 0) != 'RIFF' ||
      _tag(bytes, 8) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }
  final view = ByteData.sublistView(bytes);
  int? rate;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = _tag(bytes, at);
    final size = view.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      if (body + 16 > bytes.length) throw const FormatException('Short fmt');
      final format = view.getUint16(body, Endian.little);
      final extensible =
          format == 0xFFFE &&
          size >= 26 &&
          view.getUint16(body + 24, Endian.little) == 1;
      if ((format != 1 && !extensible) ||
          view.getUint16(body + 2, Endian.little) != 1 ||
          view.getUint16(body + 14, Endian.little) != 16) {
        throw const FormatException('Only mono PCM16 is supported');
      }
      rate = view.getUint32(body + 4, Endian.little);
      if (rate < 1000 || rate > 192000) {
        throw const FormatException('Sample rate out of range');
      }
    } else if (id == 'data') {
      if (rate == null) throw const FormatException('data before fmt');
      final available = bytes.length - body;
      final length = size == 0 || size > available ? available : size;
      final count = length ~/ 2;
      final samples = Int16List(count);
      for (var i = 0; i < count; i++) {
        samples[i] = view.getInt16(body + i * 2, Endian.little);
      }
      return WavData(samples: samples, sampleRateHz: rate);
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV has no audio');
}

Uint8List encodeWav(Int16List samples, int sampleRateHz) {
  final dataBytes = samples.length * 2;
  final out = Uint8List(44 + dataBytes);
  final view = ByteData.sublistView(out);
  void tag(int at, String text) => out.setRange(at, at + 4, text.codeUnits);
  tag(0, 'RIFF');
  view.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, sampleRateHz, Endian.little);
  view.setUint32(28, sampleRateHz * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  view.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    view.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return out;
}

String _tag(Uint8List bytes, int at) => String.fromCharCodes(bytes, at, at + 4);

/// Puts the singer over the accompaniment on the accompaniment's clock.
///
/// [offsetMs] is where in [vocal] the accompaniment's first sample lies: how
/// much later playback started than capture. It is an estimate plus the
/// singer's manual correction, never a measured latency. The count-in is
/// cut; the result stops when the singer stopped, or when the piece ends.
Int16List mixTake({
  required WavData vocal,
  required Int16List accompaniment,
  required int sampleRateHz,
  required int countInSamples,
  required int offsetMs,
  double vocalGain = 1,
  double accompanimentGain = 0.4,
}) {
  final ratio = vocal.sampleRateHz / sampleRateHz;
  final lead = offsetMs * sampleRateHz ~/ 1000;
  final vocalFrames = (vocal.samples.length / ratio).floor();
  final tail = accompaniment.length - countInSamples;
  final fromVocal = vocalFrames - countInSamples - lead;
  final length = tail < fromVocal ? tail : fromVocal;
  if (length <= 0) return Int16List(0);

  final mixed = Float32List(length);
  var peak = 0.0;
  for (var i = 0; i < length; i++) {
    final at = countInSamples + i;
    final vocalAt = (at + lead) * ratio;
    var v = 0.0;
    if (vocalAt >= 0) {
      final index = vocalAt.toInt();
      if (index + 1 < vocal.samples.length) {
        final frac = vocalAt - index;
        v =
            vocal.samples[index] +
            (vocal.samples[index + 1] - vocal.samples[index]) * frac;
      }
    }
    final sum = v * vocalGain + accompaniment[at] * accompanimentGain;
    mixed[i] = sum;
    if (sum.abs() > peak) peak = sum.abs();
  }
  // Only ever turns down: a quiet singer is not raised, so what the
  // conductor hears keeps the take's real dynamics.
  final scale = peak > 32000 ? 32000 / peak : 1.0;
  final out = Int16List(length);
  for (var i = 0; i < length; i++) {
    out[i] = (mixed[i] * scale).round();
  }
  return out;
}

/// Loudness outline of a take in [bars] buckets, 0–1. Drawn from the real
/// samples; a loud or quiet bar means only that, nothing about the singing.
List<double> wavePeaks(Int16List samples, int bars) {
  if (samples.isEmpty || bars < 1) return const [];
  final peaks = List<double>.filled(bars, 0);
  final step = samples.length / bars;
  var top = 1;
  for (var b = 0; b < bars; b++) {
    final from = (b * step).floor();
    final to = ((b + 1) * step).floor();
    var peak = 0;
    for (var i = from; i < to; i += 16) {
      final v = samples[i].abs();
      if (v > peak) peak = v;
    }
    peaks[b] = peak.toDouble();
    if (peak > top) top = peak;
  }
  return [for (final p in peaks) p / top];
}
