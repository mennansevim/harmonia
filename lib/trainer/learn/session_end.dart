import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';

/// Two-step ending: an accuracy ring, then the session card.
class SessionEnd extends StatefulWidget {
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
  State<SessionEnd> createState() => _SessionEndState();
}

class _SessionEndState extends State<SessionEnd> {
  bool _details = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final s = widget.summary;
    final pct = (s.accuracy * 100).round();
    final kind =
        node?.trainer ??
        s.records.firstOrNull?.question.trainer ??
        TrainerKind.pitch;
    final color = trainerColor(kind);
    final gate = node?.isGate ?? false;
    final strong = s.accuracy >= 0.7;
    final headline = gate
        ? (widget.passed ? 'Geçtin!' : 'Bu sefer olmadı')
        : (strong ? 'Yerine oturdu!' : 'Az kaldı!');
    final message = gate
        ? (widget.passed
              ? '%$pct ile ${node!.title} tamam. Önceki derslerin hepsi açıldı.'
              : '%$pct aldın; geçmek için %80 gerekiyor. Dersleri sırayla çalışıp tekrar dene.')
        : node == null
        ? '$pct% doğruluk. ${s.correct} / ${s.total} doğru.'
        : (strong
              ? '${node.title} yerine oturdu. Sıradaki ders açıldı.'
              : '${node.title} bir tur daha istiyor. Derslerden istediğin zaman tekrar et ya da gelecek oturumda karşına çıkacak.');
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: !_details
              ? Column(
                  key: const ValueKey('ring'),
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Ring(
                              value: s.accuracy,
                              color: TC.primary,
                              icon: trainerIcon(kind),
                            ),
                            const SizedBox(height: 26),
                            Tag(
                              gate
                                  ? 'KONTROL NOKTASI'
                                  : strong
                                  ? 'YENİ DERS · YERİNE OTURDU'
                                  : 'YENİ DERS · DEVAM',
                              color: TC.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(headline, style: TT.h2),
                            const SizedBox(height: 10),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TT.body,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: BigButton(
                        key: const Key('session_results'),
                        label: 'Oturum sonuçlarını gör',
                        chevron: true,
                        onPressed: () => setState(() => _details = true),
                      ),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('details'),
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                        children: [
                          const Center(
                            child: Text('💪', style: TextStyle(fontSize: 56)),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Çalışma bitti',
                            textAlign: TextAlign.center,
                            style: TT.h3,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strong
                                ? 'Her şey yolunda. Güzel iş.'
                                : 'Her tekrar kulağını güçlendiriyor.',
                            textAlign: TextAlign.center,
                            style: TT.small,
                          ),
                          const SizedBox(height: 20),
                          AppCard(
                            child: Column(
                              children: [
                                _MiniRing(pct: pct, color: color),
                                const SizedBox(height: 8),
                                Text(
                                  node?.isGate == true ? 'Test' : 'Yeni',
                                  style: TT.title,
                                ),
                                Text(
                                  '${widget.title ?? node?.title ?? kind.title} · ${s.total}',
                                  style: TT.small,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (final e in s.byItem().entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ItemRow(
                                kind: kind,
                                item: e.key,
                                result: e.value,
                              ),
                            ),
                          const SizedBox(height: 4),
                          AppCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDDF6EC),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: Color(0xFF137A52),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '+${s.correct * 10 + (s.total - s.correct) * 2} XP',
                                        style: TT.title,
                                      ),
                                      const Text(
                                        'Doğru cevap 10, deneme 2 XP kazandırır.',
                                        style: TT.small,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: BigButton(
                        key: const Key('session_done'),
                        label: 'Bitti',
                        onPressed: () async {
                          await maybeCelebrateStreak(context);
                          widget.onDone();
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.kind,
    required this.item,
    required this.result,
  });
  final TrainerKind kind;
  final String item;
  final (int, int) result;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final (c, n) = result;
    final ratio = n == 0 ? 0.0 : c / n;
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            itemLabel(
              kind,
              item,
              notation: store.notation,
              transposition: store.transposition,
              long: true,
            ),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        Expanded(
          child: ProgressBar(
            value: ratio,
            color: ratio >= 0.8
                ? TC.green
                : ratio >= 0.5
                ? TC.primary
                : TC.red,
            height: 8,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$c/$n',
          style: const TextStyle(fontWeight: FontWeight.w700, color: TC.body),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.color, required this.icon});
  final double value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: const Color(0xFFF0EFF8),
            ),
          ),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB9C2D0),
            ),
            child: Icon(icon, color: Colors.white, size: 48),
          ),
        ],
      ),
    ),
  );
}

class _MiniRing extends StatelessWidget {
  const _MiniRing({required this.pct, required this.color});
  final int pct;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 52,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: pct / 100,
            strokeWidth: 4,
            color: color,
            backgroundColor: const Color(0xFFF0EFF8),
          ),
        ),
        Text(
          '%$pct',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Shows the streak dialog once per day after the first finished session.
Future<void> maybeCelebrateStreak(BuildContext context) async {
  final store = TrainerScope.of(context).store;
  final today = dayKey(store.now);
  if (store.lastStreakCelebrated == today || !store.practicedToday) return;
  store.lastStreakCelebrated = today;
  store.save();
  final streak = store.streak;
  final now = store.now;
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  const labels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 6),
            Text('$streak gün üst üste!', style: TT.h2),
            const SizedBox(height: 8),
            const Text(
              'Seriyi korumak için yarın birkaç dakika yeter.',
              textAlign: TextAlign.center,
              style: TT.body,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 7; i++)
                  Builder(
                    builder: (context) {
                      final d = monday.add(Duration(days: i));
                      final active = store.activeOn(d);
                      final past = d.isBefore(
                        DateTime(now.year, now.month, now.day),
                      );
                      return Column(
                        children: [
                          Text(labels[i], style: TT.small),
                          const SizedBox(height: 6),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active
                                  ? TC.primary
                                  : const Color(0xFFF0EFF8),
                              border: past && !active
                                  ? Border.all(color: TC.line, width: 1.5)
                                  : null,
                            ),
                            child: active
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : past
                                ? const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: TC.faint,
                                  )
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            BigButton(
              label: 'Devam et',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
