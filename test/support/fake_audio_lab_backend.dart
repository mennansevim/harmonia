import 'dart:async';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

class FakeAudioLabBackend implements AudioLabBackend, AudioRecordingReader {
  Completer<CapturedAudioSamples>? readGate;
  Object? readFailure;

  /// Optional PCM returned by readRecording; caller keeps `captured` in sync.
  List<double>? recordedSamples;
  @override
  Future<CapturedAudioSamples> readRecording() async {
    calls.add('read');
    if (readFailure != null) throw readFailure!;
    return readGate == null
        ? CapturedAudioSamples(
            sampleRateHz: captured.sampleRateHz,
            samples: recordedSamples ?? List.filled(captured.sampleCount, 0),
            source: MeasurementSource.mock,
          )
        : await readGate!.future;
  }

  final events = StreamController<AudioLabInterruption>.broadcast(sync: true);
  final calls = <String>[];
  bool permission = true;
  bool capturing = false;
  Completer<bool>? permissionGate;
  Completer<void>? startGate;
  Completer<PlaybackHandle>? playbackGate;
  Completer<CapturedAudio>? stopGate;
  Completer<void> playbackEnd = Completer();
  CapturedAudio captured = CapturedAudio(
    sampleRateHz: 44100,
    sampleCount: 44100,
  );
  Object? stopFailure;
  bool cleanupFails = false;
  @override
  Stream<AudioLabInterruption> get interruptions => events.stream;
  @override
  Future<bool> requestMicrophonePermission() async {
    calls.add('permission');
    return permissionGate == null ? permission : await permissionGate!.future;
  }

  @override
  Future<void> startCapture() async {
    calls.add('start');
    capturing = true;
    await startGate?.future;
  }

  @override
  Future<CapturedAudio> stopCapture() async {
    calls.add('stop');
    capturing = false;
    if (stopFailure != null) throw stopFailure!;
    return stopGate == null ? captured : await stopGate!.future;
  }

  @override
  Future<void> discardCapture() async {
    calls.add('discard');
    if (cleanupFails) throw StateError('cleanup failure');
    capturing = false;
  }

  @override
  Future<PlaybackHandle> playReference() async {
    calls.add('reference');
    return playbackGate == null
        ? PlaybackHandle(playbackEnd.future)
        : await playbackGate!.future;
  }

  @override
  Future<PlaybackHandle> playRecording() async {
    calls.add('replay');
    return PlaybackHandle(playbackEnd.future);
  }

  @override
  Future<void> stopPlayback() async {
    calls.add('stopPlayback');
  }

  @override
  Future<void> close() async {
    calls.add('close');
    capturing = false;
    await events.close();
  }
}

class FakeRoutedAudioLabBackend extends FakeAudioLabBackend
    implements AudioRouteProbe, InputLevelSource {
  final levels = StreamController<double>.broadcast(sync: true);
  @override
  Stream<double> get inputLevelDb => levels.stream;

  @override
  MeasurementProvenance get inputLevelProvenance => const MeasurementProvenance(
    source: MeasurementSource.mock,
    analyzerVersion: 'fake-input-level-v1',
  );

  AudioRouteSnapshot route = const AudioRouteSnapshot(
    input: AudioRouteKind.builtIn,
    output: AudioRouteKind.wired,
  );
  Object? routeFailure;
  @override
  Future<AudioRouteSnapshot> currentRoute() async {
    calls.add('route');
    if (routeFailure != null) throw routeFailure!;
    return route;
  }

  /// Sets matching metadata + PCM for the next stop/read pair.
  void nextClip(List<double> samples, {int sampleRateHz = 16000}) {
    recordedSamples = samples;
    captured = CapturedAudio(
      sampleRateHz: sampleRateHz,
      sampleCount: samples.length,
    );
  }
}
