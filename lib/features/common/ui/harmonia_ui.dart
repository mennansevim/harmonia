import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/harmonia_theme.dart';

enum ChunkyTone { primary, success, neutral, record }

/// A's signature control: a raised button that sinks when pressed. Keeps a
/// 52 pt minimum height, a light haptic on press and full semantics.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ChunkyTone.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ChunkyTone tone;
  final bool expand;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final enabled = widget.onPressed != null;
    final (fill, shadow, ink, border) = switch (widget.tone) {
      ChunkyTone.primary => (
        scheme.primary,
        palette.primaryDeep,
        scheme.onPrimary,
        null,
      ),
      ChunkyTone.success => (
        palette.mint,
        Color.lerp(palette.mint, Colors.black, .28)!,
        Colors.white,
        null,
      ),
      ChunkyTone.record => (
        palette.coral,
        Color.lerp(palette.coral, Colors.black, .28)!,
        Colors.white,
        null,
      ),
      ChunkyTone.neutral => (
        scheme.surfaceContainerLowest,
        palette.line,
        scheme.primary,
        palette.line,
      ),
    };
    final disabledFill = scheme.onSurface.withValues(alpha: 0.08);
    final depth = enabled && !_down ? 4.0 : 0.0;
    final reduced = HarmoniaMotion.reduced(context);
    final body = AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 70),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(top: 4 - depth),
      constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: enabled ? fill : disabledFill,
        borderRadius: BorderRadius.circular(HarmoniaRadius.button),
        border: border == null || !enabled
            ? null
            : Border.all(color: border, width: 2),
        boxShadow: depth == 0
            ? null
            : [BoxShadow(color: shadow, offset: Offset(0, depth))],
      ),
      child: Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: 22,
              color: enabled ? ink : scheme.onSurface.withValues(alpha: .38),
            ),
            const SizedBox(width: HarmoniaSpacing.sm),
          ],
          Flexible(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: enabled ? ink : scheme.onSurface.withValues(alpha: .38),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: FocusableActionDetector(
          enabled: enabled,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: body,
        ),
      ),
    );
  }
}

enum OptionState { idle, selected, correct, wrong, dimmed }

/// Answer tile (A): large, chunky and colour plus icon for state, so the
/// result never depends on colour alone.
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.state = OptionState.idle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final OptionState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final results = context.resultColors;
    final text = Theme.of(context).textTheme;
    final (border, fill, ink, icon) = switch (state) {
      OptionState.idle => (
        palette.line,
        scheme.surfaceContainerLowest,
        scheme.onSurface,
        null,
      ),
      OptionState.selected => (
        scheme.primary,
        scheme.primary.withValues(alpha: .08),
        scheme.primary,
        null,
      ),
      OptionState.correct => (
        palette.mint,
        palette.mintSoft,
        results.correct,
        Icons.check_circle_rounded,
      ),
      OptionState.wrong => (
        palette.coral,
        palette.coralSoft,
        results.incorrect,
        Icons.cancel_rounded,
      ),
      OptionState.dimmed => (
        palette.line,
        scheme.surfaceContainerLowest,
        scheme.onSurface.withValues(alpha: .5),
        null,
      ),
    };
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: state == OptionState.selected,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(HarmoniaRadius.button),
            border: Border.all(color: border, width: 2),
            boxShadow: [BoxShadow(color: border, offset: const Offset(0, 3))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(HarmoniaRadius.button),
            onTap: enabled
                ? () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  }
                : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(
                horizontal: HarmoniaSpacing.md,
                vertical: HarmoniaSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.titleMedium?.copyWith(color: ink),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: text.bodySmall?.copyWith(
                              color: state == OptionState.idle
                                  ? palette.muted
                                  : ink,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (icon != null) Icon(icon, color: ink, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A's answer panel: slides up under the question with what happened and
/// the next action. Announced to screen readers as a live region.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.correct,
    required this.title,
    this.detail,
    required this.actionLabel,
    required this.onAction,
    this.actionKey,
    this.textKey,
  });

  final bool correct;
  final String title;
  final String? detail;
  final String actionLabel;
  final VoidCallback onAction;
  final Key? actionKey;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final results = context.resultColors;
    final text = Theme.of(context).textTheme;
    final ink = correct ? results.correct : results.incorrect;
    final reduced = HarmoniaMotion.reduced(context);
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        HarmoniaSpacing.md,
        HarmoniaSpacing.md,
        HarmoniaSpacing.md,
        HarmoniaSpacing.md,
      ),
      decoration: BoxDecoration(
        color: correct ? palette.mintSoft : palette.coralSoft,
        borderRadius: BorderRadius.circular(HarmoniaRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: ink,
                ),
                const SizedBox(width: HarmoniaSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    key: textKey,
                    style: text.titleMedium?.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: HarmoniaSpacing.xs),
            Text(detail!, style: text.bodyMedium),
          ],
          const SizedBox(height: HarmoniaSpacing.md),
          ChunkyButton(
            key: actionKey,
            label: actionLabel,
            tone: correct ? ChunkyTone.success : ChunkyTone.primary,
            onPressed: onAction,
          ),
        ],
      ),
    );
    if (reduced) return panel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: HarmoniaMotion.medium,
      curve: HarmoniaMotion.emphasized,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: panel,
    );
  }
}

/// C's data label: small tracked text with tabular digits. Case is kept as
/// written: Dart's toUpperCase is not Turkish-aware (i → I, not İ).
class DataLabel extends StatelessWidget {
  const DataLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: harmoniaDataLabel(context).copyWith(color: color));
}

