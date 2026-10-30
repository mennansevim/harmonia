import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/audio_lab_controller.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;

List<double> _noise(double seconds, double rms) {
  var state = 11;
  final amp = rms * math.sqrt(3);
  return List.generate((seconds * _rate).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return amp * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _tone(double seconds) => List.generate(
  (seconds * _rate).round(),
  (i) => 0.2 * math.sin(2 * math.pi * 261.63 * i / _rate),
);

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeRoutedAudioLabBackend backend;
  late AudioLabController controller;
  var now = DateTime.utc(2026, 10, 11, 12);

  setUp(() {
    now = DateTime.utc(2026, 10, 11, 12);
    backend = FakeRoutedAudioLabBackend();
    controller = AudioLabController(
      backend,
      worker: FakeRecordingPitchWorker(),
      calibrationDuration: const Duration(milliseconds: 1),
      clock: () => now,
    );
  });
  tearDown(() async {
    await controller.shutdown();
    controller.dispose();
  });

  Future<void> calibrate(List<double> clip) async {
    backend.nextClip(clip);
    await controller.calibrateNoiseFloor();
    expect(controller.phase, AudioLabPhase.calibrating);
    await _settle();
  }

  test('calibration measures, deletes the clip and binds the route', () async {
    await calibrate(_noise(2, 0.001));
    expect(controller.phase, AudioLabPhase.idle);
    expect(controller.calibration!.status, NoiseFloorStatus.calibrated);
    expect(
      controller.calibration!.stamp.route.signature,
      backend.route.signature,
    );
    expect(controller.recording, isNull);
    expect(
      backend.calls.sublist(backend.calls.indexOf('stop')),
      containsAllInOrder(['stop', 'read', 'discard']),
    );
  });

  test('noisy calibration is kept as an unusable, explained result', () async {
    await calibrate(_noise(2, 0.05));
    expect(controller.calibration!.status, NoiseFloorStatus.tooNoisy);
    expect(controller.calibration!.isUsable, isFalse);
  });

  test('analysis reports SNR with calibration on the same route', () async {
    await calibrate(_noise(2, 0.001));
    backend.nextClip([..._noise(0.3, 0.001), ..._tone(1.5)]);
    await controller.startRecording();
    await controller.stopRecording();
    await controller.analyzeRecording();
    final q = controller.quality!;
    expect(q.calibrationState, CalibrationState.valid);
    expect(q.status, CaptureQualityStatus.usable);
    expect(q.signalToNoiseDb, greaterThan(30));
    expect(controller.diagnostics, isNotNull);
  });

  test('route change after calibration invalidates it for analysis', () async {
    await calibrate(_noise(2, 0.001));
    backend.route = const AudioRouteSnapshot(
      input: AudioRouteKind.builtIn,
      output: AudioRouteKind.builtIn,
    );
    backend.nextClip(_tone(1.5));
    await controller.startRecording();
    await controller.stopRecording();
    await controller.analyzeRecording();
    final q = controller.quality!;
    expect(q.calibrationState, CalibrationState.routeChanged);
    expect(q.signalToNoiseDb, isNull);
    expect(q.routeDecision, RouteDecision.sequentialOnly);
  });

  test('expired calibration is reported, never silently reused', () async {
    await calibrate(_noise(2, 0.001));
    now = now.add(const Duration(minutes: 45));
    backend.nextClip(_tone(1.5));
    await controller.startRecording();
    await controller.stopRecording();
    await controller.analyzeRecording();
    expect(controller.quality!.calibrationState, CalibrationState.expired);
  });

  test('route probe failure degrades to unverified route', () async {
    backend.routeFailure = StateError('no route');
    backend.nextClip(_tone(1.5));
    await controller.startRecording();
    await controller.stopRecording();
    await controller.analyzeRecording();
    expect(controller.quality!.routeDecision, RouteDecision.unverified);
    expect(controller.quality!.calibrationState, CalibrationState.missing);
  });

  test('interruption during calibration cancels without a result', () async {
    backend.nextClip(_noise(2, 0.001));
    final slow = AudioLabController(
      backend,
      worker: FakeRecordingPitchWorker(),
      calibrationDuration: const Duration(seconds: 5),
      clock: () => now,
    );
    await slow.calibrateNoiseFloor();
    expect(slow.phase, AudioLabPhase.calibrating);
    backend.events.add(AudioLabInterruption.routeChanged);
    await _settle();
    expect(slow.phase, AudioLabPhase.idle);
    expect(slow.calibration, isNull);
    expect(backend.capturing, isFalse);
    await slow.shutdown();
    slow.dispose();
  });

  test('permission denial during calibration is a neutral error', () async {
    backend.permission = false;
    await controller.calibrateNoiseFloor();
    expect(controller.phase, AudioLabPhase.error);
    expect(controller.error, AudioLabError.permissionDenied);
    expect(controller.calibration, isNull);
  });

  test('metadata mismatch fails closed and discards capture', () async {
    backend.nextClip(_noise(2, 0.001));
    backend.readGate = Completer()
      ..complete(
        CapturedAudioSamples(
          sampleRateHz: _rate,
          samples: _noise(1.9, 0.001),
          source: MeasurementSource.mock,
        ),
      );
    await controller.calibrateNoiseFloor();
    await _settle();
    expect(controller.phase, AudioLabPhase.error);
    expect(controller.error, AudioLabError.unsupportedFormat);
    expect(controller.calibration, isNull);
    expect(backend.calls.last, 'discard');
  });

  test('calibration is unavailable without a PCM reader', () async {
    final plain = AudioLabController(_NoReaderBackend());
    expect(plain.canCalibrate, isFalse);
    await plain.shutdown();
    plain.dispose();
  });
}

class _NoReaderBackend implements AudioLabBackend {
  @override
  Stream<AudioLabInterruption> get interruptions => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  Future<void> discardCapture() async {}
  @override
  Future<PlaybackHandle> playRecording() async =>
      PlaybackHandle(Future.value());
  @override
  Future<PlaybackHandle> playReference() async =>
      PlaybackHandle(Future.value());
  @override
  Future<bool> requestMicrophonePermission() async => true;
  @override
  Future<void> startCapture() async {}
  @override
  Future<CapturedAudio> stopCapture() async =>
      CapturedAudio(sampleRateHz: _rate, sampleCount: _rate);
  @override
  Future<void> stopPlayback() async {}
}
