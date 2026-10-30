import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';

void main() {
  test('PCM16 round trip reads actual sample rate and signed amplitudes', () {
    for (final rate in [16000, 44100, 48000]) {
      final wav = Pcm16Wav(sampleRateHz: rate, samples: [-1, -.5, 0, .5, 1]);
      final read = Pcm16Wav.decode(wav.encode());
      expect(read.sampleRateHz, rate);
      expect(read.durationSeconds, 5 / rate);
      for (var i = 0; i < wav.samples.length; i++) {
        expect(read.samples[i], closeTo(wav.samples[i], 1 / 32768));
      }
    }
  });
  test('synthetic tone is deterministic bounded and fades at boundaries', () {
    final a = Pcm16Wav.tone(frequencyHz: 261.63, durationSeconds: .1);
    expect(a.samples.length, 4800);
    expect(a.samples.first, 0);
    expect(a.samples.last, 0);
    expect(a.samples.every((s) => s.abs() <= .25), isTrue);
    expect(
      a.encode(),
      Pcm16Wav.tone(frequencyHz: 261.63, durationSeconds: .1).encode(),
    );
  });
  test('empty silence PCM is accepted without fabricated voice', () {
    expect(
      Pcm16Wav.decode(
        Pcm16Wav(sampleRateHz: 48000, samples: []).encode(),
      ).samples,
      isEmpty,
    );
  });
  test('truncated and wrong format files fail closed', () {
    final original = Pcm16Wav.tone(
      frequencyHz: 440,
      durationSeconds: .01,
    ).encode();
    for (final length in [0, 8, 12, 35, 43, original.length - 1]) {
      expect(
        () => Pcm16Wav.decode(Uint8List.sublistView(original, 0, length)),
        throwsFormatException,
      );
    }
    for (final offset in [0, 8, 20, 22, 24, 28, 32, 34, 40]) {
      final broken = Uint8List.fromList(original);
      broken[offset] = 255;
      expect(() => Pcm16Wav.decode(broken), throwsFormatException);
    }
  });
  test(
    'PCM snapshots caller list and rejects non finite and oversized values',
    () {
      final samples = <double>[0];
      final wav = Pcm16Wav(sampleRateHz: 48000, samples: samples);
      samples.clear();
      expect(wav.samples.length, 1);
      expect(() => wav.samples.clear(), throwsUnsupportedError);
      for (final value in [double.nan, double.infinity, -1.1, 1.1]) {
        expect(
          () => Pcm16Wav(sampleRateHz: 48000, samples: [value]),
          throwsArgumentError,
        );
      }
      expect(() => Pcm16Wav(sampleRateHz: 0, samples: []), throwsArgumentError);
    },
  );
  test('invalid synthetic input fails before allocating samples', () {
    expect(() => Pcm16Wav.tone(frequencyHz: 24000), throwsArgumentError);
    expect(() => Pcm16Wav.tone(frequencyHz: double.nan), throwsArgumentError);
    expect(
      () => Pcm16Wav.tone(frequencyHz: 440, durationSeconds: double.infinity),
      throwsArgumentError,
    );
    expect(
      () => Pcm16Wav.tone(frequencyHz: 440, durationSeconds: 121),
      throwsArgumentError,
    );
    expect(
      () => Pcm16Wav.tone(frequencyHz: 440, amplitude: 2),
      throwsArgumentError,
    );
  });
}
