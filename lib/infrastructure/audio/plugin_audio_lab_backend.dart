import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
        InputLevelSource,
        LiveSampleSource {
  /// [livePcm]: record through the plugin's PCM stream instead of its file
  /// writer, so [liveSamples] carries the audio while it is captured. The
  /// same owned WAV file is written at stop, so [readRecording] and every
  /// analysis after it are unchanged.
  PluginAudioLabBackend({this.livePcm = false});
  final bool livePcm;
  static const _rateHz = 48000;
  final _live = StreamController<List<double>>.broadcast();
  StreamSubscription<Uint8List>? _pcmSubscription;
  final _pcm = BytesBuilder(copy: false);
  int? _carry;

  /// Live mono samples (−1…1, 48 kHz) while capturing; [livePcm] only.
  /// Display use: nothing here is measured or kept beyond the capture.
  @override
  Stream<List<double>> get liveSamples => _live.stream;
  @override
  int get liveSampleRateHz => _rateHz;

  final _events = StreamController<AudioLabInterruption>.broadcast();
  final _levels = StreamController<double>.broadcast();
  StreamSubscription<Amplitude>? _levelSubscription;

  /// Plugin amplitude (documented as dBFS; device-unverified) every 100 ms.
  @override
  Stream<double> get inputLevelDb => _levels.stream;

  @override
  MeasurementProvenance get inputLevelProvenance => const MeasurementProvenance(
    source: MeasurementSource.microphone,
    analyzerVersion: 'record-amplitude-dbfs-v1',
  );

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
    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: _rateHz,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );
    if (livePcm) {
      await _stopLevels();
      _pcm.clear();
      _carry = null;
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _rateHz,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      _pcmSubscription = stream.listen(_onPcm, onError: (Object _) {});
      return;
    }
    await _recorder!.start(config, path: _file('recording').path);
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

  /// Little-endian 16-bit mono; a byte split across chunks is carried over.
  /// Bounded by the WAV read budget: later audio is dropped, not grown.
  void _onPcm(Uint8List chunk) {
    var bytes = chunk;
    if (_carry != null) {
      bytes = Uint8List(chunk.length + 1)
        ..[0] = _carry!
        ..setRange(1, chunk.length + 1, chunk);
      _carry = null;
    }
    final even = bytes.length & ~1;
    if (even < bytes.length) _carry = bytes[even];
    if (even == 0) return;
    if (_pcm.length + even <= _maxPcmBytes) {
      _pcm.add(Uint8List.sublistView(bytes, 0, even));
    }
    final view = ByteData.sublistView(bytes, 0, even);
    final samples = List<double>.generate(
      even ~/ 2,
      (i) => view.getInt16(i * 2, Endian.little) / 32768,
    );
    var sum = 0.0;
    for (final x in samples) {
      sum += x * x;
    }
    final rms = math.sqrt(sum / samples.length);
    if (!_levels.isClosed) {
      _levels.add(
        rms <= 0 ? -160.0 : (20 * math.log(rms) / math.ln10).clamp(-160, 0),
      );
    }
    if (!_live.isClosed) _live.add(samples);
  }

  /// [readLabWav]'s budget minus the 44-byte header.
  static const _maxPcmBytes = 4224044 - 44;

  Future<void> _writePcmWav() async {
    final data = _pcm.takeBytes();
    final header = ByteData(44)
      ..setUint32(0, 0x52494646) // RIFF
      ..setUint32(4, 36 + data.length, Endian.little)
      ..setUint32(8, 0x57415645) // WAVE
      ..setUint32(12, 0x666d7420) // fmt
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, _rateHz, Endian.little)
      ..setUint32(28, _rateHz * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461) // data
      ..setUint32(40, data.length, Endian.little);
    await _file(
      'recording',
    ).writeAsBytes([...header.buffer.asUint8List(), ...data], flush: true);
  }

  @override
  Future<CapturedAudio> stopCapture() async {
    await _stopLevels();
    if (livePcm) {
      await _recorder!.stop();
      await _pcmSubscription?.cancel();
      _pcmSubscription = null;
      _capturing = false;
      await _writePcmWav();
    } else {
      final path = await _recorder!.stop();
      _capturing = false;
      if (path != _file('recording').path) {
        throw const FormatException('Unexpected recording file');
      }
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
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _pcm.clear();
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
    await attempt(_live.close);
    await attempt(_events.close);
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  }
}
