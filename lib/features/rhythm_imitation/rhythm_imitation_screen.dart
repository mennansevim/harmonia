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
                          const StatusPill(
                            'Tek dinleme',
                            key: Key('rhythm_retention_label'),
                            tone: PillTone.warning,
                          ),
                        if (c.isGuided)
                          const StatusPill(
                            'Hedefli tekrar',
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
                  ? 'Zor bölümü dinle, sonra tekrar et'
                  : 'Dinle, sonra aynı ritme dokun',
              style: text.headlineSmall,
            ),
            const SizedBox(height: ResoniaSpacing.xs),
            Text(
              'İlk dokunuşun başlangıç sayılır; sonrakiler tempoyla karşılaştırılır.',
              style: text.bodyMedium?.copyWith(color: context.palette.muted),
            ),
            if (c.pattern.review != ContentReviewStatus.educatorApproved)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                child: Text(
                  'Taslak içerik — eğitimci onayı bekliyor. ${c.pattern.description}',
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
                      idleLabel: 'Ritim burada çalacak',
                    ),
                    const SizedBox(height: ResoniaSpacing.md),
                    ChunkyButton(
                      key: const Key('rhythm_listen'),
                      onPressed: c.canListen ? c.listen : null,
                      icon: Icons.volume_up_rounded,
                      tone: c.referencePlays == 0
                          ? ChunkyTone.primary
                          : ChunkyTone.neutral,
                      label:
                          'Dinle (${c.referencePlays}/${c.maxReferencePlays})',
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
                        label: const Text('Zor bölümü çalış'),
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
                        label: const Text('Puls kavramını gözden geçir'),
                      ),
                      const Text(
                        'İsteğe bağlı metin taslağıdır; denemeyi, puanı veya sonraki adımı değiştirmez.',
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
                    child: const Text('Tam desene dön'),
                  ),
                ),
              if (_saveText(c) case final saved?)
                Text(saved, key: const Key('rhythm_saved')),
              if (c.nextStep != null) _NextStepCard(controller: c),
              if (o.isMeasured)
                TextButton(
                  key: const Key('rhythm_details'),
                  onPressed: () => setState(() => _details = !_details),
                  child: Text(_details ? 'Ayrıntıyı gizle' : 'Ölçüm ayrıntısı'),
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
                label: 'Bitirdim',
              ),
            if (c.tapsDuringReference > 0)
              Text(
                'Referans çalarken ${c.tapsDuringReference} dokunuş oldu; bunlar değerlendirilmedi.',
              ),
            if (c.playbackFailed)
              const Text(
                'Referans çalınamadı. Yeniden deneyebilirsin.',
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
    return 'Sonuç geçmişe kaydedilemedi; bu deneme yine de geçerli.';
  }
  return switch (c.recordOutcome) {
    null => null,
    RecordOutcome.recorded ||
    RecordOutcome.duplicate => 'Sonuç bu cihazdaki geçmişine kaydedildi.',
    RecordOutcome.conflict =>
      'Bu deneme geçmişte farklı kayıtlı; üzerine yazılmadı.',
    RecordOutcome.storageFull =>
      'Geçmiş dolu. Yeni sonuçlar için Geçmiş ekranından eski kayıtları sil.',
  };
}

String _status(RhythmImitationController c) => switch (c.phase) {
  RhythmImitationPhase.idle => 'Önce ritmi dinle.',
  RhythmImitationPhase.listening => 'Dinle… (dokunuşlar değerlendirilmez)',
  RhythmImitationPhase.awaitingTaps => 'Hazır olunca dokunmaya başla.',
  RhythmImitationPhase.tapping => '${c.tapCount} vuruş alındı.',
  RhythmImitationPhase.evaluating => 'Karşılaştırılıyor…',
  RhythmImitationPhase.finished =>
    c.isGuided ? 'Hedefli tekrar bitti — puanlanmadı.' : 'Deneme bitti.',
  RhythmImitationPhase.closed => 'Kapandı.',
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
      label: 'Vuruş alanı',
      hint: 'Ekran okuyucu açıkken dokunma zamanlaması değişebilir.',
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
                    active ? 'Buraya dokun' : 'Dinledikten sonra açılır',
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
                ? 'Ölçüm alınamadı — puanlanmadı. Ritmi karşılaştırmak için en az iki vuruş gerekli.'
                : 'Ölçüm alınamadı — puanlanmadı. Yeniden dene.',
            key: const Key('rhythm_result_summary'),
          ),
        ),
      );
    }
    final a = outcome.analysis!;
    // The anchor is the first reference beat, produced but never timed.
    final referenceBeats = a.matchedCount + a.missedCount + 1;
    final summary = StringBuffer(
      '$referenceBeats vuruşun ${a.matchedCount + 1} tanesi eşleşti (ilki başlangıç)',
    );
    if (a.missedCount > 0) summary.write(', ${a.missedCount} eksik');
    if (a.extraCount > 0) summary.write(', ${a.extraCount} fazla');
    if (a.earlyCount > 0) summary.write(', ${a.earlyCount} erken');
    if (a.lateCount > 0) summary.write(', ${a.lateCount} geç');
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
                  ? 'Hedefli tekrar — puanlanmadı. ${summary.toString()}'
                  : summary.toString(),
              key: const Key('rhythm_result_summary'),
              style: text.titleMedium,
            ),
            if (outcome.tempoDiffers)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.xs),
                child: Text(
                  outcome.spanRatio! > 1
                      ? 'Genel olarak referanstan yavaş çaldın; vuruşlar giderek geç kaldı.'
                      : 'Genel olarak referanstan hızlı çaldın; vuruşlar giderek erken geldi.',
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
        'Başlangıç',
        Icons.flag_outlined,
        colors.notMeasured,
      ),
      BeatVerdict.onTime => ('Zamanında', Icons.check, colors.correct),
      BeatVerdict.early => (
        '${entry.offsetMs!.abs()} ms erken',
        Icons.fast_rewind,
        colors.nearMiss,
      ),
      BeatVerdict.late => (
        '${entry.offsetMs} ms geç',
        Icons.fast_forward,
        colors.nearMiss,
      ),
      BeatVerdict.missed => ('Eksik', Icons.close, colors.incorrect),
      BeatVerdict.extra => ('Fazla', Icons.add, colors.incorrect),
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
            'Deneysel zamanlama puanı: ${a.timingAccuracy.value?.toStringAsFixed(0) ?? "Ölçülmedi"}',
          ),
          Text(
            'Ortalama mutlak sapma: ${a.averageAbsoluteOffsetMs?.toStringAsFixed(0) ?? "Ölçülmedi"}${a.averageAbsoluteOffsetMs == null ? "" : " ms"}',
          ),
          Text('Referans dinleme: ${outcome.referencePlays}'),
          const Text(
            'Puan formülü ilk deterministik sürümdür; sınav rubriği değildir ve eğitimci kalibrasyonu bekliyor. İlk vuruş başlangıç kabul edildiği için puana katılmaz.',
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
            Text('Sonraki adım', style: Theme.of(context).textTheme.labelLarge),
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
