import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/resonia_theme.dart';
import '../../application/audio_lab_controller.dart';
import '../../application/microphone_permission_recovery.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../common/input_level_meter.dart';
import '../common/ui/resonia_ui.dart';
import '../common/ui/microphone_permission_recovery_card.dart';

class AudioLabScreen extends StatefulWidget {
  const AudioLabScreen({
    super.key,
    this.backend,
    this.worker,
    this.permissionRecovery,
  });
  final AudioLabBackend? backend;
  final RecordingPitchWorker? worker;
  final MicrophonePermissionRecovery? permissionRecovery;
  @override
  State<AudioLabScreen> createState() => _AudioLabScreenState();
}

class _AudioLabScreenState extends State<AudioLabScreen>
    with WidgetsBindingObserver {
  late final AudioLabController controller;
  @override
  void initState() {
    super.initState();
    controller = AudioLabController(
      widget.backend ?? PluginAudioLabBackend(),
      worker: widget.worker ?? IsolateRecordingPitchWorker(),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A foreground OS permission dialog temporarily makes iOS inactive.
    if (state == AppLifecycleState.inactive &&
        controller.phase == AudioLabPhase.requestingPermission) {
      return;
    }
    if (state != AppLifecycleState.resumed &&
        controller.phase != AudioLabPhase.idle) {
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final recording = controller.recording;
      return LessonScaffold(
        progress: null,
        counter: 'Puansız',
        closeLabel: 'Ses laboratuvarını kapat',
        top: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusPill('Gerçek kayıt • Deneysel'),
          ),
          const SizedBox(height: ResoniaSpacing.md),
          Text(
            'Ses laboratuvarı',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'C4 referansı sentetik bir tondur. Yerel kayıt ve analiz burada denenir; doğru/yanlış kararı veya başarı puanı verilmez.',
          ),
          const SizedBox(height: ResoniaSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _status(controller.phase),
              key: const Key('audio_lab_status'),
            ),
          ),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: ResoniaSpacing.sm),
              child: Text(
                _error(controller.error!),
                key: const Key('audio_lab_error'),
              ),
            ),
          if (controller.error == AudioLabError.permissionDenied)
            MicrophonePermissionRecoveryCard(
              recovery: widget.permissionRecovery,
            ),
          if ((controller.phase == AudioLabPhase.recording ||
                  controller.phase == AudioLabPhase.calibrating) &&
              controller.backend is InputLevelSource)
            InputLevelMeter(
              levels: (controller.backend as InputLevelSource).inputLevelDb,
            ),
          const SizedBox(height: ResoniaSpacing.md),
          _CalibrationCard(controller: controller),
          if (recording != null) ...[
            const SizedBox(height: ResoniaSpacing.md),
            DataLabel(
              '${recording.durationSeconds.toStringAsFixed(2)} sn • ${recording.sampleRateHz} Hz • mono PCM16',
              key: const Key('audio_lab_metadata'),
            ),
            if (controller.analysisInFlight)
              const Text(
                'Analiz işi bitmeden yeni analiz başlatılamaz. Silme işlemi sonucu geçersiz kılar; çalışan hesaplama bitene kadar sürer.',
              ),
            if (controller.analysisError != null)
              Text(
                controller.analysisError ==
                        AudioLabAnalysisError.unsupportedInput
                    ? 'Analiz için kayıt metaverisi eşleşmeli, 8–48 kHz ve en fazla 10 sn olmalı. Kaydını hâlâ dinleyebilir veya silebilirsin.'
                    : 'Analiz tamamlanamadı. Kaydın korunuyor; yeniden deneyebilirsin.',
                key: const Key('audio_lab_analysis_error'),
              ),
            if (controller.quality case final report?)
              _QualityReport(report: report),
            if (controller.diagnostics case final evidence?)
              _Diagnostics(evidence: evidence),
          ],
        ],
        bottom: [
          if (controller.canStart) ...[
            if (recording != null)
              const Padding(
                padding: EdgeInsets.only(bottom: ResoniaSpacing.sm),
                child: Text(
                  'Yeni kayıt veya ortam ölçümü önceki geçici kaydı değiştirir.',
                ),
              ),
            ChunkyButton(
              key: const Key('audio_lab_reference'),
              onPressed: controller.playReference,
              tone: ChunkyTone.neutral,
              icon: Icons.volume_up_outlined,
              label: 'C4 referansını dinle',
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('audio_lab_record'),
              onPressed: controller.startRecording,
              tone: ChunkyTone.primary,
              icon: Icons.mic_none,
              label: 'Kaydı başlat (en fazla 10 sn)',
            ),
          ],
          if (controller.phase == AudioLabPhase.recording)
            ChunkyButton(
              key: const Key('audio_lab_stop'),
              onPressed: controller.stopRecording,
              tone: ChunkyTone.primary,
              icon: Icons.stop,
              label: 'Kaydı bitir',
            ),
          if (recording != null) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('audio_lab_analyze'),
              onPressed: controller.canAnalyze
                  ? controller.analyzeRecording
                  : null,
              tone: ChunkyTone.neutral,
              icon: Icons.analytics_outlined,
              label: 'Kaydını analiz et (deneysel)',
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('audio_lab_replay'),
              onPressed: controller.canStart ? controller.playRecording : null,
              tone: ChunkyTone.neutral,
              icon: Icons.play_arrow,
              label: 'Kendi kaydını dinle',
            ),
          ],
          if (controller.phase != AudioLabPhase.idle) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            ChunkyButton(
              key: const Key('audio_lab_cancel'),
              onPressed: controller.phase == AudioLabPhase.cancelling
                  ? null
                  : controller.cancel,
              tone: ChunkyTone.neutral,
              label: recording == null ? 'İptal et' : 'Kaydı sil ve sıfırla',
            ),
          ],
          const SizedBox(height: ResoniaSpacing.md),
          const ExpansionTile(
            key: Key('audio_lab_help'),
            tilePadding: EdgeInsets.zero,
            title: Text('Kayıt ve gizlilik rehberi'),
            children: [
              Text(
                'Mikrofon yalnız “Kaydı başlat” veya “Ortam sessizliğini ölç” ile açılır. Referans piyano veya insan sesi değildir. Kayıt geçici olarak cihazında tutulur; çıkışta silme işlemi yapılır. Sunucuya veya AI’ye gönderilmez.',
              ),
              SizedBox(height: ResoniaSpacing.sm),
              Text(
                'İsteğe bağlı analiz deneysel frekans kanıtıdır; nota doğruluğu veya öğrenci başarı puanı değildir. İzin reddedilirse telefon ayarlarından Vocalart’ın mikrofon iznini kontrol edebilirsin. İzin tekrar otomatik istenmez. Bluetooth ve kulaklık davranışı cihaz testini bekliyor.',
              ),
            ],
          ),
        ],
      );
    },
  );
}

