import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/chord_response_attempt_coordinator.dart';
import '../../application/chord_response_capture_session.dart';
import '../../application/chord_response_diagnostic_analyzer.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/audio/chord_response_matcher.dart';
import '../../domain/audio/pitch_sequence_alignment.dart';
import '../../domain/audio/visual_feedback_frame.dart';
import '../../domain/models/exercise_protocol.dart';
import '../../trainer/domain/music.dart';
import '../common/live_pitch_feedback_field.dart';
import '../common/ui/resonia_ui.dart';

/// UI-only wiring for one reviewed 2/3/4-note piano attempt.
///
/// Construction stays outside this screen so placeholder assets cannot unlock
/// it. Candidate evidence is never persisted, scored or sent to AI.
class ChordDiagnosticScreen extends StatefulWidget {
  const ChordDiagnosticScreen({
    super.key,
    required this.coordinator,
    this.ownsCoordinator = true,
  });

  final ChordResponseAttemptCoordinator coordinator;
  final bool ownsCoordinator;

  @override
  State<ChordDiagnosticScreen> createState() => _ChordDiagnosticScreenState();
}

class _ChordDiagnosticScreenState extends State<ChordDiagnosticScreen>
    with WidgetsBindingObserver {
  ChordResponseAttemptCoordinator get coordinator => widget.coordinator;
  ChordResponseCaptureSession get session => coordinator.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      unawaited(coordinator.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.ownsCoordinator) coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: coordinator,
    builder: (context, _) {
      final recording = session.recording;
      final input = session.backend;
      final InputLevelSource? levelSource = input is InputLevelSource
          ? input as InputLevelSource
          : null;
      final capturePhase = session.phase;
      final showLevel =
          levelSource != null &&
          (capturePhase == ChordResponseCapturePhase.calibrating ||
              capturePhase == ChordResponseCapturePhase.capturing);
      return LessonScaffold(
        progress: null,
        counter: 'Puansız',
        closeLabel: '${recording.voiceCount} sesli çalışmayı kapat',
        top: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill('Deneysel · İncelenmiş kayıt'),
          ),
          const SizedBox(height: ResoniaSpacing.md),
          Text(
            '${recording.voiceCount} sesli piyano',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            coordinator.responseOrder == ResponseOrder.exact
                ? 'Birlikte dinle · pes sesten tize sırayla söyle'
                : 'Birlikte dinle · sesleri istediğin sırada söyle',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Bu ekran yalnız aday perdeleri karşılaştırır. Puan, hafıza sonucu veya konservatuvar hazırlık kararı üretmez.',
          ),
          const SizedBox(height: ResoniaSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _phaseText(coordinator),
              key: const Key('chord_attempt_status'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            session.calibration?.isUsable == true
                ? 'Ortam ölçüldü. Çıkış değişirse yeniden ölç.'
                : 'Önce 2 saniye sessiz kalıp ortamı ölç.',
          ),
          const SizedBox(height: ResoniaSpacing.sm),
          _TargetStrip(
            notes: recording.targetMidiNotes,
            reveal: session.reference.targetVisibleDuringResponse,
          ),
          ExpansionTile(
            key: const Key('chord_attempt_help'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Nasıl çalışır?'),
            children: const [
              Text(
                'Piyano sesleri aynı anda çalar. Referans tamamen bittikten sonra sesleri tek tek söyle. Yanıt tek bir yerel kayıtta analiz edilir ve native kayıt silinir. Bölümleme ile nota adayları deneysel olduğundan sonuç geçmişe veya ilerlemeye yazılmaz.',
              ),
            ],
          ),
          if (showLevel)
            Padding(
              padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
              child: LivePitchFeedbackField(
                sessionId: 'chord-${recording.id}',
                phase: capturePhase == ChordResponseCapturePhase.calibrating
                    ? VisualFeedbackPhase.calibrating
                    : VisualFeedbackPhase.responding,
                levelsDb: levelSource.inputLevelDb,
                provenance: levelSource.inputLevelProvenance,
              ),
            ),
          if (session.failure case final failure?) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            _NeutralNotice(
              title: 'Oturum tamamlanamadı — puanlanmadı',
              body: _captureFailureText(failure),
            ),
          ],
          if (coordinator.outcome case final outcome?) ...[
            const SizedBox(height: ResoniaSpacing.md),
            _DiagnosticResult(outcome: outcome),
          ],
        ],
        bottom: [
          if (coordinator.canCalibrateEnvironment)
            ChunkyButton(
              key: const Key('chord_calibrate'),
              onPressed: () => unawaited(coordinator.calibrateEnvironment()),
              tone: session.calibration?.isUsable == true
                  ? ChunkyTone.neutral
                  : ChunkyTone.primary,
              icon: Icons.mic_none_rounded,
              label: 'Ortamı ölç (2 sn sessizlik)',
            ),
          if (coordinator.canPlayReference) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('chord_listen'),
              onPressed: () => unawaited(coordinator.playReference()),
              icon: Icons.hearing_rounded,
              label: 'Piyano seslerini dinle',
            ),
          ],
          if (coordinator.canStartResponse) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('chord_respond'),
              onPressed: () => unawaited(coordinator.startResponse()),
              tone: ChunkyTone.record,
              icon: Icons.mic_rounded,
              label: 'Sesleri sırayla söyle',
            ),
          ],
          if (coordinator.canStopAndAnalyze) ...[
            ChunkyButton(
              key: const Key('chord_finish'),
              onPressed: () => unawaited(coordinator.stopAndAnalyze()),
              tone: ChunkyTone.record,
              icon: Icons.stop_rounded,
              label: 'Bitirdim · yerel analiz',
            ),
          ],
          if (_canCancel(coordinator)) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('chord_cancel'),
              onPressed: () => unawaited(coordinator.cancel()),
              tone: ChunkyTone.neutral,
              label: 'İptal et',
            ),
          ],
        ],
      );
    },
  );
}

