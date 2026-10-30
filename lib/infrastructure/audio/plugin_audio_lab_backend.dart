import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/models/measurement_provenance.dart';
import 'audio_route_mapping.dart';
import 'pcm16_wav.dart';
import 'read_lab_wav.dart';

/// IO-only laboratory adapter. Files are created in its own temporary directory;
/// no arbitrary recorder-returned path is read, deleted, shared or uploaded.
class PluginAudioLabBackend
    implements
        AudioLabBackend,
        AudioRecordingReader,
        AudioRouteProbe,
        InputLevelSource {
  final _events = StreamController<AudioLabInterruption>.broadcast();
  final _levels = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _levelSubscription;

  /// Plugin amplitude (documented as dBFS; device-unverified) every 100 ms.
  @override
  Stream<double> get inputLevelDb => _levels.stream;

  Future<void> _stopLevels() async {
    await _levelSubscription?.cancel();
    _levelSubscription = null;
  }

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  Directory? _directory;
  bool _capturing = false;
  Future<void>? _initialized;
  @override
  Stream<AudioLabInterruption> get interruptions => _events.stream;
  Future<void> _initialize() => _initialized ??= _initializeOnce();
  Future<void> _initializeOnce() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      throw UnsupportedError('Mobile audio lab only');
    }
    _directory = await (await getTemporaryDirectory()).createTemp(
      'resonia-audio-lab-',
    );
    _recorder = AudioRecorder();
    _player = AudioPlayer(handleInterruptions: false);
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _subscriptions.add(
      session.interruptionEventStream.listen((event) {
        if (event.begin) _events.add(AudioLabInterruption.audioFocusLost);
      }),
    );
    _subscriptions.add(
      session.becomingNoisyEventStream.listen(
        (_) => _events.add(AudioLabInterruption.routeChanged),
      ),
    );
    _subscriptions.add(
      session.devicesChangedEventStream.listen((event) {
        if (event.devicesAdded.isNotEmpty || event.devicesRemoved.isNotEmpty) {
          _events.add(AudioLabInterruption.routeChanged);
        }
      }),
    );
    _subscriptions.add(
      _recorder!.onStateChanged().listen((state) {
        if (state == RecordState.pause && _capturing) {
          _events.add(AudioLabInterruption.audioFocusLost);
        }
      }),
    );
  }

  /// Device-unverified mapping: iOS active route, Android inferred list.
  @override
  Future<AudioRouteSnapshot> currentRoute() async {
    await _initialize();
    final devices = await (await AudioSession.instance).getDevices();
    return routeFromDevices(devices, activeRouteReported: Platform.isIOS);
  }

  File _file(String name) => File('${_directory!.path}/$name.wav');
  @override
  Future<bool> requestMicrophonePermission() async {
    await _initialize();
    return _recorder!.hasPermission();
  }

  @override
  Future<void> startCapture() async {
    await _initialize();
    _capturing = true;
    await _recorder!.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 48000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
      path: _file('recording').path,
    );
    await _stopLevels();
    _levelSubscription = _recorder!
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((amplitude) {
          final db = amplitude.current;
          if (db.isFinite && !_levels.isClosed) {
            _levels.add(db.clamp(-160.0, 0.0));
          }
        }, onError: (Object _) {});
  }

  @override
  Future<CapturedAudio> stopCapture() async {
    await _stopLevels();
    final path = await _recorder!.stop();
    _capturing = false;
    if (path != _file('recording').path) {
      throw const FormatException('Unexpected recording file');
    }
    final wav = await readLabWav(_file('recording'));
    return CapturedAudio(
      sampleRateHz: wav.sampleRateHz,
      sampleCount: wav.samples.length,
    );
  }

  @override
  Future<CapturedAudioSamples> readRecording() async {
    if (_directory == null || _capturing) {
      throw StateError('No completed local recording');
    }
    final wav = await readLabWav(_file('recording'));
    return CapturedAudioSamples(
      sampleRateHz: wav.sampleRateHz,
      samples: wav.samples,
      source: MeasurementSource.microphone,
    );
  }

  @override
  Future<void> discardCapture() async {
    await _stopLevels();
    if (_capturing) {
      await _recorder!.cancel();
      _capturing = false;
    }
    if (_directory != null) {
      final file = _file('recording');
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<PlaybackHandle> playReference() async {
    await _initialize();
    final file = _file('reference');
    if (!await file.exists()) {
      await file.writeAsBytes(
        Pcm16Wav.tone(frequencyHz: 261.63).encode(),
        flush: true,
      );
    }
    return _playFile(file);
  }

  @override
  Future<PlaybackHandle> playRecording() async {
    await _initialize();
    return _playFile(_file('recording'));
  }

  Future<PlaybackHandle> _playFile(File file) async {
    // just_audio keeps `playing` true after completion and a later play()
    // then returns immediately; stop first so `completed` means this clip
    // really ended (the session opens the mic on that signal).
    await _player!.stop();
    await _player!.setFilePath(file.path);
    return PlaybackHandle(_player!.play());
  }

  @override
  Future<void> stopPlayback() async {
    await _player?.stop();
  }

  @override
  Future<void> close() async {
    Object? failure;
    StackTrace? failureStack;
    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }

    for (final subscription in _subscriptions) {
      await attempt(subscription.cancel);
    }
    await attempt(stopPlayback);
    await attempt(discardCapture);
    await attempt(() async {
      await _recorder?.dispose();
    });
    await attempt(() async {
      await _player?.dispose();
    });
    if (_directory != null) {
      for (final name in ['recording', 'reference']) {
        await attempt(() async {
          final file = _file(name);
          if (await file.exists()) await file.delete();
        });
      }
      // Non-recursive: never remove other directories or unexpected files.
      await attempt(() async {
        await _directory!.delete();
      });
    }
    await attempt(_stopLevels);
    await attempt(_levels.close);
    await attempt(_events.close);
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }
}
