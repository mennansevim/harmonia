import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/target_note_tuning.dart';
import 'package:harmonia/domain/audio/piano_chord_reference.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_protocol.dart';

ExerciseProtocol _protocol(String note, double hz, {double a4 = 440}) =>
    ExerciseProtocol(
      mode: ExerciseMode.learning,
      a4Hz: a4,
      notes: [
        NoteEvent(
          note: TargetNote(note: note, frequencyHz: hz),
          onsetBeats: 0,
          durationBeats: 1,
        ),
      ],
    );

void main() {
  test('all canonical MIDI targets map to existing 12TET formula', () {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    for (var midi = 0; midi <= 127; midi++) {
      final name = '${names[midi % 12]}${midi ~/ 12 - 1}';
      expect(TargetNoteTuning.midiFor(name), midi);
      expect(
        TargetNoteTuning.frequencyFor(name, a4Hz: 440),
        closeTo(440 * math.pow(2, (midi - 69) / 12), 1e-9),
      );
    }
  });
  test('enharmonics preserve octave carry, not target octave folding', () {
    for (final (a, b) in [
      ('C#4', 'Db4'),
      ('B#3', 'C4'),
      ('Cb4', 'B3'),
      ('E#4', 'F4'),
      ('Fb4', 'E4'),
    ]) {
      expect(TargetNoteTuning.midiFor(a), TargetNoteTuning.midiFor(b));
    }
  });
  test('rounded two-decimal metadata remains valid', () {
    for (final note in ['C4', 'A4', 'F#5', 'G9']) {
      final hz = TargetNoteTuning.frequencyFor(note, a4Hz: 440);
      _protocol(note, (hz * 100).round() / 100);
    }
  });
  test('wrong octave or note label fails before playback/scoring', () {
    expect(() => _protocol('C4', 523.25), throwsArgumentError);
    expect(() => _protocol('D4', 261.63), throwsArgumentError);
  });
  test('A4 tuning mismatch rejected, correctly retuned target accepted', () {
    expect(() => _protocol('C4', 261.63, a4: 442), throwsArgumentError);
    final hz = TargetNoteTuning.frequencyFor('C4', a4Hz: 442);
    expect(_protocol('C4', hz, a4: 442).a4Hz, 442);
    expect(() => _protocol('A4', 440, a4: 442), throwsArgumentError);
  });
  test('malformed, solfege, whitespace and out-of-range labels rejected', () {
    for (final note in [
      'Do4',
      'H4',
      'c4',
      'C##4',
      'C 4',
      ' C4',
      'C4\n',
      'C10',
      'Cb-1',
      'B#9',
      'G#9',
    ]) {
      expect(() => TargetNoteTuning.midiFor(note), throwsArgumentError);
    }
  });
  test('numeric boundaries fail closed', () {
    for (final a4 in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => TargetNoteTuning.frequencyFor('A4', a4Hz: a4),
        throwsArgumentError,
      );
    }
    for (final hz in [0.0, -1.0, double.nan, double.infinity, 440.01]) {
      expect(() => _protocol('A4', hz), throwsArgumentError);
    }
    expect(
      () => TargetNoteTuning.frequencyFor('G9', a4Hz: 1e308),
      throwsArgumentError,
    );
  });
  test('protocol JSON reconstruction rechecks tuning consistency', () {
    final data = _protocol('C4', 261.63).toJson();
    expect(ExerciseProtocol.fromJson(data).toJson(), data);
    expect(
      () => ExerciseProtocol.fromJson({
        ...data,
        'tuning': {'system': '12tet', 'a4Hz': 442},
      }),
      throwsArgumentError,
    );
  });
  test('late invalid event cannot survive as valid sequence prefix', () {
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [
          NoteEvent(
            note: const TargetNote(note: 'A4', frequencyHz: 440),
            onsetBeats: 0,
            durationBeats: 1,
          ),
          NoteEvent(
            note: const TargetNote(note: 'A5', frequencyHz: 440),
            onsetBeats: 1,
            durationBeats: 1,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
  test('piano generated targets and rhythm-only protocols still valid', () {
    for (final a4 in [400.0, 440.0, 442.0, 480.0]) {
      final reference = PianoChordReference(
        midiNotes: [21, 60, 69, 108],
        a4Hz: a4,
      );
      expect(
        reference
            .configure(
              id: 'test',
              title: 'test',
              difficulty: 1,
              contentVersion: 'test-1',
            )
            .protocol
            .notes
            .length,
        4,
      );
    }
    expect(
      ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [],
        rhythmOnsetsBeats: [0, 1],
      ).notes,
      isEmpty,
    );
  });
}
