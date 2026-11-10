import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/result_history.dart';
import '../../application/rhythm_imitation_controller.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/rhythm_imitation.dart';
import '../../domain/content/draft_micro_lessons.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../infrastructure/audio/click_track.dart';
import '../../infrastructure/audio/tap_sound.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../common/ui/resonia_ui.dart';
import '../learning/next_step_text.dart';
import '../learning/micro_lesson_screen.dart';
import 'transient_alignment.dart';
import '../../domain/lang.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../../trainer/ui/kit.dart';
import '../../trainer/ui/rhythm_track.dart';

class RhythmImitationScreen extends StatefulWidget {
  const RhythmImitationScreen({
    super.key,
    this.player,
    this.patterns,
    this.history,
    this.initialPatternId,
    this.retentionCheck = false,
    this.tapSound,
    this.title,
  });

  /// The click heard on each tap. Defaults to the device player only when
  /// the real reference player is used (tests inject their own players).
  final TapSound? tapSound;
  final String? initialPatternId;
  final bool retentionCheck;
  final ReferenceClipPlayer? player;
  final ResultHistoryRepository? history;
  final List<RhythmPattern>? patterns;

  /// Top bar title; "Rhythm echo" by default.
  final String? title;
  @override
  State<RhythmImitationScreen> createState() => _RhythmImitationScreenState();
}

