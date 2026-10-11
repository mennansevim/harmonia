import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../learning/next_step_text.dart';
import '../../domain/models/learner_profile.dart';
import '../audio_lab/audio_lab_screen.dart';
import '../chord_exercise/chord_placeholder_screen.dart';
import '../history/history_screen.dart';
import '../onboarding/goal_selection_screen.dart';
import '../rhythm_imitation/rhythm_imitation_screen.dart';
import '../skill_map/skill_map_screen.dart';
import '../single_tone_exercise/single_tone_exercise_screen.dart';
import '../single_tone_session/single_tone_session_screen.dart';

/// Honest module status shown to users; matches CURRENT_ROADMAP evidence.
enum ModuleAvailability { experimental, demo, awaitingContent, planned }

String availabilityLabel(ModuleAvailability a) => switch (a) {
  ModuleAvailability.experimental => 'Deneysel',
  ModuleAvailability.demo => 'Simülasyon',
  ModuleAvailability.awaitingContent => 'Kayıt bekleniyor',
  ModuleAvailability.planned => 'Henüz yok',
};

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.profile,
    required this.onOpenSettings,
  });

  final LearnerProfile profile;
  final VoidCallback onOpenSettings;

  void _push(BuildContext context, Widget screen) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harmonia'),
        actions: [
          if (AppServices.maybeOf(context)?.history case final history?)
            IconButton(
              key: const Key('open_history'),
              tooltip: 'Çalışma geçmişi',
              icon: const Icon(Icons.history),
              onPressed: () => _push(context, HistoryScreen(history: history)),
            ),
          IconButton(
            key: const Key('open_skill_map'),
            tooltip: 'Beceri haritası',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => _push(
              context,
              SkillMapScreen(
                goal: profile.goal,
                history: AppServices.maybeOf(context)?.history,
              ),
            ),
          ),
          IconButton(
            key: const Key('open_settings'),
            tooltip: 'Ayarlar ve yardım',
            icon: const Icon(Icons.settings_outlined),
            onPressed: onOpenSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(HarmoniaSpacing.lg),
          children: [
            Text(
              goalTitle(profile.goal),
              key: const Key('home_goal'),
              style: text.titleMedium?.copyWith(color: scheme.secondary),
            ),
            const SizedBox(height: HarmoniaSpacing.xs),
            Text('Bugün buradan başla', style: text.headlineSmall),
            const SizedBox(height: HarmoniaSpacing.md),
            if (AppServices.maybeOf(context)?.history case final history?) ...[
              _TodayCard(history: history),
              const SizedBox(height: HarmoniaSpacing.md),
            ],
            _PrimaryCard(
              onPressed: () => _push(context, const AudioLabScreen()),
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            _ModuleTile(
              key: const Key('open_single_tone_session'),
              icon: Icons.hearing,
              title: 'Tek ses: dinle ve söyle',
              subtitle:
                  'Gerçek kayıtla akış. Doğru/yanlış kararı ses tanıma doğrulanana kadar kapalı.',
              availability: ModuleAvailability.experimental,
              onTap: () => _push(context, const SingleToneSessionScreen()),
            ),
            _ModuleTile(
              key: const Key('open_rhythm_imitation'),
              icon: Icons.touch_app_outlined,
              title: 'Ritim tekrarı',
              subtitle:
                  'Dinle ve dokunarak tekrar et; vuruş vuruş açıklama. Taslak içerik.',
              availability: ModuleAvailability.experimental,
              onTap: () => _push(
                context,
                RhythmImitationScreen(
                  history: AppServices.maybeOf(context)?.history,
                ),
              ),
            ),
            const SizedBox(height: HarmoniaSpacing.lg),
            Text('Önizlemeler', style: text.titleMedium),
            const SizedBox(height: HarmoniaSpacing.sm),
            _ModuleTile(
              key: const Key('open_single_tone'),
              icon: Icons.music_note_outlined,
              title: 'Tek ses sonuç örnekleri',
              subtitle:
                  'Sonuç ekranlarını hazır senaryolarla gör. Sesin ölçülmez.',
              availability: ModuleAvailability.demo,
              onTap: () => _push(context, SingleToneExerciseScreen()),
            ),
            _ModuleTile(
              key: const Key('open_chord_placeholders'),
              icon: Icons.library_music_outlined,
              title: '2 / 3 / 4 sesli piyano',
              subtitle: 'Gerçek piyano kayıtları eklenince açılacak.',
              availability: ModuleAvailability.awaitingContent,
              onTap: () => _push(context, const ChordPlaceholderScreen()),
            ),
            const SizedBox(height: HarmoniaSpacing.lg),
            Text('Planlanan çalışmalar', style: text.titleMedium),
            const SizedBox(height: HarmoniaSpacing.sm),
            for (final (icon, title) in const [
              (Icons.queue_music_outlined, 'Kısa ezgi tekrarı'),
              (Icons.swap_vert, 'Aralık duyma'),
              (Icons.calendar_today_outlined, 'Günlük çalışma rotası'),
            ])
              _ModuleTile(
                icon: icon,
                title: title,
                subtitle: 'Ölçümü doğrulanınca eklenecek.',
                availability: ModuleAvailability.planned,
              ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusChip(availability: ModuleAvailability.experimental),
            const SizedBox(height: HarmoniaSpacing.sm),
            Text('Ses ve ortam kontrolü', style: text.titleLarge),
            const SizedBox(height: HarmoniaSpacing.xs),
            const Text(
              'Ortam sessizliğini ölç, kısa bir kayıt al ve kayıt kalitesini gör. Mikrofon yalnız sen başlatınca açılır; kayıt cihazından çıkmaz. Puan verilmez.',
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            FilledButton.icon(
              key: const Key('open_audio_lab'),
              onPressed: onPressed,
              icon: const Icon(Icons.mic_none),
              label: const Text('Kontrolü başlat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.availability,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ModuleAvailability availability;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: HarmoniaSpacing.sm),
    child: ListTile(
      enabled: onTap != null,
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: HarmoniaSpacing.xs),
          _StatusChip(availability: availability),
        ],
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.availability});
  final ModuleAvailability availability;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(HarmoniaRadius.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HarmoniaSpacing.sm,
            vertical: HarmoniaSpacing.xs,
          ),
          child: Text(
            availabilityLabel(availability),
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
        ),
      ),
    );
  }
}

/// One recommended action from local history (LEARN-03a). Rule-based, no AI.
class _TodayCard extends StatefulWidget {
  const _TodayCard({required this.history});
  final ResultHistoryRepository history;
  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  late Future<NextStep> _step = _load();

  Future<NextStep> _load() async {
    final entries = await widget.history.load();
    return RhythmNextStepPolicy.recommend(
      results: [for (final e in entries) e.result],
      patterns: draftRhythmPatterns,
      now: DateTime.now(),
    );
  }

  Future<void> _open(NextStep step) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RhythmImitationScreen(
          history: widget.history,
          initialPatternId: step.pattern?.exercise.exercise.id,
          retentionCheck: step.kind == NextStepKind.delayedCheck,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _step = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NextStep>(
    future: _step,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(height: 4, child: LinearProgressIndicator());
      }
      if (snapshot.hasError) {
        return const Text(
          'Geçmiş okunamadığı için öneri gösterilemiyor. Ayrıntı için Geçmiş ekranına bak.',
          key: Key('today_error'),
        );
      }
      final step = snapshot.data!;
      final (title, reason, action) = nextStepText(step);
      return Card(
        key: const Key('today_card'),
        child: Padding(
          padding: const EdgeInsets.all(HarmoniaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bugünkü öneri',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: HarmoniaSpacing.xs),
              Text(reason),
              if (action.isNotEmpty) ...[
                const SizedBox(height: HarmoniaSpacing.sm),
                FilledButton(
                  key: const Key('today_action'),
                  onPressed: () => _open(step),
                  child: Text(action),
                ),
              ],
              const SizedBox(height: HarmoniaSpacing.xs),
              Text(
                draftCriterionNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
