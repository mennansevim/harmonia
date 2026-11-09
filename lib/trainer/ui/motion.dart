import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/resonia_theme.dart';
import '../app/scope.dart';
import '../audio/ui_sounds.dart';
import 'kit.dart';

/// Resonia's shared motion language (UX-MOTION-01). Every screen that adopts
/// it moves the same way: content arrives in a short stagger from below,
/// choices pop on a spring with a matching note, steps slide sideways, and
/// a guide speaks in a bubble after a brief "typing" beat. Everything is
/// short enough that a tap is never kept waiting, and with reduced motion
/// the content is simply there.
abstract final class Motion {
  /// One item's entrance.
  static const enter = Duration(milliseconds: 360);

  /// Delay between staggered items; the whole run stays under ~0.5 s.
  static const stagger = Duration(milliseconds: 45);
  static const maxStagger = Duration(milliseconds: 220);

  /// Step-to-step slide.
  static const step = Duration(milliseconds: 380);

  /// How long the guide "types" before its line shows.
  static const typing = Duration(milliseconds: 420);

  static const curve = Curves.easeOutCubic;

  /// Lively overshoot for pops and selected states.
  static const pop = Curves.elasticOut;
  static const spring = Cubic(0.34, 1.56, 0.64, 1);

  static Duration delayFor(int index) {
    final ms = stagger.inMilliseconds * index;
    return Duration(milliseconds: math.min(ms, maxStagger.inMilliseconds));
  }
}

/// Plays an interface cue when the learner allows them. Safe anywhere under
/// a [TrainerScope]; silent without one. Never sounds over a reference
/// being played: the learner may be holding that pitch.
void uiCue(BuildContext context, UiCue cue) {
  final scope = context.getInheritedWidgetOfExactType<TrainerScope>();
  if (scope == null || !scope.store.uiSounds) return;
  if (scope.audio.playing.value) return;
  scope.audio.ui.play(cue);
}

/// A cue with a light haptic, for a choice or a step.
void uiFeedback(BuildContext context, UiCue cue, {bool haptic = true}) {
  uiCue(context, cue);
  if (haptic && ResoniaHapticsScope.enabled(context)) {
    HapticFeedback.selectionClick();
  }
}

/// Fades and lifts [child] in once, after [index] stagger steps.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
    this.delay,
  });

  final Widget child;
  final int index;

  /// Rise distance in logical pixels.
  final double offset;

  /// Overrides the stagger delay.
  final Duration? delay;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  // The delay is part of the controller's run, not a timer: nothing is left
  // pending when the screen goes away.
  late final Duration _delay = widget.delay ?? Motion.delayFor(widget.index);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _delay + Motion.enter,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _delay.inMilliseconds / (_delay + Motion.enter).inMilliseconds,
      1,
      curve: Motion.curve,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    ResoniaMotion.reduced(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _t.value) * widget.offset),
        child: child,
      ),
    ),
  );
}

/// Springs [child] from small to full size once, e.g. a tile appearing.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  static const _run = Duration(milliseconds: 520);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + _run,
  );
  late final double _start =
      widget.delay.inMilliseconds / (widget.delay + _run).inMilliseconds;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    ResoniaMotion.reduced(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = ((_c.value - _start) / (1 - _start)).clamp(0.0, 1.0);
      final scale = Motion.pop.transform(t);
      return Opacity(
        opacity: math.min(1, t * 4),
        child: Transform.scale(scale: 0.2 + 0.8 * scale, child: child),
      );
    },
  );
}

/// Bounces [child] when [trigger] changes to a new value that is neither
/// null nor false (a selection, a right answer).
class Bump extends StatefulWidget {
  const Bump({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;
  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  @override
  void didUpdateWidget(Bump old) {
    super.didUpdateWidget(old);
    // Only a new, positive trigger bumps: clearing a choice stays still.
    final on = widget.trigger != null && widget.trigger != false;
    if (on &&
        old.trigger != widget.trigger &&
        !ResoniaMotion.reduced(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      // Squash then overshoot back to rest.
      final t = _c.value;
      final s = 1 + 0.06 * math.sin(t * math.pi) * (1 - t) * 2;
      return Transform.scale(scale: s, child: child);
    },
  );
}

/// The guide: a softly breathing orb that "types" and then says [message]
/// in a bubble beside it, with a short chirp. A new message replays the
/// typing beat.
class GuideBubble extends StatefulWidget {
  const GuideBubble({super.key, required this.message, this.speak = true});
  final String message;

  /// Plays the chatter cue when the line appears.
  final bool speak;

  @override
  State<GuideBubble> createState() => _GuideBubbleState();
}

class _GuideBubbleState extends State<GuideBubble>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  // The typing beat; when it completes the line shows.
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: Motion.typing,
  )..addStatusListener(_beatDone);
  bool _typing = true;
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = ResoniaMotion.reduced(context);
    if (reduced != _reduced || !_started) {
      _reduced = reduced;
      reduced ? _breath.stop() : _breath.repeat();
    }
    if (!_started) {
      _started = true;
      _say();
    }
  }

