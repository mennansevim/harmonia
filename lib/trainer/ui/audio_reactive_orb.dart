import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'kit.dart';

/// What the orb is showing. [soundDetected] is also entered on its own
/// while [listening] once the smoothed input level crosses a threshold.
enum OrbPhase { idle, listening, soundDetected, completed }

/// Maps an input level (dBFS, ≤ 0) to 0–1 for display. Speech at arm's
/// length sits around −35…−10 dBFS on phones, so that span gets most of
/// the movement. Display only: never a score or a voice claim.
double orbAmplitude(double db) {
  if (db.isNaN) return 0;
  final v = ((db + 55) / 45).clamp(0.0, 1.0);
  return math.pow(v, 1.4).toDouble();
}

/// One exponential-moving-average step that is independent of frame
/// rate: [timeConstant] is how long the value takes to cover ~63% of the
/// way to [target]. Rising and falling use different constants so the orb
/// reacts at once and lets go gently.
double emaStep(
  double current,
  double target,
  double dtSeconds, {
  double attack = 0.06,
  double release = 0.28,
}) {
  final tau = target > current ? attack : release;
  final a = 1 - math.exp(-dtSeconds / tau);
  return current + (target - current) * a;
}

/// A large microphone button with concentric rings that breathe while
/// idle and stream outward while listening, swelling with the live input
/// level. The level comes from the app's capture backend (the `record`
/// plugin's amplitude stream); the orb never opens the microphone itself.
class AudioReactiveOrb extends StatefulWidget {
  const AudioReactiveOrb({
    super.key,
    required this.phase,
    this.levelDb = -60,
    this.size = 220,
    this.rings = 5,
    this.icon,
    this.onTap,
    this.semanticLabel,
    this.detectDb = -38,
  }) : assert(rings >= 4 && rings <= 6);

  final OrbPhase phase;

  /// Latest input level in dBFS; ignored unless listening.
  final double levelDb;

  /// Overall square size including the rings.
  final double size;
  final int rings;

  /// Centre glyph; defaults to a microphone (a tick when completed).
  final IconData? icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Smoothed level above which listening reads as "sound detected".
  final double detectDb;

  @override
  State<AudioReactiveOrb> createState() => _AudioReactiveOrbState();
}

