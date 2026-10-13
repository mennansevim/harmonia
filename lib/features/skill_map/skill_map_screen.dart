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
  late Future<List<ExerciseResult>> _results = _load();

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
    if (mounted) {
      setState(() {
        _results = _load();
      });
    }
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
            return const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Yükleniyor'),
            );
          }
          final historyError = snapshot.hasError;
          final results = snapshot.data ?? const <ExerciseResult>[];
          final skills = graph.forGoal(widget.goal);
          return ListView(
            padding: const EdgeInsets.all(HarmoniaSpacing.lg),
            children: [
              const Text(
                'Önerilen sıra; kilit yok, eğitimcin sırayı değiştirebilir. Bu harita bir taslaktır ve eğitimci onayı bekliyor. Uygulamada henüz ölçülemeyen beceriler “henüz ölçülmedi” olarak kalır; bu bir eksiklik notu değildir.',
                key: Key('skill_map_intro'),
              ),
              if (historyError)
                const Padding(
                  padding: EdgeInsets.only(top: HarmoniaSpacing.sm),
                  child: Text(
                    'Geçmiş okunamadı; durumlar gösterilemiyor.',
                    key: Key('skill_map_history_error'),
                  ),
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
                      ? MasteryState.notMeasured
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
  final MasteryState state;
  final List<MicroLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pre = [for (final id in node.prerequisites) graph[id].title];
    return Card(
      key: Key('skill_${node.id}'),
      margin: const EdgeInsets.only(bottom: HarmoniaSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.title, style: text.titleMedium),
            Text(node.goal),
            const SizedBox(height: HarmoniaSpacing.xs),
            Wrap(
              spacing: HarmoniaSpacing.xs,
              runSpacing: HarmoniaSpacing.xs,
              children: [
                Chip(
                  key: Key('skill_state_${node.id}'),
                  label: Text(stateLabel(state, node.support)),
                ),
                Chip(
                  label: Text(
                    node.dimension == SkillDimension.perception
                        ? 'Algı'
                        : 'Üretim',
                  ),
                ),
              ],
            ),
            Text(supportLabel(node.support), style: text.bodySmall),
            if (pre.isNotEmpty)
              Text('Önce: ${pre.join(', ')}', style: text.bodySmall),
            for (final lesson in lessons)
              OutlinedButton(
                key: Key('open_lesson_${lesson.id}'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MicroLessonScreen(lesson: lesson),
                  ),
                ),
                child: Text('Metin taslağını oku: ${lesson.title}'),
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
    final r = report;
    final (title, reason, action) = todayStepText(r.focus);
    final strong =
        r.count(MasteryState.independent) + r.count(MasteryState.retained);
    return Card(
      key: const Key('skill_report'),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Beceri raporu', style: text.labelLarge),
            Text(
              'Rotandaki ${r.measurableCount + r.unknownCount} becerinin ${r.measurableCount} tanesi uygulamada ölçülebiliyor.',
              key: const Key('report_scope'),
            ),
            Text(
              'Bağımsız ya da korundu: $strong · Destekle: ${r.count(MasteryState.supported)} · '
              'Çalışılıyor: ${r.count(MasteryState.practicing)} · Henüz denenmedi: ${r.count(MasteryState.notMeasured)}',
              key: const Key('report_counts'),
            ),
            Text(
              '${r.unknownCount} beceri için uygulamada kanıt yok; durumları bilinmiyor (zayıf sayılmaz).',
              key: const Key('report_unknown'),
              style: text.bodySmall,
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
            Text('Tek hedef: $title', style: text.titleMedium),
            Text(reason),
            if (action.isNotEmpty && onFocus != null) ...[
              const SizedBox(height: HarmoniaSpacing.sm),
              FilledButton(
                key: const Key('report_focus_action'),
                onPressed: () => onFocus!(r.focus),
                child: Text(action),
              ),
            ],
            const SizedBox(height: HarmoniaSpacing.xs),
            Text(
              'Genel hazırlık yüzdesi gösterilmez; ölçütler taslak ve eğitimci onayı bekliyor.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
