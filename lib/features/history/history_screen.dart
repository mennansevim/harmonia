import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/measurement_provenance.dart';

/// Local attempt history. Comparisons only inside one cohort (exercise,
/// difficulty, mode, content, scoring and analyzer version); fewer than
/// [minComparable] valid attempts is shown as unknown, not as a trend.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.history});
  final ResultHistoryRepository history;
  static const minComparable = 3;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ResultHistoryEntry>> _entries = widget.history.load();

  void _reload() {
    if (!mounted) return;
    setState(() {
      _entries = widget.history.load();
    });
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
    if (ok != true) return;
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
      child: FutureBuilder<List<ResultHistoryEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(semanticsLabel: 'Yükleniyor'),
            );
          }
          if (snapshot.hasError) {
            final corrupt =
                snapshot.error is HistoryStorageException &&
                (snapshot.error as HistoryStorageException).failure ==
                    HistoryStorageFailure.corrupt;
            return _Message(
              key: const Key('history_error'),
              text: corrupt
                  ? 'Geçmiş dosyası okunamadı. Dosya silinmedi; “Tüm geçmişi sil” ile sıfırlayabilirsin.'
                  : 'Geçmişe şu an erişilemedi.',
              action: TextButton(
                onPressed: _reload,
                child: const Text('Yeniden dene'),
              ),
            );
          }
          final entries = snapshot.data!.reversed.toList();
          if (entries.isEmpty) {
            return const _Message(
              key: Key('history_empty'),
              text:
                  'Henüz kayıtlı sonuç yok. Ritim tekrarı gibi ölçülen çalışmalar burada görünür.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(HarmoniaSpacing.lg),
            children: [
              _CohortSummary(entries: snapshot.data!),
              const SizedBox(height: HarmoniaSpacing.md),
              for (final e in entries)
                _EntryTile(entry: e, onDelete: () => _delete(e.attemptId)),
            ],
          );
        },
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(HarmoniaSpacing.lg),
    children: [Text(text), ?action],
  );
}

String _cohortKey(ExerciseResult r) => [
  r.exerciseId,
  r.difficulty,
  r.exerciseMode.wireValue,
  r.contentVersion,
  r.scoringVersion,
  r.provenance.source.name,
  r.provenance.analyzerVersion,
].join('|');

class _CohortSummary extends StatelessWidget {
  const _CohortSummary({required this.entries});
  final List<ResultHistoryEntry> entries;
  @override
  Widget build(BuildContext context) {
    final byCohort = <String, List<ExerciseResult>>{};
    for (final e in entries) {
      if (!e.result.isValid) continue;
      byCohort.putIfAbsent(_cohortKey(e.result), () => []).add(e.result);
    }
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('history_summary'),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gelişim (aynı çalışma ve sürüm)', style: text.titleMedium),
            const SizedBox(height: HarmoniaSpacing.xs),
            if (byCohort.isEmpty)
              const Text('Geçerli ölçüm yok; gelişim bilinmiyor.'),
            for (final results in byCohort.values)
              Padding(
                padding: const EdgeInsets.only(top: HarmoniaSpacing.xs),
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
  final last = results.sublist(results.length - HistoryScreen.minComparable);
  if (last.first.measurements['dimension'] == 'perception') {
    final correct = [
      for (final r in last)
        '${r.measurements['correct']}/${r.measurements['total']}',
    ];
    return '$title: son ${last.length} geçerli turda doğru ${correct.join(' → ')}.';
  }
  final misses = [
    for (final r in last)
      '${(r.measurements['missed'] as int? ?? 0) + (r.measurements['extra'] as int? ?? 0)}',
  ];
  return '$title: son ${last.length} geçerli denemede eksik+fazla vuruş ${misses.join(' → ')}.';
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
    final detail = !r.isValid
        ? null
        : r.measurements['dimension'] == 'perception'
        ? '${r.measurements['correct']}/${r.measurements['total']} doğru (dinleme)'
        : r.skill == Skill.rhythm
        ? '${r.measurements['matched']} eşleşme, ${r.measurements['missed']} eksik, ${r.measurements['extra']} fazla'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: HarmoniaSpacing.sm),
      child: ListTile(
        leading: Icon(
          r.skill == Skill.rhythm
              ? Icons.touch_app_outlined
              : r.measurements['dimension'] == 'perception'
              ? Icons.hearing
              : Icons.music_note,
          color: r.isValid ? null : colors.notMeasured,
        ),
        title: Text(r.exerciseId),
        subtitle: Text(
          [
            date,
            status,
            ?detail,
            'Kaynak: ${_source(r.provenance.source)} • İçerik ${r.contentVersion}',
          ].join('\n'),
        ),
        trailing: IconButton(
          key: Key('delete_${entry.attemptId}'),
          tooltip: 'Bu kaydı sil',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
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
