import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/learning/skill_graph.dart';
import '../../domain/learning/starting_check.dart';
import '../../domain/models/learner_profile.dart';
import '../common/content_status_panel.dart';
import '../common/foreground_refresh_state.dart';
import '../common/ui/resonia_ui.dart';
import '../learning/exercise_launcher.dart';

class StartingCheckScreen extends StatefulWidget {
  const StartingCheckScreen({
    super.key,
    required this.goal,
    required this.history,
    this.catalog,
    this.launcher,
  });

  final PracticeGoal goal;
  final ResultHistoryRepository history;
  final List<MeasuredExercise>? catalog;
  final Widget Function(MeasuredExercise exercise)? launcher;

  @override
  State<StartingCheckScreen> createState() => _StartingCheckScreenState();
}

class _StartingCheckScreenState
    extends ForegroundRefreshState<StartingCheckScreen> {
  late Future<StartingCheckSummary> _summary = _loadForView();

  Future<StartingCheckSummary> _loadForView() {
    final future = _load();
    future.ignore();
    return future;
  }

  Future<StartingCheckSummary> _load() async {
    final entries = await widget.history.load();
    return StartingCheckSummary.build(
      graph: draftSkillGraph,
      goal: widget.goal,
      results: [for (final entry in entries) entry.result],
      catalog: widget.catalog,
    );
  }

  void _reload() => setState(() {
    _summary = _loadForView();
  });

  @override
  void refreshAfterForeground() => _reload();

  @override
  void didUpdateWidget(covariant StartingCheckScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.history, widget.history) ||
        oldWidget.goal != widget.goal ||
        !identical(oldWidget.catalog, widget.catalog)) {
      _reload();
    }
  }

  Future<void> _open(MeasuredExercise exercise) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            widget.launcher?.call(exercise) ??
            measuredExerciseScreen(
              exercise,
              history: widget.history,
              retentionCheck: false,
            ),
      ),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Başlangıç kontrolü')),
    body: SafeArea(
      child: FutureBuilder<StartingCheckSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: ContentStatusPanel(
                kind: ContentStatusKind.loading,
                message: 'Yerel sonuçların okunuyor.',
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: ContentStatusPanel(
                kind: ContentStatusKind.error,
                message:
                    'Başlangıç kontrolü hazırlanamadı. Verilerin silinmedi; yeniden deneyebilirsin.',
                onRetry: _reload,
              ),
            );
          }
          final summary = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(ResoniaSpacing.lg),
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusPill('Taslak · 3 kısa tur'),
              ),
              const SizedBox(height: ResoniaSpacing.md),
              Text(
                summary.isComplete
                    ? 'Başlangıç görünümün hazır'
                    : 'Önce bildiklerimizi ölçelim',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Bu kontrol yalnız dokunmayla güvenilir ölçebildiğimiz üç alanı kullanır. Konservatuvar seviyesi, ses aralığı veya sınava hazır olma puanı değildir.',
              ),
              const SizedBox(height: ResoniaSpacing.lg),
              for (final (index, item) in summary.items.indexed) ...[
                _CheckItemCard(index: index, item: item),
                const SizedBox(height: ResoniaSpacing.sm),
              ],
              Text(
                '${summary.completedCount}/${summary.items.length} geçerli tur · ${summary.unknownSkillCount} beceri henüz bu uygulamada ölçülemiyor.',
                key: const Key('starting_check_progress'),
              ),
              const SizedBox(height: ResoniaSpacing.lg),
              if (summary.next case final next?)
                ChunkyButton(
                  key: const Key('starting_check_next'),
                  onPressed: () => _open(next.exercise),
                  icon: Icons.play_arrow_rounded,
                  label: summary.isComplete
                      ? 'Önerilen pratik: ${next.exercise.title}'
                      : 'Sıradaki: ${next.exercise.title}',
                )
              else
                const Card(
                  key: Key('starting_check_complete'),
                  child: Padding(
                    padding: EdgeInsets.all(ResoniaSpacing.md),
                    child: Text(
                      'Bu üç turda ek tekrar önerisi çıkmadı. Ölçemediğimiz ses üretimi, ezgi ve çok sesli duyma alanları bilinmiyor; günlük rotadan devam edebilirsin.',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _CheckItemCard extends StatelessWidget {
  const _CheckItemCard({required this.index, required this.item});
  final int index;
  final StartingCheckItem item;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (item.status) {
      StartingCheckStatus.notTried => (
        'Henüz denenmedi',
        Icons.circle_outlined,
      ),
      StartingCheckStatus.retryNeeded => (
        'Ölçüm alınamadı; yeniden dene',
        Icons.refresh_rounded,
      ),
      StartingCheckStatus.practiceSuggested => (
        'Bu alanda pratik öneriliyor',
        Icons.route_outlined,
      ),
      StartingCheckStatus.strongRound => (
        'Bu turda güçlüydü',
        Icons.check_circle_outline,
      ),
    };
    return Card(
      key: Key('starting_check_item_$index'),
      child: ListTile(
        leading: Icon(icon),
        title: Text(item.node.title),
        subtitle: Text('${item.exercise.title} · $label'),
      ),
    );
  }
}
