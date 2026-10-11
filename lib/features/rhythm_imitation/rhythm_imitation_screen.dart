import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../application/result_history.dart';
import '../../application/rhythm_imitation_controller.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/rhythm_imitation.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../learning/next_step_text.dart';

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
  bool _details = false;

  @override
  void initState() {
    super.initState();
    controller = RhythmImitationController(
      player: widget.player ?? JustAudioClipPlayer(),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ritim tekrarı')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            final selectable =
                c.phase == RhythmImitationPhase.idle ||
                c.phase == RhythmImitationPhase.awaitingTaps ||
                c.phase == RhythmImitationPhase.finished;
            return ListView(
              padding: const EdgeInsets.all(HarmoniaSpacing.lg),
              children: [
                const Text(
                  'Dinle, sonra aynı ritmi alana dokunarak tekrar et. İlk dokunuşun başlangıç kabul edilir; onun zamanlaması ölçülmez, sonraki vuruşlar referans tempoda karşılaştırılır.',
                ),
                const SizedBox(height: HarmoniaSpacing.md),
                Wrap(
                  spacing: HarmoniaSpacing.sm,
                  runSpacing: HarmoniaSpacing.sm,
                  children: [
                    for (final p in patterns)
                      ChoiceChip(
                        key: Key('rhythm_pattern_${p.exercise.exercise.id}'),
                        label: Text(p.title),
                        selected: p == c.pattern,
                        onSelected: selectable
                            ? (_) => c.selectPattern(p)
                            : null,
                      ),
                  ],
                ),
                if (c.retentionCheck)
                  const Padding(
                    padding: EdgeInsets.only(top: HarmoniaSpacing.xs),
                    child: Text(
                      'Kalıcılık kontrolü: tek dinleme hakkın var.',
                      key: Key('rhythm_retention_label'),
                    ),
                  ),
                if (c.pattern.review != ContentReviewStatus.educatorApproved)
                  Padding(
                    padding: const EdgeInsets.only(top: HarmoniaSpacing.xs),
                    child: Text(
                      'Taslak içerik — eğitimci onayı bekliyor. ${c.pattern.description}',
                      key: const Key('rhythm_draft_label'),
                      style: text.bodySmall,
                    ),
                  ),
                const SizedBox(height: HarmoniaSpacing.md),
                OutlinedButton.icon(
                  key: const Key('rhythm_listen'),
                  onPressed: c.canListen ? c.listen : null,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: Text(
                    'Dinle (${c.referencePlays}/${c.maxReferencePlays})',
                  ),
                ),
                const SizedBox(height: HarmoniaSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _status(c),
                    key: const Key('rhythm_status'),
                    style: text.titleMedium,
                  ),
                ),
                if (c.outcome case final o?) ...[
                  const SizedBox(height: HarmoniaSpacing.md),
                  _Result(outcome: o),
                  if (_saveText(c) case final saved?)
                    Text(saved, key: const Key('rhythm_saved')),
                  if (c.nextStep != null) _NextStepCard(controller: c),
                  if (o.isMeasured)
                    TextButton(
                      key: const Key('rhythm_details'),
                      onPressed: () => setState(() => _details = !_details),
                      child: Text(
                        _details ? 'Ayrıntıyı gizle' : 'Ölçüm ayrıntısı',
                      ),
                    ),
                  if (_details && o.isMeasured) _Details(outcome: o),
                ],
                const SizedBox(height: HarmoniaSpacing.sm),
                _TapPad(controller: c),
                if (c.phase == RhythmImitationPhase.tapping)
                  FilledButton(
                    key: const Key('rhythm_finish'),
                    onPressed: c.finish,
                    child: const Text('Bitirdim'),
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
        ),
      ),
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
  RhythmImitationPhase.finished => 'Deneme bitti.',
  RhythmImitationPhase.closed => 'Kapandı.',
};

class _TapPad extends StatelessWidget {
  const _TapPad({required this.controller});
  final RhythmImitationController controller;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = controller.acceptsTaps;
    return Semantics(
      button: true,
      enabled: active,
      label: 'Vuruş alanı',
      hint: 'Ekran okuyucu açıkken dokunma zamanlaması değişebilir.',
      child: Listener(
        key: const Key('rhythm_tap_pad'),
        behavior: HitTestBehavior.opaque,
        // Engine timestamp of the pointer-down: monotonic, frame-independent.
        onPointerDown: (event) => controller.registerTap(event.timeStamp),
        child: Container(
          height: 180,
          margin: const EdgeInsets.symmetric(vertical: HarmoniaSpacing.sm),
          decoration: BoxDecoration(
            color: active
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(HarmoniaRadius.card),
          ),
          alignment: Alignment.center,
          child: Text(
            active ? 'Buraya dokun' : 'Dinledikten sonra açılır',
            style: TextStyle(
              color: active
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontSize: 20,
            ),
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
          padding: const EdgeInsets.all(HarmoniaSpacing.md),
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
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.toString(),
              key: const Key('rhythm_result_summary'),
              style: text.titleMedium,
            ),
            if (outcome.tempoDiffers)
              Padding(
                padding: const EdgeInsets.only(top: HarmoniaSpacing.xs),
                child: Text(
                  outcome.spanRatio! > 1
                      ? 'Genel olarak referanstan yavaş çaldın; vuruşlar giderek geç kaldı.'
                      : 'Genel olarak referanstan hızlı çaldın; vuruşlar giderek erken geldi.',
                  key: const Key('rhythm_tempo_hint'),
                ),
              ),
            const SizedBox(height: HarmoniaSpacing.sm),
            Wrap(
              spacing: HarmoniaSpacing.xs,
              runSpacing: HarmoniaSpacing.xs,
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
  final HarmoniaResultColors colors;
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
      padding: const EdgeInsets.symmetric(vertical: HarmoniaSpacing.sm),
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
        padding: const EdgeInsets.all(HarmoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Sonraki adım', style: Theme.of(context).textTheme.labelLarge),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(reason),
            if (action.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: HarmoniaSpacing.sm),
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
