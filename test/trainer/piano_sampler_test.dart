// AUDIO-PIANO-01: single-note trainer sounds from the cleared piano
// recordings; chords and unreachable notes stay on the synth as a whole.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/audio/piano_notes.dart';
import 'package:resonia/trainer/audio/piano_sampler.dart';
import 'package:resonia/trainer/audio/synth.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/domain/trainers.dart';

/// Goertzel magnitude of [x] at [hz].
double _bin(List<double> x, int rate, double hz) {
  final k = 2 * math.cos(2 * math.pi * hz / rate);
  var s1 = 0.0, s2 = 0.0;
  for (final v in x) {
    final s = v + k * s1 - s2;
    s2 = s1;
    s1 = s;
  }
  return math.sqrt(math.max(0, s1 * s1 + s2 * s2 - k * s1 * s2));
}

/// Energy on the first four harmonics of [midi].
double _comb(List<double> x, int rate, num midi) {
  var sum = 0.0;
  for (var h = 1; h <= 4; h++) {
    sum += _bin(x, rate, h * 440 * math.pow(2, (midi - 69) / 12).toDouble());
  }
  return sum;
}

double _rms(List<double> x) =>
    math.sqrt(x.fold<double>(0, (s, v) => s + v * v) / math.max(1, x.length));

SoundSpec _note(int midi, {double at = 0, double seconds = 1.0}) => SoundSpec([
  ToneEvent(at, seconds, [midi]),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PianoSampler sampler;
  setUp(() => sampler = PianoSampler(PianoNoteBank()));

  test('white and black keys sound their own pitch, not a neighbour', () async {
    // C3, F♯3 (moved), C4, C♯4 (moved), E4, B♭4 (moved), G5, G♯5 (moved).
    for (final midi in [48, 54, 60, 61, 64, 70, 79, 80]) {
      final wav = (await sampler.render(_note(midi)))!;
      final body = wav.samples.sublist(
        (0.1 * wav.sampleRateHz).round(),
        (0.6 * wav.sampleRateHz).round(),
      );
      final own = _comb(body, wav.sampleRateHz, midi);
      for (final other in [midi - 1, midi + 1]) {
        expect(
          own,
          greaterThan(2 * _comb(body, wav.sampleRateHz, other)),
          reason: '$midi vs $other',
        );
      }
      final source = (await sampler.sourceFor(midi))!;
      // A black key is always a neighbour moved by one semitone (G♯5 borrows
      // G5 because A5 is held back); a white key is its own recording.
      expect(source.shift.abs(), PianoNoteBank.noteName(midi) == null ? 1 : 0);
    }
  });

  test(
    'chords, harmonic intervals and unreachable notes stay synthetic',
    () async {
      expect(
        await sampler.render(
          const SoundSpec([
            ToneEvent(0, 1, [60, 64, 67]),
          ]),
        ),
        isNull,
      );
      // A5 is held back (ADR-040) and B5 above the cleared range: the whole
      // melody stays on the synth rather than switching instrument mid-way.
      expect(
        await sampler.render(
          const SoundSpec([
            ToneEvent(0, 0.5, [72]),
            ToneEvent(0.6, 0.5, [83]),
          ]),
        ),
        isNull,
      );
      expect(await sampler.render(const SoundSpec([])), isNull);
    },
  );

  test('a melody keeps its timing: trimmed onsets, release at the written '
      'length', () async {
    final wav = (await sampler.render(
      const SoundSpec([
        // A1 starts ~0.4 s late in its file; trimmed, it starts on time.
        ToneEvent(0, 0.5, [33]),
        ToneEvent(0.7, 0.5, [64]),
      ]),
    ))!;
    final r = wav.sampleRateHz;
    List<double> at(double from, double to) =>
        wav.samples.sublist((from * r).round(), (to * r).round());
    expect(_rms(at(0, 0.05)), greaterThan(0.02));
    // Silent between the first release and the second note.
    expect(_rms(at(0.63, 0.69)), lessThan(0.002));
    expect(_rms(at(0.7, 0.75)), greaterThan(0.02));
    // Gone right after the last release: nothing rings into a recording.
    expect(wav.durationSeconds, lessThan(1.2 + 0.12 + 0.03));
    expect(_rms(at(1.33, wav.durationSeconds)), lessThan(0.002));
    final peak = wav.samples.fold<double>(0, (m, s) => math.max(m, s.abs()));
    expect(peak, closeTo(0.8, 0.01));
  });

  test('TrainerAudio: piano timbre plays recordings, other timbres and '
      'chords the synth', () async {
    final audio = TrainerAudio(player: null);
    addTearDown(audio.dispose);
    expect((await audio.render(_note(60))).sampleRateHz, 48000);
    expect(
      (await audio.render(
        const SoundSpec([
          ToneEvent(0, 1, [60, 67]),
        ]),
      )).sampleRateHz,
      const TrainerSynth().sampleRateHz,
    );
    audio.timbre = Timbre.cello;
    expect(
      (await audio.render(_note(60))).sampleRateHz,
      const TrainerSynth().sampleRateHz,
    );
  });

  test('no note pops: every reachable note eases in from and out to '
      'silence', () async {
    // E1 (28) … G♯5 (80): white keys and moved black keys alike.
    for (var midi = 28; midi <= 80; midi++) {
      final wav = await sampler.render(_note(midi, seconds: 0.5));
      if (wav == null) continue; // held back (A5+): synth instead
      final x = wav.samples;
      final ms = wav.sampleRateHz ~/ 1000;
      double jump(int from, int to) {
        var m = 0.0;
        for (var i = math.max(1, from); i < math.min(to, x.length); i++) {
          m = math.max(m, (x[i] - x[i - 1]).abs());
        }
        return m;
      }

      expect(x.first.abs(), lessThan(0.005), reason: '$midi start');
      expect(x.last.abs(), lessThan(0.005), reason: '$midi end');
      // A take beginning mid-attack once jumped 0.28 in one sample.
      expect(jump(0, 2 * ms), lessThan(0.04), reason: '$midi onset');
      expect(
        jump(x.length - 100 * ms, x.length),
        lessThan(0.04),
        reason: '$midi tail',
      );
    }
  });

  test('a take shorter than the written note fades instead of being cut', () {
    // Worst case: a loud, flat take that ends long before the note does.
    final wav = PianoSampler.mix(_note(60, seconds: 1), {
      60: PianoSource(List.filled(4800, 0.5), 48000, 0),
    })!;
    final x = wav.samples;
    var worst = 0.0;
    for (var i = 1; i < x.length; i++) {
      worst = math.max(worst, (x[i] - x[i - 1]).abs());
    }
    expect(x.first, 0);
    expect(worst, lessThan(0.01));
    expect(x.sublist(4800).every((v) => v == 0), isTrue);
  });
}