class _TargetStrip extends StatelessWidget {
  const _TargetStrip({required this.notes, required this.reveal});

  final List<int> notes;
  final bool reveal;

  @override
  Widget build(BuildContext context) => Wrap(
    key: const Key('chord_target_strip'),
    spacing: ResoniaSpacing.sm,
    runSpacing: ResoniaSpacing.sm,
    children: [
      for (var i = 0; i < notes.length; i++)
        Chip(
          avatar: CircleAvatar(child: Text('${i + 1}')),
          label: Text(
            reveal
                ? PitchClass.midiName(notes[i], NoteNotation.solfege)
                : 'Ses',
          ),
        ),
    ],
  );
}

class _NeutralNotice extends StatelessWidget {
  const _NeutralNotice({required this.title, required this.body});
  final String title, body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(ResoniaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(body),
        ],
      ),
    ),
  );
}

class _DiagnosticResult extends StatelessWidget {
  const _DiagnosticResult({required this.outcome});
  final ChordResponseDiagnosticOutcome outcome;

  @override
  Widget build(BuildContext context) {
    if (outcome.status == ChordResponseDiagnosticStatus.qualityRejected) {
      return _NeutralNotice(
        title: 'Kayıt kalitesi yeterli değil — puanlanmadı',
        body: '${_qualityText(outcome.quality.status)} Yeniden ölçüp dene.',
      );
    }
    if (outcome.status == ChordResponseDiagnosticStatus.analysisUnavailable) {
      return const _NeutralNotice(
        title: 'Yerel analiz kullanılamadı — puanlanmadı',
        body: 'Kayıt öğrenci hatası sayılmadı. Yeniden deneyebilirsin.',
      );
    }
    final comparison = outcome.comparison!;
    if (comparison.status != ChordResponseStatus.candidatesCompared) {
      return _NeutralNotice(
        title: 'Kararlı nota adayı bulunamadı — puanlanmadı',
        body:
            'Kaynak: ${comparison.source.name}. Bu sonuç sıfır puan veya duyma başarısızlığı değildir.',
      );
    }
    return Card(
      key: const Key('chord_diagnostic_result'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aday karşılaştırma — puan değil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${comparison.voiceCount} hedef · kaynak: ${comparison.source.name}',
            ),
            if (comparison.responseOrder == ResponseOrder.exact)
              for (final step in comparison.alignment!.steps)
                Text(_stepText(step)),
            if (comparison.responseOrder == ResponseOrder.anyOrder) ...[
              Text(
                'Aynı mutlak perde adayı: ${comparison.setComparison!.correctCount}',
              ),
              Text(
                'Oktav farklı adayı: ${comparison.setComparison!.wrongOctaveCount}',
              ),
              Text(
                'Eksik hedef adayı: ${comparison.setComparison!.missingTargetCount}',
              ),
              Text(
                'Fazla aday: ${comparison.setComparison!.extraCandidateCount}',
              ),
            ],
            if (comparison.reorderedTargetCandidates)
              const Text('Aynı hedef adayları farklı sırada gözlendi.'),
            const SizedBox(height: ResoniaSpacing.xs),
            const Text(
              'Bunlar deneysel frekans adaylarıdır; insan sesi, hafıza, müzikal başarı veya sınav sonucu değildir. Hiçbir ilerleme kaydı yazılmadı.',
            ),
          ],
        ),
      ),
    );
  }
}

