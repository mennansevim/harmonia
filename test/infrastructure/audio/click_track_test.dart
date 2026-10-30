import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/infrastructure/audio/click_track.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';

void main() {
  test('clicks start on the exact onset sample and round-trip as WAV', () {
    final wav = renderClickTrack([0, 750, 1500], sampleRateHz: 8000);
    expect(wav.samples.length, ((1500 + 400) * 8).ceil());
    for (final onsetMs in [0, 750, 1500]) {
      final start = onsetMs * 8;
      if (start > 0) expect(wav.samples[start - 1].abs(), lessThan(1e-9));
      expect(
        wav.samples.sublist(start, start + 8).any((s) => s.abs() > 0.05),
        isTrue,
      );
    }
    final decoded = Pcm16Wav.decode(wav.encode());
    expect(decoded.sampleRateHz, 8000);
    expect(wav.samples.every((s) => s.abs() <= 1), isTrue);
  });

  test('rejects empty, unordered, negative and overlong tracks', () {
    for (final bad in [
      <int>[],
      [0, 0],
      [500, 100],
      [-1, 10],
      [0, 30001],
    ]) {
      expect(() => renderClickTrack(bad), throwsArgumentError);
    }
  });
}
