import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../domain/audio/capture_quality.dart';
import '../../infrastructure/audio/audio_route_mapping.dart';
import 'take_engine.dart';

class PluginChoirPlayer implements ChoirPlayer {
  final _player = AudioPlayer();

  @override
  Stream<Duration> get positions => _player.positionStream;
  @override
  Stream<bool> get playingChanges => _player.playerStateStream.map(
    (s) => s.playing && s.processingState != ProcessingState.completed,
  );

  @override
  Future<Duration?> open(String path, {bool loop = false}) async {
    await _player.stop();
    await _player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    return _player.setFilePath(path);
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration to) => _player.seek(to);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> close() => _player.dispose();
}

/// Device-unverified. The recorder owns the iOS session (playAndRecord); the
/// player must not touch it. Hands-free Bluetooth is left out so the phone's
/// own microphone keeps full quality and earbuds stay on A2DP.
class PluginTakeCapture implements TakeCapture {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
  );
  final _events = StreamController<TakeInterruption>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  var _watching = false;

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 44100,
    numChannels: 1,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
    audioInterruption: AudioInterruptionMode.none,
    androidConfig: AndroidRecordConfig(manageBluetooth: false),
    iosConfig: IosRecordConfig(
      categoryOptions: [
        IosAudioCategoryOption.defaultToSpeaker,
        IosAudioCategoryOption.allowBluetoothA2DP,
      ],
    ),
  );

  @override
  Stream<TakeInterruption> get interruptions => _events.stream;

  @override
  Stream<double> get levelsDb => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((a) => a.current.isFinite ? a.current.clamp(-60.0, 0.0) : -60.0);

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<AudioRouteSnapshot> route() async {
    final devices = await (await AudioSession.instance).getDevices();
    return routeFromDevices(devices, activeRouteReported: Platform.isIOS);
  }

  Future<void> _watch() async {
    if (_watching) return;
    _watching = true;
    final session = await AudioSession.instance;
    _subscriptions
      ..add(
        session.interruptionEventStream.listen((event) {
          if (event.begin) _events.add(TakeInterruption.focusLost);
        }),
      )
      ..add(
        session.becomingNoisyEventStream.listen(
          (_) => _events.add(TakeInterruption.routeChanged),
        ),
      )
      ..add(
        session.devicesChangedEventStream.listen(
          (_) => _events.add(TakeInterruption.routeChanged),
        ),
      );
  }

  @override
  Future<int> start({
    required String vocalPath,
    String? accompanimentPath,
  }) async {
    if (accompanimentPath != null) {
      await _player.setFilePath(accompanimentPath);
    }
    await _recorder.start(_config, path: vocalPath);
    final clock = Stopwatch()..start();
    await _watch();
    if (accompanimentPath == null) return 0;
    final started = _player.positionStream.firstWhere((p) => p > Duration.zero);
    unawaited(_player.play());
    final position = await started.timeout(const Duration(seconds: 5));
    final lag = clock.elapsedMilliseconds - position.inMilliseconds;
    return lag < 0 ? 0 : lag;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _recorder.stop();
  }

  @override
  Future<void> cancel() async {
    await _player.stop();
    await _recorder.cancel();
  }

  @override
  Future<void> close() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _player.dispose();
    await _recorder.dispose();
    await _events.close();
  }
}
