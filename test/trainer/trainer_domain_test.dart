import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';
import 'package:resonia/trainer/audio/synth.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/koro/aksak_patterns.dart';
import 'package:resonia/trainer/koro/range_test.dart';
import 'package:resonia/trainer/koro/voice_count.dart';
import 'package:resonia/trainer/quiz/quiz.dart';

void main() {
  group('music vocabulary', () {
    test('pitch names follow the chosen notation', () {
      expect(PitchClass.name(0, NoteNotation.solfege), 'Do');
      expect(PitchClass.name(11, NoteNotation.solfege), 'Si');
      expect(PitchClass.name(6, NoteNotation.letter), 'F♯');
      expect(PitchClass.name(13, NoteNotation.letter), 'C♯');
      expect(PitchClass.midiName(60, NoteNotation.letter), 'C4');
    });

    test('midi and Hz convert both ways', () {
      expect(midiToHz(69), closeTo(440, 1e-9));
      expect(midiToHz(60), closeTo(261.6256, 1e-3));
      expect(hzToMidi(220), closeTo(57, 1e-9));
    });

    test('interval, chord and scale tables are consistent', () {
      expect(Intervals.all.map((i) => i.semitones), [
        for (var i = 1; i <= 12; i++) i,
      ]);
      expect(Chords.byId('dim7').tones, [0, 3, 6, 9]);
      for (final s in Scales.all) {
        expect(s.steps.first, 0);
        expect(s.steps, orderedEquals([...s.steps]..sort()));
        if (s.color != null) expect(s.color, lessThan(s.steps.length));
      }
      for (final p in Progressions.all) {
        expect(p.chords, isNotEmpty);
        for (final (_, q) in p.chords) {
          expect(Chords.byId(q), isNotNull);
        }
      }
    });

    test('labels honour transposition for pitch', () {
      expect(itemLabel(TrainerKind.pitch, '2', transposition: 2), 'Do');
      expect(itemLabel(TrainerKind.interval, 'P5', long: true), 'Tam 5\'li');
    });
  });

  group('curriculum', () {
    test('every path is well formed', () {
      for (final path in trainerPaths.values) {
        final ids = path.nodes.map((n) => n.id).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: '${path.trainer} ids unique',
        );
        expect(path.nodes.first.kind, NodeKind.intro);
        expect(path.nodes.last.kind, NodeKind.finalExam);
        expect(path.introSlides, isNotEmpty);
        for (final n in path.nodes.skip(1)) {
          expect(n.items, isNotEmpty, reason: n.id);
          for (final i in n.items) {
            expect(path.trainer.allItems, contains(i), reason: '${n.id}: $i');
          }
          for (final i in n.newItems) {
            expect(n.items, contains(i), reason: '${n.id} new item $i');
          }
          expect(n.registers, isNotEmpty);
        }
      }
    });

    test('every ladder has stages, gates and a final rehearsal', () {
      for (final path in trainerPaths.values) {
        final gates = path.nodes.where((n) => n.kind == NodeKind.checkpoint);
        expect(path.lessonCount, greaterThan(15), reason: '${path.trainer}');
        expect(gates.length, greaterThanOrEqualTo(2));
        final introduced = {for (final n in path.nodes) ...n.newItems};
        expect(introduced, path.trainer.allItems.toSet());
      }
    });

    test('personal lesson copy does not assume choir membership', () {
      final copy = [
        for (final path in trainerPaths.values) ...[
          for (final node in path.nodes) ...[node.title, node.subtitle],
          for (final slide in path.introSlides) ...[
            slide.title,
            slide.body,
            ...slide.bullets,
            ...?slide.highlight,
          ],
        ],
      ].join('\n');

      expect(
        copy,
        isNot(contains(RegExp(r'\bkoro(?:da|nun)?\b', caseSensitive: false))),
      );
      expect(
        copy,
        isNot(
          contains(
            RegExp(r'\bparti(?:ler|nin|yle|si)?\b', caseSensitive: false),
          ),
        ),
      );
    });
  });

  group('sound and synthesis', () {
    final random = math.Random(7);

    test('interval sound plays low then high (ascending)', () {
      final spec = SoundFactory(
        random,
      ).interval('P5', rootMidi: 60, learn: true);
      expect(spec.events[0].midiNotes, [60]);
      expect(spec.events[1].midiNotes, [67]);
      expect(spec.events[2].midiNotes, [60, 67]);
    });

    test('descending interval starts on the top note', () {
      final spec = SoundFactory(
        random,
      ).interval('M3', rootMidi: 60, direction: IntervalDirection.descending);
      expect(spec.events.first.midiNotes, [64]);
    });

    test('synth renders bounded, non-silent PCM of the right length', () {
      const synth = TrainerSynth();
      for (final t in Timbre.values) {
        final wav = synth.render(
          SoundFactory(random).chord('maj', rootMidi: 60),
          t,
        );
        expect(wav.durationSeconds, closeTo(1.8 + 0.25, 0.05));
        final peak = wav.samples.map((s) => s.abs()).reduce(math.max);
        expect(peak, closeTo(0.8, 0.01), reason: '$t');
      }
    });

    test('progressions keep a bass note under every chord', () {
      final spec = SoundFactory(random).progression('ii-V-I', keyRoot: 48);
      expect(spec.events, hasLength(3));
      for (final e in spec.events) {
        expect(e.midiNotes.first, lessThan(e.midiNotes[1]));
      }
    });
  });

  group('quiz generation', () {
    test('identify questions only use the pool', () {
      final gen = QuizGenerator(
        const QuizConfig(
          trainer: TrainerKind.chord,
          pool: ['maj', 'min', 'dim'],
          length: 30,
        ),
        random: math.Random(1),
      );
      for (final q in gen.session()) {
        expect(q.type, QuestionType.identify);
        expect(['maj', 'min', 'dim'], contains(q.answer));
      }
    });

    test('single-item pools alternate yes/no and find', () {
      final gen = QuizGenerator(
        const QuizConfig(
          trainer: TrainerKind.interval,
          pool: ['P8'],
          length: 6,
        ),
        random: math.Random(2),
      );
      final qs = gen.session();
      expect(qs.map((q) => q.type).toSet(), {
        QuestionType.yesNo,
        QuestionType.find,
      });
      for (final q in qs) {
        if (q.type == QuestionType.find) {
          expect(q.options[q.correctIndex], 'P8');
          expect(q.options.toSet().length, q.options.length);
          expect(q.sounds, hasLength(q.options.length));
        } else {
          expect(q.target, 'P8');
          expect(q.isMatch, q.answer == 'P8');
        }
      }
    });

    test('summary counts first attempts per item', () {
      final gen = QuizGenerator(
        const QuizConfig(trainer: TrainerKind.scale, pool: ['major', 'blues']),
        random: math.Random(3),
      );
      final a = gen.identify();
      final b = gen.identify();
      final s = QuizSummary([AnswerRecord(a, true), AnswerRecord(b, false)]);
      expect(s.accuracy, 0.5);
      expect(s.byItem().values.fold(0, (n, v) => n + v.$2), 2);
    });
  });

  group('choir', () {
    test('aksak patterns are valid two-bar rhythm drafts', () {
      expect(draftAksakPatterns, hasLength(5));
      for (final p in draftAksakPatterns) {
        expect(
          p.exercise.protocol.rhythmOnsetsBeats.length,
          greaterThanOrEqualTo(5),
        );
      }
    });

    test('voicings have the requested number of distinct notes', () {
      final r = math.Random(4);
      for (final n in [2, 3, 4]) {
        final v = choirVoicing(n, r);
        expect(v, hasLength(n));
        expect(v.toSet(), hasLength(n));
      }
    });

    test(
      'range evidence: a steady tone yields its pitch, silence is unmeasured',
      () {
        final tone = Pcm16Wav.tone(
          frequencyHz: 220,
          sampleRateHz: 16000,
          durationSeconds: 1.5,
        );
        final take = evaluateRangeEvidence(
          RecordingPitchAnalyzer().analyze(
            samples: tone.samples,
            sampleRateHz: 16000,
          ),
        );
        expect(take.hz, closeTo(220, 2));
        final silent = evaluateRangeEvidence(
          RecordingPitchAnalyzer().analyze(
            samples: List.filled(16000, 0.0),
            sampleRateHz: 16000,
          ),
        );
        expect(silent.hz, isNull);
        expect(silent.failure, isNotNull);
      },
    );

    test('lower choir parts hear lessons one octave down', () {
      final node = trainerPaths[TrainerKind.interval]!.nodes.firstWhere(
        (n) => n.registers.contains(Register.high),
      );
      final tenor = QuizConfig.forNode(node, voice: VoicePart.tenor);
      final alto = QuizConfig.forNode(node, voice: VoicePart.alto);
      expect(tenor.registers, isNot(contains(Register.high)));
      expect(alto.registers, node.registers);
      expect(VoicePart.bass.fit(Register.medium), Register.low);
    });

    test('part suggestion is draft and needs a real span', () {
      expect(suggestPart(60, 62), isNull);
      expect(suggestPart(62, 81)!.title, 'Soprano');
      expect(suggestPart(41, 62)!.title, 'Bas');
    });
  });
}
