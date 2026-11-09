// QA-INT-01: interval names explained for beginners — plain descriptions,
// a naming slide, a key-count keyboard and a silent help sheet in quizzes.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/app/scope.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/quiz/quiz_view.dart';
import 'package:resonia/trainer/ui/interval_keyboard.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle;

Future<void> _quiz(WidgetTester tester, QuizQuestion q) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.views.first.physicalSize = const Size(1170, 2532);
  binding.platformDispatcher.views.first.devicePixelRatio = 3;
  final store = memoryStore({'onboardingDone': true, 'setupDone': true});
  await store.load();
  await tester.pumpWidget(app(store));
  await settle(tester);
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .push(
        MaterialPageRoute<void>(
          builder: (_) =>
              QuizView(title: 't', questions: [q], onFinished: (_) {}),
        ),
      );
  await settle(tester);
}

void main() {
  final lang = Lang.en;
  tearDown(() => Lang.en = lang);

  test('every example fits the two-octave keyboard', () {
    expect(Intervals.byId('m2').exampleRoot, 4); // E → F
    expect(Intervals.byId('P4').exampleRoot, 7); // G → C
    for (final i in Intervals.all) {
      expect(i.exampleRoot + i.semitones, lessThan(24), reason: i.id);
    }
  });

  test('descriptions are plain: no theory words a beginner cannot read', () {
    for (final en in [false, true]) {
      Lang.en = en;
      for (final i in Intervals.all) {
        expect(
          i.feel.toLowerCase(),
          isNot(matches(RegExp('dominant|tonik|tonic|çevrim|inversion'))),
          reason: '${i.id} $en',
        );
      }
    }
  });

  test('the interval intro explains how names read, m2 and M2 included', () {
    Lang.en = false;
    final slides = trainerPaths[TrainerKind.interval]!.introSlides;
    final naming = slides.firstWhere(
      (s) => s.title == 'Aralık adları nasıl okunur?',
    );
    final text = naming.bullets.join('\n');
    expect(text, contains('m2 = küçük 2\'li'));
    expect(text, contains('M2 = büyük 2\'li'));
    expect(text, contains('yan yana iki tuş'));
  });

  testWidgets('the keyboard counts keys: a minor 2nd is one key', (
    tester,
  ) async {
    Lang.en = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IntervalKeyboard(interval: Intervals.byId('m2'))),
      ),
    );
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(
      tester.getSemantics(find.byType(IntervalKeyboard)).label,
      'Klavyede Mi → Fa: 1 yarım ses',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: IntervalKeyboard(interval: Intervals.byId('P5'))),
      ),
    );
    for (var n = 1; n <= 7; n++) {
      expect(find.text('$n'), findsOneWidget, reason: '$n');
    }
  });

  testWidgets('short names on answer buttons can be looked up, silently', (
    tester,
  ) async {
    Lang.en = false;
    final gen = QuizGenerator(
      const QuizConfig(trainer: TrainerKind.interval, pool: ['m2', 'M2']),
      random: math.Random(1),
    );
    await _quiz(tester, gen.identify());
    final audio = TrainerScope.read(
      tester.element(find.byType(QuizView)),
    ).audio;
    await tester.pump(const Duration(seconds: 2)); // question sound done
    await tester.tap(find.byKey(const Key('quiz_names_help')));
    await settle(tester);
    expect(find.text('Bu adlar ne demek?'), findsWidgets);
    expect(find.text('m2 · Küçük 2\'li'), findsOneWidget);
    expect(find.text('M2 · Büyük 2\'li'), findsOneWidget);
    // Help never plays a sound: it would give the answer away.
    expect(audio.playing.value, isFalse);
  });

  testWidgets('a named target shows its meaning and keyboard', (tester) async {
    Lang.en = false;
    final gen = QuizGenerator(
      const QuizConfig(trainer: TrainerKind.interval, pool: ['m2']),
      random: math.Random(1),
    );
    await _quiz(tester, gen.find(target: 'm2', choices: 3));
    await tester.tap(find.byKey(const Key('quiz_what_is')));
    await settle(tester);
    expect(find.byKey(const Key('quiz_explain')), findsOneWidget);
    expect(find.byType(IntervalKeyboard), findsOneWidget);
    expect(find.textContaining('yan yana iki tuş'), findsWidgets);
  });

  testWidgets('pitch questions keep their plain layout', (tester) async {
    final gen = QuizGenerator(
      const QuizConfig(trainer: TrainerKind.pitch, pool: ['0', '4']),
      random: math.Random(1),
    );
    await _quiz(tester, gen.identify());
    expect(find.byKey(const Key('quiz_names_help')), findsNothing);
  });

  group('chords and scales (QA-INT-02)', () {
    test('examples fit the keyboard; Turkish text has no broken suffix', () {
      for (final c in Chords.all) {
        expect(c.exampleRoot + c.tones.last, lessThan(24), reason: c.id);
      }
      for (final sc in Scales.all) {
        expect(sc.exampleRoot + 12, lessThan(24), reason: sc.id);
      }
      Lang.en = false;
      NoteNames.current = NoteNotation.letter;
      addTearDown(() => NoteNames.current = NoteNotation.solfege);
      final text = [
        for (final c in Chords.all) c.feel,
        for (final sc in Scales.all) sc.feel,
      ].join('\n');
      // "C'dan", "G'den": a Turkish suffix stuck to a letter name.
      expect(RegExp(r"\b[A-G][♭♯]?'").hasMatch(text), isFalse, reason: text);
      expect(text, contains('C sesinden'));
    });

    test('both intros explain how names read', () {
      Lang.en = false;
      final chord = trainerPaths[TrainerKind.chord]!.introSlides;
      final scale = trainerPaths[TrainerKind.scale]!.introSlides;
      expect(chord.map((s) => s.title), contains('Akor adları nasıl okunur?'));
      expect(scale.map((s) => s.title), contains('Dizi adları nasıl okunur?'));
      expect(chordNamingRules().join(), contains('Majör (maj)'));
      expect(scaleNamingRules().join(), contains('T = tam ses (2 tuş)'));
    });

    testWidgets('a chord shows its notes by name; a scale its steps', (
      tester,
    ) async {
      Lang.en = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotesKeyboard.chord(Chords.byId('maj'))),
        ),
      );
      for (final n in ['Do', 'Mi', 'Sol']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(
        find.text('Do + Mi + Sol birlikte · aralar 4 + 3 yarım ses'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NotesKeyboard.scale(Scales.byId('major'))),
        ),
      );
      expect(
        find.text('Adımlar: T T Y T T T Y · T = 2 tuş, Y = 1 tuş'),
        findsOneWidget,
      );
      // Eight keys lit: Do up to the next Do.
      expect(find.text('Do'), findsNWidgets(2));
    });

    testWidgets('chord short names can be looked up in a question', (
      tester,
    ) async {
      Lang.en = false;
      final gen = QuizGenerator(
        const QuizConfig(trainer: TrainerKind.chord, pool: ['maj', 'min']),
        random: math.Random(1),
      );
      await _quiz(tester, gen.identify());
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const Key('quiz_names_help')));
      await settle(tester);
      expect(find.text('maj · Majör üçlü'), findsOneWidget);
      expect(find.text('min · Minör üçlü'), findsOneWidget);
      expect(find.textContaining('Majör (maj)'), findsOneWidget);
    });

    testWidgets('a named scale target shows its steps', (tester) async {
      Lang.en = false;
      final gen = QuizGenerator(
        const QuizConfig(trainer: TrainerKind.scale, pool: ['dorian']),
        random: math.Random(1),
      );
      await _quiz(tester, gen.find(target: 'dorian', choices: 3));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const Key('quiz_what_is')));
      await settle(tester);
      expect(find.byKey(const Key('notes_keyboard')), findsOneWidget);
      expect(find.textContaining('T Y T T T Y T'), findsWidgets);
    });
  });
}
