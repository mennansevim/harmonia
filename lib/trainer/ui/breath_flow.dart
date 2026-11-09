import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widget_previews.dart';

import '../koro/particle_flow.dart' show flowColor;
import 'audio_reactive_orb.dart' show emaStep;
import 'kit.dart';

/// What the breath is doing in one step of a guide.
enum BreathKind { inhale, hold, exhale }

typedef BreathStep = ({BreathKind kind, double seconds});

/// Where a looping guide of [steps] is [t] seconds in: the step, how far
/// through it (0–1), and how full the breath is drawn (0 empty, 1 full).
/// Breathing in and out follow a sine ease, so the turn at either end is
/// soft; a hold keeps whatever the step before it reached.
({int index, double progress, double fullness}) breathAt(
  List<BreathStep> steps,
  double t,
) {
  final cycle = steps.fold(0.0, (s, p) => s + p.seconds);
  if (cycle <= 0) return (index: 0, progress: 0, fullness: 0);
  var at = t <= 0 ? 0.0 : t % cycle;
  for (var i = 0; i < steps.length; i++) {
    final len = steps[i].seconds;
    if (at < len || i == steps.length - 1) {
      final p = len <= 0 ? 1.0 : (at / len).clamp(0.0, 1.0);
      final e = 0.5 - 0.5 * math.cos(math.pi * p);
      final full = switch (steps[i].kind) {
        BreathKind.inhale => e,
        BreathKind.exhale => 1 - e,
        BreathKind.hold => _heldFullness(steps, i),
      };
      return (index: i, progress: p, fullness: full);
    }
    at -= len;
  }
  return (index: 0, progress: 0, fullness: 0);
}

double _heldFullness(List<BreathStep> steps, int i) {
  for (var k = 1; k <= steps.length; k++) {
    final prev = steps[(i - k + steps.length) % steps.length].kind;
    if (prev == BreathKind.inhale) return 1;
    if (prev == BreathKind.exhale) return 0;
  }
  return 1;
}

/// The breath guide as rings of light dots, in the spirit of the voice
/// orb's travelling rings and a watch face's dotted dial. Breathing in, the
/// rings open and drift inward, gathering at the centre; holding, they
/// settle and shimmer with a small, natural tremor; breathing out, they
/// close and stream outward, fading as they leave. An outer dial of dots
/// lights up with time through the current step. Purple while drawing in,
/// a soft green while letting go, and the colour always blends, never
/// snaps.
///
/// A guide only: it follows the clock in [elapsedMs], never a microphone,
/// and measures nothing. With reduced motion the rings stand still and
/// only open and close; paused, they slow to a stop and hold still.
class BreathFlow extends StatefulWidget {
  const BreathFlow({
    super.key,
    required this.steps,
    required this.elapsedMs,
    this.running = true,
    this.done = false,
    this.size = 220,
    this.child,
  });
  final List<BreathStep> steps;

  /// The guide's own clock; the rings move smoothly between its ticks.
  final int elapsedMs;
  final bool running;
  final bool done;
  final double size;

  /// Shown in the middle of the rings (the count and the step's verb).
  final Widget? child;

  @override
  State<BreathFlow> createState() => _BreathFlowState();
}

