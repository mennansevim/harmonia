import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../domain/learning/skill_graph.dart';
import '../common/ui/harmonia_ui.dart';
import 'home_data.dart';

String stageTitle(SkillStage s) => switch (s) {
  SkillStage.voiceAndPulse => 'Ses ve puls',
  SkillStage.directionAndTonic => 'Yön ve tonik',
  SkillStage.rhythmAndReading => 'Ritim ve okuma',
  SkillStage.melodyAndMemory => 'Ezgi ve hafıza',
  SkillStage.harmonicHearing => 'Çok sesli duyma',
  SkillStage.examLiteracy => 'Dikte ve deşifre',
  SkillStage.partIndependence => 'Parti bağımsızlığı',
  SkillStage.choirMusicianship => 'Koro müzisyenliği',
  SkillStage.transfer => 'Aktarım',
};

String nodeStateText(PathNode n) {
  if (!n.measurable) {
    return switch (n.node.support) {
      MeasurementSupport.awaitingEngine => 'Yakında: ses tanıma',
      MeasurementSupport.awaitingContent => 'Yakında: içerik',
      MeasurementSupport.educatorObserved => 'Eğitimci değerlendirir',
      MeasurementSupport.measuredInApp => '',
    };
  }
  return switch (n.state) {
    MasteryState.notMeasured => 'Başlanmadı',
    MasteryState.practicing => 'Çalışılıyor',
    MasteryState.supported => 'Destekle yapıyor',
    MasteryState.independent => 'Bağımsız',
    MasteryState.retained => 'Ertesi gün korundu',
  };
}

/// A's learning path drawn from the skill graph. Nothing is locked: the
/// order is a recommendation. Unmeasurable skills are shown as "coming",
/// never as failed.
class SkillPath extends StatelessWidget {
  const SkillPath({
    super.key,
    required this.nodes,
    required this.focusId,
    required this.onOpen,
    this.focusLabel = 'Başla',
  });

  final List<PathNode> nodes;

  /// Same verb as the Today card's button, so both say the same thing.
  final String focusLabel;

