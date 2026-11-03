import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/microphone_permission_recovery.dart';
import '../../application/single_tone_session.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../domain/audio/visual_feedback_frame.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../common/live_pitch_feedback_field.dart';
import '../common/pitch_feedback_field.dart';
import '../common/ui/resonia_ui.dart';
import '../common/ui/microphone_permission_recovery_card.dart';
import '../../domain/lang.dart';

/// SESSION-01 UI: real capture flow, but no correct/incorrect decision until
/// VAD-01 + BENCH-01 pass (SingleToneSessionOutcome.scoringEnabled).
class SingleToneSessionScreen extends StatefulWidget {
  const SingleToneSessionScreen({
    super.key,
    this.backend,
    this.worker,
    this.permissionRecovery,
  });
  final AudioLabBackend? backend;
  final RecordingPitchWorker? worker;
  final MicrophonePermissionRecovery? permissionRecovery;
  @override
  State<SingleToneSessionScreen> createState() =>
      _SingleToneSessionScreenState();
}

class _SingleToneSessionScreenState extends State<SingleToneSessionScreen>
    with WidgetsBindingObserver {
  late final SingleToneSessionController session;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    session = SingleToneSessionController(
      backend: widget.backend ?? PluginAudioLabBackend(),
      worker: widget.worker ?? IsolateRecordingPitchWorker(),
      targetHz: 261.63,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OS permission dialog makes iOS briefly inactive; do not cancel it.
    if (state == AppLifecycleState.inactive) return;
    if (state != AppLifecycleState.resumed) unawaited(session.cancel());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final busy = !session.canStart;
        return LessonScaffold(
          progress: null,
          counter: tr('Puansız', 'Unscored'),
          closeLabel: tr(
            'Tek ses çalışmasını kapat',
            'Close single-note practice',
          ),
          top: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(tr('Deneysel', 'Experimental')),
            ),
            const SizedBox(height: ResoniaSpacing.md),
            Text(
              tr('Tek ses: dinle ve söyle', 'Single note: listen and sing'),
              style: text.headlineSmall,
            ),
            Text(tr('Hedef: Do (C4)', 'Target: C4'), style: text.titleMedium),
            const SizedBox(height: ResoniaSpacing.xs),
            Text(
              tr(
                'Referans sentetik bir tondur. Doğru/yanlış kararı ve puan henüz verilmez.',
                'The reference is a synthetic tone. No right/wrong verdict or score is given yet.',
              ),
            ),
            const SizedBox(height: ResoniaSpacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(
                _phaseText(session.phase),
                key: const Key('session_status'),
                style: text.titleMedium,
              ),
            ),
            Text(_calibrationText(session.calibration)),
            ExpansionTile(
              key: const Key('session_help'),
              tilePadding: EdgeInsets.zero,
              title: Text(tr('Nasıl çalışır?', 'How does it work?')),
              children: [
                Text(
                  tr(
                    'Önce 2 saniye sessiz kalıp ortamı ölç. Referans bitince kısa bir bekleme olur, sonra mikrofon açılır. En fazla 4 saniye söyle. Kayıt yerel analiz için okununca silinir; cihazdan gönderilmez. Gerçek ses ve cihaz doğrulaması bekleniyor.',
                    'First stay quiet for 2 seconds to measure the room. After the reference there is a short pause, then the microphone opens. Sing for up to 4 seconds. The recording is deleted once read for local analysis; it never leaves the device. Real voice and device validation is pending.',
                  ),
                ),
              ],
            ),
            if ((session.phase == SingleToneSessionPhase.responding ||
                    session.phase == SingleToneSessionPhase.calibrating) &&
                session.backend is InputLevelSource)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                child: LivePitchFeedbackField(
                  sessionId: 'single-tone-${identityHashCode(session)}',
                  phase: session.phase == SingleToneSessionPhase.calibrating
                      ? VisualFeedbackPhase.calibrating
                      : VisualFeedbackPhase.responding,
                  levelsDb: (session.backend as InputLevelSource).inputLevelDb,
                  provenance: (session.backend as InputLevelSource)
                      .inputLevelProvenance,
                ),
              ),
            if (session.outcome case final outcome?) ...[
              const SizedBox(height: ResoniaSpacing.md),
              _OutcomeCard(outcome: outcome),
              if (_visualFrame(outcome) case final frame?) ...[
                const SizedBox(height: ResoniaSpacing.md),
                PitchFeedbackField(frame: frame),
              ],
              if (outcome.retryReason == SessionRetryReason.permissionDenied)
                MicrophonePermissionRecoveryCard(
                  recovery: widget.permissionRecovery,
                ),
              if (!outcome.needsRetry)
                TextButton(
                  key: const Key('session_details'),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  child: Text(
                    _showDetails
                        ? tr('Ayrıntıyı gizle', 'Hide details')
                        : tr('Ölçüm ayrıntısı', 'Measurement details'),
                  ),
                ),
              if (_showDetails && !outcome.needsRetry)
                _Details(outcome: outcome),
            ],
          ],
          bottom: [
            if (!busy) ...[
              ChunkyButton(
                key: const Key('session_calibrate'),
                onPressed: session.calibrate,
                tone: session.calibration?.isUsable == true
                    ? ChunkyTone.neutral
                    : ChunkyTone.primary,
                icon: Icons.mic_none_rounded,
                label: tr(
                  'Ortamı ölç (2 sn sessizlik)',
                  'Measure the room (2 s of silence)',
                ),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
              ChunkyButton(
                key: const Key('session_start'),
                onPressed: () {
                  setState(() => _showDetails = false);
                  unawaited(session.startAttempt());
                },
                tone: session.calibration?.isUsable == true
                    ? ChunkyTone.primary
                    : ChunkyTone.neutral,
                icon: Icons.hearing,
                label: tr('Dinle ve söyle', 'Listen and sing'),
              ),
            ],
            if (session.canFinishResponse) ...[
              ChunkyButton(
                key: const Key('session_finish'),
                onPressed: session.finishResponse,
                tone: ChunkyTone.record,
                icon: Icons.stop_rounded,
                label: tr('Bitirdim', 'I am done'),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
            ],
            if (busy && session.phase != SingleToneSessionPhase.closed)
              ChunkyButton(
                key: const Key('session_cancel'),
                onPressed: session.cancel,
                tone: ChunkyTone.neutral,
                label: tr('İptal et', 'Cancel'),
              ),
          ],
        );
      },
    );
  }

  VisualFeedbackFrame? _visualFrame(SingleToneSessionOutcome outcome) {
    final quality = outcome.quality;
    final evidence = outcome.evidence;
    final deviation = outcome.deviation;
    if (outcome.needsRetry ||
        quality == null ||
        evidence == null ||
        deviation == null) {
      return null;
    }
    return VisualFeedbackFrame(
      sessionId: 'single-tone-${identityHashCode(session)}',
      phase: VisualFeedbackPhase.diagnostic,
      level01: (quality.peakAbs ?? 0).clamp(0.0, 1.0),
      signedCents: deviation.absoluteCents,
      confidence01: null,
      stability01: null,
      activeNoteIndex: null,
      completedNotes: 0,
      errorType: deviation.octaveOffset == 0
          ? null
          : VisualFeedbackError.octaveDifference,
      provenance: evidence.provenance,
    );
  }
}

