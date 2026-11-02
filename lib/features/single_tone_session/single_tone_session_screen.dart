import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../application/microphone_permission_recovery.dart';
import '../../application/single_tone_session.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../common/input_level_meter.dart';
import '../common/ui/resonia_ui.dart';
import '../common/ui/microphone_permission_recovery_card.dart';

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
          counter: 'Puansız',
          closeLabel: 'Tek ses çalışmasını kapat',
          top: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill('Deneysel'),
            ),
            const SizedBox(height: ResoniaSpacing.md),
            Text('Tek ses: dinle ve söyle', style: text.headlineSmall),
            Text('Hedef: Do (C4)', style: text.titleMedium),
            const SizedBox(height: ResoniaSpacing.xs),
            const Text(
              'Referans sentetik bir tondur. Doğru/yanlış kararı ve puan henüz verilmez.',
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
              title: const Text('Nasıl çalışır?'),
              children: const [
                Text(
                  'Önce 2 saniye sessiz kalıp ortamı ölç. Referans bitince kısa bir bekleme olur, sonra mikrofon açılır. En fazla 4 saniye söyle. Kayıt yerel analiz için okununca silinir; cihazdan gönderilmez. Gerçek ses ve cihaz doğrulaması bekleniyor.',
                ),
              ],
            ),
            if ((session.phase == SingleToneSessionPhase.responding ||
                    session.phase == SingleToneSessionPhase.calibrating) &&
                session.backend is InputLevelSource)
              Padding(
                padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                child: InputLevelMeter(
                  levels: (session.backend as InputLevelSource).inputLevelDb,
                ),
              ),
            if (session.outcome case final outcome?) ...[
              const SizedBox(height: ResoniaSpacing.md),
              _OutcomeCard(outcome: outcome),
              if (outcome.retryReason == SessionRetryReason.permissionDenied)
                MicrophonePermissionRecoveryCard(
                  recovery: widget.permissionRecovery,
                ),
              if (!outcome.needsRetry)
                TextButton(
                  key: const Key('session_details'),
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  child: Text(
                    _showDetails ? 'Ayrıntıyı gizle' : 'Ölçüm ayrıntısı',
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
                label: 'Ortamı ölç (2 sn sessizlik)',
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
                label: 'Dinle ve söyle',
              ),
            ],
            if (session.canFinishResponse) ...[
              ChunkyButton(
                key: const Key('session_finish'),
                onPressed: session.finishResponse,
                tone: ChunkyTone.record,
                icon: Icons.stop_rounded,
                label: 'Bitirdim',
              ),
              const SizedBox(height: ResoniaSpacing.sm),
            ],
            if (busy && session.phase != SingleToneSessionPhase.closed)
              ChunkyButton(
                key: const Key('session_cancel'),
                onPressed: session.cancel,
                tone: ChunkyTone.neutral,
                label: 'İptal et',
              ),
          ],
        );
      },
    );
  }
}

String _calibrationText(NoiseFloorCalibration? c) => switch (c?.status) {
  null =>
    'Önce sessiz kalarak ortamın gürültüsünü ölçelim. Ölçüm kaydı saklanmaz.',
  NoiseFloorStatus.calibrated =>
    'Ortam ölçüldü. Kulaklık/çıkış değişirse veya 30 dakika geçerse yeniden ölç.',
  NoiseFloorStatus.tooNoisy =>
    'Ortam çok gürültülü. Daha sessiz bir yerde yeniden ölç.',
  NoiseFloorStatus.activityDetected =>
    'Ölçüm sırasında ses duyuldu. Sessiz kalıp yeniden ölç.',
  _ => 'Ortam ölçülemedi. Yeniden dene.',
};

