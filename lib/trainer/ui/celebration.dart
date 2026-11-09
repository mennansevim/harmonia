import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/theme/resonia_theme.dart';
import '../audio/ui_sounds.dart';
import '../domain/curriculum.dart';
import 'kit.dart';
import 'motion.dart';

/// How big the end-of-session celebration is (PATH-01). Decided only from
/// what the session actually established, never from accuracy alone:
/// - [lesson]: a finished lesson with measured answers — a small pop;
/// - [checkpoint]: a checkpoint passed (judged at 80%) — fireworks;
/// - [finale]: the final exam passed or the whole skill path finished —
///   a longer show with a trophy.
enum CelebrationTier { none, lesson, checkpoint, finale }

/// Free practice, unanswered sessions and failed gates celebrate nothing.
CelebrationTier celebrationFor({
  required LessonNode? node,
  required bool measured,
  required bool passed,
  required bool skillDone,
}) {
  if (node == null || !measured || !passed) return CelebrationTier.none;
  if (node.kind == NodeKind.intro) return CelebrationTier.none;
  if (node.kind == NodeKind.finalExam || skillDone) {
    return CelebrationTier.finale;
  }
  if (node.kind == NodeKind.checkpoint) return CelebrationTier.checkpoint;
  return CelebrationTier.lesson;
}

