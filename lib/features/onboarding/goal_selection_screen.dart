import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/models/learner_profile.dart';

String goalTitle(PracticeGoal goal) => switch (goal) {
  PracticeGoal.conservatory => 'Konservatuvar hazırlığı',
  PracticeGoal.foundations => 'Temel duyma ve ses',
  PracticeGoal.choir => 'Koro hazırlığı',
};

String goalDescription(PracticeGoal goal) => switch (goal) {
  PracticeGoal.conservatory =>
    'Tek ses, ritim, ezgi ve çok sesli işitme çalışmaları. Sınav kazanma garantisi verilmez.',
  PracticeGoal.foundations =>
    'Doğru notayı duyma ve söyleme, ritim ve kısa ezgi temeli.',
  PracticeGoal.choir =>
    'Kendi partini koruma ve girişler. Koro rotası henüz planlama aşamasında; şimdilik ortak temel çalışmaları gösterilir.',
};

/// Guest-first goal choice. Used for onboarding and later goal changes.
class GoalSelectionScreen extends StatelessWidget {
  const GoalSelectionScreen({
    super.key,
    required this.onSelected,
    this.selected,
    this.saving = false,
    this.errorText,
  });

  final ValueChanged<PracticeGoal> onSelected;
  final PracticeGoal? selected;
  final bool saving;
  final String? errorText;

  static IconData _icon(PracticeGoal g) => switch (g) {
    PracticeGoal.conservatory => Icons.school_outlined,
    PracticeGoal.foundations => Icons.hearing_outlined,
    PracticeGoal.choir => Icons.groups_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ResoniaSpacing.lg,
            ResoniaSpacing.xl,
            ResoniaSpacing.lg,
            ResoniaSpacing.lg,
          ),
          children: [
            const _BrandMark(),
            const SizedBox(height: ResoniaSpacing.lg),
            Text(
              'Vocalart',
              style: text.labelLarge?.copyWith(color: scheme.primary),
            ),
            Text('Ne için çalışıyorsun?', style: text.headlineMedium),
            const SizedBox(height: ResoniaSpacing.sm),
            Text(
              'Hesap açman gerekmez. Seçimin yalnız bu cihazda saklanır ve istediğin zaman değiştirilebilir.',
              style: text.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: ResoniaSpacing.lg),
            for (final goal in PracticeGoal.values)
              Padding(
                padding: const EdgeInsets.only(bottom: ResoniaSpacing.md),
                child: _GoalTile(
                  key: Key('goal_${goal.name}'),
                  icon: _icon(goal),
                  title: goalTitle(goal),
                  description: goalDescription(goal),
                  selected: goal == selected,
                  onTap: saving ? null : () => onSelected(goal),
                ),
              ),
            if (saving) const LinearProgressIndicator(),
            if (errorText != null)
              Semantics(
                liveRegion: true,
                child: Text(errorText!, key: const Key('goal_error')),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final border = selected ? scheme.primary : palette.line;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    scheme.primary.withValues(alpha: .07),
                    scheme.surfaceContainerLowest,
                  )
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(ResoniaRadius.card),
            border: Border.all(color: border, width: 2),
            boxShadow: [BoxShadow(color: border, offset: const Offset(0, 4))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(ResoniaRadius.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(ResoniaSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 28),
                  ),
                  const SizedBox(width: ResoniaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleMedium),
                        const SizedBox(height: ResoniaSpacing.xs),
                        Text(
                          description,
                          style: text.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: scheme.primary,
                      semanticLabel: 'Seçili',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App mark: a note head with a sound wave, drawn so it scales crisply.
class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    return ExcludeSemantics(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: palette.primaryDeep, offset: const Offset(0, 5)),
            ],
          ),
          child: CustomPaint(painter: _MarkPainter(palette.sun)),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.accent);
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final white = Paint()..color = Colors.white;
    canvas.save();
    canvas.translate(w * .36, h * .66);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * .30, height: h * .21),
      white,
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .46, h * .2, w * .07, h * .46),
        const Radius.circular(3),
      ),
      white,
    );
    final wave = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final r = w * (.16 + i * .1);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * .55, h * .3), radius: r),
        -0.9,
        1.3,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.accent != accent;
}
