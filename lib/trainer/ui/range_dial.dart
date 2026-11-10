import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/music.dart';
import 'kit.dart';

/// Circular vocal-range dial: a 270° gauge of semitone ticks (C labels on
/// the rim), the measured span as a thick arc with a fan wedge behind it and
/// the two end notes named outside the ring. [center] sits inside the dial.
/// Purely a picture of the stored measurement; it adds no judgement.
class RangeDial extends StatelessWidget {
  const RangeDial({
    super.key,
    required this.low,
    required this.high,
    required this.notation,
    this.center,
    this.size = 240,
    this.dark = false,
  });

  final int low;
  final int high;
  final NoteNotation notation;
  final Widget? center;
  final double size;

  /// Colours for a dark (hero) background.
  final bool dark;

  /// Default span C2–C6, widened to whole octaves when the range leaves it.
  int get min => math.min(36, low - low % 12);
  int get max => math.max(84, high % 12 == 0 ? high : high + 12 - high % 12);

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, c) => _dial(math.min(size, c.maxWidth)));

  Widget _dial(double size) => SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(
              painter: RangeDialPainter(
                low: low,
                high: high,
                min: min,
                max: max,
                name: (m) => PitchClass.midiName(m, notation),
                dark: dark,
              ),
            ),
          ),
        ),
        if (center != null)
          SizedBox(
            width: size * 0.5,
            child: FittedBox(fit: BoxFit.scaleDown, child: center),
          ),
      ],
    ),
  );
}

class RangeDialPainter extends CustomPainter {
  RangeDialPainter({
    required this.low,
    required this.high,
    required this.min,
    required this.max,
    required this.name,
    required this.dark,
  });

  final int low, high, min, max;
  final String Function(int midi) name;
  final bool dark;

  static const _start = math.pi * 0.75; // bottom-left
  static const _sweep = math.pi * 1.5; // 270°, open at the bottom

  double _angle(num m) =>
      _start + _sweep * ((m - min) / (max - min)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.shortestSide;
    final ring = s * 0.045; // track thickness
    final r = s / 2 - s * 0.19; // track radius, room for labels outside
    final track = dark ? TC.heroTrack : TC.coralSoft;
    final tick = dark ? Colors.white38 : TC.faint;
    final label = dark ? TC.heroMuted : TC.muted;
    final accent = dark ? TC.sun : TC.coral;
    final fan = dark ? Colors.white : TC.primary;
    Offset at(double a, double rad) =>
        c + Offset(math.cos(a), math.sin(a)) * rad;

    // Fan wedge behind the measured span, one spoke per semitone.
    final a0 = _angle(low), a1 = _angle(high);
    final inner = r * 0.62, outer = r - ring / 2;
    final wedge = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: outer), a0, a1 - a0, true)
      ..arcTo(Rect.fromCircle(center: c, radius: inner), a1, a0 - a1, false)
      ..close();
    canvas.drawPath(
      wedge,
      Paint()..color = fan.withValues(alpha: dark ? 0.14 : 0.22),
    );
    final spoke = Paint()
      ..color = fan.withValues(alpha: dark ? 0.32 : 0.45)
      ..strokeWidth = 1;
    for (var m = low; m <= high; m++) {
      canvas.drawLine(at(_angle(m), inner), at(_angle(m), outer), spoke);
    }

    // Track and the measured arc on it.
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      rect,
      a0,
      math.max(a1 - a0, 0.02),
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring * 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Semitone ticks just outside the ring; C gets a longer tick and a name
    // unless an end-note label would sit on top of it.
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 1;
    final tickBase = r + ring * 0.9;
    for (var m = min; m <= max; m++) {
      final isC = m % 12 == 0;
      final a = _angle(m);
      canvas.drawLine(
        at(a, tickBase),
        at(a, tickBase + (isC ? s * 0.04 : s * 0.018)),
        tickPaint,
      );
      if (isC && (m - low).abs() > 3 && (m - high).abs() > 3) {
        _text(
          canvas,
          name(m),
          at(a, tickBase + s * 0.05),
          a,
          TextStyle(color: label, fontSize: s * 0.04),
        );
      }
    }

    // End notes: a dot on the arc and the bold name outside.
    for (final (m, a) in [(low, a0), (high, a1)]) {
      canvas.drawCircle(
        at(a, r),
        ring * 0.55,
        Paint()..color = dark ? TC.hero : Colors.white,
      );
      _text(
        canvas,
        name(m),
        at(a, tickBase + s * 0.05),
        a,
        TextStyle(
          color: dark ? Colors.white : TC.coralDeep,
          fontSize: s * 0.048,
          fontWeight: FontWeight.w800,
        ),
      );
    }
  }

  /// Draws [text] just outside [anchor] along angle [a]: the label's
  /// nearest edge, not its centre, sits on the anchor so it never covers
  /// the ring however wide the note name is.
  void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    double a,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final out = Offset(math.cos(a) * tp.width / 2, math.sin(a) * tp.height / 2);
    tp.paint(canvas, anchor + out - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(RangeDialPainter old) =>
      old.low != low ||
      old.high != high ||
      old.min != min ||
      old.max != max ||
      old.dark != dark ||
      old.name != name;
}