/// One-shot fireworks over the whole screen, played once when it is first
/// built. Decorative: it ignores touches and has no semantics, so the
/// result headline underneath is what screen readers announce. With reduced
/// motion there are no particles; checkpoint and finale only show their
/// badge, still, and fade it out.
class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    required this.tier,
    this.haptics = true,
    this.sound = false,
    this.seed = 11,
  });

  final CelebrationTier tier;

  /// Also needs [ResoniaHapticsScope] to allow haptics.
  final bool haptics;

  /// Plays the matching interface cue once (lesson → success, checkpoint
  /// and finale → fanfare), subject to the interface sound setting. Off by
  /// default: a celebration must not sound over reference audio.
  final bool sound;

  /// Spark layout; fixed so tests are repeatable.
  final int seed;

  static Duration durationOf(CelebrationTier tier) => switch (tier) {
    CelebrationTier.none => Duration.zero,
    CelebrationTier.lesson => const Duration(milliseconds: 1400),
    CelebrationTier.checkpoint => const Duration(milliseconds: 2600),
    CelebrationTier.finale => const Duration(milliseconds: 3600),
  };

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration>
    with TickerProviderStateMixin {
  AnimationController? _clock;
  late final AnimationController _pop;
  late final List<FireworkShell> _shells = FireworkShell.show(
    widget.tier,
    widget.seed,
  );
  bool _started = false;
  bool _playing = false;
  bool _reduced = false;
  bool _hapticsAllowed = true;
  int _burstsFelt = 0;

  Duration get _duration => Celebration.durationOf(widget.tier);
  double get _seconds => _duration.inMilliseconds / 1000;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController.unbounded(vsync: this);
  }

  static final _spring = SpringDescription(
    mass: 1,
    stiffness: 360,
    damping: 13,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ResoniaMotion.reduced(context);
    _hapticsAllowed = ResoniaHapticsScope.enabled(context);
    if (_started || widget.tier == CelebrationTier.none) return;
    _started = true;
    if (widget.sound) {
      uiCue(
        context,
        widget.tier == CelebrationTier.lesson ? UiCue.success : UiCue.fanfare,
      );
    }
    // Reduced motion: a lesson pop has nothing left to show.
    if (_reduced && widget.tier == CelebrationTier.lesson) return;
    final clock = AnimationController(vsync: this, duration: _duration)
      ..addListener(_onTick);
    _clock = clock;
    _playing = true;
    _reduced
        ? _pop.value = 1
        : _pop.animateWith(SpringSimulation(_spring, 0, 1, 0));
    clock.forward().whenComplete(() {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _onTick() {
    if (!widget.haptics || !_hapticsAllowed) return;
    final s = _clock!.value * _seconds;
    final due = _reduced ? 1 : _shells.where((sh) => sh.burstAt <= s).length;
    while (_burstsFelt < due) {
      final first = _burstsFelt == 0;
      switch (widget.tier) {
        case CelebrationTier.finale when first:
          HapticFeedback.heavyImpact();
        case CelebrationTier.lesson:
          HapticFeedback.lightImpact();
        default:
          first ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
      }
      _burstsFelt++;
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock;
    if (!_playing || clock == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_reduced)
              RepaintBoundary(
                child: CustomPaint(
                  key: const Key('celebration_sparks'),
                  painter: _FireworksPainter(clock, _shells, _seconds),
                ),
              ),
            if (widget.tier != CelebrationTier.lesson)
              Align(
                alignment: const Alignment(0, -0.45),
                child: AnimatedBuilder(
                  animation: Listenable.merge([clock, _pop]),
                  builder: (context, _) {
                    final t = clock.value;
                    final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
                    return Opacity(
                      opacity: fade.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _reduced ? 1 : math.max(0, _pop.value),
                        child: _Badge(widget.tier),
                      ),
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

class _Badge extends StatelessWidget {
  const _Badge(this.tier);
  final CelebrationTier tier;

  @override
  Widget build(BuildContext context) {
    final finale = tier == CelebrationTier.finale;
    final size = finale ? 112.0 : 92.0;
    return Container(
      key: Key(finale ? 'celebration_trophy' : 'celebration_flag'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: finale ? TC.sun : TC.primaryFill,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: finale ? TC.limeShadow : TC.primaryDeep,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        finale ? Ic.trophy : Ic.flag,
        size: size * 0.46,
        color: finale ? TC.onSun : TC.card,
      ),
    );
  }
}

/// One firework: a rocket rising from the bottom edge to [apex] (fractions
/// of the screen), then a ring of sparks. A shell with [rise] 0 bursts in
/// place without a rocket. Every position is a closed form of time, so the
/// painter allocates nothing per spark per frame.
class FireworkShell {
  const FireworkShell({
    required this.launch,
    required this.rise,
    required this.fromX,
    required this.apex,
    required this.sparks,
    required this.speed,
    required this.colors,
  });

  final double launch, rise, fromX;
  final Offset apex;
  final List<Offset> sparks; // unit directions × individual speed factor
  final double speed;
  final List<Color> colors;

  double get burstAt => launch + rise;

  static const gravity = 260.0;
  static const drag = 1.9;
  static const life = 1.15;

  static const _palettes = [
    [TC.sun, TC.limeShadow],
    [TC.coral, TC.peach],
    [TC.primaryFill, TC.navPill],
    [TC.sky, TC.sun],
    [TC.magenta, TC.coral],
  ];

  /// The shells of one tier, deterministic for [seed].
  static List<FireworkShell> show(CelebrationTier tier, int seed) {
    final r = math.Random(seed);
    FireworkShell shell(double launch, double rise, int count, double speed) {
      final sparks = [
        for (var i = 0; i < count; i++)
          () {
            final a = (i / count) * 2 * math.pi + r.nextDouble() * 0.2;
            final k = 0.72 + r.nextDouble() * 0.28;
            return Offset(math.cos(a) * k, math.sin(a) * k);
          }(),
      ];
      return FireworkShell(
        launch: launch,
        rise: rise,
        fromX: 0.2 + r.nextDouble() * 0.6,
        apex: Offset(0.18 + r.nextDouble() * 0.64, 0.14 + r.nextDouble() * 0.2),
        sparks: sparks,
        speed: speed,
        colors: _palettes[r.nextInt(_palettes.length)],
      );
    }

    return switch (tier) {
      CelebrationTier.none => const [],
      CelebrationTier.lesson => [shell(0, 0, 24, 300)],
      CelebrationTier.checkpoint => [
        shell(0.0, 0.55, 36, 420),
        shell(0.35, 0.6, 36, 420),
        shell(0.7, 0.5, 36, 420),
      ],
      CelebrationTier.finale => [
        for (var i = 0; i < 7; i++)
          shell(i * 0.3, 0.5 + r.nextDouble() * 0.15, 40, 440 + i * 8.0),
      ],
    };
  }

  /// Spark offset from the apex [age] seconds after the burst.
  Offset sparkAt(Offset dir, double age) {
    final k = (1 - math.exp(-drag * age)) / drag * speed;
    return Offset(dir.dx * k, dir.dy * k + 0.5 * gravity * age * age);
  }

  /// 1 while fresh, fading to 0 over the last half of [life].
  static double opacity(double age) =>
      age < 0 ? 0 : ((life - age) / (life / 2)).clamp(0.0, 1.0);
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter(this.clock, this.shells, this.seconds)
    : super(repaint: clock);

  final Animation<double> clock;
  final List<FireworkShell> shells;
  final double seconds;
  final Paint _dot = Paint();
  final Paint _trail = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = clock.value * seconds;
    for (final sh in shells) {
      final apex = Offset(sh.apex.dx * size.width, sh.apex.dy * size.height);
      // Rocket climbing, with a short fading tail.
      if (sh.rise > 0 && s >= sh.launch && s < sh.burstAt) {
        final k = Curves.easeOutCubic.transform((s - sh.launch) / sh.rise);
        final from = Offset(sh.fromX * size.width, size.height);
        final head = Offset.lerp(from, apex, k)!;
        // A short tail, at most 36 px behind the head.
        final back = from - head;
        final tail = head + back * math.min(1, 36 / math.max(1, back.distance));
        _trail
          ..color = sh.colors.first.withValues(alpha: 0.7)
          ..strokeWidth = 2.5;
        canvas.drawLine(tail, head, _trail);
        _dot.color = sh.colors.first;
        canvas.drawCircle(head, 2.8, _dot);
      }
      final age = s - sh.burstAt;
      final a = FireworkShell.opacity(age);
      if (a <= 0) continue;
      // A soft flash at the moment of the burst.
      if (age < 0.18) {
        _dot.color = sh.colors.first.withValues(alpha: 0.35 * (1 - age / 0.18));
        canvas.drawCircle(apex, 26 + 60 * age, _dot);
      }
      for (var i = 0; i < sh.sparks.length; i++) {
        final dir = sh.sparks[i];
        final color = sh.colors[i % sh.colors.length].withValues(alpha: a);
        final head = apex + sh.sparkAt(dir, age);
        final tail = apex + sh.sparkAt(dir, math.max(0, age - 0.035));
        _trail
          ..color = color
          ..strokeWidth = 2.2;
        canvas.drawLine(tail, head, _trail);
        // Late twinkle: alternate sparks flicker as they fade.
        if (age > 0.5 && (i + (age * 20).floor()).isOdd) continue;
        _dot.color = color;
        canvas.drawCircle(head, 2.6, _dot);
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) =>
      old.clock != clock || old.shells != shells;
}
