import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/choir/audio/take_engine.dart';
import 'package:harmonia/choir/audio/wav_io.dart';
import 'package:harmonia/choir/domain/choir.dart';
import 'package:harmonia/choir/midi/midi_section.dart';
import 'package:harmonia/choir/midi/part_renderer.dart';
import 'package:harmonia/choir/midi/smf_reader.dart';
import 'package:harmonia/domain/audio/capture_quality.dart';

MidiNote note(int key, int start, int end) => MidiNote(
  channel: 0,
  key: key,
  velocity: 100,
  startTick: start,
  endTick: end,
);

MidiTrack track(int index, String name, List<MidiNote> notes) => MidiTrack(
  index: index,
  name: name,
  notes: notes,
  endTick: notes.isEmpty ? 0 : notes.last.endTick,
  unterminatedNotes: 0,
);

/// 120 BPM, 4/4: four bars, a soprano and a bass, one note per bar.
MidiFile choirFile() => MidiFile(
  format: 1,
  ticksPerQuarter: 480,
  tracks: [
    track(0, 'Soprano', [
      for (var bar = 0; bar < 4; bar++) note(72, bar * 1920, bar * 1920 + 960),
    ]),
    track(1, 'Bas', [
      for (var bar = 0; bar < 4; bar++) note(48, bar * 1920, bar * 1920 + 960),
    ]),
  ],
  tempos: const [TempoChange(0, 500000)],
  timeSignatures: const [TimeSignature(0, 4, 4)],
);

double rms(Int16List s, int from, int to) {
  var sum = 0.0;
  for (var i = from; i < to && i < s.length; i++) {
    sum += s[i] * s[i];
  }
  return math.sqrt(sum / (to - from));
}

/// Strength of [hz] in a stretch, by correlating with it.
double energyAt(Int16List s, int from, int to, double hz, int rate) {
  var re = 0.0, im = 0.0;
  for (var i = from; i < to; i++) {
    final w = 2 * math.pi * hz * i / rate;
    re += s[i] * math.cos(w);
    im += s[i] * math.sin(w);
  }
  return math.sqrt(re * re + im * im) / (to - from);
}

