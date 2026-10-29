import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/choir/midi/smf_reader.dart';

/// Minimal SMF writer for fixtures: bytes are built here, not copied from
/// any third-party file.
List<int> vlq(int value) {
  final out = <int>[value & 0x7F];
  value >>= 7;
  while (value > 0) {
    out.insert(0, (value & 0x7F) | 0x80);
    value >>= 7;
  }
  return out;
}

List<int> u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
List<int> u16(int v) => [v >> 8 & 255, v & 255];

List<int> chunk(String tag, List<int> body) => [
  ...ascii.encode(tag),
  ...u32(body.length),
  ...body,
];

List<int> header({int format = 1, int tracks = 1, int division = 480}) =>
    chunk('MThd', [...u16(format), ...u16(tracks), ...u16(division)]);

/// Track body from (delta, event bytes) pairs; appends end-of-track.
List<int> track(List<(int, List<int>)> events, {bool end = true}) =>
    chunk('MTrk', [
      for (final (delta, bytes) in events) ...[...vlq(delta), ...bytes],
      if (end) ...[0, 0xFF, 0x2F, 0],
    ]);

List<int> name(String text) {
  final bytes = utf8.encode(text);
  return [0xFF, 0x03, ...vlq(bytes.length), ...bytes];
}

List<int> tempo(int bpm) {
  final micros = 60000000 ~/ bpm;
  return [0xFF, 0x51, 3, micros >> 16 & 255, micros >> 8 & 255, micros & 255];
}

List<int> timeSig(int num, int denPower) => [
  0xFF,
  0x58,
  4,
  num,
  denPower,
  24,
  8,
];
List<int> on(int ch, int key, [int vel = 80]) => [0x90 | ch, key, vel];
List<int> off(int ch, int key) => [0x80 | ch, key, 0];

MidiFile parse(List<int> bytes, {SmfLimits limits = const SmfLimits()}) =>
    readSmf(Uint8List.fromList(bytes), limits: limits);

