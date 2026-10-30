import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/piano_chord_reference.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';

void main() {
  for (final keys in [
    [60, 67],
    [60, 64, 67],
    [60, 64, 67, 71],
  ]) {
    test('${keys.length} piano keys bind to simultaneous chord protocol', () {
      final reference = PianoChordReference(midiNotes: keys.reversed.toList());
      final exercise = reference.configure(
        id: 'test',
        title: 'Test',
        difficulty: 1,
        contentVersion: 'piano-test-1',
      );
      expect(exercise.exercise.skill, Skill.chord);
      expect(reference.midiNotes, keys);
      expect(exercise.protocol.notes.length, keys.length);
      expect(exercise.protocol.notes.every((n) => n.onsetBeats == 0), isTrue);
      expect(
        exercise.protocol.presentation,
        ReferencePresentation.simultaneous,
      );
      expect(exercise.protocol.responseOrder, ResponseOrder.exact);
      expect(exercise.protocol.allowAccompaniment, isFalse);
      expect(exercise.protocol.notes.first.note.note, 'C4');
      expect(
        ExerciseProtocol.fromJson(exercise.protocol.toJson()).toJson(),
        exercise.protocol.toJson(),
      );
    });
  }
  test('A4/tuning and octave labels derive from the same key definition', () {
    final reference = PianoChordReference(midiNotes: [81, 69], a4Hz: 442);
    expect(reference.targetNotes.map((n) => n.note), ['A4', 'A5']);
    expect(reference.targetNotes.map((n) => n.frequencyHz), [442, 884]);
  });
  test('recall/anyOrder supports sequential answer without target hints', () {
    final reference = PianoChordReference(
      midiNotes: [60, 64, 67],
      mode: ExerciseMode.recallExam,
      responseOrder: ResponseOrder.anyOrder,
      recallDelayMs: 2000,
    );
    final protocol = reference
        .configure(
          id: 'test',
          title: 'Test',
          difficulty: 2,
          contentVersion: '1',
        )
        .protocol;
    expect(protocol.responseOrder, ResponseOrder.anyOrder);
    expect(protocol.targetVisibleDuringResponse, isFalse);
    expect(protocol.recallDelayMs, 2000);
    expect(protocol.allowPitchHint, isFalse);
  });
  test(
    'chord definition snapshots keys and rejects invalid cardinality/keys',
    () {
      final input = [67, 60];
      final reference = PianoChordReference(midiNotes: input);
      input.clear();
      expect(reference.midiNotes, [60, 67]);
      expect(() => reference.midiNotes.clear(), throwsUnsupportedError);
      expect(() => reference.targetNotes.clear(), throwsUnsupportedError);
      for (final keys in [
        <int>[],
        [60],
        [60, 60],
        [20, 60],
        [60, 109],
        [60, 61, 62, 63, 64],
      ]) {
        expect(() => PianoChordReference(midiNotes: keys), throwsArgumentError);
      }
    },
  );
  test('reference limits and incompatible modes are runtime-validated', () {
    for (final factory in <PianoChordReference Function()>[
      () => PianoChordReference(midiNotes: [60, 64], a4Hz: double.nan),
      () => PianoChordReference(midiNotes: [60, 64], a4Hz: 399),
      () => PianoChordReference(midiNotes: [60, 64], a4Hz: 481),
      () => PianoChordReference(midiNotes: [60, 64], durationMs: 99),
      () => PianoChordReference(midiNotes: [60, 64], durationMs: 5001),
      () => PianoChordReference(midiNotes: [60, 64], settleSilenceMs: -1),
      () => PianoChordReference(midiNotes: [60, 64], settleSilenceMs: 2001),
      () => PianoChordReference(midiNotes: [60, 64], recallDelayMs: 10001),
      () => PianoChordReference(midiNotes: [60, 64], maxReferencePlays: 0),
      () => PianoChordReference(
        midiNotes: [60, 64],
        mode: ExerciseMode.recallExam,
        maxReferencePlays: 2,
      ),
      () => PianoChordReference(
        midiNotes: [60, 64],
        mode: ExerciseMode.choirPractice,
      ),
    ]) {
      expect(factory, throwsArgumentError);
    }
  });
}
