import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/trainers.dart';

/// Harmonia visual system (A+C brand, see lib/app/theme): lavender canvas,
/// indigo primary shared with the choir workshop, sun for streaks and one
/// accent colour per skill.
abstract final class TC {
  static const primary = Color(0xFF5B46F5);
  static const primaryDeep = Color(0xFF3B2BBF);
  static const primarySoft = Color(0xFFEEEBFF);
  static const koro = primary;
  static const sun = Color(0xFFFFC531);
  static const onSun = Color(0xFF3D2C00);
  static const coral = Color(0xFFE5483A);
  static const teal = Color(0xFF0F9D8A);
  static const magenta = Color(0xFFC2307A);
  static const amber = Color(0xFFC98400);
  static const sky = Color(0xFF1E88E5);
  static const green = Color(0xFF1AA874);
  static const red = Color(0xFFD92D20);
  static const ink = Color(0xFF17183A);
  static const body = Color(0xFF45486A);
  static const muted = Color(0xFF6E7294);
  static const faint = Color(0xFFC4C3D9);
  static const line = Color(0xFFE4E3EF);
  static const canvas = Color(0xFFF7F7FC);
  static const card = Colors.white;
}

Color trainerColor(TrainerKind kind) => switch (kind) {
  TrainerKind.pitch => TC.coral,
  TrainerKind.interval => TC.teal,
  TrainerKind.chord => TC.magenta,
  TrainerKind.scale => TC.amber,
  TrainerKind.progression => TC.sky,
};

IconData trainerIcon(TrainerKind kind) => switch (kind) {
  TrainerKind.pitch => Icons.adjust_rounded,
  TrainerKind.interval => Icons.height_rounded,
  TrainerKind.chord => Icons.layers_rounded,
  TrainerKind.scale => Icons.signal_cellular_alt_rounded,
  TrainerKind.progression => Icons.route_rounded,
};

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color soft(Color c) =>
    Color.alphaBlend(c.withValues(alpha: 0.12), Colors.white);

ThemeData trainerTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TC.primary,
      primary: TC.primary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: TC.canvas,
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: TC.ink, displayColor: TC.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TC.ink,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

abstract final class TT {
  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: TC.ink,
    height: 1.2,
  );
  static const h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: TC.ink,
    height: 1.25,
  );
  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: TC.ink,
  );
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: TC.ink,
  );
  static const body = TextStyle(fontSize: 15, color: TC.body, height: 1.45);
  static const small = TextStyle(fontSize: 13, color: TC.muted, height: 1.35);
  static const caps = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    color: TC.muted,
    letterSpacing: 1.2,
  );
}

void tapHaptic() => HapticFeedback.selectionClick();

/// Full-width chunky call to action: flat fill on a darker base edge that
/// presses down on tap (Harmonia direction A).
class BigButton extends StatefulWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = TC.primary,
    this.icon,
    this.chevron = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool chevron;
  final bool busy;

  @override
  State<BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<BigButton> {
  static const _edge = 4.0;
  bool _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final lit = enabled || widget.busy;
    final fill = lit ? widget.color : const Color(0xFFE4E3EF);
    final base = lit ? _shade(widget.color, -0.16) : const Color(0xFFCFCEE0);
    final fg = lit ? Colors.white : TC.muted;
    final drop = enabled && _down ? _edge : 0.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _press(true) : null,
        onTapCancel: () => _press(false),
        onTapUp: enabled ? (_) => _press(false) : null,
        onTap: enabled
            ? () {
                tapHaptic();
                widget.onPressed!();
              }
            : null,
        child: SizedBox(
          height: 54 + _edge,
          child: Stack(
            children: [
              Positioned.fill(
                top: _edge,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                left: 0,
                right: 0,
                top: drop,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: widget.busy
                        ? const _Dots()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(widget.icon, color: fg, size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      widget.label,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: fg,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.chevron) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.chevron_right_rounded, color: fg),
                                ],
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                alpha: ((_c.value * 3 - i) % 3) < 1 ? 1 : 0.45,
              ),
            ),
          ),
      ],
    ),
  );
}

class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: TC.body),
    child: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
    ),
  );
}