String _status(AudioLabPhase phase) => switch (phase) {
  AudioLabPhase.idle => 'Hazır. Mikrofon kapalı.',
  AudioLabPhase.requestingPermission => 'Mikrofon izni bekleniyor…',
  AudioLabPhase.referencePlaying => 'Referansı dinle. Mikrofon kapalı.',
  AudioLabPhase.recording => 'Kayıt alınıyor. İstediğin zaman bitirebilirsin.',
  AudioLabPhase.calibrating =>
    'Ortam ölçülüyor. Lütfen 2 saniye sessiz kal; mikrofon açık.',
  AudioLabPhase.stopping => 'Kayıt bitiriliyor ve dosya doğrulanıyor…',
  AudioLabPhase.recorded => 'Kayıt hazır. Dinleyebilir veya silebilirsin.',
  AudioLabPhase.recordingPlaying => 'Kendi kaydın çalıyor. Mikrofon kapalı.',
  AudioLabPhase.analyzing =>
    'Kayıt yükleniyor veya yerel analiz yapılıyor. Mikrofon kapalı.',
  AudioLabPhase.cancelling => 'Ses kaynakları kapatılıyor…',
  AudioLabPhase.error => 'İşlem tamamlanamadı.',
  AudioLabPhase.closed => 'Oturum kapandı.',
};

