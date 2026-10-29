import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_channel.dart';
import '../../app/app_services.dart';
import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../application/practice_preferences.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/learning/daily_plan.dart';
import '../../domain/learning/practice_resume.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/learning/starting_check.dart';
import '../../domain/models/learner_profile.dart';
import '../audio_lab/audio_lab_screen.dart';
import '../chord_exercise/chord_placeholder_screen.dart';
import '../common/content_status_panel.dart';
import '../common/foreground_refresh_state.dart';
import '../common/ui/harmonia_ui.dart';
import '../daily_plan/daily_plan_screen.dart';
import '../history/history_screen.dart';
import '../interval/interval_screen.dart';
import '../learning/exercise_launcher.dart';
import '../learning/micro_lesson_screen.dart';
import '../learning/next_step_text.dart';
import '../melody/melody_session_screen.dart';
import '../onboarding/goal_selection_screen.dart';
import '../onboarding/starting_check_screen.dart';
import '../pitch_comparison/pitch_comparison_screen.dart';
import '../rhythm_imitation/rhythm_imitation_screen.dart';
import '../single_tone_exercise/single_tone_exercise_screen.dart';
import '../single_tone_session/single_tone_session_screen.dart';
import '../skill_map/skill_map_screen.dart';
import 'home_data.dart';
import 'recent_practice_card.dart';
import 'skill_path.dart';

/// Honest module status shown to users; matches CURRENT_ROADMAP evidence.
enum ModuleAvailability { experimental, demo, awaitingContent, planned }

String availabilityLabel(ModuleAvailability a) => switch (a) {
  ModuleAvailability.experimental => 'Deneysel',
  ModuleAvailability.demo => 'Simülasyon',
  ModuleAvailability.awaitingContent => 'Kayıt bekleniyor',
  ModuleAvailability.planned => 'Henüz yok',
};

/// Main shell (A+C): Today path, Practice, Progress and Profile tabs.
class HomeScreen extends StatefulWidget {
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

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _refresh = 0;

  /// Tabs are built on first visit only, so opening the app reads local
  /// history once instead of once per tab.
  final Set<int> _visited = {0};

  void _select(int i) => setState(() {
    if (i == 0 || i == 2) _refresh++;
    _tab = i;
    _visited.add(i);
  });

  @override
  Widget build(BuildContext context) {
    final history = AppServices.maybeOf(context)?.history;
    final tabs = [
      _TodayTab(
        key: ValueKey('today_$_refresh'),
        profile: widget.profile,
        history: history,
        onOpenProfile: () => _select(3),
      ),
      _PracticeTab(profile: widget.profile, channel: widget.channel),
      SkillMapScreen(
        key: ValueKey('progress_$_refresh'),
        goal: widget.profile.goal,
        history: history,
      ),
      _ProfileTab(
        profile: widget.profile,
        history: history,
        onOpenSettings: widget.onOpenSettings,
      ),
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            for (final (i, t) in tabs.indexed)
              _visited.contains(i) ? t : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              key: Key('tab_today'),
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route),
              label: 'Bugün',
            ),
            NavigationDestination(
              key: Key('tab_practice'),
              icon: Icon(Icons.graphic_eq_outlined),
              selectedIcon: Icon(Icons.graphic_eq),
              label: 'Pratik',
            ),
            NavigationDestination(
              key: Key('tab_progress'),
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Gelişim',
            ),
            NavigationDestination(
              key: Key('tab_profile'),
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

// ───────────────────────────── Today ─────────────────────────────

class _TodayTab extends StatefulWidget {
  const _TodayTab({
    super.key,
    required this.profile,
    required this.history,
    required this.onOpenProfile,
  });
  final LearnerProfile profile;
  final ResultHistoryRepository? history;
  final VoidCallback onOpenProfile;
  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayView {
  const _TodayView(this.home, this.plan, this.startingCheck, this.resume);
  final HomeData home;
  final DailyPlan plan;
  final StartingCheckSummary startingCheck;
  final PracticeResume? resume;
}

class _TodayTabState extends ForegroundRefreshState<_TodayTab> {
  late Future<_TodayView> _data = _loadForView();

  @override
  void refreshAfterForeground() => _reload();

  Future<_TodayView> _loadForView() {
    final future = _load();
    // Own fast failures before FutureBuilder subscribes on the next frame;
    // the original future still delivers the error to the visible UI.
    future.ignore();
    return future;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _data = _loadForView();
    });
  }

  @override
  void didUpdateWidget(covariant _TodayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history ||
        oldWidget.profile.goal != widget.profile.goal) {
      _data = _loadForView();
    }
  }