  @override
  void didUpdateWidget(GuideBubble old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message) _say();
  }

  void _say() {
    if (_reduced) {
      _typing = false;
      return;
    }
    _typing = true;
    _beat.forward(from: 0);
  }

  void _beatDone(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() => _typing = false);
    if (widget.speak) uiCue(context, UiCue.chatter);
  }

  @override
  void dispose() {
    _beat.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    // Screen readers get the line at once, not the typing beat.
    label: widget.message,
    liveRegion: true,
    excludeSemantics: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _breath,
          builder: (context, _) =>
              GuideOrb(size: 40, phase: _breath.value, talking: !_typing),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Motion.curve,
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: TC.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: TC.line),
                boxShadow: const [
                  BoxShadow(color: TC.cardShadow, offset: Offset(0, 3)),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _typing
                    ? const _TypingDots(key: ValueKey('typing'))
                    : Text(
                        widget.message,
                        key: ValueKey(widget.message),
                        style: TT.body.copyWith(color: TC.ink),
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({super.key});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(
                  0,
                  -3 *
                      math.max(
                        0,
                        math.sin((_c.value - i * 0.18) * 2 * math.pi),
                      ),
                ),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: TC.faint,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Resonia's guide character: a violet voice orb with a lime glint and a
/// small face. [phase] 0..1 drives a gentle breathing scale; [talking]
/// opens the mouth.
class GuideOrb extends StatelessWidget {
  const GuideOrb({
    super.key,
    this.size = 40,
    this.phase = 0,
    this.talking = false,
    this.color = TC.primaryFill,
  });

  final double size;
  final double phase;
  final bool talking;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = 1 + 0.035 * math.sin(phase * 2 * math.pi);
    return ExcludeSemantics(
      child: Transform.scale(
        scale: s,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _OrbFace(color, talking)),
        ),
      ),
    );
  }
}

class _OrbFace extends CustomPainter {
  _OrbFace(this.color, this.talking);
  final Color color;
  final bool talking;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(
      c.translate(0, r * 0.08),
      r,
      Paint()..color = Color.lerp(color, Colors.black, 0.22)!,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Lime glint, the brand's highlight.
    canvas.drawCircle(
      c.translate(-r * 0.42, -r * 0.45),
      r * 0.14,
      Paint()..color = TC.sun,
    );
    final eye = Paint()..color = Colors.white;
    final pupil = Paint()..color = TC.ink;
    for (final dx in [-0.28, 0.28]) {
      final at = c.translate(r * dx, -r * 0.05);
      canvas.drawCircle(at, r * 0.15, eye);
      canvas.drawCircle(at.translate(0, r * 0.03), r * 0.075, pupil);
    }
    final mouth = Rect.fromCenter(
      center: c.translate(0, r * 0.38),
      width: r * (talking ? 0.32 : 0.36),
      height: r * (talking ? 0.26 : 0.08),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mouth, Radius.circular(r * 0.14)),
      Paint()..color = talking ? TC.ink : Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_OrbFace old) =>
      old.color != color || old.talking != talking;
}

/// Bright tile colours for notes and letters, cycling in this order.
const noteTileColors = [
  TC.coral,
  Color(0xFFF5A524),
  Color(0xFF8DB93A),
  Color(0xFF2BB3A3),
  Color(0xFF1E88E5),
  TC.primaryFill,
  TC.magenta,
];

