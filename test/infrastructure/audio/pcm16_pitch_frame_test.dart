import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/pitch_deviation.dart';
import 'package:resonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';

void main() {
  final analyzer = YinPitchFrameAnalyzer();
  for (final rate in [8000, 16000, 44100, 48000]) {
    test('synthetic WAV decode -> frame uses actual header $rate Hz', () {
      final wav = Pcm16Wav.decode(
        Pcm16Wav.tone(
          frequencyHz: 440,
          sampleRateHz: rate,
          durationSeconds: 0.3,
        ).encode(),
      );
      // Skip the reference's fade-in; no resampling or recorder-config guess.
      final start = (rate * 0.03).round();
      final count = analyzer.recommendedFrameSamples(wav.sampleRateHz);
      final result = analyzer.analyze(
        wav.samples.sublist(start, start + count),
        sampleRateHz: wav.sampleRateHz,
      );
      expect(result.status, PitchFrameStatus.pitched);
      expect(
        PitchDeviation(
          detectedHz: result.frequencyHz!,
          targetHz: 440,
        ).absoluteCents.abs(),
        lessThan(5),
      );
    });
  }
  test('supported sample rate lies are not detectable from PCM alone', () {
    final wav = Pcm16Wav.tone(
      frequencyHz: 440,
      sampleRateHz: 16000,
      durationSeconds: 0.3,
    );
    final result = analyzer.analyze(
      wav.samples.sublist(500, 4596),
      sampleRateHz: 48000,
    );
    expect(result.status, PitchFrameStatus.pitched);
    expect(result.frequencyHz, closeTo(1320, 5));
    // This regression documents why loaders/capture must validate actual Hz.
    // The detector cannot infer a clock, identity, consent, or human origin.
  });
}