  DailyBudget _budget = DailyBudget.twelve;
  WeeklyPracticeGoal? _weeklyGoal;
  PracticePreferencesRepository? _preferencesRepository;
  bool _preferencesSourceSeen = false;
  int? _preferencesRevision;
  int _preferencesLoadGeneration = 0;
  bool _loadingPreferences = false;
  bool _savingWeeklyGoal = false;
  bool _preferencesReadFailed = false;
  String? _weeklyGoalError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServices.maybeOf(context);
    final preferences = services?.preferences;
    final revision = services?.preferencesRevision ?? 0;
    final sourceChanged =
        !_preferencesSourceSeen ||
        !identical(_preferencesRepository, preferences);
    if (!sourceChanged && _preferencesRevision == revision) {
      return;
    }
    _preferencesSourceSeen = true;
    _preferencesRepository = preferences;
    _preferencesRevision = revision;
    _loadingPreferences = false;
    _savingWeeklyGoal = false;
    _preferencesReadFailed = false;
    _weeklyGoalError = null;
    if (sourceChanged) {
      final budgetChanged = _budget != DailyBudget.twelve;
      _budget = DailyBudget.twelve;
      _weeklyGoal = null;
      if (budgetChanged) _data = _loadForView();
    }
    _loadPreferences(preferences);
  }

  void _loadPreferences(PracticePreferencesRepository? preferences) {
    final generation = ++_preferencesLoadGeneration;
    if (preferences == null) {
      _loadingPreferences = false;
      return;
    }
    _loadingPreferences = true;
    // Reads run independently and never block the screen. The generation gate
    // prevents a slow pre-import read from overwriting freshly imported data.
    final budgetRead = preferences
        .loadDailyBudget()
        .then<void>((saved) {
          if (!mounted || generation != _preferencesLoadGeneration) return;
          final next = saved ?? DailyBudget.twelve;
          if (next == _budget) return;
          setState(() {
            _budget = next;
            _data = _loadForView();
          });
        })
        .catchError((Object _) => _reportPreferenceReadFailure(generation));
    final goalRead = preferences
        .loadWeeklyGoal()
        .then<void>((saved) {
          if (!mounted || generation != _preferencesLoadGeneration) return;
          if (saved == _weeklyGoal) return;
          setState(() => _weeklyGoal = saved);
        })
        .catchError((Object _) => _reportPreferenceReadFailure(generation));
    Future.wait<void>([budgetRead, goalRead]).whenComplete(() {
      if (!mounted || generation != _preferencesLoadGeneration) return;
      setState(() => _loadingPreferences = false);
    });
  }

  void _reportPreferenceReadFailure(int generation) {
    if (!mounted || generation != _preferencesLoadGeneration) return;
    const message =
        'Çalışma tercihleri tam yüklenemedi. Güvenli varsayılanlar kullanılıyor.';
    if (_preferencesReadFailed && _weeklyGoalError == message) return;
    setState(() {
      _preferencesReadFailed = true;
      _weeklyGoalError = message;
    });
  }

  void _retryPreferences() {
    final preferences = _preferencesRepository;
    if (preferences == null || !_preferencesReadFailed) return;
    setState(() {
      _preferencesReadFailed = false;
      _weeklyGoalError = null;
    });
    _loadPreferences(preferences);
  }

  Future<void> _setWeeklyGoal(WeeklyPracticeGoal? goal) async {
    if (_loadingPreferences || _savingWeeklyGoal) return;
    final preferences = AppServices.maybeOf(context)?.preferences;
    if (preferences == null) return;
    final generation = _preferencesLoadGeneration;
    setState(() {
      _savingWeeklyGoal = true;
      _preferencesReadFailed = false;
      _weeklyGoalError = null;
    });
    try {
      await preferences.saveWeeklyGoal(goal);
      if (mounted &&
          generation == _preferencesLoadGeneration &&
          identical(preferences, _preferencesRepository)) {
        setState(() => _weeklyGoal = goal);
      }
    } catch (_) {
      if (mounted &&
          generation == _preferencesLoadGeneration &&
          identical(preferences, _preferencesRepository)) {
        setState(
          () => _weeklyGoalError =
              'Haftalık hedef kaydedilemedi. Önceki seçimin korundu; yeniden deneyebilirsin.',
        );
      }
    } finally {
      if (mounted &&
          generation == _preferencesLoadGeneration &&
          identical(preferences, _preferencesRepository)) {
        setState(() => _savingWeeklyGoal = false);
      }
    }
  }

  Future<_TodayView> _load() async {
    final h = widget.history;
    final budget = _budget;
    final entries = h == null ? const <ResultHistoryEntry>[] : await h.load();
    final results = [for (final e in entries) e.result];
    final now = DateTime.now();
    return _TodayView(
      HomeData.build(
        graph: draftSkillGraph,
        goal: widget.profile.goal,
        results: results,
        now: now,
      ),
      DailyPlanner.plan(
        graph: draftSkillGraph,
        goal: widget.profile.goal,
        results: results,
        now: now,
        budget: budget,
      ),
      StartingCheckSummary.build(
        graph: draftSkillGraph,
        goal: widget.profile.goal,
        results: results,
      ),
      PracticeResume.latest(
        graph: draftSkillGraph,
        goal: widget.profile.goal,
        results: results,
        now: now,
      ),
    );
  }

  Future<void> _afterPush(Future<void> push) async {
    await push;
    _reload();
  }

  void _openStep(HomeData d) {
    final step = d.step;
    _afterPush(
      _push(
        context,
        measuredExerciseScreen(
          step.exercise,
          history: widget.history,
          retentionCheck: step.kind == NextStepKind.delayedCheck,
        ),
      ),
    );
  }

  void _openPlan() {
    final history = widget.history;
    if (history == null) return;
    _afterPush(
      _push(
        context,
        DailyPlanScreen(
          goal: widget.profile.goal,
          history: history,
          preferences: AppServices.maybeOf(context)?.preferences,
        ),
      ),
    );
  }

  void _openStartingCheck() {
    final history = widget.history;
    if (history == null) return;
    _afterPush(
      _push(
        context,
        StartingCheckScreen(goal: widget.profile.goal, history: history),
      ),
    );
  }

  void _openResume(PracticeResume resume) {
    _afterPush(
      _push(
        context,
        measuredExerciseScreen(
          resume.exercise,
          history: widget.history,
          retentionCheck: false,
        ),
      ),
    );
  }

  void _openNode(PathNode n) {
    final e = n.nextExercise;
    if (e != null) {
      _afterPush(
        _push(
          context,
          measuredExerciseScreen(
            e,
            history: widget.history,
            retentionCheck: false,
          ),
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => _ComingSkillSheet(node: n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: FutureBuilder<_TodayView>(
        future: _data,
        builder: (context, snap) {
          // FutureBuilder may retain old data while a replacement loads or
          // fails. Never show stale streak/path/actions as current evidence.
          final d =
              snap.connectionState == ConnectionState.done && !snap.hasError
              ? snap.data
              : null;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HarmoniaSpacing.lg,
                    HarmoniaSpacing.sm,
                    HarmoniaSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goalTitle(widget.profile.goal),
                              key: const Key('home_goal'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge?.copyWith(
                                color: context.palette.muted,
                              ),
                            ),
                            Text('Bugün', style: text.headlineMedium),
                          ],
                        ),
                      ),
                      const _BetaChip(),
                      const SizedBox(width: HarmoniaSpacing.xs),
                      if (d != null) _StreakBadge(data: d.home),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  HarmoniaSpacing.lg,
                  HarmoniaSpacing.md,
                  HarmoniaSpacing.lg,
                  HarmoniaSpacing.xl,
                ),
                sliver: SliverList.list(
                  children: [
                    if (widget.history != null) ...[
                      if (snap.connectionState != ConnectionState.done)
                        const _TodaySkeleton(key: Key('today_loading'))
                      else if (snap.hasError)
                        ContentStatusPanel(
                          key: const Key('today_error'),
                          kind: ContentStatusKind.error,
                          message:
                              'Geçmiş okunamadığı için öneri gösterilemiyor. Veri silinmedi. Yeniden dene veya Profil › Çalışma geçmişi bölümünü kontrol et.',
                          onRetry: _reload,
                        )
                      else ...[
                        _NextCard(
                          view: d!,
                          onOpen: () => _openStep(d.home),
                          onOpenPlan: _openPlan,
                        ),
                      ],
                    ],
                    if (d != null) ...[
                      SkillPath(
                        nodes: d.home.path,
                        focusId: d.home.step.node?.id,
                        focusLabel: todayStepText(d.home.step).$3.isEmpty
                            ? 'Buradasın'
                            : todayStepText(d.home.step).$3,
                        onOpen: _openNode,
                      ),
                      const SizedBox(height: HarmoniaSpacing.md),
                      if (!d.startingCheck.isComplete) ...[
                        _StartingCheckCard(
                          summary: d.startingCheck,
                          onOpen: _openStartingCheck,
                        ),
                        const SizedBox(height: HarmoniaSpacing.md),
                      ],
                      if (d.resume case final resume?) ...[
                        _ResumePracticeCard(
                          resume: resume,
                          onOpen: () => _openResume(resume),
                        ),
                        const SizedBox(height: HarmoniaSpacing.md),
                      ],
                      RecentPracticeCard(
                        key: const Key('recent_practice'),
                        days: d.home.recentPractice,
                        weeklyGoal: _weeklyGoal,
                        onWeeklyGoalChanged:
                            AppServices.maybeOf(context)?.preferences == null
                            ? null
                            : _setWeeklyGoal,
                        savingGoal: _savingWeeklyGoal,
                        loadingGoal: _loadingPreferences,
                        goalError: _weeklyGoalError,
                        onRetryPreferences: _preferencesReadFailed
                            ? _retryPreferences
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StartingCheckCard extends StatelessWidget {
  const _StartingCheckCard({required this.summary, required this.onOpen});

  final StartingCheckSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('starting_check_card'),
    child: Padding(
      padding: const EdgeInsets.all(HarmoniaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusPill('İsteğe bağlı'),
          const SizedBox(height: HarmoniaSpacing.sm),
          Text(
            'Başlangıç kontrolü',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            '${summary.completedCount}/${summary.items.length} kısa tur tamamlandı. Yalnız uygulamanın güvenilir ölçebildiği alanlardan çalışma başlangıcı önerir.',
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          ChunkyButton(
            key: const Key('starting_check_open'),
            onPressed: onOpen,
            tone: ChunkyTone.neutral,
            icon: Icons.fact_check_outlined,
            label: summary.completedCount == 0
                ? 'Kontrole başla'
                : 'Kontrole devam et',
          ),
        ],
      ),
    ),
  );
}

class _ResumePracticeCard extends StatelessWidget {
  const _ResumePracticeCard({required this.resume, required this.onOpen});

  final PracticeResume resume;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('resume_practice_card'),
    child: Padding(
      padding: const EdgeInsets.all(HarmoniaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusPill('Yerel geçmiş'),
          const SizedBox(height: HarmoniaSpacing.sm),
          Text(
            'Son çalışmaya dön',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(resume.exercise.title),
          const SizedBox(height: HarmoniaSpacing.xs),
          Text(
            resume.previousMeasurementValid
                ? 'Son tur kaydedildi. Kaldığın sorudan değil, yeni bir turdan başlarsın.'
                : 'Son ölçüm tamamlanamadı. Aynı çalışmayı yeni bir turla yeniden deneyebilirsin.',
          ),
          const Text('Ses, mikrofon veya yarım oturum otomatik açılmaz.'),
          const SizedBox(height: HarmoniaSpacing.md),
          ChunkyButton(
            key: const Key('resume_practice_open'),
            onPressed: onOpen,
            tone: ChunkyTone.neutral,
            icon: Icons.replay_outlined,
            label: 'Yeni tur aç',
          ),
        ],
      ),
    ),
  );
}

/// Static, non-interactive placeholders: never fake progress or measurements.
/// One live announcement, with decorative shapes excluded from semantics.
class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget block(double width, double height) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: width,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(HarmoniaRadius.chip),
        ),
      ),
    );
    return Semantics(
      liveRegion: true,
      label:
          'Bugünkü öneri için yerel geçmiş okunuyor. Öneri ve beceri yolu henüz hazır değil.',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bugün hazırlanıyor',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text('Önerin ve beceri yolun için yerel geçmiş okunuyor.'),
          const SizedBox(height: HarmoniaSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarmoniaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  block(.65, 20),
                  const SizedBox(height: HarmoniaSpacing.md),
                  block(1, 16),
                  const SizedBox(height: HarmoniaSpacing.sm),
                  block(.8, 16),
                  const SizedBox(height: HarmoniaSpacing.lg),
                  block(1, 48),
                ],
              ),
            ),
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: HarmoniaSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: HarmoniaSpacing.md),
                  Expanded(child: block(.75, 20)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One place for every "this is a draft" note, instead of repeating it on
/// each card.
class _BetaChip extends StatelessWidget {
  const _BetaChip();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Beta sürüm hakkında',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('beta_info'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => const _BetaSheet(),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Beta',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BetaSheet extends StatelessWidget {
  const _BetaSheet();
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: HarmoniaSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: HarmoniaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                Text(
                  body,
                  style: text.bodyMedium?.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HarmoniaSpacing.lg,
          0,
          HarmoniaSpacing.lg,
          HarmoniaSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harmonia beta', style: text.titleLarge),
            const SizedBox(height: HarmoniaSpacing.md),
            row(
              Icons.edit_note_rounded,
              'Taslak ölçütler',
              'Çalışmalar ve geçme ölçütleri eğitimci onayı bekliyor; sıra ve süreler değişebilir.',
            ),
            row(
              Icons.mic_none_rounded,
              'Söyleme puanı kapalı',
              'Ses tanıma gerçek kayıtlarla doğrulanana kadar söyleme çalışmaları doğru/yanlış göstermez.',
            ),
            row(
              Icons.lock_outline_rounded,
              'Verilerin cihazında',
              'Hesap gerekmez; ses kayıtları analizden sonra silinir ve hiçbir yere gönderilmez.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.data});
  final HomeData data;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = data.streakDays > 0;
    return Semantics(
      label: active
          ? '${data.streakDays} günlük çalışma serisi'
          : 'Çalışma serisi yok',
      excludeSemantics: true,
      child: Container(
        key: const Key('streak_badge'),
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? palette.sun.withValues(alpha: .22)
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 20,
              color: active ? const Color(0xFFF57C00) : palette.muted,
            ),
            const SizedBox(width: 4),
            Text(
              '${data.streakDays}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: active ? palette.onSun : palette.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single primary action (LEARN-03b) with today's minute goal beside
/// it. One card, one button: the path below is for browsing.
class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.view,
    required this.onOpen,
    required this.onOpenPlan,
  });
  final _TodayView view;
  final VoidCallback onOpen;
  final VoidCallback onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final step = view.home.step;
    final (_, reason, action) = todayStepText(step);
    final e = step.exercise;
    final done = action.isEmpty;
    final plan = view.plan;
    final minutesDone = plan.blocks.fold<int>(
      0,
      (sum, b) =>
          sum +
          (b.roundsDoneToday.clamp(0, b.rounds) * b.exercise.draftMinutes),
    );
    final target = plan.budget.minutes;
    return Card(
      key: const Key('today_card'),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DataLabel('Bugünkü öneri'),
                      const SizedBox(height: 2),
                      Text(
                        done
                            ? 'Bugünlük tamam'
                            : step.node?.title ?? 'Sıradaki çalışma',
                        style: text.titleLarge,
                      ),
                      if (e != null)
                        Text(
                          '${e.title} · ~${e.draftMinutes} dk',
                          style: text.bodyMedium?.copyWith(
                            color: context.palette.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: HarmoniaSpacing.sm),
                _MinuteRing(
                  done: minutesDone,
                  target: target,
                  onTap: onOpenPlan,
                ),
              ],
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            Text(
              reason,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium,
            ),
            if (!done) ...[
              const SizedBox(height: HarmoniaSpacing.md),
              ChunkyButton(
                key: const Key('today_action'),
                label: action,
                icon: step.kind == NextStepKind.delayedCheck
                    ? Icons.verified_outlined
                    : Icons.play_arrow_rounded,
                onPressed: onOpen,
              ),
            ] else ...[
              const SizedBox(height: HarmoniaSpacing.sm),
              TextButton(
                onPressed: onOpenPlan,
                style: TextButton.styleFrom(foregroundColor: scheme.primary),
                child: const Text('Günlük planı aç'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Today's minutes against the chosen 5/12/15 plan; opens the plan.
class _MinuteRing extends StatelessWidget {
  const _MinuteRing({
    required this.done,
    required this.target,
    required this.onTap,
  });
  final int done;
  final int target;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final value = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: 'Günlük çalışma rotası: $target dakikanın $done dakikası',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('open_daily_plan'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: value),
                  duration: HarmoniaMotion.reduced(context)
                      ? Duration.zero
                      : HarmoniaMotion.slow,
                  builder: (context, v, _) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    backgroundColor: palette.line,
                    color: v >= 1 ? palette.mint : scheme.primary,
                  ),
                ),
              ),
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$done',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '/$target dk',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSkillSheet extends StatelessWidget {
  const _ComingSkillSheet({required this.node});
  final PathNode node;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lessons = draftMicroLessons
        .forSkill(node.node.id)
        .where(
          (l) =>
              l.route == node.node.route && l.dimension == node.node.dimension,
        )
        .toList();
    return SafeArea(
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
            Text(node.node.title, style: text.titleLarge),
            const SizedBox(height: HarmoniaSpacing.xs),
            Text(node.node.goal),
            const SizedBox(height: HarmoniaSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(nodeStateText(node)),
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            Text(
              supportLabel(node.node.support),
              style: text.bodySmall?.copyWith(color: context.palette.muted),
            ),
            for (final l in lessons) ...[
              const SizedBox(height: HarmoniaSpacing.md),
              ChunkyButton(
                label: 'Metin taslağını oku',
                tone: ChunkyTone.neutral,
                icon: Icons.menu_book_outlined,
                onPressed: () {
                  Navigator.of(context).pop();
                  _push(context, MicroLessonScreen(lesson: l));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Practice ─────────────────────────────

class _PracticeTab extends StatelessWidget {
  const _PracticeTab({required this.profile, required this.channel});
  final LearnerProfile profile;
  final AppChannel channel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final history = AppServices.maybeOf(context)?.history;
    Widget section(String title, {String? pill}) => Padding(
      padding: const EdgeInsets.only(
        top: HarmoniaSpacing.lg,
        bottom: HarmoniaSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Text(title, style: text.titleLarge),
          if (pill != null) ...[
            const SizedBox(width: HarmoniaSpacing.sm),
            StatusPill(pill),
          ],
        ],
      ),
    );
    Widget grid(List<Widget> tiles) => EqualHeightGrid(children: tiles);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarmoniaSpacing.lg,
          HarmoniaSpacing.sm,
          HarmoniaSpacing.lg,
          HarmoniaSpacing.xl,
        ),
        children: [
          Text('Pratik', style: text.headlineMedium),
          section('Dinle'),
          grid([
            _ModuleTile(
              key: const Key('open_pitch_comparison'),
              icon: Icons.swap_vert_rounded,
              color: const Color(0xFF5B46F5),
              title: 'Tiz mi, pes mi?',
              subtitle: 'İki sesi karşılaştır',
              onTap: () =>
                  _push(context, PitchComparisonScreen(history: history)),
            ),
            _ModuleTile(
              key: const Key('open_interval'),
              icon: Icons.stairs_outlined,
              color: const Color(0xFF0E8F7E),
              title: 'Dereceyi bul',
              subtitle: 'Hareketli do ile',
              onTap: () => _push(context, IntervalScreen(history: history)),
            ),
            _ModuleTile(
              key: const Key('open_rhythm_imitation'),
              icon: Icons.touch_app_outlined,
              color: const Color(0xFFE5483A),
              title: 'Ritim tekrarı',
              subtitle: 'Dinle ve dokun',
              onTap: () =>
                  _push(context, RhythmImitationScreen(history: history)),
            ),
          ]),
          section('Söyle', pill: 'Puan yok'),
          grid([
            _ModuleTile(
              key: const Key('open_single_tone_session'),
              icon: Icons.mic_none_rounded,
              color: const Color(0xFFC2410C),
              title: 'Tek ses',
              subtitle: 'Dinle ve söyle',
              onTap: () => _push(context, const SingleToneSessionScreen()),
            ),
            _ModuleTile(
              key: const Key('open_melody_session'),
              icon: Icons.queue_music_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Kısa ezgi',
              subtitle: 'Üç tonu tekrar et',
              onTap: () => _push(context, const MelodySessionScreen()),
            ),
          ]),
          if (channel.showsDeveloperTools) ...[
            section('Geliştirici'),
            grid([
              _ModuleTile(
                key: const Key('open_audio_lab'),
                icon: Icons.tune_rounded,
                color: const Color(0xFF475569),
                title: 'Ses ve ortam kontrolü',
                subtitle: 'Kayıt kalitesi',
                onTap: () => _push(context, const AudioLabScreen()),
              ),
              _ModuleTile(
                key: const Key('open_single_tone'),
                icon: Icons.music_note_outlined,
                color: const Color(0xFF475569),
                title: 'Tek ses sonuç örnekleri',
                subtitle: availabilityLabel(ModuleAvailability.demo),
                onTap: () => _push(context, SingleToneExerciseScreen()),
              ),
              _ModuleTile(
                key: const Key('open_chord_placeholders'),
                icon: Icons.piano_outlined,
                color: const Color(0xFF475569),
                title: '2 / 3 / 4 sesli piyano',
                subtitle: availabilityLabel(ModuleAvailability.awaitingContent),
                onTap: () => _push(context, const ChordPlaceholderScreen()),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? Color.lerp(color, Colors.white, .35)! : color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(HarmoniaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint, size: 26),
              ),
              const SizedBox(height: HarmoniaSpacing.sm + 4),
              Text(title, style: text.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(color: context.palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Profile ─────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.history,
    required this.onOpenSettings,
  });
  final LearnerProfile profile;
  final ResultHistoryRepository? history;
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget row(Key key, IconData icon, String label, VoidCallback onTap) =>
        ListTile(
          key: key,
          minTileHeight: 56,
          leading: Icon(icon, color: scheme.primary),
          title: Text(label, style: text.titleMedium),
          trailing: Icon(Icons.chevron_right, color: context.palette.muted),
          onTap: onTap,
        );
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          HarmoniaSpacing.lg,
          HarmoniaSpacing.md,
          HarmoniaSpacing.lg,
          HarmoniaSpacing.xl,
        ),
        children: [
          Text('Profil', style: text.headlineSmall),
          const SizedBox(height: HarmoniaSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(HarmoniaSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primary.withValues(alpha: .14),
                    child: Icon(Icons.person, color: scheme.primary),
                  ),
                  const SizedBox(width: HarmoniaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Misafir', style: text.titleMedium),
                        Text(
                          goalTitle(profile.goal),
                          style: text.bodySmall?.copyWith(
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (history != null) ...[
                  row(
                    const Key('open_history'),
                    Icons.history,
                    'Çalışma geçmişi',
                    () => _push(context, HistoryScreen(history: history!)),
                  ),
                  const Divider(indent: 56),
                ],
                row(
                  const Key('open_skill_map'),
                  Icons.account_tree_outlined,
                  'Beceri haritası',
                  () => _push(
                    context,
                    SkillMapScreen(goal: profile.goal, history: history),
                  ),
                ),
                const Divider(indent: 56),
                row(
                  const Key('open_settings'),
                  Icons.settings_outlined,
                  'Ayarlar, gizlilik ve yardım',
                  onOpenSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          Text(
            'Hesap gerekmez. Verilerin bu cihazda kalır.',
            style: text.bodySmall?.copyWith(color: context.palette.muted),
          ),
        ],
      ),
    );
  }
}
