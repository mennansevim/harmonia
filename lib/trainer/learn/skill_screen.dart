import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../practice/practice_setup.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'lesson_flow.dart';

/// Opens a skill's page (lessons + free practice in one place).
Future<void> openSkill(BuildContext context, TrainerKind kind) => Navigator.of(
  context,
).push<void>(MaterialPageRoute(builder: (_) => SkillScreen(trainer: kind)));

/// One skill: summary, the next lesson, free practice and the lesson list
/// grouped into stages ("Basamak") split by checkpoints ("Ara durak").
class SkillScreen extends StatefulWidget {
  const SkillScreen({super.key, required this.trainer});
  final TrainerKind trainer;
  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

class _SkillScreenState extends State<SkillScreen> {
  TrainerKind get kind => widget.trainer;

  Future<void> _open(LessonNode node) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LessonFlow(node: node)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final path = trainerPaths[kind]!;
    final color = trainerColor(kind);
    final done = store.completedCount(kind);
    final next = store.nextNode(kind);
    final rows = <Widget>[];
    var stage = 1;
    rows.add(_StageHeader('BASAMAK $stage'));
    for (final node in path.nodes) {
      rows.add(
        _LessonRow(
          key: ValueKey(node.id),
          node: node,
          color: color,
          current: node.id == next?.id,
          progress: store.progressOf(node.id),
          unlocked: store.isUnlocked(node),
          onTap: () => _open(node),
        ),
      );
      if (node.kind == NodeKind.checkpoint) {
        stage++;
        rows.add(_StageHeader('BASAMAK $stage'));
      }
    }
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 40),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Geri',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: TC.ink),
                ),
                Expanded(child: Text(kind.title, style: TT.h3)),
                IconButton(
                  key: const Key('skill_stats'),
                  tooltip: 'İstatistik',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TrainerStatsScreen(trainer: kind),
                    ),
                  ),
                  icon: const Icon(Icons.insights_rounded, color: TC.body),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Summary(
                    kind: kind,
                    color: color,
                    mastery: store.mastery(kind),
                    done: done,
                    total: path.lessonCount,
                    next: next,
                    onNext: next == null ? null : () => _open(next),
                    onFree: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PracticeSetupScreen(trainer: kind),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ara duraklar her zaman açık: %80 ile geçersen öncesindeki dersler tamamlanır.',
                    style: TT.small,
                  ),
                  ...rows,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.kind,
    required this.color,
    required this.mastery,
    required this.done,
    required this.total,
    required this.next,
    required this.onNext,
    required this.onFree,
  });
  final TrainerKind kind;
  final Color color;
  final double mastery;
  final int done;
  final int total;
  final LessonNode? next;
  final VoidCallback? onNext;
  final VoidCallback onFree;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TrainerBadge(color: color, icon: trainerIcon(kind), size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.tagline, style: TT.title),
                  Text('$done / $total ders tamam', style: TT.small),
                ],
              ),
            ),
            Text(
              '%${(mastery * 100).round()}',
              style: TT.h2.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 14),
        BigButton(
          key: const Key('skill_next'),
          label: next == null
              ? 'Tüm dersler tamam'
              : 'Sıradaki: ${next!.title}',
          icon: Icons.play_arrow_rounded,
          color: color,
          onPressed: onNext,
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          key: const Key('skill_free'),
          onPressed: onFree,
          style: TextButton.styleFrom(foregroundColor: color),
          icon: const Icon(Icons.tune_rounded),
          label: const Text(
            'Serbest çalışma',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _StageHeader extends StatelessWidget {
  const _StageHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(text, style: TT.caps),
  );
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    super.key,
    required this.node,
    required this.color,
    required this.current,
    required this.progress,
    required this.unlocked,
    required this.onTap,
  });
  final LessonNode node;
  final Color color;
  final bool current;
  final NodeProgress? progress;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = progress != null;
    final open = complete || current || node.isGate || unlocked;
    final (IconData icon, Color fg, Color bg) = complete
        ? (Icons.check_rounded, Colors.white, TC.green)
        : current
        ? (Icons.play_arrow_rounded, Colors.white, color)
        : node.isGate
        ? (
            node.kind == NodeKind.finalExam
                ? Icons.music_note_rounded
                : Icons.fact_check_outlined,
            color,
            soft(color),
          )
        : (Icons.lock_outline_rounded, TC.muted, TC.line);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: open ? 1 : 0.6,
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: current ? color : null,
          onTap: open ? onTap : null,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.title, style: TT.title),
                    Text(
                      node.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.small,
                    ),
                  ],
                ),
              ),
              if (complete)
                Text(
                  '${progress!.stars}/3',
                  style: TT.small.copyWith(
                    fontWeight: FontWeight.w800,
                    color: progress!.review ? TC.amber : TC.green,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