String _calibrationText(NoiseFloorCalibration? c) => switch (c?.status) {
  null => tr(
    'Önce sessiz kalarak ortamın gürültüsünü ölçelim. Ölçüm kaydı saklanmaz.',
    'First stay quiet so we can measure the room noise. The measurement is not kept.',
  ),
  NoiseFloorStatus.calibrated => tr(
    'Ortam ölçüldü. Kulaklık/çıkış değişirse veya 30 dakika geçerse yeniden ölç.',
    'Room measured. Measure again if headphones or output change, or after 30 minutes.',
  ),
  NoiseFloorStatus.tooNoisy => tr(
    'Ortam çok gürültülü. Daha sessiz bir yerde yeniden ölç.',
    'The room is too noisy. Measure again somewhere quieter.',
  ),
  NoiseFloorStatus.activityDetected => tr(
    'Ölçüm sırasında ses duyuldu. Sessiz kalıp yeniden ölç.',
    'Sound was heard during the measurement. Stay quiet and measure again.',
  ),
  _ => tr(
    'Ortam ölçülemedi. Yeniden dene.',
    'The room could not be measured. Try again.',
  ),
};

String _phaseText(SingleToneSessionPhase phase) => switch (phase) {
  SingleToneSessionPhase.idle => tr(
    'Hazır. Mikrofon kapalı.',
    'Ready. Microphone off.',
  ),
  SingleToneSessionPhase.calibrating => tr(
    'Ortam ölçülüyor — lütfen sessiz kal. Mikrofon açık.',
    'Measuring the room — please stay quiet. Microphone on.',
  ),
  SingleToneSessionPhase.preparing => tr('Hazırlanıyor…', 'Preparing…'),
  SingleToneSessionPhase.referencePlaying => tr(
    'Referansı dinle. Mikrofon kapalı.',
    'Listen to the reference. Microphone off.',
  ),
  SingleToneSessionPhase.waiting => tr('Hazırlan…', 'Get ready…'),
  SingleToneSessionPhase.responding => tr(
    'Şimdi söyle. Mikrofon açık.',
    'Sing now. Microphone on.',
  ),
  SingleToneSessionPhase.assessing => tr(
    'Kayıt kalitesi kontrol ediliyor…',
    'Checking the recording quality…',
  ),
  SingleToneSessionPhase.analyzing => tr(
    'Yerel analiz yapılıyor…',
    'Analysing locally…',
  ),
  SingleToneSessionPhase.finished => tr('Deneme bitti.', 'Attempt finished.'),
  SingleToneSessionPhase.closed => tr('Oturum kapandı.', 'Session closed.'),
};

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome});
  final SingleToneSessionOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final neutral = context.resultColors.notMeasured;
    final (title, body) = outcome.needsRetry
        ? (
            tr('Ölçüm alınamadı — puanlanmadı', 'No measurement — not scored'),
            _retryText(outcome.retryReason!, outcome.quality?.status),
          )
        : (
            tr('Kaydın analiz edildi', 'Your take was analysed'),
            tr(
              'Doğru/yanlış kararı henüz kapalı: ses tanıma doğruluğu gerçek kayıtlarla test edilmeden sonuç göstermiyoruz. İstersen ölçüm ayrıntısına bakabilirsin.',
              'Right/wrong verdicts are off for now: we show no result until pitch accuracy is tested with real recordings. You can look at the measurement details if you like.',
            ),
          );
    return Card(
      key: const Key('session_outcome'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  outcome.needsRetry ? Icons.refresh : Icons.insights_outlined,
                  color: neutral,
                ),
                const SizedBox(width: ResoniaSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ResoniaSpacing.xs),
            Text(body, key: const Key('session_outcome_body')),
          ],
        ),
      ),
    );
  }
}

