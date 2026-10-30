import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/practice_preferences.dart';
import 'home_data.dart';

/// Activity, not mastery: no rewards, pressure, countdown or inferred scores.
class RecentPracticeCard extends StatelessWidget {
  const RecentPracticeCard({
    super.key,
    required this.days,
    this.weeklyGoal,
    this.onWeeklyGoalChanged,
    this.loadingGoal = false,
    this.savingGoal = false,
    this.goalError,
    this.onRetryPreferences,
  });
  final List<PracticeDay> days;
  final WeeklyPracticeGoal? weeklyGoal;
  final Future<void> Function(WeeklyPracticeGoal? goal)? onWeeklyGoalChanged;
  final bool loadingGoal;
  final bool savingGoal;
  final String? goalError;
  final VoidCallback? onRetryPreferences;

  @override
  Widget build(BuildContext context) {
    final active = days.where((day) => day.practiced).length;
    final goal = weeklyGoal;
    final goalMet = goal != null && active >= goal.days;
    final goalActionPending = loadingGoal || savingGoal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Son 7 günde $active çalışma günü',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            Wrap(
              spacing: ResoniaSpacing.sm,
              runSpacing: ResoniaSpacing.sm,
              children: [
                for (final day in days)
                  Chip(
                    label: Text(
                      '${day.date.day}/${day.date.month} · '
                      '${day.practiced ? 'Çalışıldı' : 'Kayıt yok'}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            const Text(
              'Bu cihazdaki geçerli ve desteklenen turlar sayılır. '
              'Çalışma düzenini gösterir; beceri puanı değildir. '
              'Düşük doğru sayısı da çalışma günü sayılır.',
            ),
            if (onWeeklyGoalChanged != null) ...[
              const SizedBox(height: ResoniaSpacing.md),
              Text(
                'Gönüllü haftalık hedef',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                goal == null
                    ? 'İstersen kendin için bir gün hedefi seç. Hedef belirlemek zorunlu değildir.'
                    : '$active/${goal.days} gün${goalMet ? ' · Son 7 gün hedefin tamamlandı.' : ''}',
                key: const Key('weekly_goal_status'),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
              Wrap(
                spacing: ResoniaSpacing.sm,
                runSpacing: ResoniaSpacing.sm,
                children: [
                  ChoiceChip(
                    key: const Key('weekly_goal_none'),
                    label: const Text('Hedef yok'),
                    selected: goal == null,
                    onSelected: goalActionPending
                        ? null
                        : (_) => onWeeklyGoalChanged!(null),
                  ),
                  for (final choice in WeeklyPracticeGoal.values)
                    ChoiceChip(
                      key: Key('weekly_goal_${choice.days}'),
                      label: Text('${choice.days} gün'),
                      selected: goal == choice,
                      onSelected: goalActionPending
                          ? null
                          : (_) => onWeeklyGoalChanged!(choice),
                    ),
                ],
              ),
              if (loadingGoal)
                Padding(
                  padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: const Text('Haftalık hedef yükleniyor…'),
                  ),
                )
              else if (savingGoal)
                Padding(
                  padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: const Text('Haftalık hedef kaydediliyor…'),
                  ),
                ),
              if (goalError != null)
                Padding(
                  padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      goalError!,
                      key: const Key('weekly_goal_error'),
                    ),
                  ),
                ),
              if (goalError != null && onRetryPreferences != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('retry_preferences'),
                    onPressed: onRetryPreferences,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tercihleri yeniden yükle'),
                  ),
                ),
              const SizedBox(height: ResoniaSpacing.sm),
              const Text(
                'Bu hedef seri, beceri puanı veya sınav sonucu değildir. '
                'Kaçırınca ceza uygulanmaz; istediğin zaman değiştirebilir ya da kapatabilirsin.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
