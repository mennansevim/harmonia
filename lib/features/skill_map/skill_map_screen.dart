import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/learning/micro_lesson.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/learning/skill_report.dart';
import '../../domain/learning/today_planner.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/learner_profile.dart';
import '../learning/exercise_launcher.dart';
import '../learning/micro_lesson_screen.dart';
import '../learning/next_step_text.dart';
import '../common/content_status_panel.dart';
import '../common/ui/harmonia_ui.dart';

/// LEARN-01 view: recommended order for the learner's goal and an
/// evidence-backed state per skill. Nothing is locked; unknown is shown.
class SkillMapScreen extends StatefulWidget {
  const SkillMapScreen({
    super.key,
    required this.goal,
    this.history,
    this.graph,
    this.catalog,
    this.lessons,
    this.clock,
    this.exerciseScreen,
  });
  final PracticeGoal goal;
  final ResultHistoryRepository? history;
  final SkillGraph? graph;
  final List<MeasuredExercise>? catalog;
  final MicroLessonCatalog? lessons;
  final DateTime Function()? clock;

  /// Test seam; defaults to the real exercise screens.
  final Widget Function(MeasuredExercise exercise, bool retentionCheck)?
  exerciseScreen;
  @override
  State<SkillMapScreen> createState() => _SkillMapScreenState();
}

class _SkillMapScreenState extends State<SkillMapScreen> {
  late final SkillGraph graph = widget.graph ?? draftSkillGraph;
  late final MicroLessonCatalog lessons =
      widget.lessons ??
      (widget.graph == null
          ? draftMicroLessons
          : MicroLessonCatalog(graph: graph, lessons: const []));
  late Future<List<ExerciseResult>> _results = _loadForView();

