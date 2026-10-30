import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/audio_lab_controller.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import '../support/fake_audio_lab_backend.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAudioLabBackend backend;
  late AudioLabController controller;
  setUp(() {
    backend = FakeAudioLabBackend();
    controller = AudioLabController(backend);
  });
  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
  });
  test('entry never requests permission or opens microphone', () {
    expect(controller.phase, AudioLabPhase.idle);
    expect(backend.calls, isEmpty);
  });
  test('reference prevents recording until playback completes', () async {
    await controller.playReference();
    await controller.startRecording();
    expect(controller.phase, AudioLabPhase.referencePlaying);
    expect(backend.calls, ['reference']);
    backend.playbackEnd.complete();
    await flush();
    expect(controller.phase, AudioLabPhase.idle);
    await controller.startRecording();
    expect(controller.phase, AudioLabPhase.recording);
  });
  test('permission denial stays unrecorded without fabricated score', () async {
    backend.permission = false;
    await controller.startRecording();
    expect(controller.error, AudioLabError.permissionDenied);
    expect(controller.recording, isNull);
    expect(backend.calls, isNot(contains('start')));
    await controller.playReference();
    expect(controller.phase, AudioLabPhase.referencePlaying);
  });
  test('cancel during permission prevents late start', () async {
    backend.permissionGate = Completer();
    final starting = controller.startRecording();
    await flush();
    final cancellation = controller.cancel();
    backend.permissionGate!.complete(true);
    await starting;
    await cancellation;
    expect(backend.calls, isNot(contains('start')));
    expect(controller.phase, AudioLabPhase.idle);
  });
  test(
    'cancel during native start closes capture once start finishes',
    () async {
      backend.startGate = Completer();
      final starting = controller.startRecording();
      await flush();
      expect(backend.capturing, isTrue);
      final cancellation = controller.cancel();
      backend.startGate!.complete();
      await starting;
      await cancellation;
      expect(backend.capturing, isFalse);
      expect(controller.phase, AudioLabPhase.idle);
    },
  );
  test('double start and double stop are serialized and idempotent', () async {
    await Future.wait([
      controller.startRecording(),
      controller.startRecording(),
    ]);
    expect(backend.calls.where((c) => c == 'start').length, 1);
    await Future.wait([controller.stopRecording(), controller.stopRecording()]);
    expect(backend.calls.where((c) => c == 'stop').length, 1);
    expect(controller.phase, AudioLabPhase.recorded);
    expect(controller.recording!.sampleRateHz, 44100);
    expect(controller.recording!.durationSeconds, 1);
    await controller.playRecording();
    expect(controller.phase, AudioLabPhase.recordingPlaying);
  });
  test('cancel while stopping cannot revive a deleted recording', () async {
    await controller.startRecording();
    backend.stopGate = Completer();
    final stopping = controller.stopRecording();
    await flush();
    final cancellation = controller.cancel();
    backend.stopGate!.complete(backend.captured);
    await stopping;
    await cancellation;
    expect(controller.recording, isNull);
    expect(controller.phase, AudioLabPhase.idle);
  });
  test('late playback completion cannot overwrite a new recording', () async {
    await controller.playReference();
    await controller.cancel();
    await controller.startRecording();
    backend.playbackEnd.complete();
    await flush();
    expect(controller.phase, AudioLabPhase.recording);
  });
  test('cancel while loading consumes even late playback errors', () async {
    backend.playbackGate = Completer();
    final playing = controller.playReference();
    await flush();
    final cancellation = controller.cancel();
    backend.playbackGate!.complete(PlaybackHandle(backend.playbackEnd.future));
    await playing;
    await cancellation;
    backend.playbackEnd.completeError(StateError('late audio error'));
    await flush();
    expect(controller.phase, AudioLabPhase.idle);
  });
  test(
    'route and focus interruptions stop recording without auto resume',
    () async {
      for (final event in AudioLabInterruption.values) {
        await controller.startRecording();
        backend.events.add(event);
        await flush();
        expect(controller.phase, AudioLabPhase.idle);
        expect(backend.capturing, isFalse);
      }
    },
  );
  test(
    'malformed empty or overlong capture is rejected and discarded',
    () async {
      for (final captured in [
        CapturedAudio(sampleRateHz: 48000, sampleCount: 0),
        CapturedAudio(sampleRateHz: 48000, sampleCount: 48000 * 12),
      ]) {
        backend.captured = captured;
        await controller.startRecording();
        await controller.stopRecording();
        expect(controller.error, AudioLabError.unsupportedFormat);
        expect(controller.recording, isNull);
      }
      backend.stopFailure = const FormatException('bad WAV');
      await controller.startRecording();
      await controller.stopRecording();
      expect(controller.error, AudioLabError.unsupportedFormat);
    },
  );
  test(
    'cleanup failure is visible and cannot silently start another recording',
    () async {
      backend.cleanupFails = true;
      await controller.startRecording();
      expect(controller.error, AudioLabError.cleanupFailed);
      expect(backend.calls, isNot(contains('start')));
    },
  );
  test(
    'shutdown invalidates permission and closes backend exactly once',
    () async {
      backend.permissionGate = Completer();
      final starting = controller.startRecording();
      await flush();
      final close = controller.shutdown();
      backend.permissionGate!.complete(true);
      await starting;
      await close;
      await controller.shutdown();
      expect(backend.calls, isNot(contains('start')));
      expect(backend.calls.where((c) => c == 'close').length, 1);
      expect(controller.phase, AudioLabPhase.closed);
    },
  );
  test('capture automatically stops at the configured limit', () {
    fakeAsync((clock) {
      final isolated = FakeAudioLabBackend();
      final short = AudioLabController(
        isolated,
        recordingLimit: const Duration(seconds: 1),
      );
      unawaited(short.startRecording());
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(short.phase, AudioLabPhase.recorded);
      expect(isolated.capturing, isFalse);
      unawaited(short.shutdown());
      clock.flushMicrotasks();
      short.dispose();
      clock.flushMicrotasks();
    });
  });
}
