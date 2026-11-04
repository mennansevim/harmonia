import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/music.dart';
import '../ui/kit.dart';

/// Live trace points per take: one every ~20 ms, so 150 fill a 3 s take.
const rangeTracePoints = 150;

/// A piano keyboard over [low]..[high]: reached keys lit with a soft light
/// column, the [target] key outlined, and the live pitch as a dot above.
class KeyboardMap extends StatelessWidget {
  const KeyboardMap({
    super.key,
    required this.low,
    required this.high,
    required this.reached,
    required this.notation,
    this.target,
    this.live,
    this.press = 0,
    this.bracket = false,
  });
  final int low, high;
  final Set<int> reached;
  final NoteNotation notation;
  final int? target;
  final double? live;

  /// Result view: a bracket with the lowest and highest reached note
  /// instead of light columns.
  final bool bracket;

  /// 0–1 after a matched take: the newest reached key springs.
  final double press;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 112,
      width: double.infinity,
      child: CustomPaint(
        painter: _KeysPainter(
          base: DefaultTextStyle.of(context).style,
          bracket: bracket,
          low: low,
          high: high,
          reached: reached,
          notation: notation,
          target: target,
          live: live,
          press: press,
        ),
      ),
    ),
  );
}

bool _black(int midi) => const {1, 3, 6, 8, 10}.contains(midi % 12);

class _KeysPainter extends CustomPainter {
  _KeysPainter({
    required this.base,
    required this.bracket,
    required this.low,
    required this.high,
    required this.reached,
    required this.notation,
    required this.target,
    required this.live,
    required this.press,
  });
  final int low, high;
  final Set<int> reached;
  final NoteNotation notation;
  final int? target;
  final double? live;
  final double press;
  final TextStyle base;
  final bool bracket;

  TextPainter _text(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: base.merge(style)),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final lo = _black(low) ? low - 1 : low;
    final hi = _black(high) ? high + 1 : high;
    final whites = [
      for (var m = lo; m <= hi; m++)
        if (!_black(m)) m,
    ];
    final kw = size.width / whites.length;
    const top = 30.0;
    final kh = size.height - top - 16;
    double centre(int m) {
      final i = whites.indexOf(m);
      if (i >= 0) return kw * (i + 0.5);
      return kw * (whites.indexOf(m - 1) + 1);
    }

    double x(double m) {
      final a = m.floor().clamp(lo, hi), b = m.ceil().clamp(lo, hi);
      return centre(a) + (centre(b) - centre(a)) * (m - m.floor());
    }

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = TC.line;
    if (bracket && reached.isNotEmpty) {
      final a = reached.reduce(math.min), b = reached.reduce(math.max);
      final xa = centre(a), xb = centre(b);
      final pen = Paint()
        ..color = TC.koro
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(xa, top - 8), Offset(xb, top - 8), pen);
      canvas.drawLine(Offset(xa, top - 14), Offset(xa, top - 2), pen);
      canvas.drawLine(Offset(xb, top - 14), Offset(xb, top - 2), pen);
      final style = TT.small.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: TC.koro,
      );
      final la = _text(PitchClass.midiName(a, notation), style);
      final lb = _text(PitchClass.midiName(b, notation), style);
      la.paint(
        canvas,
        Offset((xa - la.width / 2).clamp(0, size.width - la.width), 0),
      );
      lb.paint(
        canvas,
        Offset((xb - lb.width / 2).clamp(0, size.width - lb.width), 0),
      );
    }
    // Light columns over reached keys.
    for (final m in bracket ? const <int>{} : reached) {
      if (m < lo || m > hi) continue;
      final cx = centre(m);
      final rect = Rect.fromLTRB(cx - kw * 0.42, 4, cx + kw * 0.42, top);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              TC.koro.withValues(alpha: 0.35),
              TC.koro.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
    for (var i = 0; i < whites.length; i++) {
      final m = whites[i];
      final on = reached.contains(m);
      final r = RRect.fromLTRBAndCorners(
        i * kw + 0.5,
        top,
        (i + 1) * kw - 0.5,
        top + kh,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = on ? TC.sun : TC.card);
      canvas.drawRRect(r, ink);
      if (m % 12 == 0) {
        final p = _text(
          PitchClass.midiName(m, notation),
          TT.small.copyWith(fontSize: 9, color: TC.muted),
        );
        p.paint(canvas, Offset(i * kw + (kw - p.width) / 2, top + kh + 2));
      }
    }
    for (var m = lo; m <= hi; m++) {
      if (!_black(m)) continue;
      final cx = centre(m);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          cx - kw * 0.3,
          top,
          cx + kw * 0.3,
          top + kh * 0.6,
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(3),
        ),
        Paint()..color = reached.contains(m) ? TC.koro : TC.ink,
      );
    }
    final t = target;
    if (t != null && t >= lo && t <= hi) {
      final cx = centre(t);
      final half = _black(t) ? kw * 0.32 : kw * 0.5;
      final bottom = _black(t) ? top + kh * 0.6 : top + kh;
      canvas.drawRRect(
        RRect.fromLTRBR(
          cx - half,
          top - 2,
          cx + half,
          bottom + 2,
          const Radius.circular(4),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 + 2 * press
          ..color = TC.koro,
      );
      canvas.drawPath(
        Path()
          ..moveTo(cx - 6, top - 12)
          ..lineTo(cx + 6, top - 12)
          ..lineTo(cx, top - 5)
          ..close(),
        Paint()..color = TC.koro,
      );
    }
    final l = live;
    if (l != null && l >= lo - 0.5 && l <= hi + 0.5) {
      final ok = t != null && (l - t).abs() < 0.5;
      final c = Offset(x(l.clamp(lo.toDouble(), hi.toDouble())), top - 16);
      canvas.drawCircle(
        c,
        10,
        Paint()
          ..color = (ok ? TC.sun : TC.koro).withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(c, 6, Paint()..color = ok ? TC.limeDeep : TC.koro);
    }
  }

  @override
  bool shouldRepaint(_KeysPainter old) =>
      old.low != low ||
      old.high != high ||
      old.reached.length != reached.length ||
      old.target != target ||
      old.live != live ||
      old.press != press ||
      old.bracket != bracket;
}
