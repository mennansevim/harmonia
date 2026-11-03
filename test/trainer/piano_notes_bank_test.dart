import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/trainer/audio/piano_notes.dart';
import 'package:resonia/trainer/koro/range_ladder.dart';

/// Mono PCM16 samples of a RIFF/WAVE file, walking past LIST and other chunks.
(List<double>, int) readPcm16(Uint8List bytes) {
  final b = ByteData.sublistView(bytes);
  String tag(int at) => ascii.decode(bytes.sublist(at, at + 4));
  expect(tag(0), 'RIFF');
  expect(tag(8), 'WAVE');
  int? rate;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = tag(at);
    final size = b.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'fmt ') {
      expect(b.getUint16(body, Endian.little), 1, reason: 'PCM');
      expect(b.getUint16(body + 2, Endian.little), 1, reason: 'mono');
      rate = b.getUint32(body + 4, Endian.little);
      expect(b.getUint16(body + 14, Endian.little), 16, reason: '16-bit');
    } else if (id == 'data') {
      final n = size ~/ 2;
      return (
        [
          for (var i = 0; i < n; i++)
            b.getInt16(body + 2 * i, Endian.little) / 32768,
        ],
        rate!,
      );
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  fail('no data chunk');
}

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

/// Mean energy of the first six harmonics of [midi] (±30 cents each);
/// [offset] 0.5 measures the half-way points, where only a note an octave
/// lower would have partials.
/// Unlike a pitch tracker it does not depend on a strong fundamental, so it
/// also checks the low piano notes and catches octave labels.
double _comb(List<double> x, int rate, num midi, {double offset = 0}) {
  var sum = 0.0;
  var count = 0;
  for (var h = 1; h <= 6; h++) {
    final f = (h - offset) * 440 * math.pow(2, (midi - 69) / 12).toDouble();
    if (f > rate / 2 - 500) break;
    var best = 0.0;
    for (var c = -30; c <= 30; c += 10) {
      best = math.max(best, _bin(x, rate, f * math.pow(2, c / 1200)));
    }
    sum += best;
    count++;
  }
  return sum / count;
}

/// Notes whose files sounded one white key high on 2026-11-03 (ADR-040).
const heldBack = ['A5', 'B5', 'C6', 'D6', 'E6', 'F6', 'G6', 'A6', 'B6', 'C7'];

/// Why the WAV at [path] does not sound [name], or null when it does.
String? labelProblem(String name, String path) {
  final midi = rangeLadderNotes.firstWhere(
    (m) => PianoNoteBank.noteName(m) == name,
  );
  final (samples, rate) = readPcm16(File(path).readAsBytesSync());
  if (rate != 48000) return '$name: $rate Hz';
  final seg = samples.sublist(
    (0.05 * rate).round(),
    math.min(samples.length, (0.55 * rate).round()),
  );
  final own = _comb(seg, rate, midi);
  if (own <= 2 * _comb(seg, rate, midi, offset: 0.5)) {
    return '$name has partials of the octave below';
  }
  for (final d in const [-2, -1, 1, 2, 12]) {
    if (own <= _comb(seg, rate, midi + d)) {
      return '$name sounds closer to ${d > 0 ? '+' : ''}$d';
    }
  }
  // Where the shared pitch core reads it (64–1900 Hz) it must agree.
  final target = 440.0 * math.pow(2, (midi - 69) / 12);
  if (target < 64 || target > 1900) return null;
  final hz = RecordingPitchAnalyzer()
      .analyze(
        samples: samples.sublist(0, math.min(samples.length, rate * 2)),
        sampleRateHz: rate,
      )
      .representativeFrequencyHz;
  if (hz == null) return '$name: no pitch';
  final cents = centsBetween(hz, target);
  return cents.abs() < 50 ? null : '$name: $hz Hz (${cents.round()} cents)';
}

void main() {
  final catalog =
      jsonDecode(File(PianoNoteBank.catalogPath).readAsStringSync()) as Map;
  final notes = (catalog['notes'] as Map).cast<String, String>();

  test('the catalog is cleared and holds back the mislabelled top notes', () {
    expect(catalog['kind'], 'prerecorded_piano_notes');
    expect((catalog['rightsReference'] as String).trim(), isNotEmpty);
    expect((catalog['heldBack'] as Map)['notes'], heldBack);
    expect(notes.keys.toSet(), {
      for (final m in rangeLadderNotes)
        if (!heldBack.contains(PianoNoteBank.noteName(m)))
          PianoNoteBank.noteName(m)!,
    });
    final onDisk = Directory('assets/audio/piano/notes')
        .listSync()
        .map((f) => f.path.split('/').last)
        .where((n) => n.endsWith('.wav'))
        .toSet();
    expect(onDisk, {for (final p in notes.values) p.split('/').last});
  });

  test('each recording sounds the note its name says', () {
    for (final entry in notes.entries) {
      expect(labelProblem(entry.key, entry.value), isNull);
    }
  });
}
