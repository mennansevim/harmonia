// UX-MOTION-01: synthesised interface cues and the guided, musical first
// run (guide bubble, name → note tiles, choice cues, reduced motion).
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/app/scope.dart';
import 'package:resonia/trainer/audio/ui_sounds.dart';
import 'package:resonia/trainer/onboarding/onboarding_flow.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/kit.dart';
import 'package:resonia/trainer/ui/motion.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

List<String> _cues(WidgetTester tester) =>
    TrainerScope.read(tester.element(find.byType(OnboardingFlow))).audio.ui.log;

Future<TrainerStore> _toName(WidgetTester tester, {bool sounds = true}) async {
  final store = memoryStore();
  await store.load();
  store.uiSounds = sounds;
  await tester.pumpWidget(app(store));
  await settle(tester);
  await tapKey(tester, 'get_started');
  return store;
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  group('UiCueRenderer', () {
    const renderer = UiCueRenderer();
    final cues = [...UiCue.named, for (var i = 0; i < 10; i++) UiCue.note(i)];

    test('every cue is short, quiet, deterministic and click-free', () {
      for (final cue in cues) {
        final wav = renderer.render(cue);
        expect(
          wav.durationSeconds,
          inInclusiveRange(0.05, 1.6),
          reason: cue.id,
        );
        final peak = wav.samples.fold<double>(
          0,
          (m, s) => math.max(m, s.abs()),
        );
        // Normalised to the cue's own level, never louder than 0.4.
        expect(peak, closeTo(cue.level, 0.01), reason: cue.id);
        expect(cue.level, lessThanOrEqualTo(0.4), reason: cue.id);
        expect(wav.samples.first.abs(), lessThan(0.01), reason: cue.id);
        expect(wav.samples.last.abs(), lessThan(0.01), reason: cue.id);
        expect(renderer.render(cue).samples, wav.samples, reason: cue.id);
      }
    });

    test('cue ids are unique so the file cache cannot mix them up', () {
      final ids = cues.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('note degrees climb the pentatonic run and wrap', () {
      expect(UiCue.note(0).blips.single.midi, 72);
      expect(UiCue.note(3).blips.single.midi, 79);
      expect(UiCue.note(10).id, UiCue.note(0).id);
      for (var i = 1; i < UiCue.pentatonic.length; i++) {
        expect(UiCue.pentatonic[i], greaterThan(UiCue.pentatonic[i - 1]));
      }
    });
  });

  testWidgets('the welcome greets once; each letter of a name plays the next '
      'note and the name reaches the ready screen', (tester) async {
    final store = await _toName(tester);
    final cues = _cues(tester);
    expect(cues.where((c) => c == 'hello'), hasLength(1));
    expect(cues, contains('advance'));
    expect(find.text('Sana nasıl seslenelim?'), findsOneWidget);
    // The guide's line arrives after its typing beat, with a chirp.
    expect(find.text('Merhaba! Ben ses rehberin. Önce tanışalım.'), findsOne);
    expect(cues, contains('chatter'));
    expect(find.text('Şimdilik atla'), findsOneWidget);

    cues.clear();
    for (final partial in ['A', 'Ad', 'Ada']) {
      await tester.enterText(find.byKey(const Key('ob_name')), partial);
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Deleting a letter plays nothing.
    await tester.enterText(find.byKey(const Key('ob_name')), 'Ad');
    await tester.enterText(find.byKey(const Key('ob_name')), 'Ada');
    await settle(tester);
    expect(cues, ['note0', 'note1', 'note2', 'note2']);
    expect(find.byType(NoteTile), findsNWidgets(3));
    expect(find.text('Devam'), findsOneWidget);

    await tapKey(tester, 'ob_continue');
    expect(store.username, 'Ada');
    expect(
      find.text(
        'Tanıştığımıza sevindim, Ada! Çalışmanı hedefine göre '
        'kuracağım.',
      ),
      findsOneWidget,
    );
    cues.clear();
    await tapKey(tester, 'goal_ear');
    expect(cues, ['select']);
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'level_beginner');
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'minutes_15');
    await tapKey(tester, 'ob_continue');
    expect(find.text('HAZIRSIN, ADA!'), findsOneWidget);
    expect(find.text('Planın kuruldu'), findsOneWidget);
    expect(cues, contains('success'));
    // Let the one-shot celebration finish before the test ends.
    await settle(tester, 1600);
  });

  testWidgets('skipping the name keeps it empty and the plain ready title', (
    tester,
  ) async {
    final store = await _toName(tester);
    await tapKey(tester, 'ob_continue');
    expect(store.username, isEmpty);
    expect(find.text('Ne için çalışıyorsun?'), findsOneWidget);
    expect(find.textContaining('Tanıştığımıza'), findsNothing);
  });

  testWidgets('interface sounds off: the first run plays no cue', (
    tester,
  ) async {
    final store = await _toName(tester, sounds: false);
    await tester.enterText(find.byKey(const Key('ob_name')), 'Can');
    await settle(tester);
    await tapKey(tester, 'ob_continue');
    await tapKey(tester, 'goal_ear');
    expect(_cues(tester), isEmpty);
    expect(store.uiSounds, isFalse);
  });

  testWidgets('reduced motion shows the guide line at once, no typing beat', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('get_started')));
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Merhaba! Ben ses rehberin. Önce tanışalım.'), findsOne);
  });

  testWidgets('no interface cue sounds over a playing reference', (
    tester,
  ) async {
    final store = memoryStore();
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    final context = tester.element(find.byType(OnboardingFlow));
    final audio = TrainerScope.read(context).audio;
    audio.ui.log.clear();
    audio.playing.value = true;
    uiCue(context, UiCue.select);
    expect(audio.ui.log, isEmpty);
    audio.playing.value = false;
    uiCue(context, UiCue.select);
    expect(audio.ui.log, ['select']);
  });

  test('the trainer theme moves pages the Resonia way; iOS stays native', () {
    final builders = trainerTheme().pageTransitionsTheme.builders;
    expect(
      builders[TargetPlatform.android],
      isA<ResoniaPageTransitionsBuilder>(),
    );
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
  });

  testWidgets('Bump fires on a new positive trigger only; Shake on a new '
      'non-null one', (tester) async {
    Widget host(Object? bump, Object? shake) => Directionality(
      textDirection: TextDirection.ltr,
      child: Shake(
        trigger: shake,
        child: Bump(
          trigger: bump,
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    Matrix4 bumpT() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(Bump),
            matching: find.byType(Transform),
          ),
        )
        .transform;
    Matrix4 shakeT() => tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(Shake),
            matching: find.byType(Transform),
          ),
        )
        .first
        .transform;

    await tester.pumpWidget(host(false, null));
    await tester.pumpWidget(host(true, null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bumpT().getMaxScaleOnAxis(), greaterThan(1.01));
    await tester.pump(const Duration(milliseconds: 400));
    expect(bumpT().getMaxScaleOnAxis(), closeTo(1, 0.001));
    // Clearing the choice stays still.
    await tester.pumpWidget(host(false, null));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bumpT().getMaxScaleOnAxis(), closeTo(1, 0.001));

    await tester.pumpWidget(host(false, 'A'));
    await tester.pump(const Duration(milliseconds: 30));
    expect(shakeT().getTranslation().x.abs(), greaterThan(0.5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(shakeT().getTranslation().x, closeTo(0, 0.001));
    await tester.pumpWidget(host(false, null));
    await tester.pump(const Duration(milliseconds: 30));
    expect(shakeT().getTranslation().x, closeTo(0, 0.001));
  });

  test('the interface sound preference persists and resets on', () async {
    final p = MemoryTrainerPersistence();
    final store = TrainerStore(p);
    await store.load();
    expect(store.uiSounds, isTrue);
    store.uiSounds = false;
    store.save();
    await store.flush();
    final again = TrainerStore(p);
    await again.load();
    expect(again.uiSounds, isFalse);
    await again.resetAll();
    expect(again.uiSounds, isTrue);
  });
}