class _BreathFlowState extends State<BreathFlow>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _model = _BreathModel();
  Duration? _last;
  double _clock = 0;

  @override
  void initState() {
    super.initState();
    _clock = widget.elapsedMs / 1000;
    final at = widget.done
        ? (index: 0, progress: 1.0, fullness: _restFullness)
        : breathAt(widget.steps, _clock);
    _model
      ..fullness = at.fullness
      ..progress = at.progress
      ..tone = widget.done ? 1 : _toneOf(widget.steps[at.index].kind)
      ..motion = widget.running && !widget.done ? 1 : 0;
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model.reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(BreathFlow old) {
    super.didUpdateWidget(old);
    if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _model.dispose();
    super.dispose();
  }

  static const _restFullness = 0.3;

  static double _toneOf(BreathKind k) => switch (k) {
    BreathKind.inhale => 0,
    BreathKind.hold => 0.45,
    BreathKind.exhale => 1,
  };

  /// Ring travel per second: inward breathing in, outward breathing out,
  /// almost still while holding.
  static double _flowOf(BreathKind? k) => switch (k) {
    BreathKind.inhale => -0.32,
    BreathKind.hold => 0.03,
    BreathKind.exhale => 0.26,
    null => 0,
  };

  void _tick(Duration now) {
    final dt = _last == null
        ? 1 / 60
        : ((now - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final m = _model..t += dt;
    // Run a little ahead of the guide's coarse ticks, never far from it.
    final target = widget.elapsedMs / 1000;
    final live = widget.running && !widget.done;
    if (live) {
      _clock += dt;
      _clock = (_clock - target).abs() > 0.3
          ? target
          : _clock.clamp(target, target + 0.12);
    } else {
      _clock = target;
    }
    final BreathKind? kind;
    if (widget.done) {
      kind = null;
      m.fullness = emaStep(m.fullness, _restFullness, dt, release: 0.7);
      m.progress = emaStep(m.progress, 1, dt, attack: 0.2);
      m.tone = emaStep(m.tone, 1, dt, attack: 0.5);
    } else {
      final at = breathAt(widget.steps, _clock);
      kind = widget.steps[at.index].kind;
      m.fullness = emaStep(
        m.fullness,
        at.fullness,
        dt,
        attack: 0.06,
        release: 0.06,
      );
      // A new step starts its dial from zero without sweeping back.
      m.progress = at.progress;
      m.tone = emaStep(m.tone, _toneOf(kind), dt, attack: 0.7, release: 0.7);
    }
    final holding = kind == BreathKind.hold && widget.running;
    m.holding = emaStep(m.holding, holding ? 1 : 0, dt, attack: 0.3);
    // Paused or finished, the rings glide to a stop instead of freezing.
    m.motion = emaStep(m.motion, live ? 1 : 0, dt, attack: 0.3, release: 0.35);
    m.flow = emaStep(
      m.flow,
      _flowOf(live ? kind : null),
      dt,
      attack: 0.45,
      release: 0.45,
    );
    m.step(dt);
    // Nothing left to move: rest until the guide changes.
    if (!live && m.settled) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('breath_flow'),
    width: widget.size,
    height: widget.size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _BreathPainter(_model)),
          ),
        ),
        ?widget.child,
      ],
    ),
  );
}

class _BreathModel extends ChangeNotifier {
  bool reduced = false;
  double t = 0, fullness = 0, progress = 0, tone = 0, holding = 0;

  /// 1 while the guide runs, easing to 0 when paused or done.
  double motion = 0;

  /// Signed ring travel speed (share of the span per second).
  double flow = 0;

  /// Where the rings are along their path, 0–1, and the dots' slow turn.
  double travel = 0, turn = 0;

  /// Outer reach of the rings as a share of the half size.
  static double reach(double fullness) => 0.6 + 0.24 * fullness;

  /// Inner edge, kept clear so the count stays legible.
  static const inner = 0.42;

  bool get settled => motion < 0.01 && holding < 0.01 && flow.abs() < 0.002;

  void step(double dt) {
    if (!reduced) {
      travel = (travel + flow * dt) % 1;
      turn += dt * 0.12 * motion;
    }
    notifyListeners();
  }
}

class _BreathPainter extends CustomPainter {
  _BreathPainter(this.m) : super(repaint: m);
  final _BreathModel m;

  static const _rings = 4;
  static const _ringDots = 44;
  static const _dialDots = 60;
  static final _dot = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final color = flowColor(m.tone);
    final scale = half / 110;

