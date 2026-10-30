import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';

void main() {
  NoteEvent note({double onset = 0, double duration = 1}) => NoteEvent(
    note: const TargetNote(note: 'C4', frequencyHz: 261.63),
    onsetBeats: onset,
    durationBeats: duration,
  );
  test('simultaneous four-note reference retains ordered vocal response', () {
    final protocol = ExerciseProtocol(
      mode: ExerciseMode.recallExam,
      notes: List.generate(4, (_) => note()),
      presentation: ReferencePresentation.simultaneous,
      recallDelayMs: 2000,
    );
    final configured = ConfiguredExercise(
      exercise: const Exercise(
        id: 'four',
        skill: Skill.chord,
        title: 'Dört ses',
        difficulty: 2,
        mode: ExerciseMode.recallExam,
      ),
      protocol: protocol,
    );
    expect(configured.protocol.notes.length, 4);
    expect(protocol.responseOrder, ResponseOrder.exact);
    expect(protocol.targetVisibleDuringResponse, isFalse);
    final decoded = ExerciseProtocol.fromJson(
      jsonDecode(jsonEncode(protocol.toJson())) as Map<String, Object?>,
    );
    expect(decoded.toJson(), protocol.toJson());
  });
  test('notes and rhythms are defensive snapshots', () {
    final notes = [note()];
    final rhythms = <double>[0, 1];
    final p = ExerciseProtocol(
      mode: ExerciseMode.learning,
      notes: notes,
      rhythmOnsetsBeats: rhythms,
    );
    notes.clear();
    rhythms.clear();
    expect(p.notes.length, 1);
    expect(p.rhythmOnsetsBeats.length, 2);
    expect(() => p.notes.clear(), throwsUnsupportedError);
    expect(() => p.rhythmOnsetsBeats.add(3), throwsUnsupportedError);
  });
  test('invalid notes and runtime configuration rejected', () {
    for (final duration in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => note(duration: duration), throwsArgumentError);
    }
    expect(
      () => ExerciseProtocol(mode: ExerciseMode.learning, notes: []),
      throwsArgumentError,
    );
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note()],
        a4Hz: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note()],
        tempoBpm: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note()],
        meterDenominator: 3,
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note()],
        recallDelayMs: -1,
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note()],
        maxReferencePlays: 0,
      ),
      throwsArgumentError,
    );
  });
  test('sequential overlap and non-zero simultaneous onset rejected', () {
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note(), note(onset: .5)],
      ),
      throwsArgumentError,
    );
    expect(
      () => ExerciseProtocol(
        mode: ExerciseMode.learning,
        notes: [note(onset: 1)],
        presentation: ReferencePresentation.simultaneous,
      ),
      throwsArgumentError,
    );
  });
  test('rhythm order must be strictly increasing and finite', () {
    for (final rhythm in [
      [0.0, 0.0],
      [1.0, 0.0],
      [-1.0],
      [double.nan],
    ]) {
      expect(
        () => ExerciseProtocol(
          mode: ExerciseMode.learning,
          notes: [],
          rhythmOnsetsBeats: rhythm,
        ),
        throwsArgumentError,
      );
    }
  });
  test(
    'recall aids rejected while choir accompaniment and sight reading supported',
    () {
      expect(
        () => ExerciseProtocol(
          mode: ExerciseMode.recallExam,
          notes: [note()],
          allowPitchHint: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExerciseProtocol(
          mode: ExerciseMode.recallExam,
          notes: [note()],
          allowTransposition: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => ExerciseProtocol(
          mode: ExerciseMode.learning,
          notes: [note()],
          allowAccompaniment: true,
        ),
        throwsArgumentError,
      );
      expect(
        ExerciseProtocol(
          mode: ExerciseMode.choirPractice,
          notes: [note()],
          allowAccompaniment: true,
        ).allowAccompaniment,
        isTrue,
      );
      expect(
        ExerciseProtocol(
          mode: ExerciseMode.sightReading,
          notes: [note()],
        ).targetVisibleDuringResponse,
        isTrue,
      );
    },
  );
  test('skill and mode conflicts rejected when binding catalog', () {
    final p = ExerciseProtocol(mode: ExerciseMode.learning, notes: [note()]);
    expect(
      () => ConfiguredExercise(
        exercise: const Exercise(
          id: 'e',
          skill: Skill.chord,
          title: 'e',
          difficulty: 1,
        ),
        protocol: p,
      ),
      throwsArgumentError,
    );
    expect(
      () => ConfiguredExercise(
        exercise: const Exercise(
          id: 'e',
          skill: Skill.pitch,
          title: 'e',
          difficulty: 1,
          mode: ExerciseMode.recallExam,
        ),
        protocol: p,
      ),
      throwsArgumentError,
    );
  });
  test('unknown schema or tuning cannot silently migrate', () {
    final json = ExerciseProtocol(
      mode: ExerciseMode.learning,
      notes: [note()],
    ).toJson();
    expect(
      () => ExerciseProtocol.fromJson({...json, 'schemaVersion': 99}),
      throwsFormatException,
    );
    expect(
      () => ExerciseProtocol.fromJson({
        ...json,
        'tuning': {'system': 'makam', 'a4Hz': 440},
      }),
      throwsFormatException,
    );
  });
}