class _RhythmImitationScreenState extends State<RhythmImitationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final List<RhythmPattern> patterns = orderedEasyToHard(
    widget.patterns ?? draftRhythmPatterns,
  );
  late final RhythmImitationController controller;
  late final Ticker _playhead;
  TapSound? _tapSound;
  bool _details = false;

  /// Reference beats already heard while it plays; null otherwise.
  int? _lit;
  RhythmImitationPhase? _seenPhase;

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
    controller.addListener(_onPhase);
    _playhead = createTicker(_onPlayhead);
    _tapSound =
        widget.tapSound ??
        (widget.player == null ? (JustAudioTapSound()..warmUp()) : null);
    WidgetsBinding.instance.addObserver(this);
  }

  /// Lights the reference beats in time while the reference plays.
  void _onPhase() {
    final phase = controller.phase;
    if (phase == _seenPhase) return;
    _seenPhase = phase;
    if (phase == RhythmImitationPhase.listening) {
      _lit = 0;
      if (_playhead.isActive) _playhead.stop();
      _playhead.start();
    } else {
      _lit = null;
      if (_playhead.isActive) _playhead.stop();
    }
  }

  void _onPlayhead(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    final onsets = controller.referenceOnsetsMs;
    final lit = onsets.where((o) => o <= ms).length;
    if (lit != _lit) setState(() => _lit = lit);
    if (ms > onsets.last + 400) _playhead.stop();
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
    controller.removeListener(_onPhase);
    _playhead.dispose();
    controller.dispose();
    _tapSound?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final finished = c.phase == RhythmImitationPhase.finished;
        final selectable =
            c.phase == RhythmImitationPhase.idle ||
            c.phase == RhythmImitationPhase.awaitingTaps ||
            c.phase == RhythmImitationPhase.finished;
        final index = patterns.indexOf(c.pattern);
        final protocol = c.pattern.exercise.protocol;
        final o = c.outcome;
        return Scaffold(
          backgroundColor: TC.canvas,
          body: SafeArea(
            child: Column(
              children: [
                TopBar(
                  title: widget.title ?? tr('Ritim tekrarı', 'Rhythm echo'),
                  progress: (index + 1) / patterns.length,
                  progressColor: TC.koro,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Tag(
                              tr(
                                'SEVİYE ${index + 1}/${patterns.length}',
                                'LEVEL ${index + 1}/${patterns.length}',
                              ),
                              color: TC.koro,
                            ),
                            if (c.retentionCheck)
                              Tag(
                                tr('Tek dinleme', 'Single listen'),
                                key: const Key('rhythm_retention_label'),
                                color: TC.amber,
                              ),
                            if (c.isGuided)
                              Tag(
                                tr('Hedefli tekrar', 'Targeted repeat'),
                                key: const Key('rhythm_guided_label'),
                                color: TC.amber,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: LevelPicker(
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
                        ),
                        Text(
                          tr(
                            '${c.expectedTaps} vuruş · ${protocol.tempoBpm.round()} BPM',
                            '${c.expectedTaps} beats · ${protocol.tempoBpm.round()} BPM',
                          ),
                          textAlign: TextAlign.center,
                          style: TT.small,
                        ),
                        if (c.pattern.review !=
                            ContentReviewStatus.educatorApproved)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              tr(
                                'Taslak içerik — eğitimci onayı bekliyor. ${c.pattern.description}',
                                'Draft content — awaiting educator approval. ${c.pattern.description}',
                              ),
                              key: const Key('rhythm_draft_label'),
                              textAlign: TextAlign.center,
                              style: TT.small.copyWith(
                                fontSize: 11.5,
                                color: TC.muted,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        _track(c),
                        const SizedBox(height: 10),
                        Text(
                          _headline(c),
                          key: const Key('rhythm_headline'),
                          textAlign: TextAlign.center,
                          style: TT.h3,
                        ),
                        const SizedBox(height: 4),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _status(c),
                            key: const Key('rhythm_status'),
                            textAlign: TextAlign.center,
                            style: TT.small,
                          ),
                        ),
                        if (c.phase == RhythmImitationPhase.tapping)
                          _LiveOffset(controller: c),
                        if (c.tapsDuringReference > 0 && !finished)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              tr(
                                'Referans çalarken ${c.tapsDuringReference} dokunuş oldu; bunlar değerlendirilmedi.',
                                '${c.tapsDuringReference} taps came while the reference played; they were not assessed.',
                              ),
                              textAlign: TextAlign.center,
                              style: TT.small,
                            ),
                          ),
                        if (c.playbackFailed)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              tr(
                                'Referans çalınamadı. Yeniden deneyebilirsin.',
                                'The reference could not play. You can try again.',
                              ),
                              key: const Key('rhythm_playback_error'),
                              textAlign: TextAlign.center,
                              style: TT.small.copyWith(color: TC.coralDeep),
                            ),
                          ),
                        if (o != null && finished) ...[
                          const SizedBox(height: 14),
                          _Result(outcome: o),
                          if (!c.isGuided) ..._resultActions(c, o),
                        ],
                      ],
                    ),
                  ),
                ),
                // Like the lesson result: the one primary action is pinned
                // under the scroll, everything else is a quiet option above.
                if (o != null && finished)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: c.isGuided
                        ? _GuidedActions(controller: c)
                        : c.nextStep != null &&
                              nextStepText(c.nextStep!).$3.isNotEmpty
                        ? BigButton(
                            key: const Key('rhythm_apply_next'),
                            onPressed: c.applyNextStep,
                            icon: Ic.arrowRight,
                            label: nextStepText(c.nextStep!).$3,
                          )
                        : BigButton(
                            key: const Key('rhythm_retry'),
                            onPressed: c.retry,
                            icon: Ic.rotateCcw,
                            label: tr(
                              'Tekrar dinle ve dene',
                              'Listen and try again',
                            ),
                          ),
                  ),
                if (!finished)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(
                      children: [
                        _TapPad(controller: c, sound: _tapSound),
                        const SizedBox(height: 10),
                        if (c.phase == RhythmImitationPhase.tapping)
                          BigButton(
                            key: const Key('rhythm_finish'),
                            onPressed: c.finish,
                            icon: Ic.check,
                            label: tr('Bitirdim', 'I am done'),
                          )
                        else
                          BigButton(
                            key: const Key('rhythm_listen'),
                            onPressed: c.canListen ? c.listen : null,
                            icon: Ic.volume2,
                            color: c.referencePlays == 0 ? TC.sun : TC.card,
                            label: c.referencePlays == 0
                                ? tr(
                                    'Dinle (0/${c.maxReferencePlays})',
                                    'Listen (0/${c.maxReferencePlays})',
                                  )
                                : tr(
                                    'Tekrar dinle (${c.referencePlays}/${c.maxReferencePlays})',
                                    'Listen again (${c.referencePlays}/${c.maxReferencePlays})',
                                  ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _track(RhythmImitationController c) {
    final o = c.outcome;
    if (o != null &&
        c.phase == RhythmImitationPhase.finished &&
        o.isMeasured &&
        o.referenceOnsetsMs.isNotEmpty) {
      return RhythmTrack(
        reference: o.referenceOnsetsMs,
        taps: o.userOnsetsMs,
        goodMs: RhythmImitationOutcome.onTimeToleranceMs,
        windowMs: RhythmImitationOutcome.matchToleranceMs,
        links: [
          for (final e in o.timeline)
            if (e.referenceIndex != null && e.userIndex != null)
              RhythmLink(
                e.referenceIndex!,
                e.userIndex!,
                e.verdict == BeatVerdict.anchor ? null : e.offsetMs,
              ),
        ],
      );
    }
    return RhythmTrack(
      reference: c.referenceOnsetsMs,
      taps: c.phase == RhythmImitationPhase.tapping ? c.liveTapsMs : const [],
      lit: _lit,
      goodMs: RhythmImitationOutcome.onTimeToleranceMs,
      windowMs: RhythmImitationOutcome.matchToleranceMs,
    );
  }

  List<Widget> _resultActions(
    RhythmImitationController c,
    RhythmImitationOutcome o,
  ) => [
    if (c.nextStep != null) ...[
      const SizedBox(height: 10),
      _NextStepCard(controller: c),
    ],
    // The other ways on, one quiet list instead of stacked buttons/links.
    if (c.suggestedGuidedSegment != null ||
        (c.nextStep == null && c.followingPattern != null) ||
        o.isMeasured) ...[
      const SizedBox(height: 10),
      AppCard(
        radius: 18,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _divided([
            if (c.suggestedGuidedSegment != null)
              _OptionRow(
                key: const Key('rhythm_start_guided'),
                icon: Ic.crosshair,
                label: tr('Zor bölümü çalış', 'Practise the hard part'),
                onTap: c.startGuidedSegment,
              ),
            if (c.nextStep == null && c.followingPattern != null)
              _OptionRow(
                key: const Key('rhythm_next_pattern'),
                icon: Ic.skipForward,
                label: tr(
                  'Sonraki desene geç: ${c.followingPattern!.title}',
                  'Next pattern: ${c.followingPattern!.title}',
                ),
                onTap: c.advancePattern,
              ),
            if (c.suggestedGuidedSegment != null)
              _OptionRow(
                key: const Key('rhythm_concept_review'),
                icon: Ic.bookOpen,
                label: tr(
                  'Puls kavramı (isteğe bağlı taslak metin)',
                  'The idea of pulse (optional draft text)',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MicroLessonScreen(
                      lesson: draftMicroLessons.forSkill('pulse-tap').single,
                    ),
                  ),
                ),
              ),
            if (o.isMeasured)
              _OptionRow(
                key: const Key('rhythm_details'),
                icon: Ic.info,
                label: _details
                    ? tr('Ayrıntıyı gizle', 'Hide details')
                    : tr('Ölçüm ayrıntısı', 'Measurement details'),
                trailing: _details ? Ic.chevronUp : Ic.chevronDown,
                onTap: () => setState(() => _details = !_details),
              ),
          ]),
        ),
      ),
    ],
    if (_details && o.isMeasured) _Details(outcome: o),
    const SizedBox(height: 8),
    if (_saveText(c) case final saved?)
      Text(
        saved,
        key: const Key('rhythm_saved'),
        textAlign: TextAlign.center,
        style: TT.small.copyWith(fontSize: 11.5, color: TC.muted),
      ),
  ];
}

/// The draft "clean echo" criterion, read off one outcome: every beat
/// answered, nothing extra, mean offset within the mastery limit.
bool _clean(RhythmImitationOutcome o) {
  final a = o.analysis;
  return o.isMeasured &&
      a != null &&
      a.missedCount == 0 &&
      a.extraCount == 0 &&
      (a.averageAbsoluteOffsetMs ?? 0) <=
          RhythmNextStepPolicy.maxMeanAbsOffsetMs;
}

String _headline(RhythmImitationController c) {
  switch (c.phase) {
    case RhythmImitationPhase.idle:
      return c.isGuided
          ? tr(
              'Zor bölümü dinle, sonra tekrar et',
              'Hear the hard part, then repeat it',
            )
          : tr('Dinle, sonra aynı ritme dokun', 'Listen, then tap it back');
    case RhythmImitationPhase.listening:
      return tr('Dinle', 'Listen');
    case RhythmImitationPhase.awaitingTaps:
      return tr('Sıra sende', 'Your turn');
    case RhythmImitationPhase.tapping:
      return '${c.tapCount} / ${c.expectedTaps}';
    case RhythmImitationPhase.evaluating:
      return tr('Karşılaştırılıyor…', 'Comparing…');
    case RhythmImitationPhase.finished:
      final o = c.outcome;
      if (o == null || !o.isMeasured) {
        return tr('Ölçüm alınamadı', 'No measurement');
      }
      if (_clean(o)) return tr('Ritmi yakaladın', 'You caught the rhythm');
      final a = o.analysis!;
      return a.missedCount + a.extraCount == 0
          ? tr('Çok yakın', 'Very close')
          : tr('Henüz tam değil', 'Not quite yet');
    case RhythmImitationPhase.closed:
      return '';
  }
}

/// Last tap against its nearest beat, as you play.
class _LiveOffset extends StatelessWidget {
  const _LiveOffset({required this.controller});
  final RhythmImitationController controller;
  @override
  Widget build(BuildContext context) {
    final taps = controller.liveTapsMs;
    if (taps.length < 2) {
      return const SizedBox(height: 28);
    }
    final off = RhythmTrack.liveOffsets(
      controller.referenceOnsetsMs,
      taps,
    ).last;
    final tone = RhythmTrack.toneOf(
      off,
      good: RhythmImitationOutcome.onTimeToleranceMs,
      window: RhythmImitationOutcome.matchToleranceMs,
    );
    final label = switch (tone) {
      RhythmTone.good || RhythmTone.anchor => tr('Tam zamanında', 'On time'),
      RhythmTone.near =>
        off > 0
            ? tr('$off ms geç', '$off ms late')
            : tr('${-off} ms erken', '${-off} ms early'),
      RhythmTone.off => tr('Vuruşu kaçırdın', 'Off the beat'),
    };
    final colour = RhythmTrack.colorOf(tone);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          key: const Key('rhythm_live_offset'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: soft(colour),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TT.small.copyWith(
                    color: TC.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    '${c.tapCount}/${c.expectedTaps} vuruş. Bitince “Bitirdim”e bas; son vuruştan sonra kısa bir sessizlikte kendiliğinden biter.',
    '${c.tapCount}/${c.expectedTaps} taps. Press “I am done”, or pause briefly after the last tap and it ends by itself.',
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
  const _TapPad({required this.controller, this.sound});
  final RhythmImitationController controller;
  final TapSound? sound;
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
    final c = widget.controller;
    final active = c.acceptsTaps;
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
          widget.sound?.tap();
          if (ResoniaHapticsScope.enabled(context)) {
            HapticFeedback.lightImpact();
          }
          if (!ResoniaMotion.reduced(context)) _pulse.forward(from: 0);
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_pulse.value);
            final pressed = _pulse.isAnimating && _pulse.value < 0.25;
            return Container(
              height: 132,
              width: double.infinity,
              margin: EdgeInsets.only(top: pressed ? 4 : 0),
              decoration: BoxDecoration(
                color: active ? TC.sun : const Color(0xFFEDE8EE),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: active ? TC.ink : TC.line,
                  width: active ? 2 : 1.5,
                ),
                boxShadow: [
                  if (!pressed)
                    BoxShadow(
                      color: active ? TC.limeShadow : TC.cardShadow,
                      offset: const Offset(0, 5),
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_pulse.isAnimating)
                    Opacity(
                      opacity: (1 - t) * 0.6,
                      child: Container(
                        width: 70 + 170 * t,
                        height: 70 + 170 * t,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: TC.ink, width: 3),
                        ),
                      ),
                    ),
                  child!,
                ],
              ),
            );
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Ic.pointer, size: 30, color: active ? TC.onSun : TC.faint),
                const SizedBox(height: 6),
                Text(
                  active
                      ? tr('Buraya dokun', 'Tap here')
                      : tr(
                          'Dinledikten sonra açılır',
                          'Opens after you listen',
                        ),
                  textAlign: TextAlign.center,
                  style: TT.h3.copyWith(color: active ? TC.onSun : TC.faint),
                ),
              ],
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
    if (!outcome.isMeasured) {
      return AppCard(
        key: const Key('rhythm_result'),
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
          style: TT.body,
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
    final onTime = outcome.timeline
        .where((e) => e.verdict == BeatVerdict.onTime)
        .length;
    final clean = _clean(outcome);
    return AppCard(
      key: const Key('rhythm_result'),
      color: clean ? TC.limeSoft : TC.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (n, label, colour) in [
                (onTime, tr('zamanında', 'on time'), TC.teal),
                (
                  a.earlyCount + a.lateCount,
                  tr('kaymış', 'off a bit'),
                  TC.amber,
                ),
                (
                  a.missedCount + a.extraCount,
                  tr('eksik/fazla', 'missed/extra'),
                  TC.coral,
                ),
              ])
                Expanded(
                  child: _Count(n: n, label: label, colour: colour),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // The status line already says a targeted repeat is not scored.
          Text(
            summary.toString(),
            key: const Key('rhythm_result_summary'),
            style: TT.body.copyWith(color: TC.ink),
          ),
          if (outcome.tempoDiffers)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
                style: TT.small.copyWith(color: TC.warn),
              ),
            ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.n, required this.label, required this.colour});
  final int n;
  final String label;
  final Color colour;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('$n', style: TT.h2),
        ],
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TT.small.copyWith(fontSize: 11.5),
      ),
    ],
  );
}

