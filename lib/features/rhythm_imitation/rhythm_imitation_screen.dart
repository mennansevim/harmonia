import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/result_history.dart';
import '../../application/rhythm_imitation_controller.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/rhythm_imitation.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../common/sound/playback_visual.dart';
import '../common/sound/waveform_playback_view.dart';
import '../common/ui/resonia_ui.dart';
import '../learning/next_step_text.dart';
import '../learning/micro_lesson_screen.dart';
import '../../domain/lang.dart';

class RhythmImitationScreen extends StatefulWidget {
  const RhythmImitationScreen({
    super.key,
    this.player,
    this.patterns,
    this.history,
    this.initialPatternId,
    this.retentionCheck = false,
  });
  final String? initialPatternId;
  final bool retentionCheck;
  final ReferenceClipPlayer? player;
  final ResultHistoryRepository? history;
  final List<RhythmPattern>? patterns;
  @override
  State<RhythmImitationScreen> createState() => _RhythmImitationScreenState();
}

class _RhythmImitationScreenState extends State<RhythmImitationScreen>
    with WidgetsBindingObserver {
  late final List<RhythmPattern> patterns =
      widget.patterns ?? draftRhythmPatterns;
  late final RhythmImitationController controller;
  late final VisualizingClipPlayer _visual;
  bool _details = false;

  @override
  void initState() {
    super.initState();
    controller = RhythmImitationController(
      player: _visual = VisualizingClipPlayer(
        widget.player ?? JustAudioClipPlayer(),
      ),
      renderReference: (ms) => renderClickTrack(ms).encode(),
      initialPattern: patterns.firstWhere(
        (p) => p.exercise.exercise.id == widget.initialPatternId,
        orElse: () => patterns.first,
      ),
      history: widget.history,
      catalog: patterns,
    )..retentionCheck = widget.retentionCheck;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(controller.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final selectable =
            c.phase == RhythmImitationPhase.idle ||
            c.phase == RhythmImitationPhase.awaitingTaps ||
            c.phase == RhythmImitationPhase.finished;
        final progress = switch (c.phase) {
          RhythmImitationPhase.idle => c.referencePlays > 0 ? .34 : 0.0,
          RhythmImitationPhase.listening => .2,
          RhythmImitationPhase.awaitingTaps => .4,
          RhythmImitationPhase.tapping => .7,
          RhythmImitationPhase.evaluating => .9,
          RhythmImitationPhase.finished || RhythmImitationPhase.closed => 1.0,
        };
        return LessonScaffold(
          progress: progress,
          top: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LevelPicker(
                  keyPrefix: 'rhythm',
                  choices: [
                    for (final p in patterns)
                      LevelChoice(
                        id: p.exercise.exercise.id,
                        title: p.title,
                        subtitle: p.description,
                      ),
                  ],
                  selectedId: c.pattern.exercise.exercise.id,
                  onSelected: selectable
                      ? (id) => c.selectPattern(
                          patterns.firstWhere(
                            (p) => p.exercise.exercise.id == id,
                          ),
                        )
                      : null,
                ),
                if (c.retentionCheck || c.isGuided)
                  Padding(
                    padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                    child: Wrap(
                      spacing: ResoniaSpacing.xs,
                      runSpacing: ResoniaSpacing.xs,
                      children: [
                        if (c.retentionCheck)
                          StatusPill(
                            tr('Tek dinleme', 'Single listen'),
                            key: Key('rhythm_retention_label'),
                            tone: PillTone.warning,
                          ),
                        if (c.isGuided)
                          StatusPill(
                            tr('Hedefli tekrar', 'Targeted repeat'),
                            key: Key('rhythm_guided_label'),
                            tone: PillTone.warning,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: ResoniaSpacing.md),
            Text(
              c.isGuided
                  ? tr(
                      'Zor bölümü dinle, sonra tekrar et',
                      'Hear the hard part, then repeat it',
                    )
                  : tr(
                      'Dinle, sonra aynı ritme dokun',
                      'Listen, then tap the same rhythm',
                    ),
              style: text.headlineSmall,
            ),
            const SizedBox(height: ResoniaSpacing.xs),
            Text(
              tr(
                'İlk dokunuşun başlangıç sayılır; sonrakiler tempoyla karşılaştırılır.',
                'Your first tap counts as the start; the rest are compared with the tempo.',
              ),
              style: text.bodyMedium?.copyWith(color: context.palette.muted),
            ),
            if (c.pattern.review != ContentReviewStatus.educatorApproved)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                child: Text(
                  tr(
                    'Taslak içerik — eğitimci onayı bekliyor. ${c.pattern.description}',
                    'Draft content — awaiting educator approval. ${c.pattern.description}',
                  ),
                  key: const Key('rhythm_draft_label'),
                  style: text.bodySmall?.copyWith(color: context.palette.muted),
                ),
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
                      height: 96,
                      idleLabel: tr(
                        'Ritim burada çalacak',
                        'The rhythm will play here',
                      ),
                    ),
                    const SizedBox(height: ResoniaSpacing.md),
                    ChunkyButton(
                      key: const Key('rhythm_listen'),
                      onPressed: c.canListen ? c.listen : null,
                      icon: Icons.volume_up_rounded,
                      tone: c.referencePlays == 0
                          ? ChunkyTone.primary
                          : ChunkyTone.neutral,
                      label: tr(
                        'Dinle (${c.referencePlays}/${c.maxReferencePlays})',
                        'Listen (${c.referencePlays}/${c.maxReferencePlays})',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _status(c),
                key: const Key('rhythm_status'),
                style: text.titleMedium,
              ),
            ),
            if (c.outcome case final o?) ...[
              const SizedBox(height: ResoniaSpacing.md),
              _Result(outcome: o),
              if (c.suggestedGuidedSegment != null)
                Padding(
                  padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        key: const Key('rhythm_start_guided'),
                        onPressed: c.startGuidedSegment,
                        icon: const Icon(Icons.center_focus_strong_rounded),
                        label: Text(
                          tr('Zor bölümü çalış', 'Practise the hard part'),
                        ),
                      ),
                      const SizedBox(height: ResoniaSpacing.xs),
                      OutlinedButton.icon(
                        key: const Key('rhythm_concept_review'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MicroLessonScreen(
                              lesson: draftMicroLessons
                                  .forSkill('pulse-tap')
                                  .single,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined),
                        label: Text(
                          tr(
                            'Puls kavramını gözden geçir',
                            'Review the idea of pulse',
                          ),
                        ),
                      ),
                      Text(
                        tr(
                          'İsteğe bağlı metin taslağıdır; denemeyi, puanı veya sonraki adımı değiştirmez.',
                          'An optional draft text; it does not change the attempt, the score or the next step.',
                        ),
                      ),
                    ],
                  ),
                ),
              if (c.isGuided)
                Padding(
                  padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                  child: OutlinedButton(
                    key: const Key('rhythm_exit_guided'),
                    onPressed: c.exitGuidedSegment,
                    child: Text(
                      tr('Tam desene dön', 'Back to the full pattern'),
                    ),
                  ),
                ),
              if (_saveText(c) case final saved?)
                Text(saved, key: const Key('rhythm_saved')),
              if (c.nextStep != null) _NextStepCard(controller: c),
              if (o.isMeasured)
                TextButton(
                  key: const Key('rhythm_details'),
                  onPressed: () => setState(() => _details = !_details),
                  child: Text(
                    _details
                        ? tr('Ayrıntıyı gizle', 'Hide details')
                        : tr('Ölçüm ayrıntısı', 'Measurement details'),
                  ),
                ),
              if (_details && o.isMeasured) _Details(outcome: o),
            ],
          ],
          bottom: [
            _TapPad(controller: c),
            if (c.phase == RhythmImitationPhase.tapping)
              ChunkyButton(
                key: const Key('rhythm_finish'),
                onPressed: c.finish,
                tone: ChunkyTone.success,
                icon: Icons.check_rounded,
                label: tr('Bitirdim', 'I am done'),
              ),
            if (c.tapsDuringReference > 0)
              Text(
                tr(
                  'Referans çalarken ${c.tapsDuringReference} dokunuş oldu; bunlar değerlendirilmedi.',
                  '${c.tapsDuringReference} taps came while the reference played; they were not assessed.',
                ),
              ),
            if (c.playbackFailed)
              Text(
                tr(
                  'Referans çalınamadı. Yeniden deneyebilirsin.',
                  'The reference could not play. You can try again.',
                ),
                key: Key('rhythm_playback_error'),
              ),
          ],
        );
      },
    );
  }
}