/// Grey rounded back square used on every pushed screen.
class BackSquare extends StatelessWidget {
  const BackSquare({super.key, this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Geri',
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEEF8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.chevron_left_rounded, color: TC.ink),
      ),
    ),
  );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color = TC.primary,
    this.height = 6,
  });
  final double value;
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Stack(
      children: [
        Container(height: height, color: const Color(0xFFE4E3EF)),
        AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(height: height, color: color),
        ),
      ],
    ),
  );
}

/// Header of a pushed screen: back square, centred title, optional progress.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    this.title,
    this.leading,
    this.progress,
    this.progressColor = TC.primary,
    this.counter,
    this.onBack,
    this.titleIcon,
    this.shadow = false,
  });
  final String? title;
  final Widget? leading;
  final double? progress;
  final Color progressColor;
  final String? counter;
  final VoidCallback? onBack;
  final Widget? titleIcon;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: shadow
          ? const BorderRadius.vertical(bottom: Radius.circular(22))
          : null,
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    ),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Column(
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              leading ?? BackSquare(onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: titleIcon == null
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    if (titleIcon != null) ...[
                      titleIcon!,
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: TC.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (titleIcon == null) const SizedBox(width: 48),
            ],
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ProgressBar(value: progress!, color: progressColor),
              ),
              if (counter != null) ...[
                const SizedBox(width: 10),
                Text(
                  counter!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: TC.body,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
    this.border,
    this.radius = 18,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;
  final Color? border;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      // Direction C: thin hairline cards instead of floating shadows.
      border: border == null
          ? Border.all(color: TC.line)
          : Border.all(color: border!, width: 1.5),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap == null
            ? null
            : () {
                tapHaptic();
                onTap!();
              },
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Gradient rounded-square trainer badge.
class TrainerBadge extends StatelessWidget {
  const TrainerBadge({
    super.key,
    required this.color,
    required this.icon,
    this.size = 44,
  });
  final Color color;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_shade(color, 0.08), _shade(color, -0.06)],
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.55),
  );
}

/// Bordered selectable row with checkbox or radio indicator.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.multi = true,
    this.leading,
    this.trailing,
    this.color = TC.primary,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool multi;
  final String? leading;
  final String? trailing;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : TC.line,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            tapHaptic();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                _Indicator(selected: selected, multi: multi, color: color),
                const SizedBox(width: 12),
                if (leading != null) ...[
                  Text(leading!, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: TC.ink,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? color : TC.body,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.selected,
    required this.multi,
    required this.color,
  });
  final bool selected;
  final bool multi;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: selected ? color : Colors.white,
      shape: multi ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: multi ? BorderRadius.circular(6) : null,
      border: Border.all(color: selected ? color : TC.faint, width: 1.6),
    ),
    child: selected
        ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
        : null,
  );
}

/// Pill segmented control (Low / Medium / High etc.).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.color = TC.primary,
    this.joined = false,
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final Color color;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final v in values)
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: joined ? 0 : 4),
            child: Semantics(
              selected: v == selected,
              button: true,
              child: GestureDetector(
                onTap: () {
                  tapHaptic();
                  onChanged(v);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == selected ? color : Colors.white,
                    borderRadius: BorderRadius.circular(joined ? 10 : 14),
                    border: joined
                        ? null
                        : Border.all(
                            color: v == selected ? color : TC.line,
                            width: 1.5,
                          ),
                  ),
                  child: Text(
                    label(v),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: v == selected ? Colors.white : TC.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
    if (!joined) {
      return Padding(
        padding: EdgeInsets.zero,
        child: Row(children: children),
      );
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TC.line, width: 1.5),
      ),
      child: Row(children: children),
    );
  }
}

/// Glowing coloured frame for right/wrong feedback around the whole screen.
class FeedbackFrame extends StatelessWidget {
  const FeedbackFrame({super.key, required this.state, required this.child});

