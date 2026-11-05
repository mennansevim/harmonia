import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/music.dart';
import '../ui/kit.dart';
import 'range_ladder.dart';

/// What a note's last judged attempt left on the chain.
enum ChainMark { matched, missed, octave }

/// Where the ladder is: the colour and the timer ring of the target follow it.
enum ChainPhase { piano, listening, feedback, turn }

/// The standing mark per note from a ladder's log: a match stays once
/// reached; otherwise the latest miss or octave error shows.
Map<int, ChainMark> chainMarks(Iterable<RangeAttempt> log) {
  final marks = <int, ChainMark>{};
  for (final a in log) {
    final m = a.targetMidi;
    if (marks[m] == ChainMark.matched) continue;
    marks[m] = switch (a.judgement.match) {
      RangeMatch.matched => ChainMark.matched,
      RangeMatch.octaveOff => ChainMark.octave,
      _ => ChainMark.missed,
    };
  }
  return marks;
}

/// The ladder as a string of circles: reached notes breathe in a wave,
/// light pulses run from the start note towards the target, and the ring
/// round the target times the current step. Display only.
class PulseChain extends StatefulWidget {
  const PulseChain({
    super.key,
    required this.low,
    required this.high,
    required this.start,
    required this.marks,
    required this.attempts,
    required this.notation,
    this.target,
    this.up = true,
    this.phase = ChainPhase.piano,
    this.result,
    this.listenFor = const Duration(seconds: 3),
    this.height = 92,
  });

  /// Notes shown; the view eases when they change.
  final int low, high;
  final int start;
  final Map<int, ChainMark> marks;

  /// Judged attempts so far; a new one sets off its ripple.
  final int attempts;
  final NoteNotation notation;
  final int? target;
  final bool up;
  final ChainPhase phase;

  /// The judgement shown during [ChainPhase.feedback].
  final ChainMark? result;
  final Duration listenFor;
  final double height;

  @override
  State<PulseChain> createState() => _PulseChainState();
}

class _Spring {
  double? x;
  double v = 0;
  double to(double target, double dt, {double k = 150, double d = 18}) {
    final cur = x;
    if (cur == null) return x = target;
    var p = cur;
    final n = math.max(1, (dt / 0.008).ceil());
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      v += (k * (target - p) - d * v) * h;
      p += v * h;
    }
    return x = p;
  }
}

class _Fx {
  _Fx.ring(this.x, this.y, this.color, this.r1, this.life)
    : ring = true,
      vx = 0,
      vy = 0,
      r = 0;
  _Fx.spark(this.x, this.y, this.color, this.vx, this.vy, this.r, this.life)
    : ring = false,
      r1 = 0;
  final bool ring;
  double x, y, vx, vy;
  final double r, r1, life;
  final Color color;
  double t = 0;
}

class _ChainModel extends ChangeNotifier {
  double t = 0, phaseT = 0, dt = 0;
  bool reduced = false;
  final lo = _Spring(), hi = _Spring(), spanLo = _Spring(), spanHi = _Spring();
  final target = _Spring();
  final fx = <_Fx>[];
  final rnd = math.Random(7);

  void tick(double step) {
    dt = step;
    t += step;
    phaseT += step;
    for (final f in fx) {
      f.t += step;
    }
    fx.removeWhere((f) => f.t > f.life);
    notifyListeners();
  }

  void burst(double x, double y, Color c, {required bool matched}) {
    if (matched) {
      fx.add(_Fx.ring(x, y, TC.limeShadow, 36, 0.75));
      fx.add(_Fx.ring(x, y, TC.sun, 22, 0.5));
      for (var i = 0; i < 16; i++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final s = 75 * (0.45 + rnd.nextDouble());
        fx.add(
          _Fx.spark(
            x,
            y,
            TC.limeShadow,
            math.cos(a) * s,
            math.sin(a) * s,
            1 + rnd.nextDouble() * 1.8,
            0.6 + rnd.nextDouble() * 0.45,
          ),
        );
      }
    } else {
      fx.add(_Fx.ring(x, y, c, 22, 0.6));
    }
  }
}