String? _saveText(RhythmImitationController c) {
  if (c.historyFailed) {
    return tr(
      'Sonuç geçmişe kaydedilemedi; bu deneme yine de geçerli.',
      'The result could not be saved to history; this attempt still counts.',
    );
  }
  return switch (c.recordOutcome) {
    null => null,
    RecordOutcome.recorded || RecordOutcome.duplicate => tr(
      'Sonuç bu cihazdaki geçmişine kaydedildi.',
      'The result was saved to your history on this device.',
    ),
    RecordOutcome.conflict => tr(
      'Bu deneme geçmişte farklı kayıtlı; üzerine yazılmadı.',
      'This attempt is stored differently in history; it was not overwritten.',
    ),
    RecordOutcome.storageFull => tr(
      'Geçmiş dolu. Yeni sonuçlar için Geçmiş ekranından eski kayıtları sil.',
      'History is full. Delete old entries in History to keep new results.',
    ),
  };
}

String _status(RhythmImitationController c) => switch (c.phase) {
  RhythmImitationPhase.idle => tr(
    'Önce ritmi dinle.',
    'Listen to the rhythm first.',
  ),
  RhythmImitationPhase.listening => tr(
    'Dinle… (dokunuşlar değerlendirilmez)',
    'Listen… (taps are not assessed)',
  ),
  RhythmImitationPhase.awaitingTaps => tr(
    'Hazır olunca dokunmaya başla.',
    'Start tapping when you are ready.',
  ),
  RhythmImitationPhase.tapping => tr(
    '${c.tapCount} vuruş alındı.',
    '${c.tapCount} taps received.',
  ),
  RhythmImitationPhase.evaluating => tr('Karşılaştırılıyor…', 'Comparing…'),
  RhythmImitationPhase.finished =>
    c.isGuided
        ? tr(
            'Hedefli tekrar bitti — puanlanmadı.',
            'Targeted repeat finished — not scored.',
          )
        : tr('Deneme bitti.', 'Attempt finished.'),
  RhythmImitationPhase.closed => tr('Kapandı.', 'Closed.'),
};