  Future<List<ExerciseResult>> _loadForView() {
    final pending = _load();
    // Observe early errors until the next frame subscribes; the original
    // future still delivers its failure to FutureBuilder.
    pending.ignore();
    return pending;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _results = _loadForView();
    });
  }

  Future<void> _openFocus(TodayStep step) async {
    final e = step.exercise;
    if (e == null) return;
    final retention = step.kind == NextStepKind.delayedCheck;
    final screen =
        widget.exerciseScreen?.call(e, retention) ??
        measuredExerciseScreen(
          e,
          history: widget.history,
          retentionCheck: retention,
        );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    _reload();
  }

  Future<List<ExerciseResult>> _load() async {
    final h = widget.history;
    if (h == null) return const [];
    return [for (final e in await h.load()) e.result];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beceri haritası')),
    body: SafeArea(
      child: FutureBuilder<List<ExerciseResult>>(
        future: _results,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SingleChildScrollView(
              child: ContentStatusPanel(
                key: Key('skill_map_loading'),
                kind: ContentStatusKind.loading,
                message: 'Yerel geçmişten beceri durumları okunuyor…',
              ),
            );
          }
          final historyError = snapshot.hasError;
          final results = snapshot.data ?? const <ExerciseResult>[];
          final skills = graph.forGoal(widget.goal);
          return ListView(
            padding: const EdgeInsets.all(HarmoniaSpacing.lg),
            children: [
              Text(
                'Önerilen sıra, kilit yok. Harita taslaktır; ölçülemeyen beceriler eksik sayılmaz.',
                key: const Key('skill_map_intro'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.palette.muted),
              ),
              if (historyError)
                ContentStatusPanel(
                  key: const Key('skill_map_history_error'),
                  kind: ContentStatusKind.error,
                  message:
                      'Geçmiş okunamadı; durumlar gösterilemiyor. Veri silinmedi. Ders taslaklarını okuyabilir veya yeniden deneyebilirsin.',
                  onRetry: _reload,
                ),
              if (!historyError) ...[
                const SizedBox(height: HarmoniaSpacing.md),
                _ReportCard(
                  report: SkillReport.build(
                    graph: graph,
                    goal: widget.goal,
                    results: results,
                    now: (widget.clock ?? DateTime.now)(),
                    catalog: widget.catalog,
                  ),
                  onFocus: widget.history == null ? null : _openFocus,
                ),
              ],
              const SizedBox(height: HarmoniaSpacing.md),
              for (final node in skills)
                _SkillCard(
                  node: node,
                  graph: graph,
                  lessons: lessons
                      .forSkill(node.id)
                      .where(
                        (lesson) =>
                            lesson.route == node.route &&
                            lesson.dimension == node.dimension,
                      )
                      .toList(),
                  state: historyError
                      ? null
                      : SkillStatusEvaluator.stateOf(
                          node,
                          results,
                          catalog: widget.catalog,
                        ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.node,
    required this.graph,
    required this.state,
    required this.lessons,
  });
  final SkillNode node;
  final SkillGraph graph;

  /// null means history unavailable, not an unattempted skill.
  final MasteryState? state;
  final List<MicroLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final pre = [for (final id in node.prerequisites) graph[id].title];
    final measured = node.support == MeasurementSupport.measuredInApp;
    final meta = [
      node.dimension == SkillDimension.perception ? 'Algı' : 'Üretim',
      if (pre.isNotEmpty) 'Önce: ${pre.join(', ')}',
    ].join(' · ');
    return Card(
      key: Key('skill_${node.id}'),
      margin: const EdgeInsets.only(bottom: HarmoniaSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(node.title, style: text.titleMedium)),
                const SizedBox(width: HarmoniaSpacing.sm),
                Chip(
                  key: Key('skill_state_${node.id}'),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    state == null
                        ? 'Durum alınamadı'
                        : stateLabel(state!, node.support),
                  ),
                ),
              ],
            ),
            Text(node.goal, style: text.bodyMedium),
            const SizedBox(height: HarmoniaSpacing.xs),
            Text(meta, style: text.bodySmall?.copyWith(color: palette.muted)),
            if (!measured)
              Text(
                supportLabel(node.support),
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
            for (final lesson in lessons)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: Key('open_lesson_${lesson.id}'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MicroLessonScreen(lesson: lesson),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 20),
                  label: Text('Taslak ders: ${lesson.title}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String stateLabel(MasteryState state, MeasurementSupport support) =>
    switch (state) {
      MasteryState.notMeasured => 'Henüz ölçülmedi',
      MasteryState.practicing => 'Çalışılıyor',
      MasteryState.supported => 'Destekle yapabiliyor',
      MasteryState.independent => 'Bağımsız yapabiliyor',
      MasteryState.retained => 'Sonraki gün de korundu',
    };

String supportLabel(MeasurementSupport s) => switch (s) {
  MeasurementSupport.measuredInApp =>
    'Uygulamada ölçülüyor (taslak ölçüt: art arda iki temiz deneme; tek dinlemeyle “bağımsız”, ertesi gün kontrolüyle “korundu”).',
  MeasurementSupport.awaitingEngine =>
    'Ses tanıma gerçek kayıtlarla doğrulanınca ölçülecek.',
  MeasurementSupport.awaitingContent =>
    'Eğitimci onaylı içerik eklenince açılacak.',
  MeasurementSupport.educatorObserved =>
    'Otomatik puan yok; gerçek eğitimci değerlendirir.',
};

/// LEARN-04: counts and one focus; never a readiness percentage.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onFocus});
  final SkillReport report;
  final Future<void> Function(TodayStep)? onFocus;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final r = report;
    final (title, reason, action) = todayStepText(r.focus);
    final strong =
        r.count(MasteryState.independent) + r.count(MasteryState.retained);
    final working =
        r.count(MasteryState.practicing) + r.count(MasteryState.supported);
    final untried = r.count(MasteryState.notMeasured);
    final total = r.measurableCount + r.unknownCount;
    // Distribution bar: evidence states, then unknown (grey, never "weak").
    final segments = [
      (strong, palette.sun),
      (working, scheme.primary),
      (untried, scheme.primary.withValues(alpha: .25)),
      (r.unknownCount, palette.line),
    ];
    return Card(
      key: const Key('skill_report'),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Beceri raporu', style: text.titleLarge),
            const SizedBox(height: HarmoniaSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Bağımsız',
                    value: '$strong',
                    valueColor: strong > 0 ? palette.onSun : null,
                  ),
                ),
                const SizedBox(width: HarmoniaSpacing.sm),
                Expanded(
                  child: StatTile(label: 'Çalışılıyor', value: '$working'),
                ),
                const SizedBox(width: HarmoniaSpacing.sm),
                Expanded(
                  child: StatTile(label: 'Denenmedi', value: '$untried'),
                ),
              ],
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            Semantics(
              label:
                  '$total becerinin $strong tanesi bağımsız, $working tanesi çalışılıyor, $untried tanesi denenmedi, ${r.unknownCount} tanesi bilinmiyor',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final (n, c) in segments)
                        if (n > 0)
                          Expanded(
                            flex: n,
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: c,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            Text(
              'Rotandaki $total becerinin ${r.measurableCount} tanesi uygulamada ölçülebiliyor.',
              key: const Key('report_scope'),
              style: text.bodyMedium,
            ),
            Text(
              'Bağımsız ya da korundu: $strong · Destekle: ${r.count(MasteryState.supported)} · '
              'Çalışılıyor: ${r.count(MasteryState.practicing)} · Henüz denenmedi: $untried',
              key: const Key('report_counts'),
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
            Text(
              '${r.unknownCount} beceri için uygulamada kanıt yok; durumları bilinmiyor (zayıf sayılmaz).',
              key: const Key('report_unknown'),
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
            const Divider(height: HarmoniaSpacing.lg + 8),
            const DataLabel('Tek hedef'),
            const SizedBox(height: HarmoniaSpacing.xs),
            Text(title, style: text.titleMedium),
            const SizedBox(height: 2),
            Text(reason, style: text.bodyMedium),
            if (action.isNotEmpty && onFocus != null) ...[
              const SizedBox(height: HarmoniaSpacing.md),
              ChunkyButton(
                key: const Key('report_focus_action'),
                label: action,
                icon: Icons.play_arrow_rounded,
                onPressed: () => onFocus!(r.focus),
              ),
            ],
            const SizedBox(height: HarmoniaSpacing.sm),
            Text(
              'Genel hazırlık yüzdesi gösterilmez; ölçütler taslak ve eğitimci onayı bekliyor.',
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