class _BeatChips extends StatelessWidget {
  const _BeatChips({required this.outcome});
  final RhythmImitationOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final colors = context.resultColors;
    return Wrap(
      key: const Key('rhythm_beat_chips'),
      spacing: ResoniaSpacing.xs,
      runSpacing: ResoniaSpacing.xs,
      children: [
        for (final (i, e) in outcome.timeline.indexed)
          _BeatChip(entry: e, index: i, colors: colors),
      ],
    );
  }
}

/// After a targeted repeat: one primary way on (the full, scored pattern)
/// and one quiet way past it. Nothing here is scored or recorded.
class _GuidedActions extends StatelessWidget {
  const _GuidedActions({required this.controller});
  final RhythmImitationController controller;
  @override
  Widget build(BuildContext context) {
    final next = controller.followingPattern;
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BigButton(
            key: const Key('rhythm_exit_guided'),
            onPressed: controller.exitGuidedSegment,
            icon: Ic.arrowRight,
            label: tr(
              'Devam: tam deseni çal',
              'Continue: play the full pattern',
            ),
          ),
          TextLink(
            tr('Bu bölümü tekrar et', 'Repeat this part'),
            key: const Key('rhythm_retry'),
            onTap: controller.retry,
          ),
          if (next != null)
            TextLink(
              tr(
                'Sonraki desene geç: ${next.title}',
                'Skip to the next pattern: ${next.title}',
              ),
              key: const Key('rhythm_next_pattern'),
              onTap: controller.advancePattern,
            ),
        ],
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
          if (TransientAlignmentData.fromOutcome(outcome) case final data?)
            Padding(
              padding: const EdgeInsets.only(bottom: ResoniaSpacing.sm),
              child: TransientAlignmentView(
                key: ObjectKey(outcome),
                data: data,
                showSnapToggle: !outcome.guided,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: ResoniaSpacing.sm),
            child: _BeatChips(outcome: outcome),
          ),
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
    // The action itself is the pinned primary button under the scroll.
    final (title, reason, _) = nextStepText(controller.nextStep!);
    return Container(
      key: const Key('rhythm_next_step'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TC.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Ic.sparkles, color: TC.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('SONRAKİ ADIM', 'NEXT STEP'),
                  style: TT.caps.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TT.title.copyWith(color: TC.primary, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(reason, style: TT.small),
                const SizedBox(height: 6),
                Text(
                  draftCriterionNote,
                  style: TT.small.copyWith(fontSize: 11, color: TC.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One quiet option under the result: icon, label, chevron; full-row tap.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing = Ic.chevronRight,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData trailing;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
        child: Row(
          children: [
            Icon(icon, color: TC.koro, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: TT.title.copyWith(fontSize: 14)),
            ),
            Icon(trailing, color: TC.muted, size: 18),
          ],
        ),
      ),
    ),
  );
}

List<Widget> _divided(List<Widget> rows) => [
  for (var i = 0; i < rows.length; i++) ...[
    if (i > 0) const Divider(height: 1, color: TC.line),
    rows[i],
  ],
];
