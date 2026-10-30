import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/pitch_comparison_controller.dart';
import '../../application/review_playback.dart';
import '../../application/result_history.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/perception/pitch_comparison.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../common/sound/playback_visual.dart';
import '../common/sound/waveform_playback_view.dart';
import '../common/ui/resonia_ui.dart';
import '../common/ui/answer_comparison_card.dart';
import '../learning/micro_lesson_screen.dart';

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
  bool _canLeave = false;
  bool _exiting = false;
  String? _exitError;

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
      unawaited(c.pause());
    }
  }

  Future<void> _exit() async {
    if (_exiting) return;
    setState(() {
      _exiting = true;
      _exitError = null;
    });
    try {
      await c.close();
      if (!mounted) return;
      setState(() => _canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _exitError =
            'Ses kaynağının kapandığı doğrulanamadı. Uygulamayı kapatıp yeniden aç.',
      );
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
    return PopScope<void>(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: ListenableBuilder(
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
              if (_exiting || _exitError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _exitError ?? 'Ses kapatılıyor…',
                    key: const Key('perc_exit_status'),
                  ),
                ),
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
                  const SizedBox(width: ResoniaSpacing.sm),
                  if (c.guidedRetry)
                    const StatusPill(
                      'Tekrar',
                      key: Key('perc_guided_label'),
                      tone: PillTone.warning,
                    )
                  else if (c.retentionCheck)
                    const StatusPill(
                      'Tek dinleme',
                      key: Key('perc_retention_label'),
                      tone: PillTone.warning,
                    )
                  else if (c.level.review !=
                      ContentReviewStatus.educatorApproved)
                    const StatusPill('Taslak'),
                ],
              ),
              const SizedBox(height: ResoniaSpacing.md),
              if (o == null) ...[
                Text(
                  'Hangisi daha tiz?',
                  key: const Key('perc_progress'),
                  style: text.headlineSmall,
                ),
                const SizedBox(height: ResoniaSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(ResoniaSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WaveformPlaybackView(
                          playback: _visual.current,
                          idleLabel: 'İki ses sırayla çalacak',
                        ),
                        const SizedBox(height: ResoniaSpacing.md),
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
                            padding: EdgeInsets.only(top: ResoniaSpacing.sm),
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
                        const SizedBox(width: ResoniaSpacing.sm + 4),
                    ],
                  ],
                ),
                if (feedback) ...[
                  const SizedBox(height: ResoniaSpacing.md),
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
    final text = Theme.of(context).textTheme;
    final total = outcome.round.items.length;
    final clean =
        !controller.guidedRetry &&
        outcome.correctCount >= PitchComparisonMeasuredExercise.minCorrect;
    final results = context.resultColors;
    return Column(
      key: const Key('perc_summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          controller.guidedRetry
              ? 'Hata tekrarı tamam'
              : clean
              ? 'Tur tamam'
              : 'Tur bitti',
          style: text.headlineSmall,
        ),
        const SizedBox(height: ResoniaSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Doğru',
                value: '${outcome.correctCount}/$total',
                valueColor: clean ? results.correct : null,
              ),
            ),
            const SizedBox(width: ResoniaSpacing.sm),
            Expanded(
              child: StatTile(
                label: 'Şans',
                value: '%${PitchComparisonOutcome.chanceLevelPercent}',
              ),
            ),
            const SizedBox(width: ResoniaSpacing.sm),
            Expanded(
              child: StatTile(
                label: 'Dinleme',
                value: '${outcome.referencePlays}×',
              ),
            ),
          ],
        ),
        const SizedBox(height: ResoniaSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(ResoniaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DataLabel('Ne oldu'),
                const SizedBox(height: ResoniaSpacing.xs),
                Text(
                  '$total sorudan ${outcome.correctCount} doğru.',
                  key: const Key('perc_summary_text'),
                  style: text.titleMedium,
                ),
                const SizedBox(height: ResoniaSpacing.xs),
                Text(
                  controller.guidedRetry
                      ? 'Yalnız önceki turda kaçırdığın $total çift tekrarlandı. Bu rehberli tur ölçüt veya ustalık kanıtı üretmez.'
                      : 'Şans düzeyi %${PitchComparisonOutcome.chanceLevelPercent}: rastgele seçimle ortalama ${total ~/ 2} doğru beklenir. '
                            '${clean ? 'Bu tur taslak ölçütü karşıladı (en az ${PitchComparisonMeasuredExercise.minCorrect}/$total).' : 'Taslak ölçüt: art arda iki turda en az ${PitchComparisonMeasuredExercise.minCorrect}/$total.'}',
                ),
                if (outcome.referencePlays > 1)
                  const Padding(
                    padding: EdgeInsets.only(top: ResoniaSpacing.xs),
                    child: Text(
                      'Bazı çiftleri tekrar dinledin; tek dinlemeyle başarı “bağımsız” sayılır.',
                    ),
                  ),
                if (controller.recordOutcome != null)
                  Padding(
                    padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                    child: Text(
                      'Sonuç bu cihazdaki geçmişine kaydedildi.',
                      style: text.bodySmall?.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ),
                if (controller.historyFailed)
                  const Text('Sonuç geçmişe kaydedilemedi.'),
                if (controller.guidedRetry)
                  const Padding(
                    padding: EdgeInsets.only(top: ResoniaSpacing.xs),
                    child: Text(
                      'Bu kısa hata tekrarı çalışma içindir; geçmişe, beceri durumuna veya sınav sonucuna eklenmedi.',
                      key: Key('perc_guided_notice'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ResoniaSpacing.md),
        if (controller.mistakeCount > 0) ...[
          ChunkyButton(
            key: const Key('perc_guided_retry'),
            label: 'Hataları hedefli çalış (${controller.mistakeCount})',
            icon: Icons.my_location_rounded,
            onPressed: () => unawaited(controller.startGuidedRetry()),
          ),
          const SizedBox(height: ResoniaSpacing.sm),
          if (!controller.guidedRetry) ...[
            OutlinedButton.icon(
              key: const Key('perc_concept_review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MicroLessonScreen(
                    lesson: draftMicroLessons.forSkill('pitch-high-low').single,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Kavramı gözden geçir'),
            ),
            const Text(
              'İsteğe bağlı metin taslağıdır; tur sonucunu ve beceri durumunu değiştirmez.',
            ),
            const SizedBox(height: ResoniaSpacing.sm),
          ],
        ],
        ChunkyButton(
          key: const Key('perc_new_round'),
          label: 'Yeni tur',
          icon: Icons.replay_rounded,
          onPressed: controller.newRound,
        ),
        const SizedBox(height: ResoniaSpacing.lg),
        Text('Cevaplarını karşılaştır', style: text.titleLarge),
        const Text(
          'Çalınan sentetik örnek ile dokunarak verdiğin cevap gösterilir; '
          'bu bir ses kaydı veya söyleme değerlendirmesi değildir. '
          'Ayrıntı ve isteğe bağlı tekrar dinleme için soruyu aç. '
          'Bu dinleme tur sonucunu değiştirmez.',
        ),
        for (var i = 0; i < total; i++)
          AnswerComparisonCard(
            key: Key('perc_review_$i'),
            questionNumber: i + 1,
            keyPrefix: 'perc_review_$i',
            reference: outcome.round.items[i].correct == PitchAnswer.second
                ? 'İki ton: ikinci ses birinciden daha tiz.'
                : 'İki ton: ikinci ses birinciden daha pes.',
            selected: outcome.answers[i] == null
                ? null
                : outcome.answers[i] == PitchAnswer.first
                ? 'İlk ses daha tiz'
                : 'İkinci ses daha tiz',
            correct: outcome.round.items[i].correct == PitchAnswer.first
                ? 'İlk ses daha tiz'
                : 'İkinci ses daha tiz',
            onPlayReference:
                controller.review.itemIndex == i && controller.review.busy
                ? controller.review.cancel
                : () => controller.reviewReference(i),
            referenceLoading:
                controller.review.itemIndex == i &&
                controller.review.state == ReviewPlaybackState.loading,
            referencePlaying:
                controller.review.itemIndex == i &&
                controller.review.state == ReviewPlaybackState.playing,
            playbackFailed:
                controller.review.itemIndex == i &&
                controller.review.state == ReviewPlaybackState.failed,
          ),
      ],
    );
  }
}
