import 'package:flutter/material.dart';

import '../../application/mic_check_session.dart';
import '../../application/microphone_permission_recovery.dart';
import '../../domain/audio/mic_check.dart';
import '../../domain/lang.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../../infrastructure/permissions/permission_handler_microphone_recovery.dart';
import '../app/scope.dart';
import '../ui/kit.dart';

/// Short label of a finished check, e.g. for the onboarding card.
String micCheckStatusLabel(MicCheckStatus status) => switch (status) {
  MicCheckStatus.ready => tr('Mikrofon hazır', 'Microphone ready'),
  MicCheckStatus.noisyRoom => tr('Ortam gürültülü', 'The room is noisy'),
  MicCheckStatus.tooQuiet => tr('Ses çok kısık', 'Your voice is too quiet'),
  MicCheckStatus.tooLoud => tr('Ses çok yüksek', 'Too loud'),
  MicCheckStatus.permissionDenied => tr(
    'Mikrofon izni yok',
    'No microphone permission',
  ),
  MicCheckStatus.notMeasured => tr('Ölçülemedi', 'Not measured'),
};

MicCheckController _mobileController() =>
    MicCheckController(backend: PluginAudioLabBackend());

/// MIC-01 screen: is the voice picked up clearly, is the room quiet? Opened
/// from onboarding and Settings. Pops with the last [MicCheckStatus] (or
/// null). Nothing here is a score; a failed check is "not counted".
class MicCheckScreen extends StatefulWidget {
  const MicCheckScreen({super.key, this.controllerFactory, this.recovery});

  /// Test seam. Defaults to the device microphone when live audio is on.
  final MicCheckController Function()? controllerFactory;
  final MicrophonePermissionRecovery? recovery;

  @override
  State<MicCheckScreen> createState() => _MicCheckScreenState();
}

class _MicCheckScreenState extends State<MicCheckScreen> {
  MicCheckController? _controller;
  bool _unavailable = false;

  MicCheckController? _ensure() {
    if (_controller != null || _unavailable) return _controller;
    final factory =
        widget.controllerFactory ??
        (TrainerScope.read(context).liveAudio ? _mobileController : null);
    try {
      if (factory == null) throw UnsupportedError('No live audio');
      _controller = factory()..addListener(_changed);
    } catch (_) {
      _unavailable = true;
    }
    return _controller;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    final controller = _ensure();
    if (controller == null) {
      setState(() {});
      return;
    }
    await controller.start();
  }

  Future<void> _openSettings() async {
    try {
      await (widget.recovery ?? const PermissionHandlerMicrophoneRecovery())
          .openAppSettings();
    } catch (_) {
      // The page already spells out the manual path to the setting.
    }
  }

  void _done() => Navigator.of(context).pop(_controller?.result?.status);

