import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/audio/rhythm_imitation.dart';
import '../../domain/lang.dart';

/// One timeline entry placed on both lanes. Missed beats have no tap and
/// extra taps have no reference.
class AlignmentLink {
  const AlignmentLink({
    required this.verdict,
    this.referenceMs,
    this.userMs,
    this.referenceIndex,
    this.offsetMs,
  });
  final BeatVerdict verdict;
  final int? referenceMs, userMs, referenceIndex, offsetMs;
}

/// "Transient alignment" (design 4): the reference clicks on top, the taps
/// below, each matched pair joined by a link whose slant is its offset.
/// Built from the evaluator's own timeline; the first tap is the anchor.
class TransientAlignmentData {
  const TransientAlignmentData._({
    required this.referenceMs,
    required this.links,
    required this.startMs,
    required this.endMs,
    this.largest,
  });
  final List<int> referenceMs;
  final List<AlignmentLink> links;
  final int startMs, endMs;

  /// The early or late beat with the largest offset, if any.
  final AlignmentLink? largest;

  static TransientAlignmentData? fromOutcome(RhythmImitationOutcome o) {
    final ref = o.referenceOnsetsMs, user = o.userOnsetsMs;
    if (!o.isMeasured || ref.length < 2 || user.isEmpty) return null;
    final links = <AlignmentLink>[];
    for (final e in o.timeline) {
      final r = e.referenceIndex, u = e.userIndex;
      if ((r != null && r >= ref.length) || (u != null && u >= user.length)) {
        return null;
      }
      links.add(
        AlignmentLink(
          verdict: e.verdict,
          referenceMs: r == null ? null : ref[r],
          userMs: u == null ? null : user[u],
          referenceIndex: r,
          offsetMs: e.offsetMs,
        ),
      );
    }
    AlignmentLink? largest;
    for (final l in links) {
      if (l.verdict != BeatVerdict.early && l.verdict != BeatVerdict.late) {
        continue;
      }
      if (largest == null || l.offsetMs!.abs() > largest.offsetMs!.abs()) {
        largest = l;
      }
    }
    const pad = RhythmImitationOutcome.matchToleranceMs + 40;
    return TransientAlignmentData._(
      referenceMs: List.unmodifiable(ref),
      links: List.unmodifiable(links),
      startMs: math.min(ref.first, user.first) - pad,
      endMs: math.max(ref.last, user.last) + pad,
      largest: largest,
    );
  }
}

abstract final class AlignmentColors {
  static const stage = Color(0xFF1C1330);
  static const lane = Color(0x0DFFFFFF);
  static const label = Color(0x8AFFFFFF);
  static const reference = Color(0xFFB9A6FF);
  static const onTime = Color(0xFFD9F574);
  static const near = Color(0xFFFFC861);
  static const off = Color(0xFFFF6259);
  static const anchor = Color(0xCCFFFFFF);

  static Color of(BeatVerdict v) => switch (v) {
    BeatVerdict.onTime => onTime,
    BeatVerdict.early || BeatVerdict.late => near,
    BeatVerdict.missed || BeatVerdict.extra => off,
    BeatVerdict.anchor => anchor,
  };
}

class TransientAlignmentView extends StatefulWidget {
  const TransientAlignmentView({
    required this.data,
    this.showSnapToggle = true,
    super.key,
  });
  final TransientAlignmentData data;

  /// The "show it on time" toggle; hidden where the screen wants one action.
  final bool showSnapToggle;
  @override
  State<TransientAlignmentView> createState() => _TransientAlignmentViewState();
}

