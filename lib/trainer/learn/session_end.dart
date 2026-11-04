import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/kit.dart';
import '../../domain/lang.dart';

/// End of a lesson, gate or free session in two layers: a headline result
/// with what was measured, not measured or experimental, then the per-item
/// details on demand. "Yanlışları tekrar et" runs a short, unrecorded
/// retry on fresh examples of the missed items.
class SessionEnd extends StatelessWidget {
  const SessionEnd({
    super.key,
    required this.summary,
    required this.onDone,
    this.node,
    this.passed = true,
    this.title,
    this.retryConfig,
  });
  final LessonNode? node;
  final QuizSummary summary;
  final bool passed;
  final String? title;
  final VoidCallback onDone;

  /// How the session sounded; enables the short retry when set.
  final QuizConfig? retryConfig;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final s = summary;
    final kind =
        node?.trainer ??
        s.records.firstOrNull?.question.trainer ??
        TrainerKind.pitch;
    final color = trainerColor(kind);
    final gate = node?.isGate ?? false;
    final strong = s.accuracy >= 0.7;
    final verdict = gate
        ? (passed
              ? tr('Ara durak geçildi', 'Checkpoint passed')
              : tr('Ara durak için %80 gerekiyor', 'The checkpoint needs 80%'))
        : node == null
        ? tr('Serbest çalışma bitti', 'Free practice finished')
        : (strong
              ? tr('Ders tamamlandı', 'Lesson complete')
              : tr(
                  'Bu ders bir tur daha istiyor',
                  'This lesson wants another round',
                ));
    final note = gate
        ? (passed
              ? tr(
                  'Öncesindeki dersler de tamamlandı.',
                  'The lessons before it are complete too.',
                )
              : tr(
                  'Dersleri sırayla çalışıp tekrar deneyebilirsin.',
                  'Work through the lessons in order and try again.',
                ))
        : node == null
        ? tr(
            'Sonuçlar Gelişim sekmesine eklendi.',
            'Results were added to the Progress tab.',
          )
        : (strong
              ? tr('Sıradaki ders açıldı.', 'The next lesson is open.')
              : tr(
                  'Ders listesinden istediğin zaman tekrar et.',
                  'Repeat it from the lesson list whenever you like.',
                ));
    final xp = s.correct * 10 + (s.total - s.correct) * 2;
    final items = s.byItem().entries.toList()
      ..sort(
        (a, b) => (a.value.$1 / a.value.$2).compareTo(b.value.$1 / b.value.$2),
      );
    String label(String id) => itemLabel(
      kind,
      id,
      notation: store.notation,
      transposition: store.transposition,
      long: true,
    );
    final missed = [
      for (final e in items)
        if (e.value.$1 < e.value.$2) e.key,
    ];
    final weakest = missed.isEmpty ? null : items.first;
    final sang = node != null && !gate && kind == TrainerKind.pitch;
    final upNext = store.nextNode(kind);
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
                children: [
                  Text(
                    (title ?? node?.title ?? kind.title).toUpperCase(),
                    style: TT.caps.copyWith(color: color),
                  ),
                  const SizedBox(height: 6),
                  Text(verdict, style: TT.h2),
                  const SizedBox(height: 4),
                  Text(note, style: TT.body),
                  const SizedBox(height: 18),
                  HeroCard(
                    ring: false,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Semantics(
                          label: tr(
                            '${s.total} sorudan ${s.correct} ilk denemede doğru',
                            '${s.correct} of ${s.total} right on the first try',
                          ),
                          excludeSemantics: true,
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: CustomPaint(
                              painter: _ScoreRing(
                                s.total == 0 ? 0 : s.correct / s.total,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${s.correct}',
                                      key: const Key('session_score'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        height: 1,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tr(
                                        '/ ${s.total} ilk deneme',
                                        '/ ${s.total} first tries',
                                      ),
                                      style: const TextStyle(
                                        color: TC.heroMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          tr(
                            '${kind.shortTitle} · dokunma yanıtlarından ölçüldü',
                            '${kind.shortTitle} · measured from your taps',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: TC.heroMuted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Stat(
                              value: percent(s.accuracy),
                              label: tr('ilk deneme', 'first try'),
                            ),
                            const SizedBox(width: 10),
                            _Stat(value: '+$xp', label: 'XP'),
                          ],
                        ),
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
                          const Icon(Ic.sun, color: TC.onSun),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(
                                '${store.streak} gün üst üste çalıştın',
                                store.streak == 1
                                    ? 'You practised today'
                                    : 'You practised ${store.streak} days in a row',
                              ),
                              style: TT.title.copyWith(color: TC.onSun),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _Evidence(
                    key: const Key('evidence_measured'),
                    status: tr('ÖLÇÜLDÜ', 'MEASURED'),
                    statusColor: TC.green,
                    title: weakest == null
                        ? tr(
                            'Tüm sesler ilk denemede doğru',
                            'Every sound right on the first try',
                          )
                        : tr(
                            '${label(weakest.key)} ayrımı',
                            'Telling ${label(weakest.key)} apart',
                          ),
                    body: weakest == null
                        ? tr(
                            'Bu turda karışan ses yok.',
                            'Nothing got mixed up this round.',
                          )
                        : missed.length == 1
                        ? tr(
                            '${weakest.value.$2 - weakest.value.$1} soruda karıştı',
                            'Mixed up in ${weakest.value.$2 - weakest.value.$1} questions',
                          )
                        : tr(
                            '${weakest.value.$2 - weakest.value.$1} soruda karıştı · '
                                'toplam ${missed.length} seste hata var',
                            'Mixed up in ${weakest.value.$2 - weakest.value.$1} questions · '
                                'mistakes on ${missed.length} sounds in all',
                          ),
                    action: weakest == null || retryConfig == null
                        ? null
                        : (
                            tr('Yanlışları tekrar et', 'Retry the misses'),
                            () => _retry(context, missed),
                          ),
                  ),
                  if (sang)
                    _Evidence(
                      key: Key('evidence_sing'),
                      status: tr('DENEYSEL', 'EXPERIMENTAL'),
                      statusColor: TC.amber,
                      title: tr('Söyle adımı', 'Singing step'),
                      body: tr(
                        'Söyleme puanlanmaz. Mikrofonu açtıysan gördüğün '
                            'sent farkı yalnız tanısaldı.',
                        'Singing is not scored. If you turned the microphone on, '
                            'the cent difference you saw was diagnostic only.',
                      ),
                    ),
                  if (store.breathedToday)
                    _Evidence(
                      key: Key('evidence_breath'),
                      status: tr('ÖLÇÜLMEDİ', 'NOT MEASURED'),
                      statusColor: TC.muted,
                      title: tr('Nefes', 'Breath'),
                      body: tr(
                        'Yönlendirme tamamlandı; kalite puanı üretilmedi.',
                        'Guidance completed; no quality score was produced.',
                      ),
                    ),
                  if (upNext != null && !gate) ...[
                    const SizedBox(height: 4),
                    Container(
                      key: const Key('session_next'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TC.primarySoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          const Icon(Ic.sparkles, color: TC.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(
                                    'Sıradaki: ${upNext.title}',
                                    'Next: ${upNext.title}',
                                  ),
                                  style: TT.title.copyWith(
                                    color: TC.primary,
                                    fontSize: 14.5,
                                  ),
                                ),
                                Text(
                                  tr(
                                    'Bugün sekmesindeki rotadan başlar',
                                    'Starts from the route in the Today tab',
                                  ),
                                  style: TT.small,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: const Key('session_details'),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      childrenPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      title: Text(
                        tr(
                          'AYRINTILI KANIT · SORU BAZINDA',
                          'DETAILED EVIDENCE · BY QUESTION',
                        ),
                        style: TT.caps,
                      ),
                      subtitle: Text('+$xp XP', style: TT.small),
                      children: [
                        for (final e in items)
                          _ItemRow(
                            label: label(e.key),
                            correct: e.value.$1,
                            total: e.value.$2,
                            color: color,
                          ),
                        Padding(
                          padding: EdgeInsets.only(top: 6, bottom: 4),
                          child: Text(
                            tr(
                              'Yalnız ilk denemeler sayılır. Kısa tekrar bu '
                                  'sonuçları ve ilerlemeyi değiştirmez.',
                              'Only first tries count. A quick retry does not change '
                                  'these results or your progress.',
                            ),
                            style: TT.small,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: BigButton(
                key: const Key('session_done'),
                label: tr('Bitti', 'Done'),
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Three fresh questions on the missed items, weakest first. Unrecorded:
  /// nothing reaches stats, XP, streak or lesson progress.
  Future<void> _retry(BuildContext context, List<String> missed) async {
    final config = retryConfig!;
    final gen = QuizGenerator(config);
    final questions = [
      for (var i = 0; i < 3; i++)
        () {
          final target = missed[i % missed.length];
          return config.pool.length > 1 && config.pool.contains(target)
              ? QuizQuestion.identify(
                  trainer: config.trainer,
                  answer: target,
                  options: config.pool,
                  sound: gen.soundOf(target),
                )
              : gen.find(target: target, choices: 3);
        }(),
    ];
    final messenger = ScaffoldMessenger.of(context);
    final result = await Navigator.of(context).push<QuizSummary>(
      MaterialPageRoute(
        builder: (routeContext) => QuizView(
          title: tr('Kısa tekrar', 'Quick retry'),
          questions: questions,
          record: false,
          showCounter: true,
          onExit: () => Navigator.of(routeContext).pop(),
          onFinished: (summary) => Navigator.of(routeContext).pop(summary),
        ),
      ),
    );
    if (result == null) return;
    messenger.showSnackBar(
      SnackBar(
        key: const Key('retry_result'),
        content: Text(
          tr(
            'Kısa tekrar: ${result.correct}/${result.total} · '
                'ilerlemene ve istatistiklerine yazılmadı.',
            'Quick retry: ${result.correct}/${result.total} · '
                'not added to your progress or statistics.',
          ),
        ),
      ),
    );
  }
}

class _Evidence extends StatelessWidget {
  const _Evidence({
    super.key,
    required this.status,
    required this.statusColor,
    required this.title,
    required this.body,
    this.action,
  });
  final String status;
  final Color statusColor;
  final String title;
  final String body;
  final (String, VoidCallback)? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: TT.caps.copyWith(fontSize: 10, color: statusColor),
          ),
          const SizedBox(height: 4),
          Text(title, style: TT.title.copyWith(fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(body, style: TT.small.copyWith(fontSize: 12.5)),
          if (action != null) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('retry_missed'),
              onPressed: action!.$2,
              style: TextButton.styleFrom(
                foregroundColor: TC.primary,
                backgroundColor: TC.primarySoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                action!.$1,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
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

/// Share of first-try answers; teal arc on a dark track.
class _ScoreRing extends CustomPainter {
  _ScoreRing(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = const Color(0xFF3A3D55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 6.2832, false, track);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * value.clamp(0.0, 1.0),
      false,
      track
        ..color = TC.teal
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRing old) => old.value != value;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF2E3149),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: TC.heroMuted, fontSize: 12)),
      ],
    ),
  );
}
