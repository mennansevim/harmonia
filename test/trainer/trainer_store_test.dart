import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/trainer/audio/synth.dart';
import 'package:harmonia/trainer/domain/curriculum.dart';
import 'package:harmonia/trainer/domain/music.dart';
import 'package:harmonia/trainer/domain/trainers.dart';
import 'package:harmonia/trainer/state/trainer_store.dart';

void main() {
  var now = DateTime(2026, 10, 29, 9);
  TrainerStore make([MemoryTrainerPersistence? p]) =>
      TrainerStore(p ?? MemoryTrainerPersistence(), clock: () => now);

  setUp(() => now = DateTime(2026, 10, 29, 9));

  test('first node is open, later ones unlock in order, gates always open', () {
    final s = make();
    final path = trainerPaths[TrainerKind.interval]!;
    expect(s.isUnlocked(path.nodes[0]), isTrue);
    expect(s.isUnlocked(path.nodes[1]), isFalse);
    final gate = path.nodes.firstWhere((n) => n.kind == NodeKind.checkpoint);
    expect(s.isUnlocked(gate), isTrue);
    s.completeNode(path.nodes[0], 1);
    expect(s.isUnlocked(path.nodes[1]), isTrue);
    expect(s.nextNode(TrainerKind.interval)!.id, path.nodes[1].id);
  });

  test('stars and review flag follow accuracy; best stars are kept', () {
    final s = make();
    final lesson = trainerPaths[TrainerKind.chord]!.nodes[1];
    s.completeNode(lesson, 0.5);
    expect(s.progressOf(lesson.id)!.stars, 1);
    expect(s.progressOf(lesson.id)!.review, isTrue);
    s.completeNode(lesson, 1);
    expect(s.progressOf(lesson.id)!.stars, 3);
    expect(s.progressOf(lesson.id)!.review, isFalse);
    s.completeNode(lesson, 0.85);
    expect(s.progressOf(lesson.id)!.stars, 3);
  });

  test(
    'a failed gate completes nothing; a passed gate tests out earlier nodes',
    () {
      final s = make();
      final path = trainerPaths[TrainerKind.scale]!;
      final gate = path.nodes.firstWhere((n) => n.kind == NodeKind.checkpoint);
      expect(s.completeNode(gate, 0.7), isFalse);
      expect(s.completedCount(TrainerKind.scale), 0);
      expect(s.completeNode(gate, 0.9), isTrue);
      expect(s.completedCount(TrainerKind.scale), path.indexOf(gate.id) + 1);
      expect(s.mastery(TrainerKind.scale), greaterThan(0));
    },
  );

  test(
    'streak counts consecutive active days and tolerates today being idle',
    () {
      final s = make();
      now = DateTime(2026, 10, 27, 10);
      s.recordAnswer(TrainerKind.pitch, '0', true);
      now = DateTime(2026, 10, 28, 10);
      s.recordAnswer(TrainerKind.pitch, '0', false);
      now = DateTime(2026, 10, 29, 8);
      expect(s.streak, 2);
      s.recordAnswer(TrainerKind.pitch, '7', true);
      expect(s.streak, 3);
      now = DateTime(2026, 10, 31, 8);
      expect(s.streak, 0);
    },
  );

  test('answers feed item stats, XP and the per-trainer trend', () {
    final s = make();
    s.recordAnswer(TrainerKind.interval, 'P5', true);
    s.recordAnswer(TrainerKind.interval, 'P5', false);
    expect(s.itemStats(TrainerKind.interval)['P5']!.accuracy, 0.5);
    expect(s.xp, 12);
    expect(s.trend(TrainerKind.interval).last, 0.5);
    expect(s.trend(TrainerKind.chord).last, isNull);
  });

  test('state survives an encode/decode round trip', () async {
    final p = MemoryTrainerPersistence();
    final a = make(p);
    a
      ..onboardingDone = true
      ..notation = NoteNotation.letter
      ..timbre = Timbre.cello
      ..transposition = 3
      ..dailyMinutes = 12
      ..koroRange = '48-67'
      ..voicePart = 'alto';
    a.answers['focus'] = ['interval'];
    a.completeNode(trainerPaths[TrainerKind.pitch]!.nodes[0], 1);
    a.recordAnswer(TrainerKind.pitch, '4', true);
    await a.flush();

    final b = make(p);
    await b.load();
    expect(b.loadFailed, isFalse);
    expect(b.onboardingDone, isTrue);
    expect(b.notation, NoteNotation.letter);
    expect(b.timbre, Timbre.cello);
    expect(b.transposition, 3);
    expect(b.dailyMinutes, 12);
    expect(b.koroRange, '48-67');
    expect(b.part, VoicePart.alto);
    expect(b.answers['focus'], ['interval']);
    expect(b.isComplete('pitch-intro'), isTrue);
    expect(b.itemStats(TrainerKind.pitch)['4']!.correct, 1);
    expect(b.streak, 1);
  });

  test('corrupt fields fall back to defaults instead of crashing', () async {
    final s = make(
      MemoryTrainerPersistence({
        'prefs': {'notation': 'klingon', 'transposition': 'x'},
        'nodes': {'pitch-intro': 'bad'},
        'stats': {
          'pitch': {
            '0': [1],
          },
        },
      }),
    );
    await s.load();
    expect(s.loadFailed, isFalse);
    expect(s.notation, NoteNotation.solfege);
    expect(s.nodes, isEmpty);
    expect(s.stats['pitch'], isEmpty);
  });

  test('reset wipes everything', () async {
    final p = MemoryTrainerPersistence();
    final s = make(p)..onboardingDone = true;
    s.recordAnswer(TrainerKind.chord, 'maj', true);
    await s.flush();
    await s.resetAll();
    expect(s.onboardingDone, isFalse);
    expect(s.totalQuestions, 0);
    expect(p.document, isNull);
  });
}
