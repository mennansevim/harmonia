import 'dart:async';
import 'package:flutter/material.dart';
import '../../application/audio_lab_controller.dart';
import '../../domain/audio/audio_capture.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';

class AudioLabScreen extends StatefulWidget {
  const AudioLabScreen({super.key, this.backend});
  final AudioLabBackend? backend;
  @override
  State<AudioLabScreen> createState() => _AudioLabScreenState();
}

class _AudioLabScreenState extends State<AudioLabScreen>
    with WidgetsBindingObserver {
  late final AudioLabController controller;
  @override
  void initState() {
    super.initState();
    controller = AudioLabController(widget.backend ?? PluginAudioLabBackend());
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
                  'Mikrofon yalnız “Kaydı başlat” ile açılır. Kayıt geçici olarak cihazında tutulur; çıkışta silme işlemi yapılır. Sunucuya veya AI’ye gönderilmez. Bu ekran nota tespiti yapmaz ve puan vermez.',
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
  AudioLabPhase.stopping => 'Kayıt bitiriliyor ve dosya doğrulanıyor…',
  AudioLabPhase.recorded => 'Kayıt hazır. Dinleyebilir veya silebilirsin.',
  AudioLabPhase.recordingPlaying => 'Kendi kaydın çalıyor. Mikrofon kapalı.',
  AudioLabPhase.cancelling => 'Ses kaynakları kapatılıyor…',
  AudioLabPhase.error => 'İşlem tamamlanamadı.',
  AudioLabPhase.closed => 'Oturum kapandı.',
};
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
