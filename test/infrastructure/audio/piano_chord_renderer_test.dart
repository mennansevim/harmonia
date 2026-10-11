import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/piano_chord_reference.dart';
import 'package:harmonia/infrastructure/audio/piano_chord_renderer.dart';
import 'package:harmonia/infrastructure/audio/pcm16_wav.dart';

PianoNoteSample sample(
  int midi, {
  int rate = 8000,
  double a4 = 440,
  double value = 1,
  int? count,
  PianoSampleOrigin origin = PianoSampleOrigin.syntheticTest,
}) => PianoNoteSample(
  midiNote: midi,
  a4Hz: a4,
  assetId: 'synthetic-$midi',
  rightsReference: 'self-generated-test-only',
  origin: origin,
  wav: Pcm16Wav(sampleRateHz: rate, samples: List.filled(count ?? rate, value)),
);

void main() {
  final renderer = PianoChordRenderer();
  for (final keys in [
    [60, 67],
    [60, 64, 67],
    [60, 64, 67, 71],
  ]) {
    test(
      '${keys.length} worst-case aligned peaks share one clock and do not clip',
      () {
        final reference = PianoChordReference(
          midiNotes: keys,
          durationMs: 500,
          settleSilenceMs: 250,
        );
        final sources = keys.reversed.map(sample).toList();
        final result = renderer.render(reference: reference, samples: sources);
        expect(result.wav.sampleRateHz, 8000);
        expect(result.audibleSampleCount, 4000);
        expect(result.settleSampleCount, 2000);
        expect(result.wav.samples.length, 6000);
        expect(result.wav.samples[1000], closeTo(0.8, 1e-12));
        expect(
          result.wav.samples.every((s) => s.abs() <= 0.800000000001),
          isTrue,
        );
        expect(result.wav.samples.first, 0);
        expect(result.wav.samples[3999], 0);
        expect(result.wav.samples.skip(4000).every((s) => s == 0), isTrue);
        expect(result.sources.map((s) => s.midiNote), keys);
        expect(result.isSyntheticTest, isTrue);
        expect(
          Pcm16Wav.decode(result.wav.encode()).samples[1000],
          closeTo(.8, 1 / 32768),
        );
        sources.clear();
        expect(result.sources.length, keys.length);
        expect(() => result.sources.clear(), throwsUnsupportedError);
      },
    );
  }
  test(
    'all note contributions start at same sample, bank order has no effect',
    () {
      final reference = PianoChordReference(
        midiNotes: [60, 64, 67],
        durationMs: 100,
      );
      final samples = [
        sample(60, value: .5),
        sample(64, value: -.25),
        sample(67, value: .125),
      ];
      final a = renderer.render(reference: reference, samples: samples);
      final b = renderer.render(
        reference: reference,
        samples: samples.reversed.toList(),
      );
      expect(a.wav.encode(), b.wav.encode());
      expect(a.wav.samples[100], closeTo((.5 - .25 + .125) * .8 / 3, 1e-12));
    },
  );
  test(
    'synthetic bank notes retain their per-key signals in the single WAV mix',
    () {
      final reference = PianoChordReference(
        midiNotes: [60, 64, 67],
        durationMs: 500,
      );
      final samples = <PianoNoteSample>[
        for (var i = 0; i < reference.midiNotes.length; i++)
          PianoNoteSample(
            midiNote: reference.midiNotes[i],
            a4Hz: 440,
            assetId: 'tone-$i',
            rightsReference: 'self-generated-test-only',
            origin: PianoSampleOrigin.syntheticTest,
            wav: Pcm16Wav.tone(
              frequencyHz: reference.targetNotes[i].frequencyHz,
              sampleRateHz: 16000,
              durationSeconds: 1,
            ),
          ),
      ];
      final result = renderer.render(reference: reference, samples: samples);
      const index = 1600;
      final sum = samples
          .map((s) => s.wav.samples[index])
          .reduce((a, b) => a + b);
      expect(result.wav.samples[index], closeTo(sum * .8 / 3, 1e-12));
    },
  );
  test('missing/wrong/duplicate bank keys fail with no sine fallback', () {
    final reference = PianoChordReference(midiNotes: [60, 64], durationMs: 100);
    for (final samples in [
      <PianoNoteSample>[],
      [sample(60)],
      [sample(60), sample(60)],
      [sample(60), sample(67)],
    ]) {
      expect(
        () => renderer.render(reference: reference, samples: samples),
        throwsArgumentError,
      );
    }
  });
  test(
    'clock/tuning/origin mismatch is explicit, never silently resampled',
    () {
      final reference = PianoChordReference(
        midiNotes: [60, 64],
        durationMs: 100,
      );
      for (final other in [
        sample(64, rate: 16000),
        sample(64, a4: 442),
        sample(64, origin: PianoSampleOrigin.recordedPiano),
      ]) {
        expect(
          () => renderer.render(
            reference: reference,
            samples: [sample(60), other],
          ),
          throwsArgumentError,
        );
      }
    },
  );
  test('short or silent sample cannot hide a missing chord tone', () {
    final reference = PianoChordReference(midiNotes: [60, 64], durationMs: 500);
    for (final other in [sample(64, count: 3999), sample(64, value: 0)]) {
      expect(
        () =>
            renderer.render(reference: reference, samples: [sample(60), other]),
        throwsArgumentError,
      );
    }
  });
  test('metadata, duration and supported rate are bounded', () {
    expect(() => sample(20), throwsArgumentError);
    expect(() => sample(109), throwsArgumentError);
    expect(() => sample(108), throwsArgumentError);
    expect(sample(108, rate: 16000).midiNote, 108);
    expect(() => sample(60, rate: 96000), throwsArgumentError);
    expect(() => sample(60, count: 0), throwsArgumentError);
    expect(() => sample(60, count: 40001), throwsArgumentError);
    expect(() => sample(60, a4: double.infinity), throwsArgumentError);
    expect(
      () => PianoNoteSample(
        midiNote: 60,
        a4Hz: 440,
        wav: sample(60).wav,
        assetId: 'x',
        rightsReference: '',
        origin: PianoSampleOrigin.syntheticTest,
      ),
      throwsArgumentError,
    );
  });
}
