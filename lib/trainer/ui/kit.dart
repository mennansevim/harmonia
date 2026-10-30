import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../domain/trainers.dart';

/// The design's line icons, at the thin stroke its Figma frames use.
typedef Ic = LucideIcons300;

/// Resonia visual system (A+C brand, see lib/app/theme): lavender canvas,
/// indigo primary shared with the choir workshop, sun for streaks and one
/// accent colour per skill.
abstract final class TC {
  static const primary = Color(0xFF7040E8);
  static const primaryDeep = Color(0xFF4A22BE);
  static const primarySoft = Color(0xFFEEE7FB);
  static const koro = primary;

  /// Lime: the one bright accent. Always carries ink, never white.
  static const sun = Color(0xFFDDF780);
  static const onSun = Color(0xFF261831);
  static const peach = Color(0xFFFF8A6B);
  static const warnSoft = Color(0xFFFFF0DE);
  static const warn = Color(0xFFB4561F);
  static const coral = Color(0xFFE5483A);
  static const teal = Color(0xFF0F9D8A);
  static const magenta = Color(0xFFC2307A);
  static const amber = Color(0xFFC98400);
  static const sky = Color(0xFF1E88E5);
  static const green = Color(0xFF1AA874);
  static const red = Color(0xFFD92D20);

  /// Aubergine: the dark hero surface and the darkest text.
  static const ink = Color(0xFF261831);

  /// Dark hero cards: a touch bluer than the text ink.
  static const hero = Color(0xFF27153E);
  static const body = Color(0xFF4D4957);
  static const muted = Color(0xFF6C6776);
  static const faint = Color(0xFFBDB8C6);
  static const line = Color(0xFFE8E3EB);
  static const canvas = Color(0xFFF8F7F3);
  static const card = Colors.white;
  static const heroMuted = Color(0xFFC6B8D9);
  static const navBar = Colors.white;
  static const navPill = Color(0xFFEEE7FB);
}

Color trainerColor(TrainerKind kind) => switch (kind) {
  TrainerKind.pitch => TC.coral,
  TrainerKind.interval => TC.teal,
  TrainerKind.chord => TC.magenta,
  TrainerKind.scale => TC.amber,
  TrainerKind.progression => TC.sky,
};

IconData trainerIcon(TrainerKind kind) => switch (kind) {
  TrainerKind.pitch => Ic.circleDot,
  TrainerKind.interval => Ic.moveVertical,
  TrainerKind.chord => Ic.layers,
  TrainerKind.scale => Ic.signal,
  TrainerKind.progression => Ic.route,
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
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: TC.primary,
      primary: TC.primary,
      secondaryContainer: TC.navPill,
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
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
      side: BorderSide.none,
      backgroundColor: Colors.white,
      selectedColor: TC.primary,
      labelStyle: const TextStyle(
        color: TC.ink,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 6,
      activeTrackColor: TC.primary,
      inactiveTrackColor: TC.line,
      thumbColor: TC.primary,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const _ThumbDot(),
      tickMarkShape: SliderTickMarkShape.noTickMark,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? TC.primary : TC.line,
      ),
      thumbColor: WidgetStateProperty.all(Colors.white),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: TC.ink,
        backgroundColor: Colors.white,
        iconSize: 18,
        side: const BorderSide(color: TC.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: 'Inter',
        ),
      ),
    ),
  );
}

/// The design's slider handle: a primary dot in a white ring, no shadow.
class _ThumbDot extends SliderComponentShape {
  const _ThumbDot();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(16);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = enableAnimation.value == 0
            ? TC.faint
            : sliderTheme.thumbColor ?? TC.primary,
    );
  }
}

abstract final class TT {
  /// Serif for the words a screen is about: a work, a choir, a promise.
  static const display = TextStyle(
    fontFamily: 'Lora',
    fontSize: 31,
    fontWeight: FontWeight.w400,
    color: TC.ink,
    height: 1.12,
  );
  static const h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: TC.ink,
    height: 1.15,
    letterSpacing: -1.4,
  );
  static const h2 = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w500,
    color: TC.ink,
    height: 1.15,
    letterSpacing: -0.8,
  );
  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: TC.ink,
  );
  static const title = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: TC.ink,
    height: 1.5,
  );
  static const body = TextStyle(fontSize: 13, color: TC.body, height: 1.5);
  static const small = TextStyle(fontSize: 12, color: TC.muted, height: 1.4);
  static const caps = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: TC.muted,
    letterSpacing: 1.5,
  );
  static const crumb = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: TC.primary,
    letterSpacing: 1.5,
  );
}

void tapHaptic() => HapticFeedback.selectionClick();

/// Full-width pill call to action. Pressing squeezes it slightly. A light
/// fill (lime) carries ink text, a deep one white.
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
  bool _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final lit = enabled || widget.busy;
    final fill = lit ? widget.color : const Color(0xFFE3DFE7);
    final light = widget.color.computeLuminance() > 0.35;
    final fg = !lit
        ? TC.muted
        : light
        ? TC.ink
        : Colors.white;
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
        child: AnimatedScale(
          scale: enabled && _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(12),
              border: widget.color == Colors.white
                  ? Border.all(color: TC.line)
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.busy
                ? _Dots(color: fg)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: fg, size: 18),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              style: TextStyle(
                                color: fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (widget.chevron) ...[
                          const SizedBox(width: 6),
                          Icon(Ic.chevronRight, color: fg),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots({this.color = Colors.white});
  final Color color;
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
              color: widget.color.withValues(
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

/// Secondary full-width action on the soft lavender fill.
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: onPressed == null
          ? null
          : () {
              tapHaptic();
              onPressed!();
            },
      style: TextButton.styleFrom(
        foregroundColor: TC.primary,
        backgroundColor: TC.primarySoft,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}

/// Aubergine surface for the one thing a screen is about.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.ring = true,
  });
  final Widget child;
  final EdgeInsets padding;

  /// Kept for callers that want no decoration; the card itself is plain now.
  final bool ring;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: TC.hero,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

/// Small uppercase pill on a hero (white on translucent white).
class HeroPill extends StatelessWidget {
  const HeroPill(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.17),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// White round back button used on every pushed screen.
class BackSquare extends StatelessWidget {
  const BackSquare({
    super.key,
    this.onTap,
    this.icon = Ic.chevronLeft,
    this.label = 'Geri',
  });
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: TC.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: TC.ink),
        ),
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
        Container(height: height, color: TC.line),
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
      color: shadow ? Colors.white : Colors.transparent,
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
          height: 44,
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
                        style: TT.h3,
                      ),
                    ),
                  ],
                ),
              ),
              if (titleIcon == null) const SizedBox(width: 56),
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
    this.radius = 12,
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
      border: border == null ? null : Border.all(color: border!, width: 1.5),
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

/// Status pill; lime is the app's signature for "look at this".
class TiltTag extends StatelessWidget {
  const TiltTag(this.text, {super.key, this.color = TC.sun});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
    child: Text(
      text,
      style: const TextStyle(
        color: TC.ink,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// A choice in a wrapping row: primary with a check when on, white when off.
class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? TC.primary : Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          tapHaptic();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Ic.check, color: Colors.white, size: 12),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : TC.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    // Flat tinted circle: the skill colour lives in the glyph.
    decoration: BoxDecoration(shape: BoxShape.circle, color: soft(color)),
    child: Icon(icon, color: color, size: size * 0.52),
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
        ? const Icon(Ic.check, size: 16, color: Colors.white)
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
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
