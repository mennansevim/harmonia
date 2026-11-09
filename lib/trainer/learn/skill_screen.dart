import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../practice/practice_setup.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
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
    final nodes = path.nodes;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      rows.add(
        // Nodes rise in along the path once, when first shown.
        Entrance(
          key: ValueKey('enter_${node.id}'),
          index: i,
          child: _PathNode(
            key: ValueKey(node.id),
            node: node,
            color: color,
            x: pathX(i),
            prevX: i == 0 || nodes[i - 1].kind == NodeKind.checkpoint
                ? null
                : pathX(i - 1),
            nextX: i == nodes.length - 1 || node.kind == NodeKind.checkpoint
                ? null
                : pathX(i + 1),
            walked: store.progressOf(node.id) != null,
            current: node.id == next?.id,
            progress: store.progressOf(node.id),
            unlocked: store.isUnlocked(node),
            consolidated:
                node.isGate &&
                (store.gateEvidence(node.id)?.consolidated ?? false),
            onTap: () => _open(node),
          ),
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
          color: TC.sun,
          track: TC.heroTrack,
          height: 6,
        ),
        const SizedBox(height: 16),
        BigButton(
          key: const Key('skill_next'),
          label: next == null
              ? tr('Tüm dersler tamam', 'All lessons done')
              : tr('Derse başla', 'Start the lesson'),
          icon: Ic.play,
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

/// PATH-01: horizontal place of the [i]th node on the winding path, as an
/// [Alignment.x] (-1 left edge … 1 right edge). A gentle S-curve that
/// repeats every eight nodes, like a trail down the page.
double pathX(int i) =>
    const [0.0, 0.42, 0.62, 0.42, 0.0, -0.42, -0.62, -0.42][i % 8];

class _StageHeader extends StatelessWidget {
  const _StageHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        const Expanded(child: Divider(color: TC.line, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(text, style: TT.caps),
        ),
        const Expanded(child: Divider(color: TC.line, thickness: 1.5)),
      ],
    ),
  );
}

/// One stop on the winding lesson path: a round button placed at [x],
/// joined to its neighbours by a curved trail ([prevX]/[nextX]; null where
/// a stage starts or ends). Done stops are green with their stars, the
/// current one is larger with a "Başla" tag, gates are always open and
/// locked stops are grey.
class _PathNode extends StatelessWidget {
  const _PathNode({
    super.key,
    required this.node,
    required this.color,
    required this.x,
    required this.prevX,
    required this.nextX,
    required this.walked,
    required this.current,
    required this.progress,
    required this.unlocked,
    this.consolidated = false,
    required this.onTap,
  });
  final LessonNode node;
  final Color color;
  final double x;
  final double? prevX, nextX;
  final bool walked;
  final bool current;
  final NodeProgress? progress;
  final bool unlocked;

  /// Gate attempts add up to the consolidated indicator (never a lock).
  final bool consolidated;
  final VoidCallback onTap;

  static const height = 132.0;

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
            node.kind == NodeKind.finalExam ? Ic.trophy : Ic.flag,
            color,
            soft(color),
          )
        : (Ic.lock, TC.muted, TC.line);
    final size = current ? 70.0 : 60.0;
    final state = complete
        ? tr(
            'tamamlandı, ${progress!.stars}/3 yıldız'
                '${consolidated ? ', iki ayrı günde doğrulandı' : ''}'
                '${progress!.review ? ', tekrar önerilir' : ''}',
            'done, ${progress!.stars} of 3 stars'
                '${consolidated ? ', confirmed on two separate days' : ''}'
                '${progress!.review ? ', a review is suggested' : ''}',
          )
        : current
        ? tr('sıradaki ders', 'next lesson')
        : open
        ? tr('açık', 'open')
        : tr('kilitli', 'locked');
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrailPainter(
          x: x,
          prevX: prevX,
          nextX: nextX,
          walked: walked,
          circleTop: 18 + size / 2,
        ),
        child: Align(
          alignment: Alignment(x, -1),
          child: Semantics(
            button: open,
            enabled: open,
            label: '${node.title}, $state',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: open ? onTap : null,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 150,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 18,
                      child: current
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: TC.sun,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tr('BAŞLA', 'START'),
                                style: TT.caps.copyWith(
                                  fontSize: 10,
                                  color: TC.onSun,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Opacity(
                      opacity: open ? 1 : 0.7,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: bg,
                          shape: BoxShape.circle,
                          border: current
                              ? Border.all(color: TC.sun, width: 4)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Color.lerp(bg, Colors.black, 0.22)!,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: fg, size: size * 0.42),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Canvas-coloured label so the trail passes behind it.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: TC.canvas,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              node.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TT.title.copyWith(
                                fontSize: 13.5,
                                color: open ? TC.ink : TC.muted,
                              ),
                            ),
                            if (complete)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var s = 0; s < 3; s++)
                                      Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: s < progress!.stars
                                            ? TC.amber
                                            : TC.line,
                                      ),
                                    if (consolidated) ...[
                                      const SizedBox(width: 3),
                                      Tooltip(
                                        message: tr(
                                          'iki ayrı günde doğrulandı',
                                          'confirmed on two separate days',
                                        ),
                                        child: Icon(
                                          Icons.verified_rounded,
                                          key: Key(
                                            'gate_consolidated_${node.id}',
                                          ),
                                          size: 14,
                                          color: TC.green,
                                        ),
                                      ),
                                    ],
                                    if (progress!.review) ...[
                                      const SizedBox(width: 3),
                                      const Icon(
                                        Ic.rotateCcw,
                                        size: 13,
                                        color: TC.warn,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dotted trail behind one node: from the top edge (halfway to the
/// previous node) to this node's centre, and on to the bottom edge
/// (halfway to the next). Green where the node is done.
class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.x,
    required this.prevX,
    required this.nextX,
    required this.walked,
    required this.circleTop,
  });
  final double x;
  final double? prevX, nextX;
  final bool walked;
  final double circleTop;

  @override
  void paint(Canvas canvas, Size size) {
    double px(double ax) => size.width / 2 + ax * (size.width / 2 - 75);
    final c = Offset(px(x), circleTop);
    final path = Path();
    if (prevX != null) {
      final top = Offset(px((prevX! + x) / 2), 0);
      path
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(c.dx, top.dy + 4, c.dx, c.dy);
    } else {
      path.moveTo(c.dx, c.dy);
    }
    if (nextX != null) {
      final bottom = Offset(px((nextX! + x) / 2), size.height);
      path.quadraticBezierTo(c.dx, bottom.dy - 4, bottom.dx, bottom.dy);
    }
    final paint = Paint()
      ..color = walked ? TC.green.withValues(alpha: 0.55) : TC.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    // Dotted: short dashes along the curve.
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 16) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.x != x ||
      old.prevX != prevX ||
      old.nextX != nextX ||
      old.walked != walked ||
      old.circleTop != circleTop;
}
