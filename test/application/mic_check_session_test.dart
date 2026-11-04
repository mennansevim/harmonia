import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/mic_check_session.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/audio/mic_check.dart';

import '../support/fake_audio_lab_backend.dart';

const _rate = 16000;
const _wired = AudioRouteSnapshot(
  input: AudioRouteKind.builtIn,
  output: AudioRouteKind.wired,
);

List<double> _noise(double seconds, {double rms = 0.001}) {
  var state = 29;
  final amp = rms * math.sqrt(3);
  return List.generate((seconds * _rate).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return amp * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _voice(double amplitude) => [
  ..._noise(0.3),
  ...List.generate(
    (_rate * 1.5).round(),
    (i) =>
        (amplitude * math.sin(2 * math.pi * 220 * i / _rate)).clamp(-1.0, 1.0),
  ),
];

NoiseFloorCalibration _floor(List<double> samples) =>
    NoiseFloorCalibrator.measure(
      samples: samples,
      sampleRateHz: _rate,
      route: _wired,
      measuredAt: DateTime(2026, 11, 4, 10),
    );

CaptureQualityReport _assess(
  List<double> samples,
  NoiseFloorCalibration floor, {
  AudioRouteSnapshot route = _wired,
}) => CaptureQualityAssessor.assess(
  samples: samples,
  sampleRateHz: _rate,
  route: route,
  now: DateTime(2026, 11, 4, 10, 1),
  calibration: floor,
);

class _QueuedBackend extends FakeRoutedAudioLabBackend {
  _QueuedBackend(this.clips);
  final List<List<double>> clips;
  final List<AudioRouteSnapshot> routes = [];

  @override
  Future<AudioRouteSnapshot> currentRoute() {
    if (routes.isNotEmpty) route = routes.removeAt(0);
    return super.currentRoute();
  }

  @override
  Future<CapturedAudio> stopCapture() {
    if (clips.isNotEmpty) nextClip(clips.removeAt(0));
    return super.stopCapture();
  }
}

MicCheckController _controller(FakeAudioLabBackend backend) =>
    MicCheckController(
      backend: backend,
      silenceDuration: const Duration(milliseconds: 1),
      getReadyDuration: Duration.zero,
      voiceDuration: const Duration(milliseconds: 1),
    );

void main() {
  group('MicCheckResult mapping adds no thresholds', () {
    test('silence step maps the noise-floor statuses', () {
      expect(MicCheckResult.afterSilence(_floor(_noise(2))), isNull);
      expect(
        MicCheckResult.afterSilence(_floor(_noise(2, rms: 0.02)))!.status,
        MicCheckStatus.noisyRoom,
      );
      final talked = MicCheckResult.afterSilence(
        _floor([..._noise(1.5), ..._voice(0.2)]),
      )!;
      expect(talked.status, MicCheckStatus.notMeasured);
      expect(talked.gap, MicCheckGap.activityDuringSilence);
      final short = MicCheckResult.afterSilence(_floor(_noise(0.5)))!;
      expect(short.status, MicCheckStatus.notMeasured);
      expect(short.gap, MicCheckGap.invalidCapture);
      expect(short.noiseFloorDb, isNull);
      final loud = MicCheckResult.afterSilence(
        _floor(List.filled(_rate * 2, 1.0)),
      )!;
      expect(loud.status, MicCheckStatus.tooLoud);
    });

    test('voice step maps the capture-quality statuses', () {
      final floor = _floor(_noise(2));
      MicCheckResult voice(List<double> s, {AudioRouteSnapshot? route}) =>
          MicCheckResult.afterVoice(
            floor,
            _assess(s, floor, route: route ?? _wired),
          );
      final ready = voice(_voice(0.2));
      expect(ready.status, MicCheckStatus.ready);
      expect(ready.signalToNoiseDb, greaterThan(15));
      expect(voice(_voice(4)).status, MicCheckStatus.tooLoud);
      expect(voice(_voice(0.006)).status, MicCheckStatus.tooQuiet);
      expect(voice(_noise(2)).status, MicCheckStatus.tooQuiet);
      expect(
        voice(List.filled(_rate * 2, 0.0)).status,
        MicCheckStatus.tooQuiet,
      );
      final moved = voice(
        _voice(0.2),
        route: const AudioRouteSnapshot(
          input: AudioRouteKind.wired,
          output: AudioRouteKind.wired,
        ),
      );
      expect(moved.status, MicCheckStatus.notMeasured);
      expect(moved.gap, MicCheckGap.calibrationLost);
      expect(MicCheckResult.scoringEnabled, isFalse);
      expect(ready.toJson()['status'], 'ready');
      expect(ready.toJson().containsKey('samples'), isFalse);
    });
  });

  group('MicCheckController', () {
    test('runs silence then voice and discards both clips', () async {
      final backend = _QueuedBackend([_noise(2), _voice(0.2)]);
      final c = _controller(backend);
      await c.start();
      expect(c.phase, MicCheckPhase.finished);
      expect(c.result!.status, MicCheckStatus.ready);
      expect(backend.calls.where((e) => e == 'discard').length, 2);
      await c.close();
      expect(backend.calls.last, 'close');
    });

    test('a route change between the steps is not measured', () async {
      final backend = _QueuedBackend([_noise(2), _voice(0.2)])
        ..routes.addAll([
          _wired,
          const AudioRouteSnapshot(
            input: AudioRouteKind.bluetooth,
            output: AudioRouteKind.bluetooth,
          ),
        ]);
      final c = _controller(backend);
      await c.start();
      expect(c.result!.status, MicCheckStatus.notMeasured);
      expect(c.result!.gap, MicCheckGap.calibrationLost);
      await c.close();
    });

    test('denied permission never opens the microphone', () async {
      final backend = _QueuedBackend([])..permission = false;
      final c = _controller(backend);
      await c.start();
      expect(c.result!.status, MicCheckStatus.permissionDenied);
      expect(backend.calls, ['permission']);
      await c.close();
    });

    test('an interruption publishes no late result', () async {
      final backend = _QueuedBackend([_noise(2), _voice(0.2)]);
      final c = MicCheckController(
        backend: backend,
        silenceDuration: const Duration(seconds: 5),
      );
      final run = c.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(c.phase, MicCheckPhase.silence);
      backend.events.add(AudioLabInterruption.routeChanged);
      await run;
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, MicCheckPhase.finished);
      expect(c.result!.status, MicCheckStatus.notMeasured);
      expect(c.result!.gap, MicCheckGap.captureFailed);
      expect(backend.capturing, isFalse);
      expect(backend.calls.where((e) => e == 'read'), isEmpty);
      await c.close();
    });

    test('rejects a backend without readable PCM', () {
      expect(
        () => MicCheckController(backend: _NoReader()),
        throwsArgumentError,
      );
    });
  });
}

class _NoReader implements AudioLabBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