class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.evidence});
  final RecordingPitchEvidence evidence;
  @override
  Widget build(BuildContext context) => Card(
    key: const Key('audio_lab_diagnostics'),
    child: Padding(
      padding: const EdgeInsets.all(ResoniaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yerel analiz • Başarı skoru değildir',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: ResoniaSpacing.sm),
          Text(switch (evidence.status) {
            RecordingPitchStatus.invalidInput => 'Analiz girdisi geçersiz.',
            RecordingPitchStatus.insufficientData =>
              'Kayıt analiz penceresi için çok kısa.',
            RecordingPitchStatus.noPeriodicSignal =>
              'Periyodik sinyal gözlenmedi; sessizlik veya gürültü olabilir.',
            RecordingPitchStatus.periodicSignalObserved =>
              'Periyodik sinyal gözlendi. Bu, insan sesi veya doğru nota kanıtı değildir.',
          }),
          Text(
            'Temsilî frekans: ${evidence.representativeFrequencyHz?.toStringAsFixed(1) ?? "Ölçülmedi"}${evidence.representativeFrequencyHz == null ? "" : " Hz"}',
          ),
          Text(
            'Periyodik pencere oranı: ${evidence.periodicFrameRatio == null ? "Ölçülmedi" : "${(evidence.periodicFrameRatio! * 100).toStringAsFixed(1)}%"}',
          ),
          Text(
            'Frekans dağılımı: ${evidence.pitchDispersionCents?.toStringAsFixed(1) ?? "Ölçülmedi"}${evidence.pitchDispersionCents == null ? "" : " cent"}',
          ),
          const Text(
            'Örtüşen pencereler bağımsız denemeler değildir. Oran sesli konuşma oranı, dağılım ise vokal kararlılık puanı değildir.',
          ),
          Text(
            'Kaynak: ${evidence.provenance.source.name} • Motor: ${evidence.provenance.analyzerVersion}',
          ),
        ],
      ),
    ),
  );
}

String _error(AudioLabError error) => switch (error) {
  AudioLabError.permissionDenied =>
    'Mikrofon izni verilmedi. Referansı dinlemeye devam edebilirsin.',
  AudioLabError.unsupportedFormat =>
    'Geçerli mono PCM16 kaydı alınamadı. Yeniden deneyebilirsin.',
  AudioLabError.unavailable =>
    'Ses bileşeni kullanılamadı. Bu prototip iOS ve Android içindir; tekrar deneyebilirsin.',
  AudioLabError.cleanupFailed =>
    'Ses kaynaklarının kapandığı doğrulanamadı. Uygulamayı kapatıp yeniden aç.',
};

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.controller});
  final AudioLabController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller.calibration;
    return Column(
      key: const Key('audio_lab_calibration'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.canStart) ...[
          ChunkyButton(
            key: const Key('audio_lab_calibrate'),
            onPressed: controller.canCalibrate
                ? controller.calibrateNoiseFloor
                : null,
            tone: ChunkyTone.neutral,
            icon: Icons.graphic_eq,
            label: 'Ortam sessizliğini ölç (2 sn)',
          ),
          const SizedBox(height: ResoniaSpacing.sm),
        ],
        if (controller.recording != null)
          const Text(
            'Ortam ölçümü mevcut kaydı siler; kalibrasyon kaydı saklanmaz.',
          ),
        Text(
          c == null
              ? 'Ortam ölçümü yok. Ölçüm mevcut kaydı siler; kalibrasyon kaydı saklanmaz.'
              : _calibrationText(c),
          key: const Key('audio_lab_calibration_status'),
        ),
      ],
    );
  }
}