Matcher throwsMidi(String fragment) => throwsA(
  isA<MidiFormatException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  test('format 1: conductor track, named parts, tempo and time signature', () {
    final file = parse([
      ...header(tracks: 3),
      ...track([(0, tempo(90)), (0, timeSig(3, 2))]),
      ...track([
        (0, name('Soprano')),
        (0, on(0, 72)),
        (480, off(0, 72)),
        (0, on(0, 74)),
        (480, off(0, 74)),
      ]),
      ...track([
        (0, name('Bas – İkinci')),
        (0, on(3, 48, 60)),
        (960, off(3, 48)),
      ]),
    ]);
    expect(file.format, 1);
    expect(file.ticksPerQuarter, 480);
    expect(file.tracks.map((t) => t.name), [null, 'Soprano', 'Bas – İkinci']);
    final soprano = file.tracks[1];
    expect(soprano.notes.map((n) => (n.key, n.startTick, n.endTick)), [
      (72, 0, 480),
      (74, 480, 960),
    ]);
    expect(soprano.keyRange, (72, 74));
    expect(file.tracks[2].channels, {3});
    expect(file.tracks[2].notes.single.velocity, 60);
    expect(file.tempos.single.bpm, closeTo(90, 0.01));
    expect(file.timeSignatures.single.denominator, 4);
    // 960 ticks = 2 quarters at 90 BPM (tempo stored as whole µs).
    expect(file.lengthSeconds, closeTo(4 / 3, 1e-5));
    expect(file.measureStarts(), [0]);
  });

  test('format 0 with running status and note-on velocity 0 as note-off', () {
    final file = parse([
      ...header(format: 0),
      ...track([
        (0, on(0, 60)),
        (240, [62, 70]), // running status: note on 62
        (240, [60, 0]), // running status, velocity 0 = off 60
        (240, [62, 0]),
      ]),
    ]);
    final notes = file.tracks.single.notes;
    expect(notes.map((n) => (n.key, n.startTick, n.endTick)), [
      (60, 0, 480),
      (62, 240, 720),
    ]);
    // No tempo/signature in the file: SMF defaults.
    expect(file.tempos.single.microsPerQuarter, 500000);
    expect(file.timeSignatures.single.numerator, 4);
  });

  test('tempo changes are integrated piecewise into seconds', () {
    final file = parse([
      ...header(format: 0, division: 100),
      ...track([
        (0, tempo(60)),
        (0, on(0, 60)),
        (200, tempo(120)),
        (200, off(0, 60)),
      ]),
    ]);
    // 200 ticks at 60 BPM (2 s) + 200 ticks at 120 BPM (1 s).
    expect(file.secondsAt(200), closeTo(2, 1e-9));
    expect(file.secondsAt(400), closeTo(3, 1e-9));
    expect(file.secondsAt(100), closeTo(1, 1e-9));
  });

  test('measures follow time signature changes', () {
    final file = parse([
      ...header(format: 0, division: 4),
      ...track([
        (0, timeSig(4, 2)),
        (0, on(0, 60)),
        (32, timeSig(3, 2)), // two 4/4 bars (16 ticks each)
        (36, off(0, 60)), // three 3/4 bars (12 ticks each)
      ]),
    ]);
    expect(file.measureStarts(), [0, 16, 32, 44, 56]);
    expect(file.measureAt(0), 1);
    expect(file.measureAt(31), 2);
    expect(file.measureAt(45), 4);
  });

  test('overlapping same-key notes close first-in first-out; a hanging '
      'note is closed at track end and counted', () {
    final file = parse([
      ...header(format: 0),
      ...track([
        (0, on(0, 60)),
        (100, on(0, 60)),
        (100, off(0, 60)),
        (100, off(0, 60)),
        (0, on(0, 64)),
        (50, off(0, 99)), // stray off: ignored
        (50, [0xB0, 7, 100]), // controller: skipped
      ]),
    ]);
    final t = file.tracks.single;
    expect(t.notes.map((n) => (n.key, n.startTick, n.endTick)), [
      (60, 0, 200),
      (60, 100, 300),
      (64, 300, 400),
    ]);
    expect(t.unterminatedNotes, 1);
  });

  test('SysEx, program change and unknown chunks are skipped', () {
    final file = parse([
      ...header(tracks: 1),
      ...chunk('XFIH', [1, 2, 3]),
      ...track([
        (0, [0xF0, 3, 0x7E, 0x7F, 0xF7]),
        (0, [0xC0, 52]),
        (0, on(0, 60)),
        (10, off(0, 60)),
      ]),
    ]);
    expect(file.tracks.single.notes, hasLength(1));
  });

  group('rejects', () {
    test('non-MIDI, format 2 and SMPTE division', () {
      expect(
        () => parse(ascii.encode('RIFF....WAVEfmt ')),
        throwsMidi('not a MIDI'),
      );
      expect(
        () => parse([...header(format: 2), ...track([])]),
        throwsMidi('format 2'),
      );
      expect(
        () => parse([...header(division: 0xE728), ...track([])]),
        throwsMidi('SMPTE'),
      );
      expect(
        () => parse([
          ...header(format: 0, tracks: 2),
          ...track([]),
          ...track([]),
        ]),
        throwsMidi('exactly one track'),
      );
    });

    test('truncated chunks, missing tracks and missing end-of-track', () {
      final good = [
        ...header(),
        ...track([(0, on(0, 60)), (10, off(0, 60))]),
      ];
      expect(
        () => parse(good.sublist(0, good.length - 3)),
        throwsMidi('truncated'),
      );
      expect(
        () => parse([...header(tracks: 2), ...track([])]),
        throwsMidi('missing tracks'),
      );
      expect(
        () => parse([
          ...header(),
          ...track([(0, on(0, 60))], end: false),
        ]),
        throwsMidi('end-of-track'),
      );
    });

    test('malformed events', () {
      expect(
        () => parse([
          ...header(),
          ...track([
            (0, [60, 80]),
          ]),
        ]),
        throwsMidi('running status'),
      );
      expect(
        () => parse([
          ...header(),
          ...chunk('MTrk', [0xFF, 0xFF, 0xFF, 0xFF, 0x7F]),
        ]),
        throwsMidi('longer than 4 bytes'),
      );
      expect(
        () => parse([
          ...header(),
          ...track([
            (0, [0xFF, 0x51, 3, 0, 0, 0]),
          ]),
        ]),
        throwsMidi('zero tempo'),
      );
      expect(
        () => parse([
          ...header(),
          ...track([
            (0, [0x90, 0x90, 1]),
          ]),
        ]),
        throwsMidi('data byte'),
      );
    });

    test('over-limit input', () {
      final file = [
        ...header(),
        ...track([for (var i = 0; i < 10; i++) (1, on(0, 60))]),
      ];
      expect(
        () => parse(file, limits: const SmfLimits(maxEvents: 5)),
        throwsMidi('too many events'),
      );
      expect(
        () => parse(file, limits: const SmfLimits(maxBytes: 20)),
        throwsMidi('too large'),
      );
      expect(
        () => parse([
          ...header(tracks: 3),
          ...track([]),
          ...track([]),
          ...track([]),
        ], limits: const SmfLimits(maxTracks: 2)),
        throwsMidi('too many tracks'),
      );
    });
  });
}