String _phaseText(SingleToneSessionPhase phase) => switch (phase) {
  SingleToneSessionPhase.idle => 'Hazır. Mikrofon kapalı.',
  SingleToneSessionPhase.calibrating =>
    'Ortam ölçülüyor — lütfen sessiz kal. Mikrofon açık.',
  SingleToneSessionPhase.preparing => 'Hazırlanıyor…',
  SingleToneSessionPhase.referencePlaying =>
    'Referansı dinle. Mikrofon kapalı.',
  SingleToneSessionPhase.waiting => 'Hazırlan…',
  SingleToneSessionPhase.responding => 'Şimdi söyle. Mikrofon açık.',
  SingleToneSessionPhase.assessing => 'Kayıt kalitesi kontrol ediliyor…',
  SingleToneSessionPhase.analyzing => 'Yerel analiz yapılıyor…',
  SingleToneSessionPhase.finished => 'Deneme bitti.',
  SingleToneSessionPhase.closed => 'Oturum kapandı.',
};

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome});
  final SingleToneSessionOutcome outcome;
  @override
  Widget build(BuildContext context) {
    final neutral = context.resultColors.notMeasured;
    final (title, body) = outcome.needsRetry
        ? (
            'Ölçüm alınamadı — puanlanmadı',
            _retryText(outcome.retryReason!, outcome.quality?.status),
          )
        : (
            'Kaydın analiz edildi',
            'Doğru/yanlış kararı henüz kapalı: ses tanıma doğruluğu gerçek kayıtlarla test edilmeden sonuç göstermiyoruz. İstersen ölçüm ayrıntısına bakabilirsin.',
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
  SessionRetryReason.calibrationRequired =>
    'Önce ortamı ölç. Çıkış (kulaklık/hoparlör) değiştiyse veya ölçüm eskidiyse yeniden ölçmek gerekir.',
  SessionRetryReason.permissionDenied =>
    'Mikrofon izni yok. Telefon ayarlarından Vocalart için mikrofonu açabilirsin; referansı dinlemek için izin gerekmez.',
  SessionRetryReason.routeUnsupported =>
    'Bu ses çıkışıyla bu çalışma yapılamıyor. Kablolu kulaklık dene.',
  SessionRetryReason.interrupted =>
    'Deneme kesildi (arama, bildirim veya kulaklık değişimi). Hazır olduğunda yeniden başlat.',
  SessionRetryReason.captureFailed =>
    'Kayıt alınamadı. Yeniden deneyebilirsin.',
  SessionRetryReason.analysisFailed =>
    'Analiz tamamlanamadı. Yeniden deneyebilirsin.',
  SessionRetryReason.quality => switch (quality) {
    CaptureQualityStatus.silent || CaptureQualityStatus.insufficientActivity =>
      'Yeterli ses duyulmadı. Mikrofon açılınca notayı en az bir saniye net söyle.',
    CaptureQualityStatus.lowSignalToNoise =>
      'Ortam gürültüsü sesine çok yakın. Daha sessiz bir yerde dene.',
    CaptureQualityStatus.clipped =>
      'Ses taştı. Telefondan biraz uzaklaşıp yeniden dene.',
    CaptureQualityStatus.suspectedReferenceTail =>
      'Kaydın başında referans sesi duyulmuş olabilir. Kulaklık kullan veya mikrofon açıldıktan sonra başla.',
    CaptureQualityStatus.calibrationRequired =>
      'Ortam ölçümü bu kayda uymuyor. Yeniden ölçüp dene.',
    _ => 'Kayıt kullanılamadı. Yeniden deneyebilirsin.',
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
            'Sinyal/gürültü: ${q.signalToNoiseDb?.toStringAsFixed(1) ?? "Ölçülmedi"}${q.signalToNoiseDb == null ? "" : " dB"}',
          ),
          Text(
            'Etkin enerji süresi: ${q.activeSeconds?.toStringAsFixed(2) ?? "Ölçülmedi"}${q.activeSeconds == null ? "" : " sn"}',
          ),
          Text(
            'Gözlenen temsilî frekans: ${hz == null ? "Ölçülmedi" : "${hz.toStringAsFixed(1)} Hz"}',
          ),
          const Text(
            'Bu değerler deneyseldir; insan sesi tespiti, doğru nota veya başarı kanıtı değildir.',
          ),
        ],
      ),
    );
  }
}