class _AudioReactiveOrbState extends State<AudioReactiveOrb>
    with SingleTickerProviderStateMixin {
  // A 1 s repeating clock; only its elapsed time is used, so the motion
  // integrates smoothly whatever the frame rate.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_tick);
  final _model = _OrbModel();
  Duration? _last;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _model.palette = _OrbPalette.of(widget.phase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncClock();
  }

  @override
  void didUpdateWidget(AudioReactiveOrb old) {
    super.didUpdateWidget(old);
    if (_reduced) _settle();
    _syncClock();
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_tick)
      ..dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _hearing =>
      widget.phase == OrbPhase.listening ||
      widget.phase == OrbPhase.soundDetected;

  /// The phase actually drawn: listening turns into sound detected while
  /// the smoothed level stays loud (with a little hysteresis).
  OrbPhase get _shown {
    if (widget.phase != OrbPhase.listening) return widget.phase;
    final on = orbAmplitude(widget.detectDb);
    final off = orbAmplitude(widget.detectDb - 6);
    _model.detected = _model.amp > (_model.detected ? off : on);
    return _model.detected ? OrbPhase.soundDetected : OrbPhase.listening;
  }

  void _syncClock() {
    if (_reduced) {
      _clock.stop();
      _last = null;
      _settle();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  /// Reduced motion: jump straight to the target look, no travelling rings.
  void _settle() {
    _model
      ..amp = _hearing ? orbAmplitude(widget.levelDb) : 0
      ..breath = 0.5
      ..travel = 0.35
      ..palette = _OrbPalette.of(_shown)
      ..notify();
  }

  void _tick() {
    final now = _clock.lastElapsedDuration;
    if (now == null) return;
    final dt = _last == null
        ? 1 / 60
        : ((now - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final target = _hearing ? orbAmplitude(widget.levelDb) : 0.0;
    final m = _model;
    m.amp = emaStep(m.amp, target, dt);
    final shown = _shown;
    // Rings stream outward faster the louder it gets; while idle they
    // drift slowly so the button still feels alive.
    final speed = switch (shown) {
      OrbPhase.idle => 0.18,
      OrbPhase.listening => 0.42 + 0.5 * m.amp,
      OrbPhase.soundDetected => 0.55 + 0.75 * m.amp,
      OrbPhase.completed => 0.22,
    };
    m.travel = (m.travel + dt * speed) % 1;
    m.breathClock = (m.breathClock + dt / 2.6) % 1;
    m.breath = 0.5 - 0.5 * math.cos(m.breathClock * 2 * math.pi);
    // Colours ease towards the phase over ~0.25 s instead of snapping.
    m.palette = _OrbPalette.lerp(
      m.palette,
      _OrbPalette.of(shown),
      1 - math.exp(-dt / 0.25),
    );
    m.notify();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final icon =
        widget.icon ?? (widget.phase == OrbPhase.completed ? Ic.check : Ic.mic);
    final core = widget.size * 0.36;
    final button = SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _OrbPainter(_model, widget.rings),
          child: Center(
            child: _CoreGlyph(
              model: _model,
              size: core,
              icon: icon,
              dark: shown == OrbPhase.completed,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: widget.onTap == null
            ? button
            : GestureDetector(onTap: widget.onTap, child: button),
      ),
    );
  }
}

/// The glyph scales with the core without rebuilding the widget tree.
class _CoreGlyph extends StatelessWidget {
  const _CoreGlyph({
    required this.model,
    required this.size,
    required this.icon,
    required this.dark,
  });
  final _OrbModel model;
  final double size;
  final IconData icon;
  final bool dark;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, child) =>
        Transform.scale(scale: model.coreScale, child: child),
    child: Icon(icon, size: size * 0.42, color: dark ? TC.onSun : Colors.white),
  );
}

class _OrbModel extends ChangeNotifier {
  double amp = 0;
  double travel = 0;
  double breath = 0.5;
  double breathClock = 0;
  bool detected = false;
  late _OrbPalette palette;

  /// Continuous breath plus the amplitude swell, shared by the core and
  /// its glyph so they always move together.
  double get coreScale => 1 + 0.035 * (breath - 0.5) * 2 + 0.11 * amp;

  void notify() => notifyListeners();
}

class _OrbPalette {
  const _OrbPalette(this.light, this.deep, this.glow, this.ring);
  final Color light, deep, glow, ring;

  static _OrbPalette of(OrbPhase p) => switch (p) {
    OrbPhase.idle => const _OrbPalette(
      Color(0xFF9A82EC),
      TC.primaryDeep,
      Color(0x557455DB),
      TC.primaryFill,
    ),
    OrbPhase.listening => const _OrbPalette(
      Color(0xFF9C84F0),
      TC.primary,
      Color(0x887455DB),
      TC.primaryFill,
    ),
    OrbPhase.soundDetected => const _OrbPalette(
      TC.peach,
      TC.coralShadow,
      Color(0x99FF6259),
      TC.coral,
    ),
    OrbPhase.completed => const _OrbPalette(
      Color(0xFFE9FAA0),
      TC.limeShadow,
      Color(0x88D9F574),
      TC.limeShadow,
    ),
  };

  static _OrbPalette lerp(_OrbPalette a, _OrbPalette b, double t) =>
      _OrbPalette(
        Color.lerp(a.light, b.light, t)!,
        Color.lerp(a.deep, b.deep, t)!,
        Color.lerp(a.glow, b.glow, t)!,
        Color.lerp(a.ring, b.ring, t)!,
      );
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.m, this.rings) : super(repaint: m);
  final _OrbModel m;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final coreR = maxR * 0.36 * m.coreScale;
    final p = m.palette;
    final ringPaint = Paint()..style = PaintingStyle.stroke;
    final fillPaint = Paint();

    // Rings: each one is born at the core and fades as it reaches the
    // edge. Squared fade keeps the outer ones whisper-quiet.
    for (var i = 0; i < rings; i++) {
      final t = (m.travel + i / rings) % 1;
      final eased = Curves.easeOutCubic.transform(t);
      final reach = 0.72 + 0.28 * m.amp;
      final r = coreR + (maxR - coreR) * eased * reach;
      final fade = math.pow(1 - t, 2).toDouble();
      final strength = 0.10 + 0.22 * m.breath * (1 - m.amp) + 0.45 * m.amp;
      final a = (fade * strength).clamp(0.0, 1.0);
      if (a < 0.01) continue;
      fillPaint.color = p.ring.withValues(alpha: a * 0.35);
      canvas.drawCircle(c, r, fillPaint);
      ringPaint
        ..color = p.ring.withValues(alpha: a)
        ..strokeWidth = 1.2 + 2.2 * (1 - t) * (0.4 + m.amp);
      canvas.drawCircle(c, r, ringPaint);
    }

    // Soft glow under the core, brighter with the input level.
    final glowR = coreR * (1.55 + 0.35 * m.amp);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.glow.withValues(alpha: p.glow.a * (0.6 + 0.4 * m.amp)),
            p.glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // The core: a lit-from-above radial gradient and a thin highlight rim.
    final rect = Rect.fromCircle(center: c, radius: coreR);
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          colors: [p.light, p.deep],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      coreR - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.m != m || old.rings != rings;
}