class _PulseChainState extends State<PulseChain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_tick);
  final _model = _ChainModel();
  Duration? _last;
  int? _pendingFx;
  final _labels = <(int, bool), TextPainter>{};
  NoteNotation? _labelNotation;
  TextStyle? _labelBase;

  @override
  void initState() {
    super.initState();
    _clock.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model.reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(PulseChain old) {
    super.didUpdateWidget(old);
    if (widget.phase != old.phase || widget.target != old.target) {
      _model.phaseT = 0;
    }
    if (widget.attempts > old.attempts) _pendingFx = widget.attempts;
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_tick)
      ..dispose();
    _model.dispose();
    super.dispose();
  }

  void _tick() {
    final now = _clock.lastElapsedDuration;
    if (now == null) return;
    final dt = _last == null
        ? 1 / 60
        : ((now - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    _model.tick(dt);
  }

  TextPainter _label(int midi, bool strong, TextStyle base) {
    if (_labelNotation != widget.notation || _labelBase != base) {
      _labels.clear();
      _labelNotation = widget.notation;
      _labelBase = base;
    }
    return _labels.putIfAbsent(
      (midi, strong),
      () => TextPainter(
        text: TextSpan(
          text: PitchClass.midiName(midi, widget.notation),
          style: base.merge(
            TT.small.copyWith(
              fontSize: strong ? 12.5 : 10,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              color: strong ? TC.ink : TC.faint,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final fxFor = _pendingFx;
    _pendingFx = null;
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('pulse_chain'),
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ChainPainter(
              _model,
              widget,
              (m, strong) => _label(m, strong, base),
              fxFor != null,
            ),
          ),
        ),
      ),
    );
  }
}

bool _black(int midi) => const {1, 3, 6, 8, 10}.contains(midi % 12);

Color _markColor(ChainMark m) => switch (m) {
  ChainMark.matched => TC.limeShadow,
  ChainMark.octave => TC.amber,
  ChainMark.missed => TC.coral,
};

class _ChainPainter extends CustomPainter {
  _ChainPainter(this.m, this.w, this.label, this.newResult) : super(repaint: m);
  final _ChainModel m;
  final PulseChain w;
  final TextPainter Function(int, bool) label;

  /// A judged attempt arrived with this build: its ripple starts once.
  bool newResult;

  static const _pad = 18.0;

  Color get _phaseColor => switch (w.phase) {
    ChainPhase.piano => TC.primaryFill,
    ChainPhase.listening => TC.coral,
    ChainPhase.feedback => _markColor(w.result ?? ChainMark.missed),
    ChainPhase.turn => TC.ink,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final dt = m.dt, motion = !m.reduced;
    final width = size.width, y = size.height * 0.48;
    final lo = m.lo.to(w.low.toDouble(), dt, k: 90, d: 16);
    final hi = m.hi.to(w.high.toDouble(), dt, k: 90, d: 16);
    double x(num midi) =>
        _pad + (midi - lo) / math.max(1, hi - lo) * (width - 2 * _pad);

    canvas.drawLine(
      Offset(_pad - 6, y),
      Offset(width - _pad + 6, y),
      Paint()
        ..color = TC.line
        ..strokeWidth = 2,
    );

    // The found range as a lime band that stretches with each new note.
    final reached = [
      for (final e in w.marks.entries)
        if (e.value == ChainMark.matched) e.key,
    ];
    if (reached.isNotEmpty) {
      final a = m.spanLo.to(reached.reduce(math.min).toDouble(), dt);
      final b = m.spanHi.to(reached.reduce(math.max).toDouble(), dt);
      canvas.drawLine(
        Offset(x(a), y),
        Offset(x(b), y),
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(Offset(x(a), y), Offset(x(b), y), [
            TC.limeShadow,
            TC.sun,
          ]),
      );
    }

    final target = w.target;
    final tx = target == null ? null : m.target.to(x(target), dt);

    // Light pulses from the start note towards the target: the direction.
    if (tx != null && motion) {
      final sx = x(w.start);
      for (var i = 0; i < 3; i++) {
        final k = (m.t * 0.7 + i / 3) % 1;
        canvas.drawCircle(
          Offset(sx + (tx - sx) * k, y),
          3.2,
          Paint()
            ..color = _phaseColor.withValues(
              alpha: math.sin(k * math.pi) * 0.9,
            ),
        );
      }
    }

    for (var n = w.low; n <= w.high; n++) {
      final cx = x(n), mark = w.marks[n];
      if (mark == ChainMark.matched) {
        if (motion) {
          final k = ((m.t * 0.8 - (n - w.low) * 0.08) % 1 + 1) % 1;
          canvas.drawCircle(
            Offset(cx, y),
            7 + 9 * Curves.easeOutCubic.transform(k),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = TC.limeShadow.withValues(alpha: (1 - k) * 0.5),
          );
        }
        canvas.drawCircle(
          Offset(cx, y),
          7.5,
          Paint()
            ..color = TC.limeShadow.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(Offset(cx, y), 6.5, Paint()..color = TC.sun);
        canvas.drawCircle(
          Offset(cx, y),
          6.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = TC.ink,
        );
      } else {
        final r = _black(n) ? 2.6 : 3.6;
        canvas.drawCircle(Offset(cx, y), r, Paint()..color = TC.card);
        canvas.drawCircle(
          Offset(cx, y),
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = TC.ink.withValues(alpha: 0.25),
        );
      }
      if (mark != null && mark != ChainMark.matched) {
        canvas.drawCircle(
          Offset(cx, y + 16),
          2.8,
          Paint()..color = _markColor(mark),
        );
      }
      if (n % 12 == 0 || n == w.start) {
        final p = label(n, false);
        p.paint(canvas, Offset(cx - p.width / 2, y + 23));
      }
    }

    if (target != null && tx != null) {
      final col = _phaseColor;
      canvas.drawCircle(Offset(tx, y), 10, Paint()..color = TC.card);
      canvas.drawCircle(
        Offset(tx, y),
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = col,
      );
      // The ring times the step: it turns while the piano plays and fills
      // over the take while the singer sings.
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = col;
      final ring = Rect.fromCircle(center: Offset(tx, y), radius: 15);
      switch (w.phase) {
        case ChainPhase.piano:
          canvas.drawArc(ring, m.t * 5, math.pi * 0.6, false, arc);
        case ChainPhase.listening:
          final k = (m.phaseT * 1e6 / w.listenFor.inMicroseconds).clamp(
            0.0,
            1.0,
          );
          canvas.drawArc(ring, -math.pi / 2, math.pi * 2 * k, false, arc);
        case ChainPhase.feedback:
          canvas.drawArc(ring, -math.pi / 2, math.pi * 2, false, arc);
        case ChainPhase.turn:
          break;
      }
      final p = label(target, true);
      final ly = y - 30 - p.height / 2;
      p.paint(canvas, Offset(tx - p.width / 2, ly));
      // A chevron beside the name points the way the ladder is going.
      final cx = tx + (w.up ? 1 : -1) * (p.width / 2 + 10), cy = y - 30;
      final s = w.up ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(cx - 3.5 * s, cy - 4.2)
          ..lineTo(cx + 2.8 * s, cy)
          ..lineTo(cx - 3.5 * s, cy + 4.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = col,
      );
      if (newResult) {
        newResult = false;
        final r = w.result;
        if (r != null && !m.reduced) {
          m.burst(tx, y, _markColor(r), matched: r == ChainMark.matched);
        }
      }
    }

    for (final f in m.fx) {
      final k = f.t / f.life;
      if (f.ring) {
        canvas.drawCircle(
          Offset(f.x, f.y),
          4 + (f.r1 - 4) * Curves.easeOutCubic.transform(k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * (1 - k) + 0.4
            ..color = f.color.withValues(alpha: (1 - k) * 0.85),
        );
      } else {
        final damp = math.pow(0.08, dt).toDouble();
        f.vx *= damp;
        f.vy = f.vy * damp + 40 * dt;
        f.x += f.vx * dt;
        f.y += f.vy * dt;
        canvas.drawCircle(
          Offset(f.x, f.y),
          f.r * (1 - k * 0.6),
          Paint()..color = f.color.withValues(alpha: 1 - k),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChainPainter old) => true;
}
