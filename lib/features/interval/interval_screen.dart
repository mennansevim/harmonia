import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/interval_controller.dart';
import '../../application/review_playback.dart';
import '../../application/result_history.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/learning/measured_exercise.dart';
import '../../domain/perception/interval_identification.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../common/sound/playback_visual.dart';
import '../common/sound/waveform_playback_view.dart';
import '../common/ui/harmonia_ui.dart';
import '../common/ui/answer_comparison_card.dart';
import '../learning/micro_lesson_screen.dart';

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
  late final VisualizingClipPlayer _visual;
  bool _canLeave = false;
  bool _exiting = false;
  String? _exitError;

  @override
  void initState() {
    super.initState();
    c = IntervalController(
      player: _visual = VisualizingClipPlayer(
        widget.player ?? JustAudioClipPlayer(),
      ),
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
          final item = c.round.items[c.index];
          final feedback = c.phase == IntervalPhase.feedback;
          final total = c.round.items.length;
          OptionState stateOf(SolfegeDegree d) {
            if (!feedback) return OptionState.idle;
            if (d == item.degree) return OptionState.correct;
            if (d == c.answers[c.index]) return OptionState.wrong;
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
                    key: const Key('int_exit_status'),
                  ),
                ),
              Row(
                children: [
                  Flexible(
                    child: LevelPicker(
                      keyPrefix: 'int',
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
                  if (c.guidedRetry)
                    const StatusPill(
                      'Tekrar',
                      key: Key('int_guided_label'),
                      tone: PillTone.warning,
                    )
                  else if (c.retentionCheck)
                    const StatusPill(
                      'Tek dinleme',
                      key: Key('int_retention_label'),
                      tone: PillTone.warning,
                    )
                  else if (c.level.review !=
                      ContentReviewStatus.educatorApproved)
                    const StatusPill('Taslak'),
                ],
              ),
              const SizedBox(height: HarmoniaSpacing.md),
              if (o == null) ...[
                Text(
                  'Do\'dan sonra hangi derece?',
                  key: const Key('int_progress'),
                  style: text.headlineSmall,
                ),
                const SizedBox(height: HarmoniaSpacing.xs),
                Text(
                  'Önce tonu duy (do–mi–sol), sonra do ve hedef ses.',
                  style: text.bodyMedium?.copyWith(
                    color: context.palette.muted,
                  ),
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
                          idleLabel: 'Tonik, ardından do ve hedef derece',
                        ),
                        const SizedBox(height: HarmoniaSpacing.md),
                        ChunkyButton(
                          key: const Key('int_play'),
                          onPressed: c.canPlay ? c.playCurrent : null,
                          icon: Icons.volume_up_rounded,
                          tone: c.plays[c.index] == 0
                              ? ChunkyTone.primary
                              : ChunkyTone.neutral,
                          label: c.phase == IntervalPhase.playing
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
                EqualHeightGrid(
                  children: [
                    for (final d in c.level.options)
                      AnswerOption(
                        key: Key('int_answer_${d.name}'),
                        title: d.syllable,
                        subtitle: d.intervalName,
                        state: stateOf(d),
                        onTap: c.canAnswer ? () => c.answer(d) : null,
                      ),
                  ],
                ),
                if (feedback) ...[
                  const SizedBox(height: HarmoniaSpacing.md),
                  FeedbackPanel(
                    correct: c.lastAnswerCorrect,
                    textKey: const Key('int_feedback'),
                    actionKey: const Key('int_next'),
                    title: c.lastAnswerCorrect
                        ? 'Doğru: ${item.degree.syllable} (${item.degree.intervalName}).'
                        : 'Bu sefer değil: ${item.degree.syllable} idi (${item.degree.intervalName}).',
                    detail: c.lastAnswerCorrect
                        ? null
                        : 'Tekrar dinleyip do\'dan uzaklığı karşılaştır.',
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
  final IntervalController controller;
  final IntervalOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = outcome.round.items.length;
    final clean =
        !controller.guidedRetry &&
        outcome.correctCount >= PerceptionCriterion.minCorrect;
    final confusions = outcome.confusions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      key: const Key('int_summary'),
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
        const SizedBox(height: HarmoniaSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Doğru',
                value: '${outcome.correctCount}/$total',
                valueColor: clean ? context.resultColors.correct : null,
              ),
            ),
            const SizedBox(width: HarmoniaSpacing.sm),
            Expanded(
              child: StatTile(
                label: 'Şans',
                value: '%${outcome.chancePercent.round()}',
              ),
            ),
            const SizedBox(width: HarmoniaSpacing.sm),
            Expanded(
              child: StatTile(
                label: 'Seçenek',
                value: '${outcome.round.level.options.length}',
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
                  key: const Key('int_summary_text'),
                  style: text.titleMedium,
                ),
                const SizedBox(height: HarmoniaSpacing.xs),
                Text(
                  controller.guidedRetry
                      ? 'Yalnız önceki turda kaçırdığın $total derece tekrarlandı. Bu rehberli tur ölçüt veya ustalık kanıtı üretmez.'
                      : 'Şans düzeyi yaklaşık %${outcome.chancePercent.round()} (${outcome.round.level.options.length} seçenek). Taslak ölçüt: art arda iki turda en az ${PerceptionCriterion.minCorrect}/$total.',
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
                if (controller.guidedRetry)
                  const Padding(
                    padding: EdgeInsets.only(top: HarmoniaSpacing.xs),
                    child: Text(
                      'Bu kısa hata tekrarı çalışma içindir; geçmişe, beceri durumuna veya sınav sonucuna eklenmedi.',
                      key: Key('int_guided_notice'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (confusions.isNotEmpty) ...[
          const SizedBox(height: HarmoniaSpacing.sm),
          Card(
            color: context.palette.sun.withValues(alpha: .16),
            child: Padding(
              padding: const EdgeInsets.all(HarmoniaSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DataLabel('En çok karışan'),
                  const SizedBox(height: HarmoniaSpacing.xs),
                  Text(
                    'En çok karışan: ${confusions.first.key.replaceAll('→', ' yerine ')} (${confusions.first.value} kez). Bu iki dereceyi do\'dan başlayarak tekrar dinle.',
                    key: const Key('int_confusion'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: HarmoniaSpacing.md),
        if (controller.mistakeCount > 0) ...[
          ChunkyButton(
            key: const Key('int_guided_retry'),
            label: 'Hataları hedefli çalış (${controller.mistakeCount})',
            icon: Icons.my_location_rounded,
            onPressed: () => unawaited(controller.startGuidedRetry()),
          ),
          const SizedBox(height: HarmoniaSpacing.sm),
          if (!controller.guidedRetry) ...[
            OutlinedButton.icon(
              key: const Key('int_concept_review'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MicroLessonScreen(
                    lesson: draftMicroLessons.forSkill('tonic-degree').single,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Tonik ve dereceyi gözden geçir'),
            ),
            const Text(
              'İsteğe bağlı metin taslağıdır; tur sonucunu ve beceri durumunu değiştirmez.',
            ),
            const SizedBox(height: HarmoniaSpacing.sm),
          ],
        ],
        ChunkyButton(
          key: const Key('int_new_round'),
          label: 'Yeni tur',
          icon: Icons.replay_rounded,
          onPressed: controller.newRound,
        ),
        const SizedBox(height: HarmoniaSpacing.lg),
        Text('Cevaplarını karşılaştır', style: text.titleLarge),
        const Text(
          'Çalınan sentetik örnek ile dokunarak verdiğin cevap gösterilir; '
          'bu bir ses kaydı veya söyleme değerlendirmesi değildir. '
          'Ayrıntı ve isteğe bağlı karşılaştırmalı dinleme için soruyu aç. '
          'Bu dinlemeler tur sonucunu değiştirmez.',
        ),
        for (var i = 0; i < total; i++)
          AnswerComparisonCard(
            key: Key('int_review_$i'),
            questionNumber: i + 1,
            keyPrefix: 'int_review_$i',
            reference:
                'Do–mi–sol bağlamı, ardından do → '
                '${outcome.round.items[i].degree.syllable}.',
            selected: outcome.answers[i] == null
                ? null
                : '${outcome.answers[i]!.syllable} · ${outcome.answers[i]!.intervalName}',
            correct:
                '${outcome.round.items[i].degree.syllable} · '
                '${outcome.round.items[i].degree.intervalName}',
            onPlayReference:
                controller.review.itemIndex == i &&
                    controller.review.clipId == 'reference' &&
                    controller.review.busy
                ? controller.review.cancel
                : () => controller.reviewReference(i),
            onPlaySelected: outcome.answers[i] == null
                ? null
                : controller.review.itemIndex == i &&
                      controller.review.clipId == 'selected' &&
                      controller.review.busy
                ? controller.review.cancel
                : () => controller.reviewSelected(i),
            referenceLoading:
                controller.review.itemIndex == i &&
                controller.review.clipId == 'reference' &&
                controller.review.state == ReviewPlaybackState.loading,
            referencePlaying:
                controller.review.itemIndex == i &&
                controller.review.clipId == 'reference' &&
                controller.review.state == ReviewPlaybackState.playing,
            selectedLoading:
                controller.review.itemIndex == i &&
                controller.review.clipId == 'selected' &&
                controller.review.state == ReviewPlaybackState.loading,
            selectedPlaying:
                controller.review.itemIndex == i &&
                controller.review.clipId == 'selected' &&
                controller.review.state == ReviewPlaybackState.playing,
            playbackFailed:
                controller.review.itemIndex == i &&
                controller.review.state == ReviewPlaybackState.failed,
          ),
      ],
    );
  }
}