/// A squarish, slightly tilted tile with a tiny face: one letter of a name
/// or one note of a scale.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.label,
    required this.index,
    this.size = 46,
  });

  final String label;
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = noteTileColors[index % noteTileColors.length];
    final tilt = (index.isEven ? -1 : 1) * 0.06;
    final ink = color.computeLuminance() > 0.4 ? TC.ink : Colors.white;
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: size,
        height: size * 1.08,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(color, Colors.black, 0.25)!,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 2; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: size * 0.08,
                    height: size * 0.1,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
            SizedBox(height: size * 0.04),
            // Decorative and sized to the tile: system text scale would
            // only push the letter out of it.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.08),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: ink,
                    fontSize: size * 0.42,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of [NoteTile]s, one per letter of [text]; each new letter pops in.
/// Decorative: the text field it mirrors carries the meaning.
class LetterTiles extends StatelessWidget {
  const LetterTiles({super.key, required this.text, this.size = 46});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letters = text.characters
        .where((c) => c.trim().isNotEmpty)
        .take(12)
        .toList();
    return ExcludeSemantics(
      child: SizedBox(
        height: size * 1.25,
        child: Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < letters.length; i++)
              PopIn(
                // Keyed by position and letter: an edited letter pops anew.
                key: ValueKey('$i${letters[i]}'),
                child: NoteTile(
                  label: trCaps(letters[i]),
                  index: i,
                  size: size,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Notes floating around the welcome orb, each bobbing on its own phase.
class FloatingNotes extends StatefulWidget {
  const FloatingNotes({super.key, required this.labels, this.size = 260});
  final List<String> labels;
  final double size;
  @override
  State<FloatingNotes> createState() => _FloatingNotesState();
}

class _FloatingNotesState extends State<FloatingNotes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ResoniaMotion.reduced(context);
    _reduced ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.labels.length;
    final s = widget.size;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: s,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: GuideOrb(
                  size: s * 0.42,
                  phase: _c.value * 2,
                  talking: true,
                ),
              ),
              for (var i = 0; i < n; i++)
                _place(i, n, s, _reduced ? 0 : _c.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _place(int i, int n, double s, double t) {
    final angle = -math.pi / 2 + i * 2 * math.pi / n;
    final radius = s * 0.4;
    final bob = math.sin((t + i / n) * 2 * math.pi) * 5;
    final tile = s * 0.15;
    return Positioned(
      left: s / 2 + math.cos(angle) * radius - tile / 2,
      top: s / 2 + math.sin(angle) * radius - tile / 2 + bob,
      child: PopIn(
        delay: Duration(milliseconds: 80 + i * 70),
        child: NoteTile(label: widget.labels[i], index: i, size: tile),
      ),
    );
  }
}

/// Step-to-step transition: the new step slides in from the side it comes
/// from while the old one slides out and fades.
class StepSwitcher extends StatelessWidget {
  const StepSwitcher({super.key, required this.forward, required this.child});
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = ResoniaMotion.reduced(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : Motion.step,
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) {
        final incoming = child.key == this.child.key;
        final dir = forward ? 1.0 : -1.0;
        final from = incoming ? 0.22 * dir : -0.22 * dir;
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: Offset(from, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Shakes [child] sideways whenever [trigger] changes to a new non-null
/// value: a wrong answer. Motion only; reduced motion leaves it still.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final Object? trigger;
  final Widget child;
  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null &&
        old.trigger != widget.trigger &&
        !ResoniaMotion.reduced(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = _c.value;
      final dx = math.sin(t * math.pi * 5) * 7 * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}

/// The app-wide page change (UX-MOTION-01): the new page rises a little
/// and fades in over the old one, which eases back. iOS keeps the native
/// Cupertino push so the edge swipe back still works.
class ResoniaPageTransitionsBuilder extends PageTransitionsBuilder {
  const ResoniaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (ResoniaMotion.reduced(context)) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: Motion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    final under = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.curve,
    );
    return AnimatedBuilder(
      animation: under,
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
      // The covered page drifts left and dims slightly, like a step back.
      builder: (context, page) => Transform.translate(
        offset: Offset(-24 * under.value, 0),
        child: Opacity(opacity: 1 - 0.3 * under.value, child: page),
      ),
    );
  }
}

/// Page transitions for the trainer theme.
const resoniaPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ResoniaPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ResoniaPageTransitionsBuilder(),
    TargetPlatform.linux: ResoniaPageTransitionsBuilder(),
    TargetPlatform.windows: ResoniaPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);