  /// null = neutral, true = correct, false = wrong.
  final bool? state;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final color = state == null ? null : (state! ? TC.green : TC.red);
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(44),
              border: Border.all(
                color: color ?? Colors.transparent,
                width: color == null ? 0 : 4,
              ),
              boxShadow: color == null
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 40,
                        spreadRadius: -6,
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated layered sine waves; idle state collapses to a line with a label.
class WaveView extends StatefulWidget {
  const WaveView({
    super.key,
    required this.playing,
    required this.color,
    this.label,
    this.onTap,
    this.height = 180,
  });
  final ValueListenable<bool> playing;
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  final double height;
  @override
  State<WaveView> createState() => _WaveViewState();
}

class _WaveViewState extends State<WaveView>
    with SingleTickerProviderStateMixin {
  late final _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  double _amp = 0;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: widget.onTap != null,
    label: widget.label ?? 'Tekrar dinle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.height,
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.playing,
          builder: (context, playing, _) => TweenAnimationBuilder<double>(
            tween: Tween(end: playing ? 1 : 0),
            duration: Duration(milliseconds: playing ? 260 : 700),
            curve: Curves.easeOutCubic,
            builder: (context, amp, _) {
              _amp = amp;
              return AnimatedBuilder(
                animation: _ticker,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _WavePainter(
                          phase: _ticker.value * 2 * math.pi,
                          amplitude: _amp,
                          color: widget.color,
                          gap: widget.label != null && !playing ? 1 - _amp : 0,
                        ),
                      ),
                    ),
                    if (widget.label != null)
                      Center(
                        child: Opacity(
                          opacity: (1 - _amp).clamp(0.0, 1.0),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              widget.label!,
                              style: TextStyle(
                                color: widget.color,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.phase,
    required this.amplitude,
    required this.color,
    required this.gap,
  });
  final double phase;
  final double amplitude;
  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final gapHalf = 90 * gap;
    for (var layer = 4; layer >= 0; layer--) {
      final main = layer == 0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = main ? 3.2 : 1.4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: main ? 1 : 0.28);
      final path = Path();
      var started = false;
      final amp =
          (size.height * 0.36) * amplitude * (main ? 1 : 0.55 + layer * 0.1);
      for (var x = 0.0; x <= size.width; x += 3) {
        if (gapHalf > 1 && (x - size.width / 2).abs() < gapHalf) {
          started = false;
          continue;
        }
        final t = x / size.width;
        final env = math.sin(math.pi * t).clamp(0.25, 1.0);
        final y =
            mid +
            amp *
                env *
                math.sin(t * 2 * math.pi * 1.6 + phase + layer * 0.9) *
                math.cos(phase * 0.5 + layer);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase ||
      old.amplitude != amplitude ||
      old.color != color ||
      old.gap != gap;
}

/// White rounded bottom sheet with a drag handle.
Future<T?> showTrainerSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool dismissible = true,
}) => showModalBottomSheet<T>(
  context: context,
  isDismissible: dismissible,
  enableDrag: dismissible,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.4),
  builder: (context) => SafeArea(
    child: Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD3D2E6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          builder(context),
        ],
      ),
    ),
  ),
);

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancel,
  required String confirm,
  bool destructive = true,
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

/// Small rounded label (CHECKPOINT, NEW LESSON, ...).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: soft(color),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: _shade(color, -0.08),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

/// Bulleted info row on a white card (lesson slides).
class BulletCard extends StatelessWidget {
  const BulletCard(this.text, {super.key, required this.color, this.highlight});
  final String text;
  final Color color;
  final List<String>? highlight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: highlighted(text, highlight, color)),
        ],
      ),
    ),
  );
}

Widget highlighted(
  String text,
  List<String>? words,
  Color color, {
  TextStyle style = const TextStyle(fontSize: 14.5, color: TC.ink, height: 1.4),
  TextAlign align = TextAlign.start,
}) {
  if (words == null || words.isEmpty) {
    return Text(text, style: style, textAlign: align);
  }
  final spans = <TextSpan>[];
  var rest = text;
  while (rest.isNotEmpty) {
    var best = -1;
    String? hit;
    for (final w in words) {
      final i = rest.indexOf(w);
      if (i >= 0 && (best < 0 || i < best)) {
        best = i;
        hit = w;
      }
    }
    if (hit == null) {
      spans.add(TextSpan(text: rest));
      break;
    }
    spans.add(TextSpan(text: rest.substring(0, best)));
    spans.add(
      TextSpan(
        text: hit,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
    rest = rest.substring(best + hit.length);
  }
  return Text.rich(
    TextSpan(style: style, children: spans),
    textAlign: align,
  );
}