class _TransientAlignmentViewState extends State<TransientAlignmentView>
    with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _snapped = false;
  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _reveal.value = 1;
    } else if (_reveal.value == 0 && !_reveal.isAnimating) {
      _reveal.forward();
    }
  }

  void _toggleSnap() {
    setState(() => _snapped = !_snapped);
    final target = _snapped ? 1.0 : 0.0;
    if (_still) {
      _snap.value = target;
    } else {
      _snap.animateTo(target, curve: Curves.easeInOutCubic);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _snap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final text = Theme.of(context).textTheme;
    final largest = d.largest;
    final snapped = _snapped;
    return Column(
      key: const Key('rhythm_alignment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: tr(
            'Hizalama: üstte ${d.referenceMs.length} referans tık, altta dokunuşların; her çift bir bağla birleşir.',
            'Alignment: ${d.referenceMs.length} reference clicks above, your taps below; each pair is joined by a link.',
          ),
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 184,
              child: AnimatedBuilder(
                animation: Listenable.merge([_reveal, _snap]),
                builder: (context, _) => CustomPaint(
                  painter: TransientAlignmentPainter(
                    data: d,
                    reveal: _reveal.value,
                    snap: _snap.value,
                    referenceLabel: tr('REFERANS', 'REFERENCE'),
                    tapLabel: tr('DOKUNUŞ', 'TAPS'),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: ResoniaSpacing.xs),
        if (largest != null)
          Text(
            largest.verdict == BeatVerdict.late
                ? tr(
                    'En büyük kayma: ${largest.referenceIndex! + 1}. vuruş, ${largest.offsetMs} ms geç.',
                    'Largest shift: beat ${largest.referenceIndex! + 1}, ${largest.offsetMs} ms late.',
                  )
                : tr(
                    'En büyük kayma: ${largest.referenceIndex! + 1}. vuruş, ${largest.offsetMs!.abs()} ms erken.',
                    'Largest shift: beat ${largest.referenceIndex! + 1}, ${largest.offsetMs!.abs()} ms early.',
                  ),
            key: const Key('rhythm_alignment_largest'),
            style: text.bodyMedium,
          ),
        Text(
          tr(
            'Gölgeli pencere ±${RhythmImitationOutcome.matchToleranceMs} ms eşleşme aralığıdır; ilk dokunuş başlangıç kabul edilir.',
            'The shaded window is the ±${RhythmImitationOutcome.matchToleranceMs} ms matching range; the first tap is taken as the start.',
          ),
          style: text.bodySmall,
        ),
        if (widget.showSnapToggle)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('rhythm_alignment_snap'),
              onPressed: _toggleSnap,
              icon: Icon(
                snapped ? Icons.undo_rounded : Icons.straighten_rounded,
              ),
              label: Text(
                snapped
                    ? tr('Kendi zamanlamamı göster', 'Show my timing')
                    : tr('Tam zamanında hâlini göster', 'Show it on time'),
              ),
            ),
          ),
      ],
    );
  }
}

class TransientAlignmentPainter extends CustomPainter {
  TransientAlignmentPainter({
    required this.data,
    required this.reveal,
    required this.snap,
    required this.referenceLabel,
    required this.tapLabel,
  });
  final TransientAlignmentData data;

  /// 0 → 1 sweep that uncovers both lanes left to right.
  final double reveal;