    // A soft glow that swells with the breath.
    final glowR = half * (_BreathModel.reach(m.fullness) + 0.08);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          glowR,
          [
            color.withValues(alpha: 0.05 + 0.1 * m.fullness),
            color.withValues(alpha: 0.12 + 0.12 * m.fullness),
            color.withValues(alpha: 0),
          ],
          [0, 0.7, 1],
        ),
    );
    // The middle stays light so the count reads clearly.
    final innerR = half * _BreathModel.inner;
    canvas.drawCircle(
      c,
      innerR,
      Paint()
        ..shader = ui.Gradient.radial(c, innerR, [
          TC.card,
          Color.lerp(TC.card, color, 0.14)!,
        ]),
    );

    _dial(canvas, c, half, color, scale);
    _breathRings(canvas, c, half, color, scale);
  }

  /// The dotted dial: time through the current step, like a watch face.
  void _dial(Canvas canvas, Offset c, double half, Color color, double s) {
    final r = half - 4 * s;
    final lit = m.progress.clamp(0.0, 1.0) * _dialDots;
    for (var i = 0; i < _dialDots; i++) {
      final th = -math.pi / 2 + 2 * math.pi * i / _dialDots;
      final on = (lit - i).clamp(0.0, 1.0);
      // The leading dot is the brightest; lit ones stay full.
      final head = on > 0 && lit - i < 1.6 ? 1.0 : 0.0;
      final major = i % 5 == 0;
      final base = (major ? 1.5 : 1.1) * s;
      final radius = base + (0.7 + 0.6 * head) * s * on;
      _dot.color = Color.lerp(
        TC.line,
        color,
        on,
      )!.withValues(alpha: 0.55 + 0.45 * on);
      canvas.drawCircle(
        Offset(c.dx + r * math.cos(th), c.dy + r * math.sin(th)),
        radius,
        _dot,
      );
    }
  }

  /// Rings of dots travelling between the clear middle and the breath's
  /// reach: born faint at one end, brightest in the middle of their path,
  /// fading at the other end, so the motion never pops.
  void _breathRings(
    Canvas canvas,
    Offset c,
    double half,
    Color color,
    double s,
  ) {
    final from = half * (_BreathModel.inner + 0.06);
    final to = half * _BreathModel.reach(m.fullness);
    // Holding: a small, natural tremor on the rings, nothing more.
    final tremor = m.reduced
        ? 0.0
        : m.holding *
              (0.7 * math.sin(m.t * 2 * math.pi * 4.6) +
                  0.4 * math.sin(m.t * 2 * math.pi * 1.3 + 0.8));
    final light = Color.lerp(color, Colors.white, 0.35)!;
    for (var k = 0; k < _rings; k++) {
      final u = m.reduced ? (k + 0.5) / _rings : (m.travel + k / _rings) % 1;
      final r = from + (to - from) * u + tremor;
      final fade = math.sin(math.pi * u);
      final ringAlpha = fade * (0.35 + 0.65 * (0.4 + 0.6 * m.fullness));
      if (ringAlpha < 0.02) continue;
      // Alternate rings turn the other way, a slow drift, never a whirl.
      final dir = k.isEven ? 1.0 : -1.0;
      final offset = dir * m.turn + k * math.pi / _ringDots;
      for (var i = 0; i < _ringDots; i++) {
        final th = offset + 2 * math.pi * i / _ringDots;
        // A gentle wave of size around the ring keeps it alive.
        final wave = m.reduced
            ? 0.5
            : 0.5 + 0.5 * math.sin(3 * th - m.t * 1.6 * m.motion + k * 1.3);
        final radius = s * (0.9 + 0.9 * u + 0.6 * wave);
        _dot.color = Color.lerp(
          color,
          light,
          wave * 0.5,
        )!.withValues(alpha: (ringAlpha * (0.55 + 0.45 * wave)).clamp(0, 1));
        canvas.drawCircle(
          Offset(c.dx + r * math.cos(th), c.dy + r * math.sin(th)),
          radius,
          _dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BreathPainter old) => old.m != m;
}

/// Drives a [BreathFlow] from its own clock for previews (in 4 · hold 2 ·
/// out 6), as the breathing screen does.
class _BreathFlowPreview extends StatefulWidget {
  const _BreathFlowPreview();
  @override
  State<_BreathFlowPreview> createState() => _BreathFlowPreviewState();
}

class _BreathFlowPreviewState extends State<_BreathFlowPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (e) => setState(() => _ms = e.inMilliseconds ~/ 100 * 100),
  );
  int _ms = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: TC.canvas,
    child: Center(
      child: BreathFlow(
        steps: const [
          (kind: BreathKind.inhale, seconds: 4),
          (kind: BreathKind.hold, seconds: 2),
          (kind: BreathKind.exhale, seconds: 6),
        ],
        elapsedMs: _ms,
      ),
    ),
  );
}

@Preview(name: 'Nefes akışı · al 4 · tut 2 · ver 6', size: Size(390, 320))
Widget breathFlowPreview() => const _BreathFlowPreview();