class _TapPad extends StatefulWidget {
  const _TapPad({required this.controller});
  final RhythmImitationController controller;
  @override
  State<_TapPad> createState() => _TapPadState();
}

/// Big thumb target. Timing comes from the pointer-down engine timestamp;
/// the ring and haptic are feedback only and never delay the measurement.
class _TapPadState extends State<_TapPad> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final c = widget.controller;
    final active = c.acceptsTaps;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      enabled: active,
      label: tr('Vuruş alanı', 'Tap area'),
      hint: tr(
        'Ekran okuyucu açıkken dokunma zamanlaması değişebilir.',
        'Tap timing may change while a screen reader is on.',
      ),
      child: Listener(
        key: const Key('rhythm_tap_pad'),
        behavior: HitTestBehavior.opaque,
        // Engine timestamp of the pointer-down: monotonic, frame-independent.
        onPointerDown: (event) {
          c.registerTap(event.timeStamp);
          if (!active) return;
          if (ResoniaHapticsScope.enabled(context)) {
            HapticFeedback.lightImpact();
          }
          if (!ResoniaMotion.reduced(context)) _pulse.forward(from: 0);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 200),
          padding: const EdgeInsets.all(ResoniaSpacing.md),
          margin: const EdgeInsets.symmetric(vertical: ResoniaSpacing.sm),
          decoration: BoxDecoration(
            color: active ? palette.coral : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Color.lerp(palette.coral, Colors.black, .28)!,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeOutCubic.transform(_pulse.value);
                  return Opacity(
                    opacity: (1 - t) * (_pulse.isAnimating ? 0.5 : 0),
                    child: Container(
                      width: 80 + 160 * t,
                      height: 80 + 160 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 40,
                    color: active ? Colors.white : palette.muted,
                  ),
                  const SizedBox(height: ResoniaSpacing.xs),
                  Text(
                    active
                        ? tr('Buraya dokun', 'Tap here')
                        : tr(
                            'Dinledikten sonra açılır',
                            'Opens after you listen',
                          ),
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(
                      color: active ? Colors.white : palette.muted,
                    ),
                  ),
                  if (c.phase == RhythmImitationPhase.tapping)
                    Text(
                      '${c.tapCount}',
                      style: text.displaySmall?.copyWith(
                        color: Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.outcome});
  final RhythmImitationOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final colors = context.resultColors;
    final text = Theme.of(context).textTheme;
    if (!outcome.isMeasured) {
      return Card(
        key: const Key('rhythm_result'),
        child: Padding(
          padding: const EdgeInsets.all(ResoniaSpacing.md),
          child: Text(
            outcome.status == RhythmImitationStatus.tooFewTaps
                ? tr(
                    'Ölçüm alınamadı — puanlanmadı. Ritmi karşılaştırmak için en az iki vuruş gerekli.',
                    'No measurement — not scored. At least two taps are needed to compare the rhythm.',
                  )
                : tr(
                    'Ölçüm alınamadı — puanlanmadı. Yeniden dene.',
                    'No measurement — not scored. Try again.',
                  ),
            key: const Key('rhythm_result_summary'),
          ),
        ),
      );
    }
    final a = outcome.analysis!;
    // The anchor is the first reference beat, produced but never timed.
    final referenceBeats = a.matchedCount + a.missedCount + 1;
    final summary = StringBuffer(
      tr(
        '$referenceBeats vuruşun ${a.matchedCount + 1} tanesi eşleşti (ilki başlangıç)',
        '${a.matchedCount + 1} of $referenceBeats beats matched (the first is the start)',
      ),
    );
    if (a.missedCount > 0) {
      summary.write(
        tr(', ${a.missedCount} eksik', ', ${a.missedCount} missed'),
      );
    }
    if (a.extraCount > 0) {
      summary.write(tr(', ${a.extraCount} fazla', ', ${a.extraCount} extra'));
    }
    if (a.earlyCount > 0) {
      summary.write(tr(', ${a.earlyCount} erken', ', ${a.earlyCount} early'));
    }
    if (a.lateCount > 0) {
      summary.write(tr(', ${a.lateCount} geç', ', ${a.lateCount} late'));
    }
    summary.write('.');
    return Card(
      key: const Key('rhythm_result'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              outcome.guided
                  ? tr(
                      'Hedefli tekrar — puanlanmadı. ${summary.toString()}',
                      'Targeted repeat — not scored. ${summary.toString()}',
                    )
                  : summary.toString(),
              key: const Key('rhythm_result_summary'),
              style: text.titleMedium,
            ),
            if (outcome.tempoDiffers)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                child: Text(
                  outcome.spanRatio! > 1
                      ? tr(
                          'Genel olarak referanstan yavaş çaldın; vuruşlar giderek geç kaldı.',
                          'Overall you played slower than the reference; the taps fell further behind.',
                        )
                      : tr(
                          'Genel olarak referanstan hızlı çaldın; vuruşlar giderek erken geldi.',
                          'Overall you played faster than the reference; the taps came earlier and earlier.',
                        ),
                  key: const Key('rhythm_tempo_hint'),
                ),
              ),
            const SizedBox(height: ResoniaSpacing.sm),
            Wrap(
              spacing: ResoniaSpacing.xs,
              runSpacing: ResoniaSpacing.xs,
              children: [
                for (final (i, e) in outcome.timeline.indexed)
                  _BeatChip(entry: e, index: i, colors: colors),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatChip extends StatelessWidget {
  const _BeatChip({
    required this.entry,
    required this.index,
    required this.colors,
  });
  final BeatTimelineEntry entry;
  final int index;
  final ResoniaResultColors colors;
  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (entry.verdict) {
      BeatVerdict.anchor => (
        tr('Başlangıç', 'Start'),
        Icons.flag_outlined,
        colors.notMeasured,
      ),
      BeatVerdict.onTime => (
        tr('Zamanında', 'On time'),
        Icons.check,
        colors.correct,
      ),
      BeatVerdict.early => (
        tr(
          '${entry.offsetMs!.abs()} ms erken',
          '${entry.offsetMs!.abs()} ms early',
        ),
        Icons.fast_rewind,
        colors.nearMiss,
      ),
      BeatVerdict.late => (
        tr('${entry.offsetMs} ms geç', '${entry.offsetMs} ms late'),
        Icons.fast_forward,
        colors.nearMiss,
      ),
      BeatVerdict.missed => (
        tr('Eksik', 'Missed'),
        Icons.close,
        colors.incorrect,
      ),
      BeatVerdict.extra => (tr('Fazla', 'Extra'), Icons.add, colors.incorrect),
    };
    return Semantics(
      label: '${index + 1}. $label',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, color: color, size: 18),
        label: Text(label),
        side: BorderSide(color: color),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.outcome});
  final RhythmImitationOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final a = outcome.analysis!;
    return Padding(
      key: const Key('rhythm_details_panel'),
      padding: const EdgeInsets.symmetric(vertical: ResoniaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'Deneysel zamanlama puanı: ${a.timingAccuracy.value?.toStringAsFixed(0) ?? "Ölçülmedi"}',
              'Experimental timing score: ${a.timingAccuracy.value?.toStringAsFixed(0) ?? "Not measured"}',
            ),
          ),
          Text(
            tr(
              'Ortalama mutlak sapma: ${a.averageAbsoluteOffsetMs?.toStringAsFixed(0) ?? "Ölçülmedi"}${a.averageAbsoluteOffsetMs == null ? "" : " ms"}',
              'Mean absolute offset: ${a.averageAbsoluteOffsetMs?.toStringAsFixed(0) ?? "Not measured"}${a.averageAbsoluteOffsetMs == null ? "" : " ms"}',
            ),
          ),
          Text(
            tr(
              'Referans dinleme: ${outcome.referencePlays}',
              'Reference plays: ${outcome.referencePlays}',
            ),
          ),
          Text(
            tr(
              'Puan formülü ilk deterministik sürümdür; sınav rubriği değildir ve eğitimci kalibrasyonu bekliyor. İlk vuruş başlangıç kabul edildiği için puana katılmaz.',
              'The score formula is a first deterministic version; it is not an exam rubric and awaits educator calibration. The first tap is the start, so it is left out of the score.',
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.controller});
  final RhythmImitationController controller;
  @override
  Widget build(BuildContext context) {
    final (title, reason, action) = nextStepText(controller.nextStep!);
    return Card(
      key: const Key('rhythm_next_step'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Sonraki adım', 'Next step'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(reason),
            if (action.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                child: FilledButton(
                  key: const Key('rhythm_apply_next'),
                  onPressed: controller.applyNextStep,
                  child: Text(action),
                ),
              ),
            Text(
              draftCriterionNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
