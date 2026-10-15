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
import '../common/sound/playback_visual.dart';
import '../common/sound/waveform_playback_view.dart';
import '../common/ui/harmonia_ui.dart';

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
  late final VisualizingClipPlayer _visual;

  @override
  void initState() {
    super.initState();
    c = PitchComparisonController(
      player: _visual = VisualizingClipPlayer(
        widget.player ?? JustAudioClipPlayer(),
      ),
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
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final o = c.outcome;
        final feedback = c.phase == PitchComparisonPhase.feedback;
        final item = c.round.items[c.index];
        final total = c.round.items.length;
        OptionState stateOf(PitchAnswer a) {
          if (!feedback) return OptionState.idle;
          if (a == item.correct) return OptionState.correct;
          if (a == c.answers[c.index]) return OptionState.wrong;
          return OptionState.dimmed;
        }

        return LessonScaffold(
          progress: o != null ? 1 : (c.index + (feedback ? 1 : 0)) / total,
          counter: o == null ? '${c.index + 1}/$total' : null,
          top: [
            Row(
              children: [
                Flexible(
                  child: LevelPicker(
                    keyPrefix: 'perc',
                    choices: [
                      for (final l in levels)
                        LevelChoice(id: l.exerciseId, title: l.title),
                    ],
                    selectedId: c.level.exerciseId,
                    onSelected: c.canChangeLevel
                        ? (id) => c.selectLevel(
                            levels.firstWhere((l) => l.exerciseId == id),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: HarmoniaSpacing.sm),
                if (c.retentionCheck)
                  const StatusPill(
                    'Tek dinleme',
                    key: Key('perc_retention_label'),
                    tone: PillTone.warning,
                  )
                else if (c.level.review != ContentReviewStatus.educatorApproved)
                  const StatusPill('Taslak'),
              ],
            ),
            const SizedBox(height: HarmoniaSpacing.md),
            if (o == null) ...[
              Text(
                'Hangisi daha tiz?',
                key: const Key('perc_progress'),
                style: text.headlineSmall,
              ),
              const SizedBox(height: HarmoniaSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(HarmoniaSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WaveformPlaybackView(
                        playback: _visual.current,
                        idleLabel: 'İki ses sırayla çalacak',
                      ),
                      const SizedBox(height: HarmoniaSpacing.md),
                      ChunkyButton(
                        key: const Key('perc_play'),
                        onPressed: c.canPlay ? c.playCurrent : null,
                        icon: Icons.volume_up_rounded,
                        tone: c.plays[c.index] == 0
                            ? ChunkyTone.primary
                            : ChunkyTone.neutral,
                        label: c.phase == PitchComparisonPhase.playing
                            ? 'Çalıyor…'
                            : c.plays[c.index] == 0
                            ? 'Dinle'
                            : 'Tekrar dinle',
                      ),
                      if (c.playbackFailed)
                        const Padding(
                          padding: EdgeInsets.only(top: HarmoniaSpacing.sm),
                          child: Text('Ses çalınamadı. Yeniden dene.'),
                        ),
                    ],
                  ),
                ),
              ),
            ] else
              _Summary(controller: c, outcome: o),
          ],
          bottom: [
            if (o == null) ...[
              Row(
                children: [
                  for (final (a, label) in const [
                    (PitchAnswer.first, '1. ses'),
                    (PitchAnswer.second, '2. ses'),
                  ]) ...[
                    Expanded(
                      child: AnswerOption(
                        key: Key('perc_answer_${a.name}'),
                        title: label,
                        subtitle: 'daha tiz',
                        state: stateOf(a),
                        onTap: c.canAnswer ? () => c.answer(a) : null,
                      ),
                    ),
                    if (a == PitchAnswer.first)
                      const SizedBox(width: HarmoniaSpacing.sm + 4),
                  ],
                ],
              ),
              if (feedback) ...[
                const SizedBox(height: HarmoniaSpacing.md),
                FeedbackPanel(
                  correct: c.lastAnswerCorrect,
                  textKey: const Key('perc_feedback'),
                  actionKey: const Key('perc_next'),
                  title: c.lastAnswerCorrect
                      ? 'Doğru.'
                      : 'Bu sefer değil: ${item.correct == PitchAnswer.first ? '1.' : '2.'} ses daha tizdi.',
                  detail: c.lastAnswerCorrect
                      ? null
                      : 'Tekrar dinleyip karşılaştırabilirsin.',
                  actionLabel: c.index < total - 1
                      ? 'Sonraki soru'
                      : 'Turu bitir',
                  onAction: c.next,
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.controller, required this.outcome});
  final PitchComparisonController controller;
  final PitchComparisonOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = outcome.round.items.length;
    final clean =
        outcome.correctCount >= PitchComparisonMeasuredExercise.minCorrect;
    final results = context.resultColors;
    return Column(
      key: const Key('perc_summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(clean ? 'Tur tamam' : 'Tur bitti', style: text.headlineSmall),
        const SizedBox(height: HarmoniaSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Doğru',
                value: '${outcome.correctCount}/$total',
                valueColor: clean ? results.correct : null,
              ),
            ),
            const SizedBox(width: HarmoniaSpacing.sm),
            Expanded(
              child: StatTile(
                label: 'Şans',
                value: '%${PitchComparisonOutcome.chanceLevelPercent}',
              ),
            ),
            const SizedBox(width: HarmoniaSpacing.sm),
            Expanded(
              child: StatTile(
                label: 'Dinleme',
                value: '${outcome.referencePlays}×',
              ),
            ),
          ],
        ),
        const SizedBox(height: HarmoniaSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(HarmoniaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DataLabel('Ne oldu'),
                const SizedBox(height: HarmoniaSpacing.xs),
                Text(
                  '$total sorudan ${outcome.correctCount} doğru.',
                  key: const Key('perc_summary_text'),
                  style: text.titleMedium,
                ),
                const SizedBox(height: HarmoniaSpacing.xs),
                Text(
                  'Şans düzeyi %${PitchComparisonOutcome.chanceLevelPercent}: rastgele seçimle ortalama ${total ~/ 2} doğru beklenir. '
                  '${clean ? 'Bu tur taslak ölçütü karşıladı (en az ${PitchComparisonMeasuredExercise.minCorrect}/$total).' : 'Taslak ölçüt: art arda iki turda en az ${PitchComparisonMeasuredExercise.minCorrect}/$total.'}',
                ),
                if (outcome.referencePlays > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: HarmoniaSpacing.xs),
                    child: Text(
                      'Bazı çiftleri tekrar dinledin; tek dinlemeyle başarı “bağımsız” sayılır.',
                    ),
                  ),
                if (controller.recordOutcome != null)
                  Padding(
                    padding: const EdgeInsets.only(top: HarmoniaSpacing.xs),
                    child: Text(
                      'Sonuç bu cihazdaki geçmişine kaydedildi.',
                      style: text.bodySmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ),
                if (controller.historyFailed)
                  const Text('Sonuç geçmişe kaydedilemedi.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: HarmoniaSpacing.md),
        ChunkyButton(
          key: const Key('perc_new_round'),
          label: 'Yeni tur',
          icon: Icons.replay_rounded,
          onPressed: controller.newRound,
        ),
      ],
    );
  }
}