String _retryText(
  SessionRetryReason reason,
  CaptureQualityStatus? quality,
) => switch (reason) {
  SessionRetryReason.calibrationRequired => tr(
    'Önce ortamı ölç. Çıkış (kulaklık/hoparlör) değiştiyse veya ölçüm eskidiyse yeniden ölçmek gerekir.',
    'Measure the room first. If the output (headphones/speaker) changed or the measurement is stale, measure again.',
  ),
  SessionRetryReason.permissionDenied => tr(
    'Mikrofon izni yok. Telefon ayarlarından Vocalart için mikrofonu açabilirsin; referansı dinlemek için izin gerekmez.',
    'No microphone permission. You can allow it for Vocalart in your phone settings; listening to the reference needs no permission.',
  ),
  SessionRetryReason.routeUnsupported => tr(
    'Bu ses çıkışıyla bu çalışma yapılamıyor. Kablolu kulaklık dene.',
    'This exercise cannot run with this audio output. Try wired headphones.',
  ),
  SessionRetryReason.interrupted => tr(
    'Deneme kesildi (arama, bildirim veya kulaklık değişimi). Hazır olduğunda yeniden başlat.',
    'The attempt was interrupted (a call, a notification or a headphone change). Start again when you are ready.',
  ),
  SessionRetryReason.captureFailed => tr(
    'Kayıt alınamadı. Yeniden deneyebilirsin.',
    'Nothing was recorded. You can try again.',
  ),
  SessionRetryReason.analysisFailed => tr(
    'Analiz tamamlanamadı. Yeniden deneyebilirsin.',
    'The analysis could not finish. You can try again.',
  ),
  SessionRetryReason.quality => switch (quality) {
    CaptureQualityStatus.silent ||
    CaptureQualityStatus.insufficientActivity => tr(
      'Yeterli ses duyulmadı. Mikrofon açılınca notayı en az bir saniye net söyle.',
      'Not enough voice was heard. When the microphone opens, sing the note clearly for at least a second.',
    ),
    CaptureQualityStatus.lowSignalToNoise => tr(
      'Ortam gürültüsü sesine çok yakın. Daha sessiz bir yerde dene.',
      'The room noise is too close to your voice. Try somewhere quieter.',
    ),
    CaptureQualityStatus.clipped => tr(
      'Ses taştı. Telefondan biraz uzaklaşıp yeniden dene.',
      'The sound clipped. Move a little away from the phone and try again.',
    ),
    CaptureQualityStatus.suspectedReferenceTail => tr(
      'Kaydın başında referans sesi duyulmuş olabilir. Kulaklık kullan veya mikrofon açıldıktan sonra başla.',
      'The reference may be audible at the start of the take. Use headphones or start after the microphone opens.',
    ),
    CaptureQualityStatus.calibrationRequired => tr(
      'Ortam ölçümü bu kayda uymuyor. Yeniden ölçüp dene.',
      'The room measurement does not fit this take. Measure again and retry.',
    ),
    _ => tr(
      'Kayıt kullanılamadı. Yeniden deneyebilirsin.',
      'The take could not be used. You can try again.',
    ),
  },
};

