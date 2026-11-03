import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/lang.dart';
import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/review_memory.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';

/// One question per due card. Options come from items the learner has
/// already met in that trainer, so a card never asks about unseen material;
/// with fewer than two met items it becomes a pick-the-sound question.
List<QuizQuestion> reviewQuestions(
  TrainerStore store,
  List<ReviewCard> cards, {
  math.Random? random,
}) {
  final r = random ?? math.Random();
  final out = <QuizQuestion>[];
  for (final card in cards) {
    final kind = TrainerKind.values.asNameMap()[card.trainer];
    if (kind == null || !kind.allItems.contains(card.item)) continue;
    final met =
        (store.memory[card.trainer]?.keys ?? const <String>[])
            .where(kind.allItems.contains)
            .where((i) => i != card.item)
            .toList()
          ..shuffle(r);
    final pool = [card.item, ...met.take(4)];
    final register = store.part?.fit(Register.medium) ?? Register.medium;
    final gen = QuizGenerator(
      QuizConfig(trainer: kind, pool: pool, registers: [register]),
      random: r,
    );
    out.add(
      pool.length < 2
          ? gen.find(target: card.item, choices: 3)
          : QuizQuestion.identify(
              trainer: kind,
              answer: card.item,
              options: pool..shuffle(r),
              sound: gen.soundOf(card.item),
            ),
    );
  }
  return out;
}

/// Days from [now] until a memory is due again.
int daysUntilDue(ItemMemory m, DateTime now) {
  // p = 2^(−Δ/h) < target  ⇔  Δ > −h·log2(target)
  final dueIn =
      -m.halfLifeDays * math.log(reviewTarget) / math.ln2 -
      now.difference(m.lastSeen).inMinutes / (24 * 60);
  return math.max(0, dueIn.ceil());
}

/// Runs today's review round and shows when each card comes back.
Future<void> startReview(BuildContext context) async {
  final scope = TrainerScope.read(context);
  final store = scope.store;
  final cards = store.dueReview;
  final questions = reviewQuestions(store, cards);
  if (questions.isEmpty) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (routeContext) => QuizView(
        title: tr('Tekrar kartları', 'Review cards'),
        questions: questions,
        allowRetry: false,
        onFinished: (summary) {
          store.markReviewDone();
          Navigator.of(routeContext).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ReviewEnd(summary: summary),
            ),
          );
        },
      ),
    ),
  );
}

class ReviewEnd extends StatelessWidget {
  const ReviewEnd({super.key, required this.summary});
  final QuizSummary summary;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final s = summary;
    String when(int days) => switch (days) {
      0 => tr('bugün', 'today'),
      1 => tr('yarın', 'tomorrow'),
      _ => tr('$days gün sonra', 'in $days days'),
    };
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Text(tr('TEKRAR KARTLARI', 'REVIEW CARDS'), style: TT.crumb),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      '${s.total} kartın ${s.correct} tanesini hatırladın',
                      'You remembered ${s.correct} of ${s.total} cards',
                    ),
                    key: const Key('review_score'),
                    style: TT.h2,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Hatırladığın kart daha seyrek, kaçırdığın daha sık gelir. '
                          'Karışık sırayla sorulması zor gelebilir; kalıcılığı artırır.',
                      'Cards you remember come back less often, missed ones sooner. '
                          'Mixed order can feel harder; it helps the memory last.',
                    ),
                    style: TT.body,
                  ),
                  const SizedBox(height: 18),
                  for (final rec in s.records)
                    Builder(
                      builder: (context) {
                        final q = rec.question;
                        final id = q.type == QuestionType.identify
                            ? q.answer
                            : q.target;
                        final mem = store.memory[q.trainer.id]?[id];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  rec.correct ? Ic.check : Ic.rotateCcw,
                                  color: rec.correct ? TC.green : TC.warn,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        itemLabel(
                                          q.trainer,
                                          id,
                                          notation: store.notation,
                                          long: true,
                                        ),
                                        style: TT.title,
                                      ),
                                      Text(q.trainer.title, style: TT.small),
                                    ],
                                  ),
                                ),
                                if (mem != null)
                                  Text(
                                    tr(
                                      'Sonraki: ${when(daysUntilDue(mem, store.now))}',
                                      'Next: ${when(daysUntilDue(mem, store.now))}',
                                    ),
                                    style: TT.small,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: BigButton(
                key: const Key('review_done'),
                label: tr('Bitti', 'Done'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
