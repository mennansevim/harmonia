import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HarmoniaSpacing.lg),
          children: [
            Text('Harmonia', style: text.headlineMedium),
            const SizedBox(height: HarmoniaSpacing.sm),
            Text('Ne için çalışıyorsun?', style: text.titleLarge),
            const SizedBox(height: HarmoniaSpacing.sm),
            const Text(
              'Hesap açman gerekmez. Seçimin yalnız bu cihazda saklanır ve istediğin zaman değiştirilebilir.',
            ),
            const SizedBox(height: HarmoniaSpacing.lg),
            for (final goal in PracticeGoal.values)
              Padding(
                padding: const EdgeInsets.only(bottom: HarmoniaSpacing.md),
                child: Card(
                  child: InkWell(
                    key: Key('goal_${goal.name}'),
                    borderRadius: BorderRadius.circular(HarmoniaRadius.card),
                    onTap: saving ? null : () => onSelected(goal),
                    child: Padding(
                      padding: const EdgeInsets.all(HarmoniaSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(goalTitle(goal), style: text.titleMedium),
                                const SizedBox(height: HarmoniaSpacing.xs),
                                Text(goalDescription(goal)),
                              ],
                            ),
                          ),
                          if (goal == selected)
                            const Icon(
                              Icons.check_circle,
                              semanticLabel: 'Seçili',
                            ),
                        ],
                      ),
                    ),
                  ),
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
