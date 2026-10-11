import 'dart:math' as math;
import 'dart:typed_data';

/// Narrow initial interchange format: uncompressed mono PCM16 RIFF/WAVE.
/// Header values, not requested recorder settings, determine the sample rate.
class Pcm16Wav {
  Pcm16Wav({required this.sampleRateHz, required List<double> samples})
    : samples = List.unmodifiable(samples) {
    if (sampleRateHz < 8000 ||
        sampleRateHz > 192000 ||
        samples.length > sampleRateHz * 120 ||
        samples.any((s) => !s.isFinite || s < -1 || s > 1)) {
      throw ArgumentError('Invalid or oversized PCM');
    }
  }
  final int sampleRateHz;
  final List<double> samples;
  double get durationSeconds => samples.length / sampleRateHz;

  factory Pcm16Wav.decode(Uint8List bytes) {
    if (bytes.length < 12 || bytes.length > 46080044) {
      throw const FormatException('Invalid WAV size');
    }
    final view = ByteData.sublistView(bytes);
    String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
    if (tag(0) != 'RIFF' ||
        tag(8) != 'WAVE' ||
        view.getUint32(4, Endian.little) + 8 != bytes.length) {
      throw const FormatException('Invalid RIFF/WAVE header');
    }
    int? rate;
    Uint8List? pcm;
    for (var at = 12; at < bytes.length;) {
      if (at + 8 > bytes.length) throw const FormatException('Truncated chunk');
      final length = view.getUint32(at + 4, Endian.little);
      final start = at + 8;
      final end = start + length;
      if (end + (length & 1) > bytes.length) {
        throw const FormatException('Truncated chunk data');
      }
      if (tag(at) == 'fmt ') {
        if (rate != null ||
            length < 16 ||
            view.getUint16(start, Endian.little) != 1 ||
            view.getUint16(start + 2, Endian.little) != 1 ||
            view.getUint16(start + 14, Endian.little) != 16) {
          throw const FormatException('Only mono PCM16 is supported');
        }
        rate = view.getUint32(start + 4, Endian.little);
        if (rate < 8000 ||
            rate > 192000 ||
            view.getUint16(start + 12, Endian.little) != 2 ||
            view.getUint32(start + 8, Endian.little) != rate * 2) {
          throw const FormatException('Invalid PCM format');
        }
      } else if (tag(at) == 'data') {
        if (pcm != null || length.isOdd) {
          throw const FormatException('Invalid PCM data');
        }
        pcm = Uint8List.sublistView(bytes, start, end);
      }
      at = end + (length & 1);
    }
    if (rate == null || pcm == null || pcm.length > rate * 120 * 2) {
      throw const FormatException('Missing or oversized PCM');
    }
    final data = ByteData.sublistView(pcm);
    return Pcm16Wav(
      sampleRateHz: rate,
      samples: List.generate(
        pcm.length ~/ 2,
        (i) => data.getInt16(i * 2, Endian.little) / 32768,
      ),
    );
  }

  Uint8List encode() {
    final bytes = Uint8List(44 + samples.length * 2);
    final view = ByteData.sublistView(bytes);
    void tag(int at, String text) => bytes.setRange(at, at + 4, text.codeUnits);
    tag(0, 'RIFF');
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    tag(36, 'data');
    view.setUint32(4, bytes.length - 8, Endian.little);
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, 1, Endian.little);
    view.setUint32(24, sampleRateHz, Endian.little);
    view.setUint32(28, sampleRateHz * 2, Endian.little);
    view.setUint16(32, 2, Endian.little);
    view.setUint16(34, 16, Endian.little);
    view.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(
        44 + 2 * i,
        (samples[i] * 32768).round().clamp(-32768, 32767),
        Endian.little,
      );
    }
    return bytes;
  }

  /// Synthetic reference/test tone, not a human voice benchmark.
  factory Pcm16Wav.tone({
    required double frequencyHz,
    int sampleRateHz = 48000,
    double durationSeconds = 1,
    double amplitude = .25,
  }) {
    if (!frequencyHz.isFinite ||
        frequencyHz <= 0 ||
        frequencyHz >= sampleRateHz / 2 ||
        sampleRateHz < 8000 ||
        sampleRateHz > 192000 ||
        !durationSeconds.isFinite ||
        durationSeconds <= 0 ||
        durationSeconds > 120 ||
        !amplitude.isFinite ||
        amplitude < 0 ||
        amplitude > 1) {
      throw ArgumentError('Invalid synthetic tone');
    }
    final length = (durationSeconds * sampleRateHz).round();
    final fade = math.min((.012 * sampleRateHz).round(), length ~/ 2);
    return Pcm16Wav(
      sampleRateHz: sampleRateHz,
      samples: List.generate(length, (i) {
        final envelope = fade == 0
            ? 1.0
            : math.min(1.0, math.min(i / fade, (length - 1 - i) / fade));
        return amplitude *
            envelope *
            math.sin(2 * math.pi * frequencyHz * i / sampleRateHz);
      }),
    );
  }
}