class _Details extends StatelessWidget {
  const _Details({required this.outcome});
  final SingleToneSessionOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final q = outcome.quality!;
    final hz = outcome.evidence?.representativeFrequencyHz;
    return Padding(
      key: const Key('session_details_panel'),
      padding: const EdgeInsets.symmetric(vertical: ResoniaSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(
              'Sinyal/gürültü: ${q.signalToNoiseDb?.toStringAsFixed(1) ?? "Ölçülmedi"}${q.signalToNoiseDb == null ? "" : " dB"}',
              'Signal/noise: ${q.signalToNoiseDb?.toStringAsFixed(1) ?? "Not measured"}${q.signalToNoiseDb == null ? "" : " dB"}',
            ),
          ),
          Text(
            tr(
              'Etkin enerji süresi: ${q.activeSeconds?.toStringAsFixed(2) ?? "Ölçülmedi"}${q.activeSeconds == null ? "" : " sn"}',
              'Active energy time: ${q.activeSeconds?.toStringAsFixed(2) ?? "Not measured"}${q.activeSeconds == null ? "" : " s"}',
            ),
          ),
          Text(
            tr(
              'Gözlenen temsilî frekans: ${hz == null ? "Ölçülmedi" : "${hz.toStringAsFixed(1)} Hz"}',
              'Observed representative frequency: ${hz == null ? "Not measured" : "${hz.toStringAsFixed(1)} Hz"}',
            ),
          ),
          Text(
            tr(
              'Bu değerler deneyseldir; insan sesi tespiti, doğru nota veya başarı kanıtı değildir.',
              'These values are experimental; they are not voice detection, a right note or proof of success.',
            ),
          ),
        ],
      ),
    );
  }
}