  /// 0 = taps where they fell, 1 = taps moved onto their reference beat.
  final double snap;
  final String referenceLabel, tapLabel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AlignmentColors.stage);
    const side = 12.0, gap = 40.0, top = 14.0, bottom = 12.0;
    final w = size.width - side * 2;
    final laneH = (size.height - top - bottom - gap) / 2;
    if (w <= 0 || laneH <= 0) return;
    final aTop = top,
        aBot = top + laneH,
        bTop = aBot + gap,
        bBot = bTop + laneH;
    final span = (data.endMs - data.startMs).toDouble();
    double x(num ms) => side + (ms - data.startMs) / span * w;
    final until = data.startMs + reveal * span;

    final lanePaint = Paint()..color = AlignmentColors.lane;
    canvas
      ..drawRRect(
        RRect.fromLTRBR(side, aTop, side + w, aBot, const Radius.circular(8)),
        lanePaint,
      )
      ..drawRRect(
        RRect.fromLTRBR(side, bTop, side + w, bBot, const Radius.circular(8)),
        lanePaint,
      );
    _label(canvas, referenceLabel, Offset(side + 6, aTop + 4));
    _label(canvas, tapLabel, Offset(side + 6, bTop + 4));

    // Matching windows behind every timed reference beat (not the anchor).
    const tol = RhythmImitationOutcome.matchToleranceMs,
        onTime = RhythmImitationOutcome.onTimeToleranceMs;
    for (var i = 1; i < data.referenceMs.length; i++) {
      final r = data.referenceMs[i];
      if (r > until) break;
      canvas
        ..drawRect(
          Rect.fromLTRB(x(r - tol), bTop, x(r + tol), bBot),
          Paint()..color = AlignmentColors.near.withValues(alpha: .08),
        )
        ..drawRect(
          Rect.fromLTRB(
            x(r - onTime) - .5,
            bTop,
            math.max(x(r + onTime), x(r - onTime) + 1.5),
            bBot,
          ),
          Paint()..color = AlignmentColors.onTime.withValues(alpha: .28),
        );
    }

    // Reference clicks as short decaying transients (the synthesized click).
    final midA = (aTop + aBot) / 2, amp = laneH * .38;
    final transient = Paint()..color = AlignmentColors.reference;
    for (final r in data.referenceMs) {
      if (r > until) break;
      final path = Path()..moveTo(x(r), midA);
      for (var k = 0; k <= 12; k++) {
        final t = k * 8;
        final a = amp * math.exp(-t / 28);
        path.lineTo(x(r + t), midA - a);
      }
      for (var k = 12; k >= 0; k--) {
        final t = k * 8;
        path.lineTo(x(r + t), midA + amp * math.exp(-t / 28));
      }
      path.close();
      canvas.drawPath(path, transient);
    }

    final link = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final l in data.links) {
      final color = AlignmentColors.of(l.verdict);
      final r = l.referenceMs, u = l.userMs;
      if (u != null && u <= until) {
        final ux = r == null ? x(u) : x(u + (r - u) * snap);
        if (r != null) {
          final rx = x(r);
          link.color = color;
          canvas.drawPath(
            Path()
              ..moveTo(rx, aBot)
              ..cubicTo(rx, aBot + gap * .55, ux, bTop - gap * .55, ux, bTop),
            link,
          );
          final o = l.offsetMs;
          if (o != null &&
              (l.verdict == BeatVerdict.early ||
                  l.verdict == BeatVerdict.late) &&
              snap < .5) {
            _label(
              canvas,
              '${o > 0 ? '+' : '−'}${o.abs()}',
              Offset((rx + ux) / 2 + 4, aBot + gap / 2 - 6),
              color: color,
            );
          }
        }
        canvas.drawRRect(
          RRect.fromLTRBR(
            ux - 2.5,
            bTop + laneH * .18,
            ux + 2.5,
            bBot - laneH * .18,
            const Radius.circular(3),
          ),
          Paint()..color = color,
        );
        if (l.verdict == BeatVerdict.extra) {
          _label(canvas, '+', Offset(ux + 4, bTop + 2), color: color);
        }
      } else if (u == null && r != null && r <= until) {
        final rx = x(r), my = (bTop + bBot) / 2;
        final cross = Paint()
          ..color = color
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(Offset(rx - 5, my - 5), Offset(rx + 5, my + 5), cross)
          ..drawLine(Offset(rx + 5, my - 5), Offset(rx - 5, my + 5), cross);
      }
    }

    if (reveal < 1) {
      final sx = x(until);
      canvas.drawRect(
        Rect.fromLTWH(sx, aTop - 4, 1.5, bBot - aTop + 8),
        Paint()..color = AlignmentColors.onTime,
      );
    }
  }

  void _label(
    Canvas canvas,
    String s,
    Offset at, {
    Color color = AlignmentColors.label,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(TransientAlignmentPainter old) =>
      old.reveal != reveal ||
      old.snap != snap ||
      !identical(old.data, data) ||
      old.referenceLabel != referenceLabel;
}