void main() {
  group('Part suggestion and sections', () {
    test(
      'track names in several languages suggest a part; silence does not',
      () {
        final file = MidiFile(
          format: 1,
          ticksPerQuarter: 480,
          tracks: [
            track(0, 'Sopran I', [note(72, 0, 480)]),
            track(1, 'Contralto', [note(60, 0, 480)]),
            track(2, 'Basse', [note(48, 0, 480)]),
            track(3, 'Piano', [note(60, 0, 480)]),
            track(4, 'Tenor', const []),
          ],
          tempos: const [TempoChange(0, 500000)],
          timeSignatures: const [TimeSignature(0, 4, 4)],
        );
        expect(suggestTrackParts(file), {
          0: ChoirPart.soprano,
          1: ChoirPart.alto,
          2: ChoirPart.bass,
        });
      },
    );

    test('section covers whole measures and refuses what is not there', () {
      final file = choirFile();
      final s = MidiSection.of(file, from: 2, to: 3);
      expect((s.startTick, s.endTick), (1920, 5760));
      final whole = MidiSection.of(file);
      expect((whole.startTick, whole.endTick), (0, file.lengthTicks));
      expect(MidiSection.of(file, from: 3, to: 99).toMeasure, 4);
      expect(() => MidiSection.of(file, from: 9, to: 10), throwsRangeError);
    });
  });

  group('Part rendering', () {
    const rate = 8000;

    test('own part stands out and the other can be silenced', () {
      final file = choirFile();
      final map = {0: ChoirPart.soprano, 1: ChoirPart.bass};
      final out = renderPart(
        file: file,
        section: MidiSection.of(file),
        trackParts: map,
        mix: const PartMix(ownPart: ChoirPart.soprano, othersGain: 0),
        sampleRateHz: rate,
      );
      final bassHz = 440 * math.pow(2, (48 - 69) / 12).toDouble();
      final topHz = 440 * math.pow(2, (72 - 69) / 12).toDouble();
      final bass = energyAt(out.samples, 0, rate ~/ 2, bassHz, rate);
      final top = energyAt(out.samples, 0, rate ~/ 2, topHz, rate);
      expect(top, greaterThan(bass * 10));
    });

    test('practice tempo stretches time and keeps pitch', () {
      final file = choirFile();
      RenderedPart at(double factor) => renderPart(
        file: file,
        section: MidiSection.of(file, from: 1, to: 1),
        trackParts: const {},
        mix: PartMix(tempoFactor: factor),
        sampleRateHz: rate,
      );
      final full = at(1), half = at(0.5);
      expect(half.duration.inMilliseconds, closeTo(4600, 30));
      expect(full.duration.inMilliseconds, closeTo(2600, 30));
      final hz = 440 * math.pow(2, (72 - 69) / 12).toDouble();
      expect(
        energyAt(half.samples, 0, rate, hz, rate),
        greaterThan(energyAt(half.samples, 0, rate, hz * 1.5, rate) * 5),
      );
    });

    test('count-in is one bar of clicks before the first note', () {
      final file = choirFile();
      final out = renderPart(
        file: file,
        section: MidiSection.of(file, from: 2, to: 2),
        trackParts: const {},
        mix: const PartMix(countInBars: 1),
        sampleRateHz: rate,
      );
      expect(out.countInSamples, 2 * rate);
      final clickRoom = rms(out.samples, rate ~/ 8, rate ~/ 3);
      expect(clickRoom, lessThan(1));
      expect(
        rms(out.samples, 2 * rate + 200, 2 * rate + 2000),
        greaterThan(500),
      );
    });

    test('an unreasonably long render is refused before allocating', () {
      final file = MidiFile(
        format: 1,
        ticksPerQuarter: 480,
        tracks: [
          track(0, 'x', [note(60, 0, 480 * 60 * 60)]),
        ],
        tempos: const [TempoChange(0, 1000000)],
        timeSignatures: const [TimeSignature(0, 4, 4)],
      );
      expect(
        () => renderPart(
          file: file,
          section: MidiSection.of(file),
          trackParts: const {},
          mix: const PartMix(),
          sampleRateHz: rate,
        ),
        throwsA(isA<RenderTooLong>()),
      );
    });
  });

  group('WAV and mixing', () {
    test('round-trips and survives a recorder size placeholder', () {
      final samples = Int16List.fromList([0, 1000, -1000, 32767, -32768]);
      final bytes = encodeWav(samples, 44100);
      final back = readWav(bytes);
      expect(back.samples, samples);
      expect(back.sampleRateHz, 44100);
      final open = Uint8List.fromList(bytes);
      ByteData.sublistView(open).setUint32(40, 0, Endian.little);
      expect(readWav(open).samples, samples);
      ByteData.sublistView(open).setUint32(40, 0xFFFFFFFF, Endian.little);
      expect(readWav(open).samples, samples);
    });

    test('refuses what is not mono PCM16', () {
      expect(() => readWav(Uint8List(100)), throwsFormatException);
      final stereo = encodeWav(Int16List(16), 44100);
      ByteData.sublistView(stereo).setUint16(22, 2, Endian.little);
      expect(() => readWav(stereo), throwsFormatException);
    });

    test('count-in is cut and the offset lines the voice up', () {
      const rate = 1000;
      final accompaniment = Int16List(3000);
      final voiceIn = Int16List(3200);
      // Voice sings at 1500 ms into capture; piece starts at 1000 ms of the
      // file (after the count-in) and playback lagged capture by 100 ms.
      voiceIn[1500] = 10000;
      final out = mixTake(
        vocal: WavData(samples: voiceIn, sampleRateHz: rate),
        accompaniment: accompaniment,
        sampleRateHz: rate,
        countInSamples: 1000,
        offsetMs: 100,
      );
      expect(out.length, 2000);
      expect(out.indexWhere((s) => s != 0), 400);
    });

    test('a quiet voice is not raised, a hot mix does not wrap', () {
      const rate = 1000;
      final accompaniment = Int16List.fromList(List.filled(100, 30000));
      final quiet = mixTake(
        vocal: WavData(
          samples: Int16List.fromList(List.filled(100, 100)),
          sampleRateHz: rate,
        ),
        accompaniment: Int16List(100),
        sampleRateHz: rate,
        countInSamples: 0,
        offsetMs: 0,
      );
      expect(quiet.sublist(0, 98).every((s) => s == 100), isTrue);
      final hot = mixTake(
        vocal: WavData(
          samples: Int16List.fromList(List.filled(100, 30000)),
          sampleRateHz: rate,
        ),
        accompaniment: accompaniment,
        sampleRateHz: rate,
        countInSamples: 0,
        offsetMs: 0,
      );
      expect(hot.first, inInclusiveRange(30000, 32000));
    });

    test('different recorder rate lands at the same time', () {
      final voice = Int16List(2000);
      voice[1000] = 8000; // 500 ms at 2 kHz
      final out = mixTake(
        vocal: WavData(samples: voice, sampleRateHz: 2000),
        accompaniment: Int16List(1000),
        sampleRateHz: 1000,
        countInSamples: 0,
        offsetMs: 0,
      );
      expect(out.indexWhere((s) => s != 0), inInclusiveRange(499, 501));
    });

    test('stopping early ends the take there, stopping before singing '
        'gives nothing', () {
      final out = mixTake(
        vocal: WavData(samples: Int16List(700), sampleRateHz: 1000),
        accompaniment: Int16List(3000),
        sampleRateHz: 1000,
        countInSamples: 1000,
        offsetMs: 0,
      );
      expect(out, isEmpty);
    });
  });

  test('wave outline follows real loudness and handles nothing', () {
    final quietThenLoud = Int16List(1000);
    for (var i = 500; i < 1000; i++) {
      quietThenLoud[i] = 20000;
    }
    final peaks = wavePeaks(quietThenLoud, 2);
    expect(peaks, [0, 1]);
    expect(wavePeaks(Int16List(0), 4), isEmpty);
  });

  test('route advice keeps accompanied takes off the speaker', () {
    RouteAdvice of(AudioRouteKind output) => adviseRoute(
      AudioRouteSnapshot(input: AudioRouteKind.builtIn, output: output),
    );
    expect(of(AudioRouteKind.wired), RouteAdvice.ready);
    expect(of(AudioRouteKind.usb), RouteAdvice.ready);
    expect(of(AudioRouteKind.bluetooth), RouteAdvice.bluetoothDelay);
    expect(of(AudioRouteKind.builtIn), RouteAdvice.speaker);
    expect(of(AudioRouteKind.unknown), RouteAdvice.unknown);
  });

  test('renders a small file fast enough for a phone', () {
    final file = choirFile();
    final clock = Stopwatch()..start();
    renderPart(
      file: file,
      section: MidiSection.of(file),
      trackParts: const {},
      mix: const PartMix(countInBars: 1, metronomeGain: 0.5),
    );
    expect(clock.elapsedMilliseconds, lessThan(Platform.isIOS ? 4000 : 2000));
  });
}
