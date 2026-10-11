import 'dart:async';
import 'package:harmonia/domain/audio/audio_capture.dart';

class FakeAudioLabBackend implements AudioLabBackend {
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
