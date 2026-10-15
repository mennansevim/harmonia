import 'package:flutter/material.dart';

import '../../app/app_channel.dart';
import '../../app/app_services.dart';
import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/learning/today_planner.dart';
import '../../domain/models/learner_profile.dart';
import '../daily_plan/daily_plan_screen.dart';
import '../learning/exercise_launcher.dart';
import '../learning/next_step_text.dart';
import '../audio_lab/audio_lab_screen.dart';
import '../chord_exercise/chord_placeholder_screen.dart';
import '../common/content_status_panel.dart';
import '../history/history_screen.dart';
import '../interval/interval_screen.dart';
import '../melody/melody_session_screen.dart';
import '../onboarding/goal_selection_screen.dart';
import '../pitch_comparison/pitch_comparison_screen.dart';
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
    this.channel = AppChannel.dev,
  });

  final LearnerProfile profile;

  /// Beta hides developer diagnostics, simulations and placeholders.
  final AppChannel channel;
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
              _TodayCard(history: history, goal: profile.goal),
              const SizedBox(height: HarmoniaSpacing.md),
            ],
            if (channel.showsDeveloperTools) ...[
              _PrimaryCard(
                onPressed: () => _push(context, const AudioLabScreen()),
              ),
              const SizedBox(height: HarmoniaSpacing.sm),
            ],
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
              key: const Key('open_pitch_comparison'),
              icon: Icons.swap_vert,
              title: 'Tiz mi, pes mi?',
              subtitle:
                  'İki sesten tiz olanı seç; dinleme çalışması, mikrofon yok. Taslak içerik.',
              availability: ModuleAvailability.experimental,
              onTap: () => _push(
                context,
                PitchComparisonScreen(
                  history: AppServices.maybeOf(context)?.history,
                ),
              ),
            ),
            if (AppServices.maybeOf(context)?.history case final history?)
              _ModuleTile(
                key: const Key('open_daily_plan'),
                icon: Icons.calendar_today_outlined,
                title: 'Günlük çalışma rotası',
                subtitle:
                    '5, 12 veya 15 dakikalık plan: kontrol, tekrar ve yeni. Taslak süreler.',
                availability: ModuleAvailability.experimental,
                onTap: () => _push(
                  context,
                  DailyPlanScreen(
                    goal: profile.goal,
                    history: history,
                    preferences: AppServices.maybeOf(context)?.preferences,
                  ),
                ),
              ),
            _ModuleTile(
              key: const Key('open_interval'),
              icon: Icons.stacked_line_chart,
              title: 'Dereceyi bul (hareketli do)',
              subtitle:
                  'Tonu duy, do\'ya göre dereceyi seç; dinleme çalışması. Taslak içerik.',
              availability: ModuleAvailability.experimental,
              onTap: () => _push(
                context,
                IntervalScreen(history: AppServices.maybeOf(context)?.history),
              ),
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
            _ModuleTile(
              key: const Key('open_melody_session'),
              icon: Icons.queue_music_outlined,
              title: 'Kısa ezgi tekrarı',
              subtitle:
                  'Sentetik üç ton: dinle ve söyle. Yerel analiz, puan yok.',
              availability: ModuleAvailability.experimental,
              onTap: () => _push(context, const MelodySessionScreen()),
            ),
            if (channel.showsDeveloperTools) ...[
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
            ],
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

/// One recommended action across the goal's measured skills (LEARN-03b).
/// Rule-based, no AI.
class _TodayCard extends StatefulWidget {
  const _TodayCard({required this.history, required this.goal});
  final ResultHistoryRepository history;
  final PracticeGoal goal;
  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  late Future<TodayStep> _step = _loadForView();

  Future<TodayStep> _loadForView() {
    final future = _load();
    // Own fast failures before FutureBuilder subscribes on the next frame.
    // Return the original future so the error still reaches the visible UI.
    future.ignore();
    return future;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _step = _loadForView();
    });
  }

  @override
  void didUpdateWidget(covariant _TodayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history || oldWidget.goal != widget.goal) {
      _step = _loadForView();
    }
  }

  Future<TodayStep> _load() async {
    final entries = await widget.history.load();
    return TodayPlanner.recommend(
      graph: draftSkillGraph,
      goal: widget.goal,
      results: [for (final e in entries) e.result],
      now: DateTime.now(),
    );
  }

  Future<void> _open(TodayStep step) async {
    final retention = step.kind == NextStepKind.delayedCheck;
    final screen = measuredExerciseScreen(
      step.exercise,
      history: widget.history,
      retentionCheck: retention,
    );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TodayStep>(
    future: _step,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const ContentStatusPanel(
          key: Key('today_loading'),
          kind: ContentStatusKind.loading,
          message: 'Bugünkü öneri için yerel geçmiş okunuyor.',
        );
      }
      if (snapshot.hasError) {
        return ContentStatusPanel(
          key: const Key('today_error'),
          kind: ContentStatusKind.error,
          message:
              'Geçmiş okunamadığı için öneri gösterilemiyor. Veri silinmedi. Yeniden dene veya Geçmiş ekranını kontrol et.',
          onRetry: _reload,
        );
      }
      final step = snapshot.data!;
      final (title, reason, action) = todayStepText(step);
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
                'Taslak ölçütler eğitimci onayı bekliyor. Sıra beceri haritasındaki rotana göre.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
