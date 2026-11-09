// QA-NOTE-01: one note naming everywhere (lesson titles, hints, options),
// a language choice on the first screen, and neutral yes/no answers.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/quiz/quiz_view.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/kit.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

const _solfegeWord =
    r'(?<![A-Za-zÇĞİÖŞÜçğıöşü])(Do|Re|Mi|Fa|Sol|La|Si)(?![A-Za-zÇĞİÖŞÜçğıöşü])';

void main() {
  final lang = Lang.en;
  tearDown(() {
    NoteNames.current = NoteNotation.solfege;
    Lang.en = lang;
  });

  group('letter naming leaves no Do Re Mi behind', () {
    for (final en in [false, true]) {
      test(en ? 'English' : 'Turkish', () {
        Lang.en = en;
        NoteNames.current = NoteNotation.letter;
        final pitch = trainerPaths[TrainerKind.pitch]!;
        final text = [
          for (final n in pitch.nodes) ...[n.title, n.subtitle],
          for (final sl in pitch.introSlides) ...[
            sl.title,
            sl.body,
            ...sl.bullets,
          ],
          itemFeel(TrainerKind.pitch, '0'),
          for (final i in Intervals.all) ...[i.feel, i.anchor],
          for (final c in Chords.all) c.feel,
        ].join('\n');
        expect(RegExp(_solfegeWord).allMatches(text).map((m) => m[0]), isEmpty);
        // The lesson the learner saw: same names as the answer buttons.
        expect(
          pitch.nodes.map((n) => n.title),
          contains(en ? '2. New: E' : '2. Yeni: E'),
        );
        expect(itemLabel(TrainerKind.pitch, '4'), 'E');
      });
    }

    test('solfège naming keeps Do Re Mi, in English too', () {
      Lang.en = true;
      NoteNames.current = NoteNotation.solfege;
      expect(itemLabel(TrainerKind.pitch, '4'), 'Mi');
      expect(
        trainerPaths[TrainerKind.pitch]!.nodes.map((n) => n.title),
        contains('2. New: Mi'),
      );
      expect(Intervals.byId('m2').anchor, 'Mi → Fa');
    });
  });

  test('note runs convert; ordinary words are left alone', () {
    NoteNames.current = NoteNotation.letter;
    expect(NoteNames.inText('Kök (Do-Mi-Sol♯).'), 'Kök (C-E-G♯).');
    expect(NoteNames.inText('Dolu bir Lale'), 'Dolu bir Lale');
    NoteNames.current = NoteNotation.solfege;
    expect(NoteNames.inTextEn('Root (C-E-G).'), 'Root (Do-Mi-Sol).');
    expect(NoteNames.inTextEn('A third of B.'), 'A third of B.');
  });

  test('the store keeps the shared naming in step', () async {
    final store = TrainerStore(
      MemoryTrainerPersistence({
        'prefs': {'notation': 'letter'},
      }),
    );
    await store.load();
    expect(NoteNames.current, NoteNotation.letter);
    store.notation = NoteNotation.solfege;
    expect(NoteNames.current, NoteNotation.solfege);
  });

  group('first screen', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1170,
        2532,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 3;
      binding.platformDispatcher.localesTestValue = const [Locale('tr', 'TR')];
    });

    testWidgets('picking English switches the wording and the note names', (
      tester,
    ) async {
      final store = memoryStore();
      await store.load();
      await tester.pumpWidget(app(store));
      await settle(tester);
      expect(find.text('Başlayalım'), findsOneWidget);
      await tapKey(tester, 'lang_en');
      expect(store.language, 'en');
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      await tapKey(tester, 'get_started');
      expect(store.notation, NoteNotation.letter);

      // And back: Turkish wording, solfège at the next start.
      await tester.tap(find.byTooltip('Back').first);
      await settle(tester);
      await tapKey(tester, 'lang_tr');
      expect(find.text('Başlayalım'), findsOneWidget);
      await tapKey(tester, 'get_started');
      expect(store.notation, NoteNotation.solfege);
    });
  });

  testWidgets('yes/no answers are neutral before an answer', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    final gen = QuizGenerator(
      const QuizConfig(trainer: TrainerKind.pitch, pool: ['0']),
      random: math.Random(2),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => QuizView(
              title: 't',
              questions: [gen.yesNo()],
              onFinished: (_) {},
            ),
          ),
        );
    await settle(tester);
    // A green "yes" looked like the right answer when "no" was.
    for (final label in ['Evet, bu', 'Hayır, değil']) {
      final button = tester.widget<BigButton>(
        find.ancestor(of: find.text(label), matching: find.byType(BigButton)),
      );
      expect(button.color, isNot(anyOf(TC.green, TC.coralDeep)), reason: label);
    }
  });
}
