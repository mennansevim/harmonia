import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/celebration.dart';
import '../../app/theme/resonia_theme.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
import '../../domain/lang.dart';

/// End of a lesson, gate or free session in two layers: a headline result
/// with what was measured, not measured or experimental, then the per-item
/// details on demand. "Yanlışları tekrar et" runs a short, unrecorded
/// retry on fresh examples of the missed items.
///
/// WIDE-03: completing a lesson, a wrong answer, an unmeasured step and a
/// skill gain are different statements. The headline says what happened
/// (completed / answers measured); XP is practice volume and stays in the
/// details; one "next step" card names the single suggested follow-up.
///
/// PATH-01: a passed lesson or gate celebrates by tier ([celebrationFor])
/// and, when [onContinue] is set and the skill has a next node, offers
/// "Devam et" so the path keeps going without a trip back to Today.
class SessionEnd extends StatelessWidget {
  const SessionEnd({
    super.key,
    required this.summary,
    required this.onDone,
    this.node,
    this.passed = true,
    this.title,
    this.retryConfig,
    this.onContinue,
    this.onReviewPrevious,
    this.onRetryGate,
  });
  final LessonNode? node;
  final QuizSummary summary;
  final bool passed;
  final String? title;
  final VoidCallback onDone;

  /// How the session sounded; enables the short retry when set.
  final QuizConfig? retryConfig;

  /// Opens the skill's next node in place of this one; null hides
  /// "Devam et".
  final VoidCallback? onContinue;

  /// A failed gate: opens the lesson right before it again.
  final VoidCallback? onReviewPrevious;

