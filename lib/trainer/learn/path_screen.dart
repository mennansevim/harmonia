import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';
import 'lesson_flow.dart';

/// Vertical timeline of a trainer's lessons, checkpoints and final exam.
class PathScreen extends StatefulWidget {
  const PathScreen({super.key, required this.trainer});
  final TrainerKind trainer;
  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  final _scroll = ScrollController();
  final _currentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = TrainerScope.of(context).store;
      final seenKey = 'path-${widget.trainer.id}';
      if (!store.seenTrainerSheets.contains(seenKey)) {
        store.seenTrainerSheets.add(seenKey);
        store.save();
        await showTrainerSheet<void>(
          context,
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🚀',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 44),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu bölümü zaten biliyor musun?',
                textAlign: TextAlign.center,
                style: TT.h3,
              ),
              const SizedBox(height: 6),
              const Text(
                'Test olmak için bir kontrol noktasına dokun. Geçersen doğrudan ileri atlarsın.',
                textAlign: TextAlign.center,
                style: TT.small,
              ),
              const SizedBox(height: 18),
              BigButton(
                label: 'Anladım',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
      final c = _currentKey.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(
          c,
          alignment: 0.3,
          duration: const Duration(milliseconds: 400),
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(LessonNode node) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LessonFlow(node: node)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final path = trainerPaths[widget.trainer]!;
    final color = trainerColor(widget.trainer);
    final done = store.completedCount(widget.trainer);
    final next = store.nextNode(widget.trainer);
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TopBar(
              title: widget.trainer.title,
              titleIcon: TrainerBadge(
                color: color,
                icon: trainerIcon(widget.trainer),
                size: 32,
              ),
              progress: done / path.lessonCount,
              progressColor: color,
              counter: '$done / ${path.lessonCount}',
              shadow: true,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                itemCount: path.nodes.length,
                itemBuilder: (context, i) {
                  final node = path.nodes[i];
                  final isNext = node.id == next?.id;
                  return _NodeRow(
                    key: isNext ? _currentKey : ValueKey(node.id),
                    node: node,
                    color: color,
                    first: i == 0,
                    last: i == path.nodes.length - 1,
                    current: isNext,
                    progress: store.progressOf(node.id),
                    unlocked: store.isUnlocked(node),
                    onTap: () => _open(node),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    super.key,
    required this.node,
    required this.color,
    required this.first,
    required this.last,
    required this.current,
    required this.progress,
    required this.unlocked,
    required this.onTap,
  });
  final LessonNode node;
  final Color color;
  final bool first;
  final bool last;
  final bool current;
  final NodeProgress? progress;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final complete = progress != null;
    final gate = node.kind == NodeKind.checkpoint;
    final exam = node.kind == NodeKind.finalExam;
    final tappable = complete || current || node.isGate || unlocked;
    Widget marker;
    if (complete) {
      marker = _circle(
        color,
        const Icon(Icons.check_rounded, color: Colors.white),
      );
    } else if (current) {
      marker = Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 3),
        ),
        child: Icon(Icons.play_arrow_rounded, color: color),
      );
    } else if (gate) {
      marker = _circle(
        color,
        const Icon(Icons.flag_rounded, color: Colors.white, size: 20),
      );
    } else if (exam) {
      marker = _circle(
        const Color(0xFFE5E9F0),
        const Icon(Icons.emoji_events_outlined, color: TC.muted, size: 20),
      );
    } else {
      marker = _circle(
        const Color(0xFFE9EDF3),
        const Icon(Icons.lock_outline_rounded, color: TC.muted, size: 18),
      );
    }
    final cardColor = exam
        ? const Color(0xFFF1E8FD)
        : gate
        ? soft(color)
        : Colors.white;
    final stars = progress?.stars ?? 0;
    final review = progress?.review ?? false;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: 2,
                        color: first ? Colors.transparent : TC.line,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: last ? Colors.transparent : TC.line,
                      ),
                    ),
                  ],
                ),
                marker,
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Opacity(
                opacity: tappable || gate || exam ? 1 : 0.65,
                child: AppCard(
                  color: cardColor,
                  border: current
                      ? color
                      : (review ? const Color(0xFFF5D96B) : null),
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  onTap: tappable ? onTap : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (gate || exam) ...[
                              Tag(
                                exam ? 'FİNAL SINAVI' : 'KONTROL NOKTASI',
                                color: exam ? TC.purple : color,
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              node.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: complete || current || gate || exam
                                    ? TC.ink
                                    : TC.body,
                              ),
                            ),
                            if (!exam) ...[
                              const SizedBox(height: 3),
                              Text(
                                node.subtitle,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: TC.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (complete && !gate && !exam)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var s = 0; s < 3; s++)
                                  Icon(
                                    s < stars
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 18,
                                    color: s < stars ? color : TC.faint,
                                  ),
                              ],
                            ),
                            if (review) ...[
                              const SizedBox(height: 4),
                              const Tag('TEKRAR', color: TC.gold),
                            ],
                          ],
                        )
                      else if (current)
                        Tag('BAŞLA', color: color)
                      else if (!tappable)
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: TC.faint,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(Color c, Widget child) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    child: Center(child: child),
  );
}
