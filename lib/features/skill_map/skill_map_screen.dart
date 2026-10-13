import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/learning/micro_lesson.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/learner_profile.dart';
import '../learning/micro_lesson_screen.dart';

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
  });
  final PracticeGoal goal;
  final ResultHistoryRepository? history;
  final SkillGraph? graph;
  final List<MeasuredExercise>? catalog;
  final MicroLessonCatalog? lessons;
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
  late final Future<List<ExerciseResult>> _results = _load();

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