enum PillTone { success, primary, warning, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = PillTone.neutral});
  final String label;
  final PillTone tone;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final results = context.resultColors;
    final (bg, fg) = switch (tone) {
      PillTone.success => (palette.mintSoft, results.correct),
      PillTone.primary => (
        scheme.primary.withValues(alpha: .12),
        scheme.primary,
      ),
      PillTone.warning => (palette.sun.withValues(alpha: .28), palette.onSun),
      PillTone.neutral => (scheme.surfaceContainerHigh, palette.muted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Rounded progress bar (A) with an animated fill.
class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({
    super.key,
    required this.value,
    this.semanticsLabel,
  });
  final double value;
  final String? semanticsLabel;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: semanticsLabel,
      value: '%${(value * 100).round()}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 12,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: palette.line),
              TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0, 1)),
                duration: HarmoniaMotion.reduced(context)
                    ? Duration.zero
                    : HarmoniaMotion.slow,
                curve: HarmoniaMotion.emphasized,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.mint,
                      borderRadius: BorderRadius.circular(8),
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

/// Small stat tile (C) for result summaries.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HarmoniaSpacing.sm + 4,
        vertical: HarmoniaSpacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DataLabel(label),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Lesson mode chrome (Duolingo/Simply pattern): close, progress, counter.
/// No title bar; the question is the screen's only heading. [bottom] sits
/// in the thumb zone at the bottom of tall screens and scrolls with the
/// content on short ones or with large text.
class LessonScaffold extends StatelessWidget {
  const LessonScaffold({
    super.key,
    required this.progress,
    required this.top,
    this.bottom = const [],
    this.counter,
    this.closeLabel = 'Çalışmayı kapat',
  });

  final double progress;
  final List<Widget> top;
  final List<Widget> bottom;
  final String? counter;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HarmoniaSpacing.xs,
                HarmoniaSpacing.xs,
                HarmoniaSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('lesson_close'),
                    tooltip: closeLabel,
                    icon: Icon(Icons.close_rounded, color: palette.muted),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: HarmoniaSpacing.xs),
                  Expanded(
                    child: LessonProgressBar(
                      value: progress,
                      semanticsLabel: 'Tur ilerlemesi',
                    ),
                  ),
                  if (counter != null) ...[
                    const SizedBox(width: HarmoniaSpacing.md),
                    Text(counter!, style: harmoniaDataLabel(context)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    HarmoniaSpacing.lg,
                    HarmoniaSpacing.sm,
                    HarmoniaSpacing.lg,
                    HarmoniaSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (box.maxHeight -
                                  HarmoniaSpacing.sm -
                                  HarmoniaSpacing.lg)
                              .clamp(0, double.infinity),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...top,
                          if (bottom.isNotEmpty) ...[
                            const Spacer(),
                            const SizedBox(height: HarmoniaSpacing.md),
                            ...bottom,
                          ],
                        ],
                      ),
                    ),
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

/// One option in a [LevelPicker].
class LevelChoice {
  const LevelChoice({required this.id, required this.title, this.subtitle});
  final String id;
  final String title;
  final String? subtitle;
}

/// Compact level selector: a pill that opens a sheet. Replaces rows of
/// chips competing with the question. Disabled mid-round.
class LevelPicker extends StatelessWidget {
  const LevelPicker({
    super.key,
    required this.keyPrefix,
    required this.choices,
    required this.selectedId,
    required this.onSelected,
  });

  final String keyPrefix;
  final List<LevelChoice> choices;
  final String selectedId;

  /// Null while the level cannot change (round in progress).
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final current = choices.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => choices.first,
    );
    final enabled = onSelected != null && choices.length > 1;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Seviye: ${current.title}',
      hint: enabled ? 'Değiştirmek için dokun' : null,
      excludeSemantics: true,
      child: InkWell(
        key: Key('${keyPrefix}_level_picker'),
        borderRadius: BorderRadius.circular(999),
        onTap: !enabled
            ? null
            : () async {
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheet) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HarmoniaSpacing.lg,
                        0,
                        HarmoniaSpacing.lg,
                        HarmoniaSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Seviye seç', style: text.titleLarge),
                          const SizedBox(height: HarmoniaSpacing.md),
                          for (final c in choices) ...[
                            AnswerOption(
                              key: Key('${keyPrefix}_level_${c.id}'),
                              title: c.title,
                              subtitle: c.subtitle,
                              state: c.id == selectedId
                                  ? OptionState.selected
                                  : OptionState.idle,
                              onTap: () => Navigator.of(sheet).pop(c.id),
                            ),
                            const SizedBox(height: HarmoniaSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
                if (picked != null && picked != selectedId) {
                  onSelected!(picked);
                }
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.line, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current.title,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge,
                    ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: palette.muted,
                    ),
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

/// Two columns of equal-height tiles (one on very narrow screens). Built
/// from rows rather than a LayoutBuilder so it can live in scroll views
/// that size to their content.
class EqualHeightGrid extends StatelessWidget {
  const EqualHeightGrid({
    super.key,
    required this.children,
    this.narrowBreakpoint = 340,
  });
  final List<Widget> children;
  final double narrowBreakpoint;

  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width < narrowBreakpoint ? 1 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final cells = children.sublist(i, (i + cols).clamp(0, children.length));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: HarmoniaSpacing.sm),
                Expanded(child: j < cells.length ? cells[j] : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, r) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: HarmoniaSpacing.sm + 2),
          r,
        ],
      ],
    );
  }
}