String _stepText(PitchSequenceStep step) {
  final target = step.referenceIndex == null
      ? null
      : '${step.referenceIndex! + 1}. ses';
  return switch (step.kind) {
    PitchSequenceStepKind.correct => '$target: aynı mutlak perde adayı',
    PitchSequenceStepKind.wrongOctave =>
      '$target: nota sınıfı yakın, oktav farklı',
    PitchSequenceStepKind.wrongPitch => '$target: farklı perde adayı',
    PitchSequenceStepKind.missing => '$target: aday bulunamadı',
    PitchSequenceStepKind.extra =>
      'Fazla aday ses (${(step.responseIndex ?? 0) + 1}. yanıt)',
  };
}

String _phaseText(ChordResponseAttemptCoordinator coordinator) {
  if (coordinator.phase == ChordResponseAttemptPhase.analyzing) {
    return 'Yerel aday analizi yapılıyor…';
  }
  return switch (coordinator.session.phase) {
    ChordResponseCapturePhase.idle => 'Hazır. Mikrofon kapalı.',
    ChordResponseCapturePhase.requestingPermission =>
      'Mikrofon izni bekleniyor.',
    ChordResponseCapturePhase.calibrating =>
      'Ortam ölçülüyor; lütfen sessiz kal.',
    ChordResponseCapturePhase.calibrationReady =>
      'Ortam hazır. Piyano seslerini dinle.',
    ChordResponseCapturePhase.referencePlaying =>
      'Piyano sesleri birlikte çalıyor. Mikrofon kapalı.',
    ChordResponseCapturePhase.readyForResponse =>
      'Referans bitti. Şimdi sesleri tek tek söyle.',
    ChordResponseCapturePhase.startingCapture => 'Mikrofon hazırlanıyor…',
    ChordResponseCapturePhase.capturing => 'Sırayla söyle. Mikrofon açık.',
    ChordResponseCapturePhase.finalizing => 'Kayıt güvenle kapatılıyor…',
    ChordResponseCapturePhase.captured => 'Kayıt yerel analize hazır.',
    ChordResponseCapturePhase.failed => 'Oturum tamamlanamadı.',
    ChordResponseCapturePhase.closed => 'Oturum kapandı.',
  };
}

String _captureFailureText(ChordResponseCaptureFailure failure) =>
    switch (failure) {
      ChordResponseCaptureFailure.permissionDenied =>
        'Mikrofon izni verilmedi. İzin olmadan kayıt başlatılmadı.',
      ChordResponseCaptureFailure.calibrationUnavailable =>
        'Ortam ölçümü alınamadı. Yeniden dene.',
      ChordResponseCaptureFailure.calibrationRejected =>
        'Ortam çok gürültülü veya ölçüm sırasında ses vardı.',
      ChordResponseCaptureFailure.referenceUnavailable =>
        'Piyano referansı oynatılamadı. Mikrofon açılmadı.',
      ChordResponseCaptureFailure.captureUnavailable =>
        'Kayıt başlatılamadı veya okunamadı.',
      ChordResponseCaptureFailure.invalidCapture =>
        'Kayıt metadata doğrulamasından geçmedi.',
      ChordResponseCaptureFailure.interrupted =>
        'Ses yolu değişti veya oturum kesildi; otomatik devam edilmedi.',
      ChordResponseCaptureFailure.cleanupFailed =>
        'Ses kaynağı güvenle kapatılamadı. Uygulamayı yeniden başlat.',
    };

bool _canCancel(ChordResponseAttemptCoordinator coordinator) =>
    coordinator.phase == ChordResponseAttemptPhase.analyzing ||
    const {
      ChordResponseCapturePhase.requestingPermission,
      ChordResponseCapturePhase.calibrating,
      ChordResponseCapturePhase.referencePlaying,
      ChordResponseCapturePhase.startingCapture,
      ChordResponseCapturePhase.capturing,
      ChordResponseCapturePhase.finalizing,
    }.contains(coordinator.session.phase);

String _qualityText(CaptureQualityStatus status) => switch (status) {
  CaptureQualityStatus.usable => 'Kayıt analize uygun.',
  CaptureQualityStatus.invalidInput => 'Kayıt doğrulanamadı.',
  CaptureQualityStatus.tooShort => 'Kayıt analiz için çok kısa kaldı.',
  CaptureQualityStatus.silent => 'Kayıtta yeterli ses düzeyi bulunamadı.',
  CaptureQualityStatus.insufficientActivity =>
    'Yeterince uzun bir ses bölümü bulunamadı.',
  CaptureQualityStatus.lowSignalToNoise =>
    'Ses, ortam gürültüsünden yeterince ayrılamadı.',
  CaptureQualityStatus.clipped =>
    'Kayıt seviyesi çok yüksekti; telefondan biraz uzaklaş.',
  CaptureQualityStatus.suspectedReferenceTail =>
    'Piyano referansının kayda taşmış olabileceği görüldü.',
  CaptureQualityStatus.calibrationRequired =>
    'Bu kayıt için geçerli bir ortam ölçümü bulunamadı.',
};
