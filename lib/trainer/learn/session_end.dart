import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../ui/kit.dart';

/// Single evidence card at the end of a lesson, gate or free session:
/// accuracy, per-item first attempts, XP and the day streak inline.
class SessionEnd extends StatelessWidget {
  const SessionEnd({
    super.key,
    required this.summary,
    required this.onDone,
    this.node,
    this.passed = true,
    this.title,
  });
  final LessonNode? node;
  final QuizSummary summary;
  final bool passed;
  final String? title;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final s = summary;
    final pct = (s.accuracy * 100).round();
    final kind =
        node?.trainer ??
        s.records.firstOrNull?.question.trainer ??
        TrainerKind.pitch;
    final color = trainerColor(kind);
    final gate = node?.isGate ?? false;
    final strong = s.accuracy >= 0.7;
    final verdict = gate
        ? (passed ? 'Ara durak geçildi' : 'Ara durak için %80 gerekiyor')
        : node == null
        ? 'Serbest çalışma bitti'
        : (strong ? 'Ders tamamlandı' : 'Bu ders bir tur daha istiyor');
    final note = gate
        ? (passed
              ? 'Öncesindeki dersler de tamamlandı.'
              : 'Dersleri sırayla çalışıp tekrar deneyebilirsin.')
        : node == null
        ? 'Sonuçlar İlerleme sekmesine eklendi.'
        : (strong
              ? 'Sıradaki ders açıldı.'
              : 'Ders listesinden istediğin zaman tekrar et.');
    final xp = s.correct * 10 + (s.total - s.correct) * 2;
    final items = s.byItem().entries.toList()
      ..sort(
        (a, b) => (a.value.$1 / a.value.$2).compareTo(b.value.$1 / b.value.$2),
      );
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                children: [
                  Text(
                    (title ?? node?.title ?? kind.title).toUpperCase(),
                    style: TT.caps.copyWith(color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(verdict, style: TT.h2),
                  const SizedBox(height: 4),
                  Text(note, style: TT.body),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Row(
                      children: [
                        _Stat(value: '%$pct', label: 'doğruluk', color: color),
                        _Stat(
                          value: '${s.correct}/${s.total}',
                          label: 'ilk denemede',
                          color: TC.ink,
                        ),
                        _Stat(value: '+$xp', label: 'XP', color: TC.ink),
                      ],
                    ),
                  ),
                  if (store.practicedToday && store.streak > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('session_streak'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: TC.sun.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wb_sunny_rounded, color: TC.onSun),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${store.streak} gün üst üste çalıştın',
                              style: TT.title.copyWith(color: TC.onSun),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const Text('SORU BAZINDA · İLK DENEME', style: TT.caps),
                  const SizedBox(height: 8),
                  for (final e in items)
                    _ItemRow(
                      label: itemLabel(
                        kind,
                        e.key,
                        notation: store.notation,
                        transposition: store.transposition,
                        long: true,
                      ),
                      correct: e.value.$1,
                      total: e.value.$2,
                      color: color,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: BigButton(
                key: const Key('session_done'),
                label: 'Bitti',
                color: color,
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: TT.small),
      ],
    ),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.label,
    required this.correct,
    required this.total,
    required this.color,
  });
  final String label;
  final int correct;
  final int total;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label, style: TT.title)),
        Expanded(
          child: ProgressBar(
            value: total == 0 ? 0 : correct / total,
            color: correct == total ? TC.green : color,
            height: 8,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$correct/$total',
          style: TT.small.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
