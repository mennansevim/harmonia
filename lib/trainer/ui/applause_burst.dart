import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/resonia_theme.dart';
import 'kit.dart';

/// A one-shot applause celebration over [child]: a lime badge springs in
/// and is "clapped" three times, each clap sending a ring and a handful of
/// confetti out from the centre, with a matching haptic tap.
///
/// Plays whenever [shot] grows, so the caller only counts celebrations
/// (`_cheers++`) after a real, judged success; rebuilding with the same
/// value never replays. Decorative: no semantics of its own, so the
/// caller's live-region text is the one announced. With reduced motion the
/// badge just appears and fades, without particles, rings or spring.
class ApplauseBurst extends StatefulWidget {
  const ApplauseBurst({
    super.key,
    required this.shot,
    required this.child,
    this.haptics = true,
    this.seed = 7,
  });

  final int shot;
  final Widget child;

  /// Also needs [ResoniaHapticsScope] to allow haptics.
  final bool haptics;

  /// Confetti layout; fixed so goldens and tests are repeatable.
  final int seed;

  /// Whole celebration, badge fade-out included.
  static const duration = Duration(milliseconds: 1600);

  /// Seconds after the start at which each clap lands.
  static const claps = [0.0, 0.26, 0.52];

  @override
  State<ApplauseBurst> createState() => _ApplauseBurstState();
}

class _ApplauseBurstState extends State<ApplauseBurst>
    with TickerProviderStateMixin {
  late final AnimationController _burst;
  late final AnimationController _pop;
  late final List<ApplausePiece> _pieces;
  int _clapsFelt = 0;
  bool _playing = false;
  bool _reduced = false;
  bool _hapticsAllowed = true;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(vsync: this, duration: ApplauseBurst.duration)
      ..addListener(_onTick);
    _pop = AnimationController.unbounded(vsync: this);
    _pieces = ApplausePiece.scatter(widget.seed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ResoniaMotion.reduced(context);
    _hapticsAllowed = ResoniaHapticsScope.enabled(context);
  }

  static final _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 14,
  );

  @override
  void didUpdateWidget(ApplauseBurst old) {
    super.didUpdateWidget(old);
    if (widget.shot > old.shot) _play();
  }

  void _play() {
    _clapsFelt = 0;
    setState(() => _playing = true);
    if (_reduced) {
      _pop.value = 1;
    } else {
      _pop.animateWith(SpringSimulation(_spring, 0, 1, 0));
    }
    _burst.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _onTick() {
    final s = _burst.value * ApplauseBurst.duration.inMilliseconds / 1000;
    // One tap per clap; reduced motion keeps a single confirming tap.
    final due = _reduced ? 1 : ApplauseBurst.claps.where((c) => c <= s).length;
    while (_clapsFelt < due) {
      if (widget.haptics && _hapticsAllowed) {
        _clapsFelt == 0
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.lightImpact();
      }
      _clapsFelt++;
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_playing && !reduced)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const Key('applause_particles'),
                  painter: _ApplausePainter(_burst, _pieces),
                ),
              ),
            ),
          ),
        if (_playing)
          IgnorePointer(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([_burst, _pop]),
                builder: (context, _) {
                  final t = _burst.value;
                  final s = t * ApplauseBurst.duration.inMilliseconds / 1000;
                  final scale = reduced ? 1.0 : _pop.value + _clapBump(s);
                  final fade = t < 0.72 ? 1.0 : 1 - (t - 0.72) / 0.28;
                  return Opacity(
                    opacity: fade.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: math.max(0, scale),
                      child: const _Badge(),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  /// Each later clap squeezes the badge a little, like palms meeting.
  static double _clapBump(double s) {
    var bump = 0.0;
    for (final c in ApplauseBurst.claps.skip(1)) {
      final d = s - c;
      if (d >= 0) bump += 0.12 * math.exp(-d * 12) * math.cos(d * 30);
    }
    return bump;
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('applause_badge'),
    width: 88,
    height: 88,
    decoration: const BoxDecoration(
      color: TC.sun,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: TC.limeShadow, offset: Offset(0, 5))],
    ),
    child: const Icon(LucideIcons.partyPopper, size: 40, color: TC.onSun),
  );
}

/// One confetti piece, thrown by clap [wave] from the centre. Its path is
/// a closed form of time, so the painter allocates nothing per frame.
class ApplausePiece {
  const ApplausePiece({
    required this.wave,
    required this.velocity,
    required this.size,
    required this.spin,
    required this.color,
    required this.round,
  });

  final int wave;
  final Offset velocity;
  final double size, spin;
  final Color color;
  final bool round;

  static const perWave = 14;
  static const gravity = 980.0;
  static const drag = 2.4;
  static const life = 0.9;

  static const _colors = [
    TC.sun,
    TC.coral,
    TC.primaryFill,
    TC.peach,
    TC.sky,
    TC.magenta,
  ];

  static List<ApplausePiece> scatter(int seed) {
    final r = math.Random(seed);
    return [
      for (var w = 0; w < ApplauseBurst.claps.length; w++)
        for (var i = 0; i < perWave; i++)
          () {
            // Mostly upward, like confetti thrown from clapping hands.
            final a = -math.pi / 2 + (r.nextDouble() * 2 - 1) * 1.25;
            final v = 360 + r.nextDouble() * 380;
            return ApplausePiece(
              wave: w,
              velocity: Offset(math.cos(a) * v, math.sin(a) * v),
              size: 5 + r.nextDouble() * 5,
              spin: (r.nextDouble() * 2 - 1) * 14,
              color: _colors[r.nextInt(_colors.length)],
              round: r.nextBool(),
            );
          }(),
    ];
  }

  /// Offset from the centre [age] seconds after its clap.
  Offset at(double age) {
    final k = (1 - math.exp(-drag * age)) / drag;
    return Offset(
      velocity.dx * k,
      velocity.dy * k + 0.5 * gravity * age * age * 0.45,
    );
  }

  /// 1 while fresh, fading to 0 over the last third of [life].
  static double opacity(double age) =>
      age < 0 ? 0 : ((life - age) / (life / 3)).clamp(0.0, 1.0);
}

class _ApplausePainter extends CustomPainter {
  _ApplausePainter(this.burst, this.pieces) : super(repaint: burst);

  final Animation<double> burst;
  final List<ApplausePiece> pieces;
  final Paint _fill = Paint();
  final Paint _ring = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final s = burst.value * ApplauseBurst.duration.inMilliseconds / 1000;
    final c = size.center(Offset.zero);
    for (final start in ApplauseBurst.claps) {
      final k = (s - start) / 0.5;
      if (k < 0 || k > 1) continue;
      final e = Curves.easeOutCubic.transform(k);
      _ring
        ..color = TC.sun.withValues(alpha: 1 - k)
        ..strokeWidth = 3 - 2 * e;
      canvas.drawCircle(c, 48 + 90 * e, _ring);
    }
    for (final p in pieces) {
      final age = s - ApplauseBurst.claps[p.wave];
      final a = ApplausePiece.opacity(age);
      if (a <= 0) continue;
      final o = c + p.at(age);
      _fill.color = p.color.withValues(alpha: a);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(p.spin * age);
      p.round
          ? canvas.drawCircle(Offset.zero, p.size / 2, _fill)
          : canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: p.size,
                  height: p.size * 0.5,
                ),
                const Radius.circular(1.5),
              ),
              _fill,
            );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ApplausePainter old) =>
      old.burst != burst || old.pieces != pieces;
}
