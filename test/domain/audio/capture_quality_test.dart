import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/capture_quality.dart';

const _rate = 16000;
final _t0 = DateTime.utc(2026, 10, 11, 12);
const _speaker = AudioRouteSnapshot(
  input: AudioRouteKind.builtIn,
  output: AudioRouteKind.builtIn,
);
const _wired = AudioRouteSnapshot(
  input: AudioRouteKind.builtIn,
  output: AudioRouteKind.wired,
);

/// Deterministic uniform noise at the requested RMS (synthetic, not a room).
List<double> _noise(double seconds, double rms, {int seed = 7}) {
  var state = seed;
  final amp = rms * math.sqrt(3);
  return List.generate((seconds * _rate).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return amp * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _tone(double seconds, double amp, {double hz = 261.63}) =>
    List.generate(
      (seconds * _rate).round(),
      (i) => amp * math.sin(2 * math.pi * hz * i / _rate),
    );

List<double> _mix(List<double> a, List<double> b) => [
  for (var i = 0; i < a.length; i++) a[i] + (i < b.length ? b[i] : 0),
];

NoiseFloorCalibration _calibrate(
  List<double> s, {
  AudioRouteSnapshot route = _wired,
}) => NoiseFloorCalibrator.measure(
  samples: s,
  sampleRateHz: _rate,
  route: route,
  measuredAt: _t0,
);

CaptureQualityReport _assess(
  List<double> s, {
  NoiseFloorCalibration? calibration,
  AudioRouteSnapshot route = _wired,
  DateTime? now,
  bool requireCalibration = true,
  CapturePurpose purpose = CapturePurpose.pitchResponse,
}) => CaptureQualityAssessor.assess(
  samples: s,
  sampleRateHz: _rate,
  route: route,
  now: now ?? _t0.add(const Duration(minutes: 1)),
  calibration: calibration,
  requireCalibration: requireCalibration,
  purpose: purpose,
);

void main() {
  group('RoutePolicy', () {
    test('unknown or inferred routes are unverified, never allowed', () {
      expect(
        RoutePolicy.assess(
          const AudioRouteSnapshot.unknown(),
          CapturePurpose.pitchResponse,
        ),
        RouteDecision.unverified,
      );
      expect(
        RoutePolicy.assess(
          const AudioRouteSnapshot(
            input: AudioRouteKind.builtIn,
            output: AudioRouteKind.wired,
            certainty: RouteCertainty.inferred,
          ),
          CapturePurpose.pitchResponse,
        ),
        RouteDecision.unverified,
      );
    });

    test('loudspeaker pitch is sequential only; guided choir unsupported', () {
      expect(
        RoutePolicy.assess(_speaker, CapturePurpose.pitchResponse),
        RouteDecision.sequentialOnly,
      );
      expect(
        RoutePolicy.assess(_speaker, CapturePurpose.guidedChoirPart),
        RouteDecision.unsupported,
      );
      expect(
        RoutePolicy.assess(_wired, CapturePurpose.guidedChoirPart),
        RouteDecision.allowed,
      );
    });

    test('rhythm always needs a measured latency; bluetooth choir too', () {
      for (final route in [_speaker, _wired]) {
        expect(
          RoutePolicy.assess(route, CapturePurpose.rhythmTap),
          RouteDecision.requiresLatencyCalibration,
        );
      }
      expect(
        RoutePolicy.assess(
          const AudioRouteSnapshot(
            input: AudioRouteKind.builtIn,
            output: AudioRouteKind.bluetooth,
          ),
          CapturePurpose.guidedChoirPart,
        ),
        RouteDecision.requiresLatencyCalibration,
      );
    });
  });

  group('NoiseFloorCalibrator', () {
    test('quiet room calibrates near the synthetic RMS level', () {
      final c = _calibrate(_noise(2, 0.001));
      expect(c.status, NoiseFloorStatus.calibrated);
      expect(c.noiseFloorDb, closeTo(-60, 1.5));
      expect(c.isUsable, isTrue);
      expect(c.toJson()['route'], _wired.toJson());
    });

    test('loud room, speech burst, clipping, short and bad input fail', () {
      expect(_calibrate(_noise(2, 0.05)).status, NoiseFloorStatus.tooNoisy);
      final burst = _noise(2, 0.001);
      final speech = _tone(0.5, 0.3);
      for (var i = 0; i < speech.length; i++) {
        burst[8000 + i] += speech[i];
      }
      final c = _calibrate(burst);
      expect(c.status, NoiseFloorStatus.activityDetected);
      expect(c.isUsable, isFalse);
      final clipped = _noise(2, 0.001)..fillRange(0, 200, 1.0);
      expect(_calibrate(clipped).status, NoiseFloorStatus.clipped);
      expect(_calibrate(_noise(1, 0.001)).status, NoiseFloorStatus.tooShort);
      expect(
        _calibrate(_noise(6, 0.001)).status,
        NoiseFloorStatus.invalidInput,
      );
      expect(
        _calibrate(_noise(2, 0.001)..[5] = double.nan).status,
        NoiseFloorStatus.invalidInput,
      );
    });

    test('calibration is invalid after route/rate change or expiry', () {
      final c = _calibrate(_noise(2, 0.001));
      CalibrationState at(AudioRouteSnapshot r, int rate, Duration age) =>
          c.stateFor(
            currentRoute: r,
            currentSampleRateHz: rate,
            now: _t0.add(age),
          );
      expect(at(_wired, _rate, Duration.zero), CalibrationState.valid);
      expect(at(_speaker, _rate, Duration.zero), CalibrationState.routeChanged);
      expect(
        at(_wired, 48000, Duration.zero),
        CalibrationState.sampleRateChanged,
      );
      expect(
        at(_wired, _rate, const Duration(minutes: 31)),
        CalibrationState.expired,
      );
      expect(
        at(_wired, _rate, const Duration(seconds: -1)),
        CalibrationState.expired,
      );
      expect(
        _calibrate(
          _noise(2, 0.05),
        ).stateFor(currentRoute: _wired, currentSampleRateHz: _rate, now: _t0),
        CalibrationState.missing,
      );
    });
  });

  group('CaptureQualityAssessor', () {
    final floor = _calibrate(_noise(2, 0.001));

    test('clear tone over calibrated floor is usable with measured SNR', () {
      final answer = _mix([
        ..._noise(0.3, 0.001),
        ..._tone(1.5, 0.2),
      ], _noise(1.8, 0.001, seed: 3));
      final r = _assess(answer, calibration: floor);
      expect(r.status, CaptureQualityStatus.usable);
      expect(r.allowsAnalysis, isTrue);
      expect(r.signalToNoiseDb, greaterThan(40));
      expect(r.activeSeconds, closeTo(1.5, 0.05));
      expect(r.activityOnsetSeconds, closeTo(0.3, 0.03));
      expect(r.noiseFloorDb, floor.noiseFloorDb);
      expect(r.toJson()['status'], 'usable');
    });

    test('missing or stale calibration blocks product analysis', () {
      final answer = _tone(1, 0.2);
      expect(_assess(answer).status, CaptureQualityStatus.calibrationRequired);
      final stale = _assess(
        answer,
        calibration: floor,
        now: _t0.add(const Duration(hours: 1)),
      );
      expect(stale.status, CaptureQualityStatus.calibrationRequired);
      expect(stale.calibrationState, CalibrationState.expired);
      expect(stale.allowsAnalysis, isFalse);
      final routeChanged = _assess(
        answer,
        calibration: floor,
        route: const AudioRouteSnapshot(
          input: AudioRouteKind.builtIn,
          output: AudioRouteKind.usb,
        ),
      );
      expect(routeChanged.calibrationState, CalibrationState.routeChanged);
      expect(routeChanged.status, CaptureQualityStatus.calibrationRequired);
    });

    test('lab mode may run uncalibrated but reports no SNR or floor', () {
      final r = _assess(_tone(1, 0.2), requireCalibration: false);
      expect(r.status, CaptureQualityStatus.usable);
      expect(r.calibrationState, CalibrationState.missing);
      expect(r.signalToNoiseDb, isNull);
      expect(r.noiseFloorDb, isNull);
    });

    test('silence, brief blip and low SNR are neutral retries', () {
      final silence = _assess(List.filled(_rate, 0.0), calibration: floor);
      expect(silence.status, CaptureQualityStatus.silent);
      expect(silence.allowsAnalysis, isFalse);
      final blip = _assess([
        ..._noise(0.5, 0.001),
        ..._tone(0.2, 0.2),
        ..._noise(0.5, 0.001),
      ], calibration: floor);
      expect(blip.status, CaptureQualityStatus.insufficientActivity);
      final noisyFloor = _calibrate(_noise(2, 0.004));
      expect(noisyFloor.isUsable, isTrue);
      final weak = _assess(
        _mix(_tone(1.5, 0.03), _noise(1.5, 0.004, seed: 5)),
        calibration: noisyFloor,
      );
      expect(weak.status, CaptureQualityStatus.lowSignalToNoise);
      expect(weak.signalToNoiseDb, lessThan(15));
    });

    test('clipping blocks analysis even when the tone is otherwise clear', () {
      final r = _assess(
        _tone(1, 1.2).map((s) => s.clamp(-1.0, 1.0)).toList(),
        calibration: floor,
      );
      expect(r.status, CaptureQualityStatus.clipped);
      expect(r.clippedSampleRatio, greaterThan(0.001));
    });

    test('early energy on loudspeaker route is a suspected reference tail', () {
      final speakerFloor = _calibrate(_noise(2, 0.001), route: _speaker);
      final immediate = _tone(1.5, 0.2);
      final r = _assess(immediate, calibration: speakerFloor, route: _speaker);
      expect(r.routeDecision, RouteDecision.sequentialOnly);
      expect(r.status, CaptureQualityStatus.suspectedReferenceTail);
      expect(r.allowsAnalysis, isFalse);
      final delayed = _assess(
        [..._noise(0.4, 0.001), ..._tone(1.5, 0.2)],
        calibration: speakerFloor,
        route: _speaker,
      );
      expect(delayed.status, CaptureQualityStatus.usable);
      // Same immediate onset with headphones has no bleed path.
      expect(
        _assess(immediate, calibration: floor).status,
        CaptureQualityStatus.usable,
      );
    });

    test('unsupported route, bad samples and size limits are invalid', () {
      expect(
        _assess(
          _tone(1, 0.2),
          route: _speaker,
          purpose: CapturePurpose.guidedChoirPart,
          requireCalibration: false,
        ).status,
        CaptureQualityStatus.invalidInput,
      );
      expect(
        _assess(
          _tone(1, 0.2)..[10] = double.infinity,
          calibration: floor,
        ).status,
        CaptureQualityStatus.invalidInput,
      );
      expect(
        _assess(_tone(11, 0.2), calibration: floor).status,
        CaptureQualityStatus.invalidInput,
      );
      expect(
        _assess(_tone(0.05, 0.2), calibration: floor).status,
        CaptureQualityStatus.tooShort,
      );
    });
  });

  group('LatencyCalibration', () {
    test('default is not measured and yields no correction', () {
      const l = LatencyCalibration.notMeasured();
      expect(l.isMeasured, isFalse);
      expect(
        l.correctionMsFor(
          currentRoute: _wired,
          currentSampleRateHz: _rate,
          now: _t0,
        ),
        isNull,
      );
    });

    test('measured latency applies only on its own route and rate', () {
      final l = LatencyCalibration.measured(
        latencyMs: 120,
        method: LatencyMethod.tapAlignment,
        sampleCount: 8,
        stamp: CalibrationStamp(
          route: _wired,
          sampleRateHz: _rate,
          measuredAt: _t0,
        ),
      );
      expect(
        l.correctionMsFor(
          currentRoute: _wired,
          currentSampleRateHz: _rate,
          now: _t0,
        ),
        120,
      );
      expect(
        l.correctionMsFor(
          currentRoute: _speaker,
          currentSampleRateHz: _rate,
          now: _t0,
        ),
        isNull,
      );
    });

    test('rejects implausible latency or too few measurements', () {
      final stamp = CalibrationStamp(
        route: _wired,
        sampleRateHz: _rate,
        measuredAt: _t0,
      );
      for (final ms in [-1.0, 501.0, double.nan]) {
        expect(
          () => LatencyCalibration.measured(
            latencyMs: ms,
            method: LatencyMethod.loopback,
            sampleCount: 8,
            stamp: stamp,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => LatencyCalibration.measured(
          latencyMs: 100,
          method: LatencyMethod.loopback,
          sampleCount: 7,
          stamp: stamp,
        ),
        throwsArgumentError,
      );
    });
  });
}