  @override
  void dispose() {
    _controller
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<MicCheckStatus?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _done();
    },
    child: Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: tr('Mikrofon testi', 'Microphone check'),
              onBack: _done,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: _content(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: _actions(),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _content() {
    final c = _controller;
    final result = c?.result;
    return [
      PageTitle(
        tr('Sesin net geliyor mu?', 'Is your voice coming through?'),
        subtitle: tr(
          'Önce birkaç saniye sessiz kalırsın, sonra rahat bir "aaa" söylersin. '
              'Ortam gürültüsünü ve sesinin ne kadar net alındığını görürsün.',
          'First stay quiet for a few seconds, then sing an easy "aaa". '
              'You see the room noise and how clearly your voice comes through.',
        ),
      ),
      const SizedBox(height: 18),
      _Steps(phase: c?.phase ?? MicCheckPhase.idle, result: result),
      const SizedBox(height: 14),
      if (result != null && c!.phase == MicCheckPhase.finished)
        _ResultCard(result: result)
      else
        _PhaseCard(controller: c, unavailable: _unavailable),
      const SizedBox(height: 12),
      Text(
        tr(
          'Puan değil; yalnız kayıt koşulunu gösterir. Kayıtlar cihazdan çıkmaz '
              've ölçümden hemen sonra silinir.',
          'Not a score; it only shows the recording conditions. Recordings stay '
              'on the device and are deleted right after measuring.',
        ),
        style: TT.small,
      ),
    ];
  }

  Widget _actions() {
    final c = _controller;
    if (c != null && c.isRunning) {
      return BigButton(
        key: const Key('mic_check_cancel'),
        label: tr('Durdur', 'Stop'),
        icon: Ic.circleStop,
        color: TC.body,
        onPressed: c.cancel,
      );
    }
    final result = c?.result;
    final denied = result?.status == MicCheckStatus.permissionDenied;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (denied)
          BigButton(
            key: const Key('mic_check_settings'),
            label: tr('Ayarları aç', 'Open Settings'),
            icon: Ic.settings2,
            onPressed: _openSettings,
          )
        else if (result?.isReady == true)
          BigButton(
            key: const Key('mic_check_done'),
            label: tr('Devam', 'Continue'),
            onPressed: _done,
          )
        else
          BigButton(
            key: const Key('mic_check_start'),
            label: result == null
                ? tr('Testi başlat', 'Start the check')
                : tr('Tekrar dene', 'Try again'),
            icon: Ic.mic,
            onPressed: _unavailable ? null : _start,
          ),
        TextLink(
          result?.isReady == true
              ? tr('Tekrar dene', 'Try again')
              : denied
              ? tr('Tekrar dene', 'Try again')
              : tr('Şimdilik geç', 'Skip for now'),
          key: const Key('mic_check_secondary'),
          onTap: result?.isReady == true || denied ? _start : _done,
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.phase, required this.result});
  final MicCheckPhase phase;
  final MicCheckResult? result;

  @override
  Widget build(BuildContext context) {
    final current = switch (phase) {
      MicCheckPhase.permission => 0,
      MicCheckPhase.silence => 1,
      MicCheckPhase.getReady ||
      MicCheckPhase.voice ||
      MicCheckPhase.assessing => 2,
      MicCheckPhase.finished => 3,
      _ => -1,
    };
    final labels = [
      tr('İzin', 'Permission'),
      tr('Sessizlik', 'Silence'),
      tr('Ses', 'Voice'),
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                ProgressBar(
                  value: i < current ? 1 : (i == current ? 0.5 : 0),
                  height: 5,
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: TT.small.copyWith(
                    color: i == current ? TC.ink : TC.muted,
                    fontWeight: i == current ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.controller, required this.unavailable});
  final MicCheckController? controller;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final phase = c?.phase ?? MicCheckPhase.idle;
    final (icon, title, body) = unavailable
        ? (
            Ic.micOff,
            tr('Bu cihazda başlatılamadı', 'Could not start on this device'),
            tr(
              'Mikrofon testi burada çalışmıyor. İstersen bu adımı geç.',
              'The microphone check does not run here. Skip this step if you like.',
            ),
          )
        : switch (phase) {
            MicCheckPhase.permission => (
              Ic.mic,
              tr('Mikrofon izni', 'Microphone permission'),
              tr(
                'İzin yalnız bu test ve ses egzersizleri için kullanılır.',
                'The permission is used only for this check and voice exercises.',
              ),
            ),
            MicCheckPhase.silence => (
              Ic.micOff,
              tr('Birkaç saniye sessiz kal', 'Stay quiet for a few seconds'),
              tr(
                'Ortamın gürültüsünü ölçüyoruz; konuşma ve telefona dokunma.',
                'We are measuring the room noise; do not talk or touch the phone.',
              ),
            ),
            MicCheckPhase.getReady => (
              Ic.audioLines,
              tr('Hazırlan…', 'Get ready…'),
              tr(
                'Birazdan rahat bir "aaa" söyleyeceksin.',
                'In a moment you will sing an easy "aaa".',
              ),
            ),
            MicCheckPhase.voice => (
              Ic.audioLines,
              tr('Şimdi rahat bir "aaa" söyle', 'Now sing an easy "aaa"'),
              tr(
                'Konuşur gibi, zorlamadan ve sabit tut.',
                'Like speaking, without forcing, and hold it steady.',
              ),
            ),
            MicCheckPhase.assessing => (
              Ic.audioLines,
              tr('Kayıt kontrol ediliyor…', 'Checking the recording…'),
              tr(
                'Ses seviyesi, kırpılma ve ortamdan ayrışma.',
                'Level, clipping and separation from the room.',
              ),
            ),
            _ => (
              Ic.mic,
              tr('Hazır olduğunda başlat', 'Start when you are ready'),
              tr(
                'Mikrofon yalnız sen başlatınca açılır. Sessiz bir yer seç, '
                    'telefonu yüzünden 20–30 cm uzakta tut.',
                'The microphone opens only when you start. Pick a quiet place '
                    'and hold the phone 20–30 cm from your face.',
              ),
            ),
          };
    final recording =
        phase == MicCheckPhase.silence || phase == MicCheckPhase.voice;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: TC.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    title,
                    key: const Key('mic_check_status'),
                    style: TT.title,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: TT.body),
          if (recording && c != null && c.hasLevel) ...[
            const SizedBox(height: 14),
            _LevelBar(db: c.level),
          ],
        ],
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.db});
  final double? db;
  @override
  Widget build(BuildContext context) {
    final v = db == null ? 0.0 : ((db! + 60) / 60).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('GİRİŞ SEVİYESİ', 'INPUT LEVEL'), style: TT.caps),
        const SizedBox(height: 8),
        ProgressBar(value: v, height: 10),
        const SizedBox(height: 6),
        Text(
          tr(
            'Yalnız gösterge; sonuç kayıttan hesaplanır.',
            'An indicator only; the result is computed from the recording.',
          ),
          style: TT.small,
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final MicCheckResult result;

  @override
  Widget build(BuildContext context) {
    final ready = result.isReady;
    final (icon, title, tips) = _copy(result);
    return AppCard(
      key: Key('mic_check_result_${result.status.name}'),
      border: ready ? TC.green : TC.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: ready ? TC.green : TC.warn),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    title,
                    key: const Key('mic_check_status'),
                    style: TT.h3,
                  ),
                ),
              ),
            ],
          ),
          if (!ready) ...[
            const SizedBox(height: 4),
            Text(
              tr('Sayılmadı · puan değil', 'Not counted · not a score'),
              key: const Key('mic_check_not_counted'),
              style: TT.small,
            ),
          ],
          const SizedBox(height: 10),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Ic.chevronRight, size: 16, color: TC.muted),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(tip, style: TT.body)),
                ],
              ),
            ),
          if (result.noiseFloorDb != null) ...[
            const SizedBox(height: 6),
            Text(
              _details(result),
              key: const Key('mic_check_details'),
              style: TT.small,
            ),
          ],
        ],
      ),
    );
  }

  static String _db(double v) => v.toStringAsFixed(0).replaceAll('-', '−');

  static String _details(MicCheckResult r) {
    final floor = _db(r.noiseFloorDb!);
    final snr = r.signalToNoiseDb;
    return snr == null
        ? tr(
            'Ortam: $floor dBFS · cihaza göre ayarlanmamış ham değer',
            'Room: $floor dBFS · raw value, not device-calibrated',
          )
        : tr(
            'Ortam: $floor dBFS · ayrışma: ${_db(snr)} dB · cihaza göre '
                'ayarlanmamış ham değer',
            'Room: $floor dBFS · separation: ${_db(snr)} dB · raw value, not '
                'device-calibrated',
          );
  }

  static (IconData, String, List<String>) _copy(
    MicCheckResult r,
  ) => switch (r.status) {
    MicCheckStatus.ready => (
      Ic.circleCheck,
      tr('Hazır', 'Ready'),
      [
        tr(
          'Sesin net alınıyor ve ortam yeterince sessiz.',
          'Your voice comes through clearly and the room is quiet enough.',
        ),
        tr(
          'Yer veya kulaklık değişirse testi tekrarla.',
          'Repeat the check if you change place or headphones.',
        ),
      ],
    ),
    MicCheckStatus.noisyRoom => (
      Ic.volume2,
      tr('Ortam gürültülü', 'The room is noisy'),
      [
        tr(
          'Daha sessiz bir odaya geç; fan, TV ya da müziği kapat.',
          'Move to a quieter room; turn off fans, TV or music.',
        ),
        tr(
          'Mikrofonlu kulaklık ortam sesini azaltabilir.',
          'A headset with a microphone can reduce room noise.',
        ),
      ],
    ),
    MicCheckStatus.tooQuiet => (
      Ic.volume1,
      tr('Ses çok kısık', 'Your voice is too quiet'),
      [
        tr(
          'Telefonu biraz yaklaştır; mikrofon deliğini kapatma.',
          'Bring the phone a little closer; do not cover the microphone.',
        ),
        tr(
          'Biraz daha güçlü ama zorlamadan söyle.',
          'Sing a little stronger, without forcing.',
        ),
      ],
    ),
    MicCheckStatus.tooLoud => (
      Ic.triangleAlert,
      tr('Ses çok yüksek · kırpılıyor', 'Too loud · clipping'),
      [
        tr(
          'Telefonu biraz uzaklaştır.',
          'Move the phone a little further away.',
        ),
        tr(
          'Bağırmadan, rahat bir sesle söyle.',
          'Sing comfortably, without shouting.',
        ),
      ],
    ),
    MicCheckStatus.permissionDenied => (
      Ic.lock,
      tr('Mikrofon izni yok', 'No microphone permission'),
      [
        tr(
          'İstersen bu adımı geç; ses ölçümü izin verilene kadar yapılmaz.',
          'Skip this step if you like; voice measuring waits for permission.',
        ),
        tr(
          'Ayarlar > Vocalart > Mikrofon\'dan açabilirsin.',
          'You can turn it on in Settings > Vocalart > Microphone.',
        ),
      ],
    ),
    MicCheckStatus.notMeasured => (
      Ic.circleHelp,
      tr('Ölçülemedi', 'Not measured'),
      [
        switch (r.gap) {
          MicCheckGap.activityDuringSilence => tr(
            'Sessiz kalma sırasında ses duyuldu. Tekrar dene ve o birkaç '
                'saniye konuşma.',
            'Sound was heard while you were meant to be quiet. Try again '
                'and stay silent for those seconds.',
          ),
          MicCheckGap.earlyActivity => tr(
            '"Şimdi söyle" yazısını görünce başla.',
            'Start when you see "Now sing".',
          ),
          MicCheckGap.calibrationLost => tr(
            'Ses yolu değişti (ör. kulaklık takıldı). Testi baştan yap.',
            'The audio route changed (e.g. headphones). Start the check again.',
          ),
          MicCheckGap.invalidCapture || MicCheckGap.captureFailed || null => tr(
            'Kayıt alınamadı ya da kesildi. Tekrar dene.',
            'Nothing usable was recorded, or it was interrupted. Try again.',
          ),
        },
      ],
    ),
  };
}
