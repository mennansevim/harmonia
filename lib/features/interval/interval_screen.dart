import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/interval_controller.dart';
import '../../application/result_history.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/perception/interval_identification.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';

/// Context arpeggio do–mi–sol, pause, then do → target degree (ascending).
List<int> renderIntervalItem(IntervalItem item) => renderToneSequence(
  [
    (item.hzOf(0), 0.3),
    (item.hzOf(4), 0.3),
    (item.hzOf(7), 0.3),
    (item.hzOf(0), 0.6),
    (item.targetHz, 0.6),
  ],
  gapsAfter: const [0.05, 0.05, 0.6, 0.25, 0.2],
).encode();

class IntervalScreen extends StatefulWidget {
  const IntervalScreen({
    super.key,
    this.player,
    this.history,
    this.levels,
    this.initialLevelId,
    this.retentionCheck = false,
  });
  final ReferenceClipPlayer? player;
  final ResultHistoryRepository? history;
  final List<IntervalLevel>? levels;
  final String? initialLevelId;
  final bool retentionCheck;
  @override
  State<IntervalScreen> createState() => _IntervalScreenState();
}

class _IntervalScreenState extends State<IntervalScreen>
    with WidgetsBindingObserver {
  late final List<IntervalLevel> levels = widget.levels ?? draftIntervalLevels;
  late final IntervalController c;

  @override
  void initState() {
    super.initState();
    c = IntervalController(
      player: widget.player ?? JustAudioClipPlayer(),
      renderItem: renderIntervalItem,
      initialLevel: levels.firstWhere(
        (l) => l.exerciseId == widget.initialLevelId,
        orElse: () => levels.first,
      ),
      history: widget.history,
    )..retentionCheck = widget.retentionCheck;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(c.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.resultColors;
    return Scaffold(
      appBar: AppBar(title: const Text('Dereceyi bul (hareketli do)')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final o = c.outcome;
            final item = c.round.items[c.index];
            return ListView(
              padding: const EdgeInsets.all(HarmoniaSpacing.lg),
              children: [
                const Text(
                  'Önce tonu tanıtan do–mi–sol duyulur, sonra do ve bir ses daha. İkinci ses do\'ya göre hangi derece? Ton her soruda değişir; hareketli do kullanıyoruz, yani “do” her zaman o anki tonun ilk sesidir. Mikrofon kullanılmaz.',
                ),
                const SizedBox(height: HarmoniaSpacing.md),
                Wrap(
                  spacing: HarmoniaSpacing.sm,
                  runSpacing: HarmoniaSpacing.sm,
                  children: [
                    for (final l in levels)
                      ChoiceChip(
                        key: Key('int_level_${l.exerciseId}'),
                        label: Text(l.title),
                        selected: l == c.level,
                        onSelected: c.canChangeLevel
                            ? (_) => c.selectLevel(l)
                            : null,
                      ),
                  ],
                ),
                if (c.level.review != ContentReviewStatus.educatorApproved)
                  Text(
                    'Taslak içerik — eğitimci onayı bekliyor. Sesler sentetik tondur.',
                    style: text.bodySmall,
                  ),
                if (c.retentionCheck)
                  const Text(
                    'Kalıcılık kontrolü: her soruyu bir kez dinleyebilirsin.',
                    key: Key('int_retention_label'),
                  ),
                const SizedBox(height: HarmoniaSpacing.md),
                if (o == null) ...[
                  Text(
                    'Soru ${c.index + 1} / ${c.round.items.length}',
                    key: const Key('int_progress'),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: HarmoniaSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('int_play'),
                    onPressed: c.canPlay ? c.playCurrent : null,
                    icon: const Icon(Icons.volume_up_outlined),
                    label: Text(
                      c.plays[c.index] == 0 ? 'Dinle' : 'Tekrar dinle',
                    ),
                  ),
                  if (c.playbackFailed)
                    const Text('Ses çalınamadı. Yeniden dene.'),
                  const SizedBox(height: HarmoniaSpacing.sm),
                  Wrap(
                    spacing: HarmoniaSpacing.sm,
                    runSpacing: HarmoniaSpacing.sm,
                    children: [
                      for (final d in c.level.options)
                        FilledButton(
                          key: Key('int_answer_${d.name}'),
                          onPressed: c.canAnswer ? () => c.answer(d) : null,
                          child: Text('${d.syllable}  (${d.intervalName})'),
                        ),
                    ],
                  ),
                  if (c.phase == IntervalPhase.feedback) ...[
                    const SizedBox(height: HarmoniaSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        c.lastAnswerCorrect
                            ? 'Doğru: ${item.degree.syllable} (${item.degree.intervalName}).'
                            : 'Bu sefer değil: ${item.degree.syllable} idi (${item.degree.intervalName}). Tekrar dinleyip do\'dan uzaklığı karşılaştır.',
                        key: const Key('int_feedback'),
                        style: TextStyle(
                          color: c.lastAnswerCorrect
                              ? colors.correct
                              : colors.incorrect,
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const Key('int_next'),
                      onPressed: c.next,
                      child: Text(
                        c.index < c.round.items.length - 1
                            ? 'Sonraki soru'
                            : 'Turu bitir',
                      ),
                    ),
                  ],
                ] else
                  _Summary(controller: c, outcome: o),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.controller, required this.outcome});
  final IntervalController controller;
  final IntervalOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final total = outcome.round.items.length;
    final confusions = outcome.confusions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      key: const Key('int_summary'),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$total sorudan ${outcome.correctCount} doğru.',
              key: const Key('int_summary_text'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Şans düzeyi yaklaşık %${outcome.chancePercent.round()} (${outcome.round.level.options.length} seçenek). Taslak ölçüt: art arda iki turda en az ${PerceptionCriterion.minCorrect}/$total.',
            ),
            if (confusions.isNotEmpty)
              Text(
                'En çok karışan: ${confusions.first.key.replaceAll('→', ' yerine ')} (${confusions.first.value} kez). Bu iki dereceyi do\'dan başlayarak tekrar dinle.',
                key: const Key('int_confusion'),
              ),
            if (controller.recordOutcome != null)
              const Text('Sonuç bu cihazdaki geçmişine kaydedildi.'),
            if (controller.historyFailed)
              const Text('Sonuç geçmişe kaydedilemedi.'),
            const SizedBox(height: HarmoniaSpacing.sm),
            FilledButton(
              key: const Key('int_new_round'),
              onPressed: controller.newRound,
              child: const Text('Yeni tur'),
            ),
          ],
        ),
      ),
    );
  }
}
