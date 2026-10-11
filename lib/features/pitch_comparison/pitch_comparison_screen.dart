import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/pitch_comparison_controller.dart';
import '../../application/result_history.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/perception/pitch_comparison.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';

class PitchComparisonScreen extends StatefulWidget {
  const PitchComparisonScreen({
    super.key,
    this.player,
    this.history,
    this.levels,
    this.initialLevelId,
    this.retentionCheck = false,
  });
  final String? initialLevelId;
  final bool retentionCheck;
  final ReferenceClipPlayer? player;
  final ResultHistoryRepository? history;
  final List<PitchComparisonLevel>? levels;
  @override
  State<PitchComparisonScreen> createState() => _PitchComparisonScreenState();
}

class _PitchComparisonScreenState extends State<PitchComparisonScreen>
    with WidgetsBindingObserver {
  late final List<PitchComparisonLevel> levels =
      widget.levels ?? draftPitchLevels;
  late final PitchComparisonController c;

  @override
  void initState() {
    super.initState();
    c = PitchComparisonController(
      player: widget.player ?? JustAudioClipPlayer(),
      renderPair: (a, b) => renderTonePair(a, b).encode(),
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
      appBar: AppBar(title: const Text('Tiz mi, pes mi?')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final selectable = c.canChangeLevel;
            final o = c.outcome;
            return ListView(
              padding: const EdgeInsets.all(HarmoniaSpacing.lg),
              children: [
                const Text(
                  'İki ses duyacaksın. Hangisi daha tiz (ince)? Bu bir dinleme çalışmasıdır; mikrofon kullanılmaz ve şarkı söyleme becerin hakkında bir şey söylemez.',
                ),
                const SizedBox(height: HarmoniaSpacing.md),
                Wrap(
                  spacing: HarmoniaSpacing.sm,
                  runSpacing: HarmoniaSpacing.sm,
                  children: [
                    for (final l in levels)
                      ChoiceChip(
                        key: Key('perc_level_${l.exerciseId}'),
                        label: Text(l.title),
                        selected: l == c.level,
                        onSelected: selectable ? (_) => c.selectLevel(l) : null,
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
                    'Kalıcılık kontrolü: her çifti bir kez dinleyebilirsin.',
                    key: Key('perc_retention_label'),
                  ),
                const SizedBox(height: HarmoniaSpacing.md),
                if (o == null) ...[
                  Text(
                    'Soru ${c.index + 1} / ${c.round.items.length}',
                    key: const Key('perc_progress'),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: HarmoniaSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('perc_play'),
                    onPressed: c.canPlay ? c.playCurrent : null,
                    icon: const Icon(Icons.volume_up_outlined),
                    label: Text(
                      c.plays[c.index] == 0 ? 'Dinle' : 'Tekrar dinle',
                    ),
                  ),
                  if (c.playbackFailed)
                    const Text('Ses çalınamadı. Yeniden dene.'),
                  const SizedBox(height: HarmoniaSpacing.sm),
                  Row(
                    children: [
                      for (final (a, label) in const [
                        (PitchAnswer.first, '1. ses'),
                        (PitchAnswer.second, '2. ses'),
                      ]) ...[
                        Expanded(
                          child: FilledButton(
                            key: Key('perc_answer_${a.name}'),
                            onPressed: c.canAnswer ? () => c.answer(a) : null,
                            child: Text('$label daha tiz'),
                          ),
                        ),
                        if (a == PitchAnswer.first)
                          const SizedBox(width: HarmoniaSpacing.sm),
                      ],
                    ],
                  ),
                  if (c.phase == PitchComparisonPhase.feedback) ...[
                    const SizedBox(height: HarmoniaSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        c.lastAnswerCorrect
                            ? 'Doğru.'
                            : 'Bu sefer değil: ${c.round.items[c.index].correct == PitchAnswer.first ? '1.' : '2.'} ses daha tizdi. İstersen tekrar dinleyip karşılaştır.',
                        key: const Key('perc_feedback'),
                        style: TextStyle(
                          color: c.lastAnswerCorrect
                              ? colors.correct
                              : colors.incorrect,
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const Key('perc_next'),
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
  final PitchComparisonController controller;
  final PitchComparisonOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final total = outcome.round.items.length;
    final clean =
        outcome.correctCount >= PitchComparisonMeasuredExercise.minCorrect;
    return Card(
      key: const Key('perc_summary'),
      child: Padding(
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$total sorudan ${outcome.correctCount} doğru.',
              key: const Key('perc_summary_text'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Şans düzeyi %${PitchComparisonOutcome.chanceLevelPercent}: rastgele seçimle ortalama ${total ~/ 2} doğru beklenir. '
              '${clean ? 'Bu tur taslak ölçütü karşıladı (en az ${PitchComparisonMeasuredExercise.minCorrect}/$total).' : 'Taslak ölçüt: art arda iki turda en az ${PitchComparisonMeasuredExercise.minCorrect}/$total.'}',
            ),
            if (outcome.referencePlays > 1)
              const Text(
                'Bazı çiftleri tekrar dinledin; tek dinlemeyle başarı “bağımsız” sayılır.',
              ),
            if (controller.recordOutcome != null)
              const Text('Sonuç bu cihazdaki geçmişine kaydedildi.'),
            if (controller.historyFailed)
              const Text('Sonuç geçmişe kaydedilemedi.'),
            const SizedBox(height: HarmoniaSpacing.sm),
            FilledButton(
              key: const Key('perc_new_round'),
              onPressed: controller.newRound,
              child: const Text('Yeni tur'),
            ),
          ],
        ),
      ),
    );
  }
}
