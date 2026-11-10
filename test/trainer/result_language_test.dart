// WIDE-03: plain result and one next step. Completed ≠ skill gained,
// wrong ≠ not measured, XP ≠ skill. Scores and thresholds are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/learn/session_end.dart';
import 'package:resonia/trainer/quiz/quiz.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/kit.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

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

LessonNode _node(NodeKind kind) =>
    trainerPaths[TrainerKind.pitch]!.nodes.firstWhere((n) => n.kind == kind);

Future<TrainerStore> _show(
  WidgetTester tester,
  QuizSummary summary, {
  LessonNode? node,
  bool passed = true,
}) async {
  final store = memoryStore({'onboardingDone': true, 'setupDone': true});
  await store.load();
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
            retryConfig: _config,
            onDone: () {},
          ),
        ),
      );
  await settle(tester);
  return store;
}

Future<void> _openDetails(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('session_details')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tapKey(tester, 'session_details');
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

  testWidgets('a weak lesson is still completed; accuracy is told apart', (
    tester,
  ) async {
    await _show(tester, _summary(1), node: _node(NodeKind.lesson));
    expect(find.text('Ders tamamlandı'), findsOneWidget);
    expect(find.text('Bu ders bir tur daha istiyor'), findsNothing);
    expect(find.textContaining('Sıradaki ders açıldı.'), findsOneWidget);
    expect(find.text('ÖLÇÜLDÜ'), findsOneWidget);
    expect(find.text('/ 4 ilk deneme'), findsOneWidget);
    // No "skill improved" wording anywhere on the result.
    expect(find.textContaining('gelişti'), findsNothing);
    expect(find.textContaining('beceri'), findsNothing);
  });

  testWidgets('XP leaves the headline and is labelled practice points', (
    tester,
  ) async {
    await _show(tester, _summary(3));
    expect(find.text('XP'), findsNothing);
    // One summary line replaces the chips that repeated the ring.
    expect(find.text('%75 ilk denemede doğru'), findsOneWidget);
    await _openDetails(tester);
    expect(
      find.text('+32 XP · pratik puanı, beceri ölçümü değil'),
      findsOneWidget,
    );
  });

  testWidgets('one next step: the misses first, the result stays recorded '
      'once', (tester) async {
    final store = await _show(tester, _summary(2));
    final next = find.byKey(const Key('session_next'));
    expect(next, findsOneWidget);
    expect(find.text('SONRAKİ ADIM'), findsOneWidget);
    expect(find.text('Karışanları kısa tekrarla çalış'), findsOneWidget);
    expect(
      find.descendant(
        of: next,
        matching: find.byKey(const Key('retry_missed')),
      ),
      findsOneWidget,
    );
    // The screen keeps a single primary action.
    expect(find.byType(BigButton), findsOneWidget);
    expect(store.xp, 0);
  });

  testWidgets('with no misses the next step is the next lesson', (
    tester,
  ) async {
    await _show(tester, _summary(4));
    expect(find.text('Tüm sesler ilk denemede doğru'), findsOneWidget);
    expect(find.byKey(const Key('retry_missed')), findsNothing);
    expect(find.textContaining('Sıradaki: '), findsOneWidget);
  });

  testWidgets('no answers: not measured, no score, no wrong answers', (
    tester,
  ) async {
    await _show(tester, QuizSummary(const []));
    expect(find.text('Bu turda yanıt kaydedilmedi'), findsOneWidget);
    expect(find.byKey(const Key('session_score')), findsNothing);
    expect(find.text('ÖLÇÜLDÜ'), findsNothing);
    expect(find.text('ÖLÇÜLMEDİ'), findsOneWidget);
    expect(
      find.text('Yanıt olmadığı için doğru ya da yanlış sayılmadı.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('session_next')), findsNothing);
    expect(find.textContaining('karıştı'), findsNothing);
  });

  testWidgets('a failed checkpoint states its threshold, offers no lesson', (
    tester,
  ) async {
    await _show(
      tester,
      _summary(2),
      node: _node(NodeKind.checkpoint),
      passed: false,
    );
    expect(find.text('Ara durak için %80 gerekiyor'), findsOneWidget);
    expect(find.textContaining('Sıradaki: '), findsNothing);
  });

  testWidgets('progress says the level counts practice, not skill', (
    tester,
  ) async {
    final store = memoryStore({
      'onboardingDone': true,
      'setupDone': true,
      'xp': 4200,
    });
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_2');
    expect(find.textContaining('PRATİK SEVİYESİ 4'), findsOneWidget);
    expect(find.byKey(const Key('level_scope')), findsOneWidget);
    expect(find.text('Beceriler'), findsNothing);
  });
}
