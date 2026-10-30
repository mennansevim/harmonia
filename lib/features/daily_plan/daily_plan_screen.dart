import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/practice_preferences.dart';
import '../../application/result_history.dart';
import '../../domain/learning/daily_plan.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/models/learner_profile.dart';
import '../learning/exercise_launcher.dart';
import '../learning/next_step_text.dart';
import '../common/content_status_panel.dart';
import '../common/foreground_refresh_state.dart';
import '../common/ui/resonia_ui.dart';

/// LEARN-03 view: today's timed plan. Rule-based; durations, review
/// intervals and criteria are drafts awaiting educator review.
class DailyPlanScreen extends StatefulWidget {
  const DailyPlanScreen({
    super.key,
    required this.goal,
    required this.history,
    this.graph,
    this.catalog,
    this.preferences,
    this.clock,
    this.exerciseScreen,
  });
  final PracticeGoal goal;
  final ResultHistoryRepository history;

  /// Remembers the chosen budget on this device (optional).
  final PracticePreferencesRepository? preferences;
  final SkillGraph? graph;
  final List<MeasuredExercise>? catalog;
  final DateTime Function()? clock;

  /// Test seam; defaults to the real exercise screens.
  final Widget Function(MeasuredExercise exercise, bool retentionCheck)?
  exerciseScreen;

  @override
  State<DailyPlanScreen> createState() => _DailyPlanScreenState();
}

class _DailyPlanScreenState extends ForegroundRefreshState<DailyPlanScreen> {
  var _budget = DailyBudget.twelve;
  late Future<DailyPlan> _plan = _loadForView();

  var _budgetRestored = false;

  Future<DailyPlan> _loadForView() {
    final pending = _load();
    // A rapid error may arrive between setState and FutureBuilder's next
    // subscription. Observe it now; return the original future so the UI
    // still receives the error, never an invented successful plan.
    pending.ignore();
    return pending;
  }

