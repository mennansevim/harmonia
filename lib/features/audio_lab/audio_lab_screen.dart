import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/audio_lab_controller.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../common/input_level_meter.dart';

class AudioLabScreen extends StatefulWidget {
  const AudioLabScreen({super.key, this.backend, this.worker});
  final AudioLabBackend? backend;
  final RecordingPitchWorker? worker;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ses laboratuvarı')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final recording = controller.recording;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Gerçek kayıt • Deneysel',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'C4 referansını dinle, sonra kısa bir ses kaydı al. Referans sentetik bir tondur; piyano veya insan sesi değildir.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mikrofon yalnız “Kaydı başlat” ile açılır. Kayıt geçici olarak cihazında tutulur; çıkışta silme işlemi yapılır. Sunucuya veya AI’ye gönderilmez. İsteğe bağlı analiz deneysel frekans kanıtını gösterir; nota doğruluğu veya öğrenci başarı puanı vermez.',
                ),
                const SizedBox(height: 24),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _status(controller.phase),
                    key: const Key('audio_lab_status'),
                  ),
                ),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error(controller.error!),
                      key: const Key('audio_lab_error'),
                    ),
                  ),
                const SizedBox(height: 16),
                _CalibrationCard(controller: controller),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('audio_lab_reference'),
                  onPressed: controller.canStart
                      ? controller.playReference
                      : null,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('C4 referansını dinle'),
                ),
                FilledButton.icon(
                  key: const Key('audio_lab_record'),
                  onPressed: controller.canStart
                      ? controller.startRecording
                      : null,
                  icon: const Icon(Icons.mic_none),
                  label: const Text('Kaydı başlat (en fazla 10 sn)'),
                ),
                if ((controller.phase == AudioLabPhase.recording ||
                        controller.phase == AudioLabPhase.calibrating) &&
                    controller.backend is InputLevelSource)
                  InputLevelMeter(
                    levels:
                        (controller.backend as InputLevelSource).inputLevelDb,
                  ),
                if (controller.phase == AudioLabPhase.recording)
                  FilledButton.icon(
                    key: const Key('audio_lab_stop'),
                    onPressed: controller.stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Kaydı bitir'),
                  ),
                if (recording != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${recording.durationSeconds.toStringAsFixed(2)} sn • ${recording.sampleRateHz} Hz • mono PCM16',
                    key: const Key('audio_lab_metadata'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('audio_lab_analyze'),
                    onPressed: controller.canAnalyze
                        ? controller.analyzeRecording
                        : null,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Kaydını analiz et (deneysel)'),
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
                  OutlinedButton.icon(
                    key: const Key('audio_lab_replay'),
                    onPressed: controller.canStart
                        ? controller.playRecording
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Kendi kaydını dinle'),
                  ),
                ],
                if (controller.phase != AudioLabPhase.idle)
                  TextButton(
                    key: const Key('audio_lab_cancel'),
                    onPressed: controller.phase == AudioLabPhase.cancelling
                        ? null
                        : controller.cancel,
                    child: Text(
                      recording == null ? 'İptal et' : 'Kaydı sil ve sıfırla',
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'İzin reddedilirse telefon ayarlarından Harmonia’nın mikrofon iznini kontrol edebilirsin. İzin tekrar otomatik istenmez. Bluetooth ve kulaklık davranışı cihaz testini bekliyor.',
                ),
              ],
            ),
          );
        },
      ),
    ),
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
  Widget build(BuildContext context) => Padding(
    key: const Key('audio_lab_diagnostics'),
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Yerel analiz • Başarı skoru değildir'),
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
        OutlinedButton.icon(
          key: const Key('audio_lab_calibrate'),
          onPressed: controller.canCalibrate
              ? controller.calibrateNoiseFloor
              : null,
          icon: const Icon(Icons.graphic_eq),
          label: const Text('Ortam sessizliğini ölç (2 sn)'),
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
  Widget build(BuildContext context) => Padding(
    key: const Key('audio_lab_quality'),
    padding: const EdgeInsets.only(top: 16),
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