String _calibrationText(NoiseFloorCalibration c) {
  final floor = c.noiseFloorDb == null
      ? ''
      : ' (${c.noiseFloorDb!.toStringAsFixed(1)} dBFS)';
  return switch (c.status) {
    NoiseFloorStatus.calibrated =>
      'Ortam ölçüldü$floor. Kulaklık/çıkış değişirse veya 30 dk geçerse yeniden ölç.',
    NoiseFloorStatus.tooNoisy =>
      'Ortam çok gürültülü$floor. Daha sessiz bir yerde yeniden dene.',
    NoiseFloorStatus.activityDetected =>
      'Ölçüm sırasında ses algılandı. Sessiz kalıp yeniden dene.',
    NoiseFloorStatus.clipped => 'Mikrofon seviyesi taştı. Yeniden dene.',
    NoiseFloorStatus.tooShort ||
    NoiseFloorStatus.invalidInput => 'Ortam ölçümü alınamadı. Yeniden dene.',
  };
}

class _QualityReport extends StatelessWidget {
  const _QualityReport({required this.report});
  final CaptureQualityReport report;
  @override
  Widget build(BuildContext context) => Card(
    key: const Key('audio_lab_quality'),
    child: Padding(
      padding: const EdgeInsets.all(ResoniaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kayıt kalitesi: ${_qualityText(report.status)}',
            key: const Key('audio_lab_quality_status'),
          ),
          Text(
            'Etkin enerji: ${report.activeSeconds?.toStringAsFixed(2) ?? "Ölçülmedi"}${report.activeSeconds == null ? "" : " sn"} • '
            'Sinyal/gürültü: ${report.signalToNoiseDb == null ? "Kalibrasyon yok" : "${report.signalToNoiseDb!.toStringAsFixed(1)} dB"}',
          ),
          Text('Çıkış/route: ${_routeText(report.routeDecision)}'),
          const Text(
            'Enerji ölçümü insan sesi tespiti değildir; öksürük, konuşma veya hoparlör sızıntısı da enerji üretir.',
          ),
        ],
      ),
    ),
  );
}

String _qualityText(CaptureQualityStatus status) => switch (status) {
  CaptureQualityStatus.usable => 'analiz için yeterli görünüyor.',
  CaptureQualityStatus.invalidInput => 'kayıt geçersiz.',
  CaptureQualityStatus.tooShort => 'kayıt çok kısa.',
  CaptureQualityStatus.silent => 'sessiz; ses alınmadı.',
  CaptureQualityStatus.insufficientActivity =>
    'çok kısa veya zayıf ses; biraz daha uzun ve net söyle.',
  CaptureQualityStatus.lowSignalToNoise =>
    'ortam gürültüsü sese çok yakın; daha sessiz yerde dene.',
  CaptureQualityStatus.clipped => 'ses taştı; telefondan biraz uzaklaş.',
  CaptureQualityStatus.suspectedReferenceTail =>
    'kayıt başında referans sesi duyulmuş olabilir; kulaklık kullan veya referans bitince biraz bekle.',
  CaptureQualityStatus.calibrationRequired => 'önce ortam ölçümü gerekli.',
};

String _routeText(RouteDecision decision) => switch (decision) {
  RouteDecision.allowed => 'uygun.',
  RouteDecision.sequentialOnly =>
    'hoparlör; referans bitmeden söyleme, kulaklık önerilir.',
  RouteDecision.requiresLatencyCalibration => 'gecikme ölçümü gerekli.',
  RouteDecision.unsupported => 'bu çalışma için desteklenmiyor.',
  RouteDecision.unverified => 'doğrulanamadı (cihaz testi bekliyor).',
};