  Future<DailyPlan> _load() async {
    if (!_budgetRestored) {
      _budgetRestored = true;
      final saved = await widget.preferences?.loadDailyBudget();
      if (saved != null && mounted) setState(() => _budget = saved);
    }
    final entries = await widget.history.load();
    return DailyPlanner.plan(
      graph: widget.graph ?? draftSkillGraph,
      goal: widget.goal,
      results: [for (final e in entries) e.result],
      now: (widget.clock ?? DateTime.now)(),
      budget: _budget,
      catalog: widget.catalog,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _plan = _loadForView();
    });
  }

  @override
  void refreshAfterForeground() => _reload();

  @override
  void didUpdateWidget(covariant DailyPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history == widget.history &&
        oldWidget.goal == widget.goal &&
        oldWidget.preferences == widget.preferences) {
      return;
    }
    if (oldWidget.preferences != widget.preferences) {
      _budget = DailyBudget.twelve;
      _budgetRestored = false;
    }
    _plan = _loadForView();
  }

  Future<void> _open(PlanBlock b) async {
    final screen =
        widget.exerciseScreen?.call(b.exercise, b.retention) ??
        measuredExerciseScreen(
          b.exercise,
          history: widget.history,
          retentionCheck: b.retention,
        );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LessonScaffold(
      progress: null,
      counter: 'Plan',
      closeLabel: 'Günlük planı kapat',
      top: [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill('Taslak plan'),
        ),
        const SizedBox(height: ResoniaSpacing.md),
        Text('Günlük çalışma rotası', style: text.headlineSmall),
        const Text('Bugün ne kadar vaktin var?'),
        const SizedBox(height: ResoniaSpacing.md),
        SegmentedButton<DailyBudget>(
          key: const Key('plan_budget'),
          segments: [
            for (final b in DailyBudget.values)
              ButtonSegment(
                value: b,
                label: Text('${b.minutes} dk', key: Key('budget_${b.minutes}')),
              ),
          ],
          selected: {_budget},
          onSelectionChanged: (s) {
            _budget = s.single;
            // Convenience only; a failed save keeps today's choice.
            widget.preferences
                ?.saveDailyBudget(_budget)
                .catchError((Object _) {});
            _reload();
          },
        ),
        const SizedBox(height: ResoniaSpacing.md),
        Text(
          'Taslak süreler ve ölçütler; eğitimci onayı bekliyor.',
          style: text.bodySmall,
        ),
        ExpansionTile(
          key: const Key('plan_help'),
          tilePadding: EdgeInsets.zero,
          title: const Text('Plan nasıl kurulur?'),
          children: const [
            Text(
              'Önce kalıcılık kontrolü, sonra tekrar, sonra yeni çalışma. Tekrar aralıkları (1/3/7/14 gün) ve süreler geliştirici taslağıdır; öğrenme pilotu bekliyor. Plan her gün gece yarısı yenilenir. Geçerli tur sayısı beceri veya hazırlık yüzdesi değildir.',
            ),
          ],
        ),
        const SizedBox(height: ResoniaSpacing.md),
        FutureBuilder<DailyPlan>(
          future: _plan,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ContentStatusPanel(
                key: Key('plan_loading'),
                kind: ContentStatusKind.loading,
                message: 'Yerel geçmişten günlük plan hazırlanıyor…',
              );
            }
            if (snapshot.hasError) {
              return ContentStatusPanel(
                key: const Key('plan_error'),
                kind: ContentStatusKind.error,
                message:
                    'Geçmiş okunamadığı için plan kurulamadı. Veri silinmedi. Yeniden deneyebilir veya Geçmiş ekranına bakabilirsin.',
                onRetry: _reload,
              );
            }
            return _PlanBody(plan: snapshot.data!, onOpen: _open);
          },
        ),
      ],
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({required this.plan, required this.onOpen});
  final DailyPlan plan;
  final Future<void> Function(PlanBlock) onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final next = plan.nextReviewDay;
    switch (plan.status) {
      case DailyPlanStatus.noMeasuredContent:
        return const ContentStatusPanel(
          key: Key('plan_no_content'),
          kind: ContentStatusKind.empty,
          message:
              'Bu rotada uygulamanın ölçebildiği çalışma henüz yok. İçerikler eğitimci onayından sonra eklenecek.',
        );
      case DailyPlanStatus.nothingDue:
        return ContentStatusPanel(
          key: const Key('plan_nothing_due'),
          kind: ContentStatusKind.empty,
          message:
              'Bugün vadesi gelen kontrol yok; ölçülebilen çalışmaların hepsi taslak ölçüte göre tamam.'
              '${next == null ? '' : ' Sıradaki kontrol: ${_date(next)}.'}',
        );
      case DailyPlanStatus.planned:
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Plan: ${plan.plannedMinutes} / ${plan.budget.minutes} dk',
          key: const Key('plan_minutes'),
          style: text.titleMedium,
        ),
        if (plan.complete)
          Padding(
            padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
            child: Text(
              'Bugünkü plan tamam. Yarın yeni plan kurulur.',
              key: const Key('plan_complete'),
              style: text.titleSmall,
            ),
          ),
        const SizedBox(height: ResoniaSpacing.sm),
        for (final (i, b) in plan.blocks.indexed)
          _BlockCard(index: i, block: b, onOpen: () => onOpen(b)),
        if (plan.freeMinutes > 0)
          Text(
            '${plan.freeMinutes} dk planlanmadı: ölçülebilen içerik şimdilik sınırlı. '
            'Beceri haritasındaki taslak mikroderslere bakabilir veya dinlenebilirsin.',
            key: const Key('plan_free'),
            style: text.bodySmall,
          ),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.index,
    required this.block,
    required this.onOpen,
  });
  final int index;
  final PlanBlock block;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = block;
    final (label, reason, action) = switch (b.kind) {
      PlanBlockKind.retentionCheck => (
        'Kalıcılık kontrolü',
        'Daha önce tamamladın; ${b.reviewIntervalDays} günlük tekrar aralığı doldu. Tek dinlemeyle, ipucusuz dene.',
        'Kontrol et',
      ),
      PlanBlockKind.weakRepeat => (
        'Tekrar',
        lastResultReason(b.lastResult),
        'Tekrar et',
      ),
      PlanBlockKind.newItem => (
        'Yeni',
        'Bu beceride sıradaki çalışma. Ölçüt için art arda iki temiz tur gerekir.',
        'Başla',
      ),
    };
    return Card(
      key: Key('plan_block_$index'),
      margin: const EdgeInsets.only(bottom: ResoniaSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill('$label · ~${b.minutes} dk'),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            Text(
              '${b.node.title} — ${b.exercise.title}',
              style: text.titleMedium,
            ),
            const SizedBox(height: ResoniaSpacing.xs),
            Text(reason),
            const SizedBox(height: ResoniaSpacing.xs),
            Text(
              b.done
                  ? 'Bugün tamamlandı (${b.roundsDoneToday} geçerli tur).'
                  : 'Bugün: ${b.roundsDoneToday} / ${b.rounds} geçerli tur.',
              key: Key('plan_progress_$index'),
              style: text.bodySmall,
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: Key('plan_start_$index'),
              onPressed: onOpen,
              tone: b.done ? ChunkyTone.neutral : ChunkyTone.primary,
              label: b.done ? 'Bir tur daha' : action,
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime d) => '${d.day}.${d.month}.${d.year}';
