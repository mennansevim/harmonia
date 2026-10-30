import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/measurement_provenance.dart';
import '../common/content_status_panel.dart';
import '../common/foreground_refresh_state.dart';
import '../common/ui/resonia_ui.dart';

/// Local attempt history. Comparisons only inside one cohort (exercise,
/// skill, difficulty, mode, content, scoring and analyzer version); fewer than
/// [minComparable] valid attempts is shown as unknown, not as a trend.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.history});
  final ResultHistoryRepository history;
  static const minComparable = 3;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ForegroundRefreshState<HistoryScreen> {
  late Future<List<ResultHistoryEntry>> _entries = _loadForView();

  Future<List<ResultHistoryEntry>> _loadForView() {
    final future = widget.history.load();
    future.ignore();
    return future;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _entries = _loadForView();
    });
  }

  @override
  void refreshAfterForeground() => _reload();

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      _entries = _loadForView();
    }
  }

  Future<void> _delete(String id) async {
    try {
      await widget.history.delete(id);
    } catch (_) {
      if (mounted) _snack('Kayıt silinemedi. Yeniden dene.');
    }
    _reload();
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tüm geçmiş silinsin mi?'),
        content: const Text(
          'Bu cihazdaki bütün çalışma sonuçların silinir. Geri alınamaz. Sunucuda kopyası yok.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('confirm_clear_history'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.history.clear();
    } catch (_) {
      if (mounted) _snack('Geçmiş silinemedi. Yeniden dene.');
    }
    _reload();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Çalışma geçmişi'),
      actions: [
        IconButton(
          key: const Key('clear_history'),
          tooltip: 'Tüm geçmişi sil',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: _clear,
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          const LocalOnlyNotice(key: Key('history_local_notice')),
          Expanded(
            child: FutureBuilder<List<ResultHistoryEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SingleChildScrollView(
                    child: ContentStatusPanel(
                      kind: ContentStatusKind.loading,
                      message: 'Geçmiş yükleniyor…',
                    ),
                  );
                }
                if (snapshot.hasError) {
                  final corrupt =
                      snapshot.error is HistoryStorageException &&
                      (snapshot.error as HistoryStorageException).failure ==
                          HistoryStorageFailure.corrupt;
                  return SingleChildScrollView(
                    child: ContentStatusPanel(
                      key: const Key('history_error'),
                      kind: ContentStatusKind.error,
                      message: corrupt
                          ? 'Geçmiş dosyası okunamadı. Dosya silinmedi; “Tüm geçmişi sil” ile sıfırlayabilirsin.'
                          : 'Geçmişe şu an erişilemedi.',
                      onRetry: _reload,
                    ),
                  );
                }
                final entries = snapshot.data!.reversed.toList();
                if (entries.isEmpty) {
                  return const SingleChildScrollView(
                    child: ContentStatusPanel(
                      key: Key('history_empty'),
                      kind: ContentStatusKind.empty,
                      message:
                          'Henüz kayıtlı sonuç yok. Ritim tekrarı gibi ölçülen çalışmalar burada görünür.',
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(ResoniaSpacing.lg),
                  children: [
                    _CohortSummary(entries: snapshot.data!),
                    ExpansionTile(
                      key: const Key('history_help'),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Karşılaştırma nasıl yapılır?'),
                      children: const [
                        Text(
                          'Yalnız aynı çalışma, beceri, zorluk, mod, içerik ve analiz sürümündeki aynı kaynaklı geçerli sonuçlar karşılaştırılır. En az 3 karşılaştırılabilir deneme gerekir. Ölçülemeyen değer sıfır hata veya başarı değildir.',
                        ),
                      ],
                    ),
                    const SizedBox(height: ResoniaSpacing.md),
                    for (final e in entries)
                      _EntryTile(
                        entry: e,
                        onDelete: () => _delete(e.attemptId),
                      ),
                    const SizedBox(height: ResoniaSpacing.sm),
                    ChunkyButton(
                      key: const Key('history_back'),
                      label: 'Geri dön',
                      tone: ChunkyTone.neutral,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Object _cohortKey(ExerciseResult r) => (
  r.exerciseId,
  r.skill,
  r.difficulty,
  r.exerciseMode.wireValue,
  r.contentVersion,
  r.scoringVersion,
  r.provenance.source.name,
  r.provenance.analyzerVersion,
);

class _CohortSummary extends StatelessWidget {
  const _CohortSummary({required this.entries});
  final List<ResultHistoryEntry> entries;
  @override
  Widget build(BuildContext context) {
    final byCohort = <Object, List<ExerciseResult>>{};
    for (final e in entries) {
      if (!e.result.isValid) continue;
      byCohort.putIfAbsent(_cohortKey(e.result), () => []).add(e.result);
    }
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('history_summary'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill('Karşılaştırılabilir kanıt'),
            const SizedBox(height: ResoniaSpacing.sm),
            Text('Gelişim (aynı çalışma ve sürüm)', style: text.titleMedium),
            const SizedBox(height: ResoniaSpacing.xs),
            if (byCohort.isEmpty)
              const Text('Geçerli ölçüm yok; gelişim bilinmiyor.'),
            for (final results in byCohort.values)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                child: Text(_trend(results)),
              ),
          ],
        ),
      ),
    );
  }
}

String _trend(List<ExerciseResult> results) {
  final title = results.first.exerciseId;
  if (results.length < HistoryScreen.minComparable) {
    return '$title: ${results.length} geçerli deneme — karşılaştırma için en az ${HistoryScreen.minComparable} gerekli, gelişim bilinmiyor.';
  }
  final ordered = [...results]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final last = ordered.sublist(ordered.length - HistoryScreen.minComparable);
  if (last.any((r) => r.measurements['dimension'] == 'perception')) {
    if (!last.every(_hasPerceptionCounts)) {
      return '$title: karşılaştırılabilir ölçüm alanları eksik; gelişim bilinmiyor.';
    }
    final correct = [
      for (final r in last)
        '${r.measurements['correct']}/${r.measurements['total']}',
    ];
    return '$title: son ${last.length} geçerli turda doğru ${correct.join(' → ')}.';
  }
  if (last.any((r) => r.skill != Skill.rhythm)) {
    return '$title: bu çalışma için sayısal gelişim henüz gösterilmiyor.';
  }
  if (!last.every((r) {
    final missed = r.measurements['missed'];
    final extra = r.measurements['extra'];
    return missed is int && extra is int && missed >= 0 && extra >= 0;
  })) {
    return '$title: karşılaştırılabilir ölçüm alanları eksik; gelişim bilinmiyor.';
  }
  final misses = [
    for (final r in last)
      '${(r.measurements['missed'] as int) + (r.measurements['extra'] as int)}',
  ];
  return '$title: son ${last.length} geçerli denemede eksik+fazla vuruş ${misses.join(' → ')}.';
}

bool _hasPerceptionCounts(ExerciseResult r) {
  final correct = r.measurements['correct'];
  final total = r.measurements['total'];
  return r.measurements['dimension'] == 'perception' &&
      correct is int &&
      total is int &&
      total > 0 &&
      correct >= 0 &&
      correct <= total;
}

String? _entryDetail(ExerciseResult r) {
  if (!r.isValid) return null;
  if (r.measurements['dimension'] == 'perception') {
    return _hasPerceptionCounts(r)
        ? '${r.measurements['correct']}/${r.measurements['total']} doğru (dinleme)'
        : 'Ayrıntılı ölçüm alanları eksik.';
  }
  if (r.skill != Skill.rhythm) return null;
  if (!['matched', 'missed', 'extra'].every((key) {
    final count = r.measurements[key];
    return count is int && count >= 0;
  })) {
    return 'Ayrıntılı ölçüm alanları eksik.';
  }
  return '${r.measurements['matched']} eşleşme, ${r.measurements['missed']} eksik, ${r.measurements['extra']} fazla';
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});
  final ResultHistoryEntry entry;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final r = entry.result;
    final colors = context.resultColors;
    final local = r.createdAt.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final status = r.isValid ? 'Ölçüldü' : 'Ölçülemedi — puanlanmadı';
    final detail = _entryDetail(r);
    return Card(
      margin: const EdgeInsets.only(bottom: ResoniaSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  r.skill == Skill.rhythm
                      ? Icons.touch_app_outlined
                      : r.measurements['dimension'] == 'perception'
                      ? Icons.hearing
                      : Icons.music_note,
                  color: r.isValid ? null : colors.notMeasured,
                ),
                const SizedBox(width: ResoniaSpacing.sm),
                Expanded(
                  child: Text(
                    r.exerciseId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: Key('delete_${entry.attemptId}'),
                  tooltip: 'Bu kaydı sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
            DataLabel(date),
            const SizedBox(height: ResoniaSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(status),
            ),
            if (detail != null) Text(detail),
            Text(
              'Kaynak: ${_source(r.provenance.source)} • İçerik ${r.contentVersion}',
            ),
          ],
        ),
      ),
    );
  }
}

String _source(MeasurementSource s) => switch (s) {
  MeasurementSource.touch => 'dokunma',
  MeasurementSource.microphone => 'mikrofon',
  MeasurementSource.synthetic => 'sentetik',
  MeasurementSource.mock => 'simülasyon',
  MeasurementSource.unverified => 'doğrulanmamış',
};
