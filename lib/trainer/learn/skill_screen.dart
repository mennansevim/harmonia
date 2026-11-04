import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../practice/practice_setup.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'lesson_flow.dart';
import '../../domain/lang.dart';

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
    rows.add(_StageHeader(tr('BASAMAK $stage', 'STAGE $stage')));
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
        rows.add(_StageHeader(tr('BASAMAK $stage', 'STAGE $stage')));
      }
    }
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CrumbBar(
              crumb: trCaps(
                tr(
                  'Beceriler / ${kind.shortTitle}',
                  'Skills / ${kind.shortTitle}',
                ),
              ),
              trailing: IconButton(
                key: const Key('skill_stats'),
                tooltip: tr('İstatistik', 'Statistics'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TrainerStatsScreen(trainer: kind),
                  ),
                ),
                icon: const Icon(
                  Ic.chartNoAxesCombined,
                  color: TC.body,
                  size: 20,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
                children: [
                  PageTitle(kind.title),
                  const SizedBox(height: 26),
                  _Summary(
                    kind: kind,
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
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      'Ara duraklar her zaman açık: %80 ile geçersen öncesindeki dersler tamamlanır.',
                      'Checkpoints are always open: pass with 80% and the lessons before it are completed.',
                    ),
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
    required this.mastery,
    required this.done,
    required this.total,
    required this.next,
    required this.onNext,
    required this.onFree,
  });
  final TrainerKind kind;
  final double mastery;
  final int done;
  final int total;
  final LessonNode? next;
  final VoidCallback? onNext;
  final VoidCallback onFree;
  @override
  Widget build(BuildContext context) => HeroCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TC.sun,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(trainerIcon(kind), color: TC.onSun),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                next == null
                    ? tr('TÜM DERSLER TAMAM', 'ALL LESSONS DONE')
                    : tr('SIRADAKİ DERS', 'NEXT LESSON'),
                style: TT.heroCaps,
              ),
            ),
            TiltTag(
              tr('${percent(mastery)} ustalık', '${percent(mastery)} mastery'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          next?.title ?? kind.tagline,
          style: TT.display.copyWith(color: Colors.white, fontSize: 26),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            '${kind.tagline} · $done / $total ders tamam',
            '${kind.tagline} · $done / $total lessons done',
          ),
          style: const TextStyle(
            color: TC.heroMuted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ProgressBar(
          value: mastery,
          color: TC.teal,
          track: const Color(0xFF3A3D55),
          height: 6,
        ),
        const SizedBox(height: 16),
        BigButton(
          key: const Key('skill_next'),
          label: next == null
              ? tr('Tüm dersler tamam', 'All lessons done')
              : tr('Derse başla', 'Start the lesson'),
          icon: Ic.play,
          color: Colors.white,
          onPressed: onNext,
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          key: const Key('skill_free'),
          onPressed: onFree,
          style: TextButton.styleFrom(foregroundColor: TC.sun),
          icon: const Icon(Ic.settings2, size: 18),
          label: Text(
            tr('Serbest çalışma', 'Free practice'),
            style: TextStyle(fontWeight: FontWeight.w600),
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
        ? (Ic.check, Colors.white, TC.green)
        : current
        ? (Ic.play, Colors.white, color)
        : node.isGate
        ? (
            node.kind == NodeKind.finalExam ? Ic.music2 : Ic.clipboardCheck,
            color,
            soft(color),
          )
        : (Ic.lock, TC.muted, TC.line);
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
