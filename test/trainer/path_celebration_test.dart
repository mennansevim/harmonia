// PATH-01: winding lesson path, "Devam et" after a passed node and tiered
// celebrations. Celebrations follow what the session established (finished
// lesson, passed gate, finished skill), never accuracy alone.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/learn/session_end.dart';
import 'package:resonia/trainer/learn/skill_screen.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/celebration.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle;

const _config = QuizConfig(
  trainer: TrainerKind.pitch,
  pool: ['0', '7'],
  length: 4,
);

QuizSummary _summary(int correct) {
  final questions = QuizGenerator(_config).session();
  return QuizSummary([
    for (var i = 0; i < questions.length; i++)
      AnswerRecord(questions[i], i < correct),
  ]);
}

final _path = trainerPaths[TrainerKind.pitch]!;
LessonNode _first(NodeKind kind) =>
    _path.nodes.firstWhere((n) => n.kind == kind);

final _sparks = find.byKey(const Key('celebration_sparks'));
final _flag = find.byKey(const Key('celebration_flag'));
final _trophy = find.byKey(const Key('celebration_trophy'));

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1170,
      2532,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 3;
  });

  group('celebrationFor', () {
    CelebrationTier tier(
      LessonNode? node, {
      bool measured = true,
      bool passed = true,
      bool skillDone = false,
    }) => celebrationFor(
      node: node,
      measured: measured,
      passed: passed,
      skillDone: skillDone,
    );

    test('free practice, intros and unanswered sessions celebrate nothing', () {
      expect(tier(null), CelebrationTier.none);
      expect(tier(_first(NodeKind.intro)), CelebrationTier.none);
      expect(
        tier(_first(NodeKind.lesson), measured: false),
        CelebrationTier.none,
      );
    });

    test('a failed gate celebrates nothing', () {
      expect(
        tier(_first(NodeKind.checkpoint), passed: false),
        CelebrationTier.none,
      );
      expect(
        tier(_first(NodeKind.finalExam), passed: false),
        CelebrationTier.none,
      );
    });

    test('lesson < checkpoint < finale', () {
      expect(tier(_first(NodeKind.lesson)), CelebrationTier.lesson);
      expect(tier(_first(NodeKind.checkpoint)), CelebrationTier.checkpoint);
      expect(tier(_first(NodeKind.finalExam)), CelebrationTier.finale);
      // Finishing the whole path by any node is the finale.
      expect(
        tier(_first(NodeKind.lesson), skillDone: true),
        CelebrationTier.finale,
      );
    });
  });

  test('fireworks are deterministic and grow with the tier', () {
    int sparks(CelebrationTier t) =>
        FireworkShell.show(t, 11).fold(0, (sum, s) => sum + s.sparks.length);
    expect(FireworkShell.show(CelebrationTier.none, 11), isEmpty);
    expect(
      sparks(CelebrationTier.lesson),
      lessThan(sparks(CelebrationTier.checkpoint)),
    );
    expect(
      sparks(CelebrationTier.checkpoint),
      lessThan(sparks(CelebrationTier.finale)),
    );
    final a = FireworkShell.show(CelebrationTier.finale, 3);
    final b = FireworkShell.show(CelebrationTier.finale, 3);
    expect([for (final s in a) s.apex], [for (final s in b) s.apex]);
    // Every burst ends inside its tier's duration.
    for (final t in CelebrationTier.values.skip(1)) {
      final end = Celebration.durationOf(t).inMilliseconds / 1000;
      for (final s in FireworkShell.show(t, 11)) {
        expect(s.burstAt + FireworkShell.life, lessThanOrEqualTo(end + 1e-9));
      }
    }
    expect(FireworkShell.opacity(-0.1), 0);
    expect(FireworkShell.opacity(0.1), 1);
    expect(FireworkShell.opacity(FireworkShell.life), 0);
  });

  group('Celebration widget', () {
    late List<String> haptics;
    setUp(() {
      haptics = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String);
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Widget host(CelebrationTier tier, {bool reduced = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: ResoniaHapticsScope(
        enabled: ValueNotifier(true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Celebration(tier: tier),
        ),
      ),
    );

    testWidgets('a finale plays fireworks and a trophy, then clears', (
      tester,
    ) async {
      await tester.pumpWidget(host(CelebrationTier.finale));
      await tester.pump(const Duration(milliseconds: 900));
      expect(_sparks, findsOneWidget);
      expect(_trophy, findsOneWidget);
      expect(haptics.first, 'HapticFeedbackType.heavyImpact');
      await tester.pump(Celebration.durationOf(CelebrationTier.finale));
      await tester.pump();
      expect(_sparks, findsNothing);
      expect(_trophy, findsNothing);
      // One tap per burst, no more.
      expect(haptics, hasLength(7));
    });

    testWidgets('a lesson pops without a badge', (tester) async {
      await tester.pumpWidget(host(CelebrationTier.lesson));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_sparks, findsOneWidget);
      expect(_flag, findsNothing);
      expect(_trophy, findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('reduced motion: no sparks; gates keep a still badge', (
      tester,
    ) async {
      await tester.pumpWidget(host(CelebrationTier.lesson, reduced: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_sparks, findsNothing);
      expect(haptics, isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(CelebrationTier.checkpoint, reduced: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_sparks, findsNothing);
      expect(_flag, findsOneWidget);
      expect(haptics, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
      expect(_flag, findsNothing);
    });
  });

  group('SessionEnd', () {
    Future<(TrainerStore, List<String>)> show(
      WidgetTester tester,
      QuizSummary summary, {
      LessonNode? node,
      bool passed = true,
      bool complete = true,
    }) async {
      final store = memoryStore({'onboardingDone': true, 'setupDone': true});
      await store.load();
      if (node != null && complete) store.completeNode(node, summary.accuracy);
      final taps = <String>[];
      await tester.pumpWidget(app(store));
      await settle(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => SessionEnd(
                summary: summary,
                node: node,
                passed: passed,
                onDone: () => taps.add('done'),
                onContinue: () => taps.add('continue'),
              ),
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return (store, taps);
    }

    testWidgets('a finished lesson pops and offers the next one', (
      tester,
    ) async {
      final lesson = _path.nodes[1];
      final (store, taps) = await show(tester, _summary(4), node: lesson);
      expect(_sparks, findsOneWidget);
      final next = store.nextNode(TrainerKind.pitch)!;
      expect(find.text('Devam et: ${next.title}'), findsOneWidget);
      // The "next lesson" card would repeat the button, so it is gone.
      expect(find.textContaining('Sıradaki: '), findsNothing);
      await tester.tap(find.byKey(const Key('session_continue')));
      await tester.tap(find.byKey(const Key('session_done')));
      expect(taps, ['continue', 'done']);
      await settle(tester, 2000);
      expect(_sparks, findsNothing);
    });

    testWidgets('a passed checkpoint gets fireworks and its flag', (
      tester,
    ) async {
      await show(tester, _summary(4), node: _first(NodeKind.checkpoint));
      await tester.pump(const Duration(milliseconds: 700));
      expect(_sparks, findsOneWidget);
      expect(_flag, findsOneWidget);
      await settle(tester, 3000);
    });

    testWidgets('a failed checkpoint: no fireworks and no "Devam et"', (
      tester,
    ) async {
      final gate = _first(NodeKind.checkpoint);
      await show(tester, _summary(1), node: gate, passed: false);
      expect(_sparks, findsNothing);
      expect(_flag, findsNothing);
      expect(find.byKey(const Key('session_continue')), findsNothing);
      expect(find.text('Bitti'), findsOneWidget);
    });

    testWidgets(
      'a passed final names itself, shows the trophy, no "Devam et"',
      (tester) async {
        final fin = _first(NodeKind.finalExam);
        await show(tester, _summary(4), node: fin);
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Final sınavı geçildi'), findsOneWidget);
        expect(
          find.text('Bu becerinin tüm dersleri tamamlandı.'),
          findsOneWidget,
        );
        expect(_trophy, findsOneWidget);
        expect(find.byKey(const Key('session_continue')), findsNothing);
        await settle(tester, 4000);
      },
    );

    testWidgets('free practice: no celebration, no "Devam et"', (tester) async {
      await show(tester, _summary(4));
      expect(_sparks, findsNothing);
      expect(find.byKey(const Key('session_continue')), findsNothing);
    });
  });

  test('the path winds and repeats every eight nodes', () {
    expect(pathX(0), 0);
    expect(pathX(2), greaterThan(0));
    expect(pathX(6), lessThan(0));
    expect(pathX(9), pathX(1));
    for (var i = 0; i < 16; i++) {
      expect(pathX(i).abs(), lessThanOrEqualTo(0.62));
    }
  });

  testWidgets('skill path: every node is reachable by its title and state', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    store.completeNode(_path.nodes.first, 1);
    await tester.pumpWidget(app(store));
    await settle(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const SkillScreen(trainer: TrainerKind.pitch),
          ),
        );
    await settle(tester);
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(
        RegExp('^${RegExp.escape(_path.nodes.first.title)}, tamamlandı'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('${_path.nodes[1].title}, sıradaki ders'),
      findsOneWidget,
    );
    expect(find.text('BAŞLA'), findsOneWidget);
    // A locked lesson does not open.
    final locked = _path.nodes.indexed
        .where((e) => !e.$2.isGate && e.$1 > 2)
        .first
        .$2;
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(locked.id)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(ValueKey(locked.id)), warnIfMissed: false);
    await settle(tester);
    expect(find.byType(SkillScreen), findsOneWidget);
    expect(find.bySemanticsLabel('${locked.title}, kilitli'), findsOneWidget);
    handle.dispose();
  });
}
