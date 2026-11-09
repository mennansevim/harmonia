// PLACE-01: goal tracks, the stated level, early-stopping placement gates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/placement.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/home/daily_route.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

/// Every (correct, wrong) answer order of a full gate, as the verdict the
/// full gate would give and the one early stop gives.
void _expectSameVerdictAsFullGate(int length) {
  final stop = GateStop(length);
  for (var correct = 0; correct <= length; correct++) {
    final wrong = length - correct;
    final full = correct / length >= 0.8;
    // Walk answers in two extreme orders; early stop may fire on the way.
    for (final order in [
      [
        for (var i = 0; i < correct; i++) true,
        for (var i = 0; i < wrong; i++) false,
      ],
      [
        for (var i = 0; i < wrong; i++) false,
        for (var i = 0; i < correct; i++) true,
      ],
    ]) {
      var c = 0, w = 0;
      bool? verdict;
      for (final a in order) {
        a ? c++ : w++;
        verdict = stop.verdict(c, w);
        if (verdict != null) break;
      }
      expect(verdict, full, reason: 'L=$length c=$correct order=$order');
      // The accuracy written to the store agrees with the verdict.
      expect(stop.accuracy(c) >= 0.8, full, reason: 'L=$length c=$c');
    }
  }
}

void main() {
  group('GateStop', () {
    test('checkpoint: 10 correct passes, 3 wrong fails', () {
      const s = GateStop(12);
      expect(s.needed, 10);
      expect(s.failAt, 3);
      expect(s.verdict(10, 0), isTrue);
      expect(s.verdict(9, 2), isNull);
      expect(s.verdict(0, 3), isFalse);
    });

    test('final: 16 correct passes, 5 wrong fails', () {
      const s = GateStop(20);
      expect(s.needed, 16);
      expect(s.failAt, 5);
    });

    test('early stop never changes the full gate verdict', () {
      for (final l in [10, 12, 20]) {
        _expectSameVerdictAsFullGate(l);
      }
    });

    test('an early pass is not scored as a perfect round', () {
      const s = GateStop(12);
      expect(TrainerStore.starsFor(s.accuracy(10)), 2);
      // With the 90% three-star cut: 10/12 = 0.83 stays 2 stars, 11/12 = 3.
      expect(TrainerStore.starsFor(s.accuracy(11)), 3);
    });
  });

  group('PlacementRun', () {
    final path = trainerPaths[TrainerKind.interval]!;

    test('beginner gets no placement', () {
      expect(PlacementRun(path, ExperienceLevel.beginner).done, isTrue);
    });

    test('some: starts at checkpoint 1, climbs, stops at first fail', () {
      final run = PlacementRun(path, ExperienceLevel.some);
      expect(run.current!.id, 'interval-cp1');
      run.record(true);
      expect(run.current!.id, 'interval-cp2');
      run.record(false);
      expect(run.done, isTrue);
      expect(run.placed!.id, 'interval-cp1');
    });

    test('some: failing the first checkpoint places at the start', () {
      final run = PlacementRun(path, ExperienceLevel.some)..record(false);
      expect(run.done, isTrue);
      expect(run.placed, isNull);
    });

    test('experienced: starts at the second-to-last checkpoint', () {
      final run = PlacementRun(path, ExperienceLevel.experienced);
      expect(run.current!.id, 'interval-cp3');
      run
        ..record(true)
        ..record(true);
      expect(run.current!.kind, NodeKind.finalExam);
      run.record(true);
      expect(run.done, isTrue);
      expect(run.placed!.kind, NodeKind.finalExam);
      expect(run.attempted, 3);
    });

    test('experienced: a fail steps down until a pass', () {
      final run = PlacementRun(path, ExperienceLevel.experienced)
        ..record(false);
      expect(run.current!.id, 'interval-cp2');
      run.record(true);
      expect(run.done, isTrue);
      expect(run.placed!.id, 'interval-cp2');
    });

    test('experienced: failing every step down ends at the start', () {
      final run = PlacementRun(path, ExperienceLevel.experienced);
      while (!run.done) {
        run.record(false);
      }
      expect(run.placed, isNull);
      expect(run.attempted, 3);
    });

    test('experienced on a three-checkpoint path starts at checkpoint 2', () {
      final run = PlacementRun(
        trainerPaths[TrainerKind.pitch]!,
        ExperienceLevel.experienced,
      );
      expect(run.current!.id, 'pitch-cp2');
    });
  });

  group('goal tracks', () {
    test('each track opens with its old first lesson', () {
      expect(PracticeGoal.beginner.lesson, TrainerKind.pitch);
      expect(PracticeGoal.voice.lesson, TrainerKind.pitch);
      expect(PracticeGoal.ear.lesson, TrainerKind.interval);
      expect(PracticeGoal.choir.lesson, TrainerKind.interval);
      expect(PracticeGoal.exam.lesson, TrainerKind.interval);
      expect(PracticeGoal.stage.track, isEmpty);
      expect(PracticeGoal.stage.lesson, isNull);
    });

    test('every path is on at least one track', () {
      final onTrack = {for (final g in PracticeGoal.values) ...g.track};
      expect(onTrack, TrainerKind.values.toSet());
    });

    test('today moves to the next path once one is finished', () async {
      final store = memoryStore({
        'onboardingDone': true,
        'setupDone': true,
        'answers': {'goal': 'ear'},
      });
      await store.load();
      expect(focusTrainer(store), TrainerKind.interval);
      final interval = trainerPaths[TrainerKind.interval]!;
      // Passing the final completes every node of the path.
      store.completeNode(interval.nodes.last, 1);
      expect(store.nextNode(TrainerKind.interval), isNull);
      expect(focusTrainer(store), TrainerKind.chord);
    });

    test('a passed placement gate moves today\'s lesson past it', () async {
      final store = memoryStore({
        'answers': {'goal': 'ear'},
      });
      await store.load();
      final gate = trainerPaths[TrainerKind.interval]!.byId('interval-cp1');
      expect(store.completeNode(gate, const GateStop(12).accuracy(10)), isTrue);
      final next = store.nextNodeAfterIntro(TrainerKind.interval)!;
      expect(
        trainerPaths[TrainerKind.interval]!.indexOf(next.id),
        greaterThan(trainerPaths[TrainerKind.interval]!.indexOf(gate.id)),
      );
    });
  });

  group('onboarding', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1170,
        2532,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 3;
    });

    Future<TrainerStore> toReady(WidgetTester tester, String level) async {
      final store = memoryStore();
      await store.load();
      await tester.pumpWidget(app(store));
      await settle(tester);
      await tapKey(tester, 'get_started');
      await tapKey(tester, 'ob_continue');
      await tapKey(tester, 'goal_ear');
      await tapKey(tester, 'ob_continue');
      await tapKey(tester, 'level_$level');
      await tapKey(tester, 'ob_continue');
      await tapKey(tester, 'minutes_10');
      await tapKey(tester, 'ob_continue');
      return store;
    }

    testWidgets('beginner: no placement offered', (tester) async {
      final store = await toReady(tester, 'beginner');
      expect(store.answers['level'], 'beginner');
      expect(find.byKey(const Key('ob_placement')), findsNothing);
      expect(find.byKey(const Key('today_session_begin')), findsOneWidget);
      await settle(tester, 1600);
    });

    testWidgets('some: placement is an optional link', (tester) async {
      await toReady(tester, 'some');
      expect(find.byKey(const Key('ob_placement')), findsOneWidget);
      expect(find.text('İlk çalışmaya başla'), findsOneWidget);
      await settle(tester, 1600);
    });

    testWidgets('experienced: placement leads and opens at checkpoint 3', (
      tester,
    ) async {
      final store = await toReady(tester, 'experienced');
      expect(find.text('Seviyemi bul'), findsOneWidget);
      await settle(tester, 1600);
      await tester.ensureVisible(find.byKey(const Key('ob_placement')));
      await tapKey(tester, 'ob_placement');
      await settle(tester);
      expect(store.onboardingDone, isTrue);
      expect(find.text('Bildiklerini atlayalım'), findsOneWidget);
      expect(find.textContaining('Ara durak 3'), findsOneWidget);
      expect(find.textContaining('yaklaşık'), findsOneWidget);
    });
  });
}