  /// The node the Today recommendation points at (gets the start bubble).
  final String? focusId;
  final ValueChanged<PathNode> onOpen;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    SkillStage? stage;
    var indexInStage = 0;
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      if (n.node.stage != stage) {
        stage = n.node.stage;
        indexInStage = 0;
        children.add(_StageBanner(stage: stage, nodes: nodes, index: i));
      }
      final nextSameStage =
          i + 1 < nodes.length && nodes[i + 1].node.stage == stage;
      children.add(
        _NodeRow(
          node: n,
          offset: _offset(indexInStage),
          nextOffset: nextSameStage ? _offset(indexInStage + 1) : null,
          focus: n.node.id == focusId,
          focusLabel: focusLabel,
          onTap: () => onOpen(n),
        ),
      );
      indexInStage++;
    }
    return Column(children: children);
  }

  /// Classic snake: centre, right, centre, left (fraction of half width).
  static double _offset(int i) => const [0.0, 0.55, 0.0, -0.55][i % 4];
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({
    required this.stage,
    required this.nodes,
    required this.index,
  });
  final SkillStage stage;
  final List<PathNode> nodes;
  final int index;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final inStage = nodes.where((n) => n.node.stage == stage).toList();
    final done = inStage.where((n) => n.mastered).length;
    final measurable = inStage.where((n) => n.measurable).length;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: HarmoniaSpacing.md,
        bottom: HarmoniaSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HarmoniaSpacing.md),
          decoration: BoxDecoration(
            color: measurable == 0
                ? scheme.surfaceContainerHigh
                : scheme.primary,
            borderRadius: BorderRadius.circular(HarmoniaRadius.card),
            boxShadow: measurable == 0
                ? null
                : [
                    BoxShadow(
                      color: palette.primaryDeep,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BÖLÜM ${stage.index + 1}',
                      style: harmoniaDataLabel(context).copyWith(
                        color: measurable == 0
                            ? palette.muted
                            : scheme.onPrimary.withValues(alpha: .8),
                      ),
                    ),
                    Text(
                      stageTitle(stage),
                      style: text.titleLarge?.copyWith(
                        color: measurable == 0
                            ? scheme.onSurface
                            : scheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                measurable == 0 ? 'yakında' : '$done/${inStage.length}',
                style: text.titleMedium?.copyWith(
                  color: measurable == 0 ? palette.muted : scheme.onPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.offset,
    required this.nextOffset,
    required this.focus,
    required this.focusLabel,
    required this.onTap,
  });
  final String focusLabel;
  final PathNode node;
  final double offset;
  final double? nextOffset;
  final bool focus;
  final VoidCallback onTap;

  static const size = 70.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    const top = 34.0; // room for the start bubble
    final labelBlock = 52 * scale;
    final nodeBlock = top + size + 8 + labelBlock;
    final rowHeight = nextOffset == null ? nodeBlock + 8 : nodeBlock + 40;
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxWidth / 2;
        final cx = half + offset * (half - size);
        final nx = nextOffset == null
            ? null
            : half + nextOffset! * (half - size);
        return SizedBox(
          height: rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (nx != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConnectorPainter(
                      from: Offset(cx, top + size + 8 + labelBlock),
                      to: Offset(nx, rowHeight + top - 4),
                      color: palette.line,
                    ),
                  ),
                ),
              Positioned(
                left: (cx - 70).clamp(0, constraints.maxWidth - 140),
                width: 140,
                top: top,
                child: _Node(
                  node: node,
                  focus: focus,
                  focusLabel: focusLabel,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({
    required this.from,
    required this.to,
    required this.color,
  });
  final Offset from, to;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, from.dy + 20, to.dx, to.dy - 20, to.dx, to.dy);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Dotted trail.
    for (final metric in path.computeMetrics()) {
      for (var d = 6.0; d < metric.length - 4; d += 14) {
        final p = metric.getTangentForOffset(d)!.position;
        canvas.drawCircle(p, 3.5, paint..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.from != from || old.to != to || old.color != color;
}

class _Node extends StatefulWidget {
  const _Node({
    required this.node,
    required this.focus,
    required this.focusLabel,
    required this.onTap,
  });
  final PathNode node;
  final bool focus;
  final String focusLabel;
  final VoidCallback onTap;
  @override
  State<_Node> createState() => _NodeState();
}

class _NodeState extends State<_Node> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final n = widget.node;
    final (fill, shadow, ink, icon) = !n.measurable
        ? (
            scheme.surfaceContainerHigh,
            palette.line,
            palette.muted,
            Icons.hourglass_empty_rounded,
          )
        : n.mastered
        ? (
            palette.sun,
            Color.lerp(palette.sun, Colors.black, .22)!,
            palette.onSun,
            n.state == MasteryState.retained
                ? Icons.workspace_premium_rounded
                : Icons.check_rounded,
          )
        : widget.focus ||
              n.state == MasteryState.practicing ||
              n.state == MasteryState.supported
        ? (
            scheme.primary,
            palette.primaryDeep,
            scheme.onPrimary,
            Icons.play_arrow_rounded,
          )
        : (
            scheme.surfaceContainerLowest,
            palette.line,
            scheme.primary,
            Icons.music_note_rounded,
          );
    final depth = _down ? 0.0 : 5.0;
    return Semantics(
      button: true,
      label:
          '${n.node.title}. ${nodeStateText(n)}${widget.focus ? '. Bugünkü öneri' : ''}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (widget.focus)
                  Container(
                    width: _NodeRow.size + 16,
                    height: _NodeRow.size + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: .25),
                        width: 6,
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 70),
                  margin: EdgeInsets.only(top: 5 - depth),
                  width: _NodeRow.size,
                  height: _NodeRow.size - 4,
                  decoration: BoxDecoration(
                    color: fill,
                    shape: BoxShape.circle,
                    border: fill == scheme.surfaceContainerLowest
                        ? Border.all(color: palette.line, width: 3)
                        : null,
                    boxShadow: depth == 0
                        ? null
                        : [BoxShadow(color: shadow, offset: Offset(0, depth))],
                  ),
                  child: Icon(icon, color: ink, size: 34),
                ),
                if (widget.focus)
                  Positioned(
                    top: -30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.line, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          widget.focusLabel,
                          style: text.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              n.node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.labelLarge,
            ),
            if (!n.measurable || n.state != MasteryState.notMeasured)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: n.mastered
                    ? StatusPill(nodeStateText(n), tone: PillTone.warning)
                    : Text(
                        nodeStateText(n),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: palette.muted),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