  /// A failed gate: runs the same gate again.
  final VoidCallback? onRetryGate;

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
    // No answered question: nothing was measured, so no score or verdict.
    final measured = s.total > 0;
    final verdict = !measured
        ? tr('Bu turda yanıt kaydedilmedi', 'No answers were recorded')
        : gate && passed && node?.kind == NodeKind.finalExam
        ? tr('Final sınavı geçildi', 'Final exam passed')
        : gate
        ? (passed
              ? tr('Ara durak geçildi', 'Checkpoint passed')
              : tr('Ara durak için %80 gerekiyor', 'The checkpoint needs 80%'))
        : node == null
        ? tr('Serbest çalışma bitti', 'Free practice finished')
        // Every finished lesson is complete (completeNode); accuracy is told
        // apart in the note, never as a pass/fail or skill verdict.
        : tr('Ders tamamlandı', 'Lesson complete');
    final note =
        measured && passed && node != null && store.nextNode(kind) == null
        ? tr(
            'Bu becerinin tüm dersleri tamamlandı.',
            'Every lesson of this skill is complete.',
          )
        : !measured
        ? tr(
            'Puan ya da ilerleme yazılmadı. İstediğin zaman yeniden dene.',
            'No score or progress was written. Try again whenever you like.',
          )
        : gate
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
                  'Sıradaki ders açıldı. Bu turda karışan sesler oldu; '
                      'önce kısa bir tekrar iyi gelebilir.',
                  'The next lesson is open. Some sounds got mixed up this '
                      'round; a quick retry first may help.',
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
    final canContinue =
        onContinue != null &&
        node != null &&
        measured &&
        passed &&
        upNext != null;
    final tier = celebrationFor(
      node: node,
      measured: measured,
      passed: passed,
      skillDone: node != null && upNext == null,
    );
    // One suggested follow-up, in this order: retry today's misses, else the
    // next lesson. A failed checkpoint already says what to do in its note.
    final failedGate = gate && measured && !passed;
    final (String, String, (String, VoidCallback)?)? nextStep =
        failedGate && onReviewPrevious != null
        ? (
            tr('Önceki dersi tekrar et', 'Repeat the previous lesson'),
            tr(
              'Kapıdan hemen önceki dersi yeniden aç; hazır olunca kapıyı yeniden dene.',
              'Reopen the lesson right before the gate; try the gate again when ready.',
            ),
            (
              tr('Önceki dersi aç', 'Open the previous lesson'),
              onReviewPrevious!,
            ),
          )
        : measured && weakest != null && retryConfig != null
        ? (
            tr('Karışanları kısa tekrarla çalış', 'Practise the mix-ups'),
            tr(
              '3 soru · ilerlemene ve istatistiklerine yazılmaz',
              '3 questions · not added to your progress or statistics',
            ),
            (
              tr('Yanlışları tekrar et', 'Retry the misses'),
              () => _retry(context, missed),
            ),
          )
        : upNext != null && !gate && measured && !canContinue
        ? (
            tr('Sıradaki: ${upNext.title}', 'Next: ${upNext.title}'),
            tr(
              'Bugün sekmesindeki rotadan başlar',
              'Starts from the route in the Today tab',
            ),
            null,
          )
        : null;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: Stack(
        children: [
          SafeArea(
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
                      Entrance(child: Text(verdict, style: TT.h2)),
                      const SizedBox(height: 4),
                      Entrance(index: 1, child: Text(note, style: TT.body)),
                      const SizedBox(height: 18),
                      if (measured)
                        Entrance(
                          index: 2,
                          child: HeroCard(
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
                                    // The ring fills up to the result.
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: s.total == 0
                                            ? 0
                                            : s.correct / s.total,
                                      ),
                                      duration: ResoniaMotion.reduced(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 900),
                                      curve: Motion.curve,
                                      builder: (context, v, ring) =>
                                          CustomPaint(
                                            painter: _ScoreRing(v),
                                            child: ring,
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
                                // Wraps instead of overflowing on narrow screens
                                // and large text.
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _Stat(
                                      value: percent(s.accuracy),
                                      label: tr('ilk deneme', 'first try'),
                                    ),
                                    // Question count, not XP: XP is practice volume
                                    // and lives in the details (WIDE-03).
                                    _Stat(
                                      value: '${s.total}',
                                      label: tr('soru', 'questions'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                        status: measured
                            ? tr('ÖLÇÜLDÜ', 'MEASURED')
                            : tr('ÖLÇÜLMEDİ', 'NOT MEASURED'),
                        statusColor: measured ? TC.green : TC.muted,
                        title: !measured
                            ? tr('Dinleme yanıtları', 'Listening answers')
                            : weakest == null
                            ? tr(
                                'Tüm sesler ilk denemede doğru',
                                'Every sound right on the first try',
                              )
                            : tr(
                                '${label(weakest.key)} ayrımı',
                                'Telling ${label(weakest.key)} apart',
                              ),
                        body: !measured
                            ? tr(
                                'Yanıt olmadığı için doğru ya da yanlış sayılmadı.',
                                'With no answers, nothing counted as right or wrong.',
                              )
                            : weakest == null
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
                      if (nextStep != null) ...[
                        const SizedBox(height: 4),
                        _NextStep(
                          title: nextStep.$1,
                          body: nextStep.$2,
                          action: nextStep.$3,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: const Key('session_details'),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
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
                          subtitle: Text(
                            tr(
                              '+$xp XP · pratik puanı, beceri ölçümü değil',
                              '+$xp XP · practice points, not a skill measure',
                            ),
                            style: TT.small,
                          ),
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
                  child: failedGate && onRetryGate != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BigButton(
                              key: const Key('session_retry_gate'),
                              label: tr('Yeniden dene', 'Try again'),
                              icon: Ic.rotateCcw,
                              onPressed: onRetryGate,
                            ),
                            TextButton(
                              key: const Key('session_done'),
                              onPressed: onDone,
                              child: Text(tr('Şimdilik bitir', 'Stop for now')),
                            ),
                          ],
                        )
                      : canContinue
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BigButton(
                              key: const Key('session_continue'),
                              label: tr(
                                'Devam et: ${upNext.title}',
                                'Continue: ${upNext.title}',
                              ),
                              icon: Ic.play,
                              onPressed: onContinue,
                            ),
                            TextButton(
                              key: const Key('session_done'),
                              onPressed: onDone,
                              child: Text(tr('Şimdilik bitir', 'Stop for now')),
                            ),
                          ],
                        )
                      : BigButton(
                          key: const Key('session_done'),
                          label: tr('Bitti', 'Done'),
                          onPressed: onDone,
                        ),
                ),
              ],
            ),
          ),
          if (tier != CelebrationTier.none)
            Positioned.fill(child: Celebration(tier: tier, sound: true)),
        ],
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

/// The single suggested follow-up after a session (WIDE-03).
class _NextStep extends StatelessWidget {
  const _NextStep({required this.title, required this.body, this.action});
  final String title;
  final String body;
  final (String, VoidCallback)? action;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('session_next'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: TC.primarySoft,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('SONRAKİ ADIM', 'NEXT STEP'), style: TT.caps),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Ic.sparkles, color: TC.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TT.title.copyWith(color: TC.primary, fontSize: 14.5),
                  ),
                  Text(body, style: TT.small),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[
          const SizedBox(height: 8),
          SoftButton(
            key: const Key('retry_missed'),
            label: action!.$1,
            onPressed: action!.$2,
          ),
        ],
      ],
    ),
  );
}

class _Evidence extends StatelessWidget {
  const _Evidence({
    super.key,
    required this.status,
    required this.statusColor,
    required this.title,
    required this.body,
  });
  final String status;
  final Color statusColor;
  final String title;
  final String body;
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

/// Share of first-try answers; lime arc on the hero's track.
class _ScoreRing extends CustomPainter {
  _ScoreRing(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..color = TC.heroTrack
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
        ..color = TC.sun
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
      color: TC.heroTile,
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
