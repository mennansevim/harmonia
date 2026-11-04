import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/content/rhythm_patterns.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';
import 'package:resonia/trainer/koro/aksak_patterns.dart';

RhythmPattern _p(String id, List<double> beats, {double bpm = 80, int d = 1}) =>
    RhythmPattern(
      title: id,
      description: id,
      exercise: ConfiguredExercise(
        exercise: Exercise(
          id: id,
          skill: Skill.rhythm,
          title: id,
          difficulty: d,
          contentVersion: 'test',
        ),
        protocol: ExerciseProtocol(
          mode: ExerciseMode.learning,
          notes: const [],
          rhythmOnsetsBeats: beats,
          tempoBpm: bpm,
          maxReferencePlays: 3,
        ),
      ),
    );

List<String> _ids(List<RhythmPattern> ps) => [
  for (final p in ps) p.exercise.exercise.id,
];

void main() {
  test('shipped catalogs already run easy → hard', () {
    expect(
      _ids(orderedEasyToHard(draftRhythmPatterns)),
      _ids(draftRhythmPatterns),
    );
    expect(
      _ids(orderedEasyToHard(draftAksakPatterns)),
      _ids(draftAksakPatterns),
    );
  });

  test('order: tag, syncopation, subdivision, shortest gap, count', () {
    final shuffled = [
      _p('tag2', [0, 1], d: 2),
      _p('syncopated', [0, 1.5, 2, 3]),
      _p('subdivided', [0, 1, 1.5, 2]),
      _p('fast', [0, 1, 2], bpm: 120),
      _p('long', [0, 1, 2, 3, 4]),
      _p('short', [0, 1, 2]),
    ];
    expect(_ids(orderedEasyToHard(shuffled)), [
      'short',
      'long',
      'fast',
      'subdivided',
      'syncopated',
      'tag2',
    ]);
  });

  test('ties keep catalog order and the input is not mutated', () {
    final a = _p('a', [0, 1, 2]), b = _p('b', [0, 1, 2]);
    final input = [b, a];
    expect(_ids(orderedEasyToHard(input)), ['b', 'a']);
    expect(_ids(input), ['b', 'a']);
  });
}
