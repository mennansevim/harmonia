import 'dart:math' as math;

/// AUD-DEV-05 capture-quality and calibration contracts.
///
/// Everything here is ENERGY/route bookkeeping. Activity above a noise floor
/// is not human-voice detection, not voicedRatio and not a student score. All
/// numeric thresholds are pre-registered hypotheses awaiting the labelled
/// device benchmark (AUDIO_TESTING.md); do not tune them by looking at results.

enum AudioRouteKind { builtIn, wired, bluetooth, usb, airPlay, unknown }

/// iOS reports the active route; Android only lists available devices, so a
/// route built from that list is inferred and must not be treated as certain.
enum RouteCertainty { reported, inferred, unknown }

class AudioRouteSnapshot {
  const AudioRouteSnapshot({
    required this.input,
    required this.output,
    this.certainty = RouteCertainty.reported,
  });

  const AudioRouteSnapshot.unknown()
    : input = AudioRouteKind.unknown,
      output = AudioRouteKind.unknown,
      certainty = RouteCertainty.unknown;

  final AudioRouteKind input;
  final AudioRouteKind output;
  final RouteCertainty certainty;

  /// Calibrations are bound to this signature; any change invalidates them.
  String get signature => '${input.name}>${output.name}/${certainty.name}';

  Map<String, Object?> toJson() => {
    'input': input.name,
    'output': output.name,
    'certainty': certainty.name,
  };
}

enum CapturePurpose { pitchResponse, rhythmTap, guidedChoirPart }

enum RouteDecision {
  /// Route is acceptable for this purpose.
  allowed,

  /// Loudspeaker + microphone: reference must finish before the answer window
  /// and early answer-window activity is treated as a possible reference tail.
  sequentialOnly,

  /// Timing depends on an independently measured latency for this route.
  requiresLatencyCalibration,

  /// The purpose cannot be measured honestly on this route.
  unsupported,

  /// Route unknown/inferred: results must carry an unverified-route label.
  unverified,
}

class RoutePolicy {
  const RoutePolicy._();

  static RouteDecision assess(
    AudioRouteSnapshot route,
    CapturePurpose purpose,
  ) {
    if (route.certainty != RouteCertainty.reported ||
        route.input == AudioRouteKind.unknown ||
        route.output == AudioRouteKind.unknown) {
      return RouteDecision.unverified;
    }
    final speaker = route.output == AudioRouteKind.builtIn;
    final wireless =
        route.output == AudioRouteKind.bluetooth ||
        route.output == AudioRouteKind.airPlay;
    switch (purpose) {
      case CapturePurpose.pitchResponse:
        return speaker ? RouteDecision.sequentialOnly : RouteDecision.allowed;
      case CapturePurpose.rhythmTap:
        // Output latency shifts the reference the student hears; wireless
        // latency is variable, so it always needs its own measurement.
        return RouteDecision.requiresLatencyCalibration;
      case CapturePurpose.guidedChoirPart:
        if (speaker) return RouteDecision.unsupported;
        return wireless
            ? RouteDecision.requiresLatencyCalibration
            : RouteDecision.allowed;
    }
  }
}

enum CalibrationState {
  valid,
  missing,
  routeChanged,
  sampleRateChanged,
  expired,
}

/// Shared binding of a calibration to the route/rate/time it was measured in.
class CalibrationStamp {
  CalibrationStamp({
    required this.route,
    required this.sampleRateHz,
    required this.measuredAt,
  }) {
    if (sampleRateHz < 8000 || sampleRateHz > 192000) {
      throw ArgumentError('Invalid calibration sample rate');
    }
  }

  /// Hypothesis: re-check after 30 min; environment noise drifts.
  static const defaultMaxAge = Duration(minutes: 30);

  final AudioRouteSnapshot route;
  final int sampleRateHz;
  final DateTime measuredAt;

  CalibrationState stateFor({
    required AudioRouteSnapshot currentRoute,
    required int currentSampleRateHz,
    required DateTime now,
    Duration maxAge = defaultMaxAge,
  }) {
    if (currentRoute.signature != route.signature) {
      return CalibrationState.routeChanged;
    }
    if (currentSampleRateHz != sampleRateHz) {
      return CalibrationState.sampleRateChanged;
    }
    final age = now.difference(measuredAt);
    if (age.isNegative || age > maxAge) return CalibrationState.expired;
    return CalibrationState.valid;
  }
}

enum NoiseFloorStatus {
  calibrated,
  tooNoisy,
  activityDetected,
  clipped,
  tooShort,
  invalidInput,
}

class NoiseFloorCalibration {
  const NoiseFloorCalibration._({
    required this.status,
    required this.stamp,
    this.noiseFloorDb,
    this.burstDb,
  });

  final NoiseFloorStatus status;
  final CalibrationStamp stamp;

  /// Median 20 ms frame RMS in dBFS. Null unless the input was analyzable.
  final double? noiseFloorDb;

  /// 90th-percentile frame RMS; a large gap to the median means someone
  /// spoke/moved during calibration, so the floor is not trusted.
  final double? burstDb;

  bool get isUsable => status == NoiseFloorStatus.calibrated;

  CalibrationState stateFor({
    required AudioRouteSnapshot currentRoute,
    required int currentSampleRateHz,
    required DateTime now,
  }) => isUsable
      ? stamp.stateFor(
          currentRoute: currentRoute,
          currentSampleRateHz: currentSampleRateHz,
          now: now,
        )
      : CalibrationState.missing;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'version': NoiseFloorCalibrator.version,
    'status': status.name,
    'noiseFloorDb': noiseFloorDb,
    'burstDb': burstDb,
    'sampleRateHz': stamp.sampleRateHz,
    'route': stamp.route.toJson(),
    'measuredAt': stamp.measuredAt.toUtc().toIso8601String(),
  };
}

/// Measures the room with the user asked to stay silent. Bounded O(n).
class NoiseFloorCalibrator {
  const NoiseFloorCalibrator._();

  static const version = 'noise-floor-1';
  static const minSeconds = 1.5;
  static const maxSeconds = 5.0;

  /// Hypotheses pending device benchmark.
  static const maxUsableFloorDb = -45.0;
  static const maxBurstSpreadDb = 12.0;

  static NoiseFloorCalibration measure({
    required List<double> samples,
    required int sampleRateHz,
    required AudioRouteSnapshot route,
    required DateTime measuredAt,
  }) {
    final stamp = CalibrationStamp(
      route: route,
      sampleRateHz: sampleRateHz,
      measuredAt: measuredAt,
    );
    NoiseFloorCalibration result(
      NoiseFloorStatus status, [
      double? floor,
      double? burst,
    ]) => NoiseFloorCalibration._(
      status: status,
      stamp: stamp,
      noiseFloorDb: floor,
      burstDb: burst,
    );
    if (samples.length > sampleRateHz * maxSeconds) {
      return result(NoiseFloorStatus.invalidInput);
    }
    if (!_allFinite(samples)) return result(NoiseFloorStatus.invalidInput);
    if (samples.length < sampleRateHz * minSeconds) {
      return result(NoiseFloorStatus.tooShort);
    }
    if (_clippedRatio(samples) > CaptureQualityAssessor.maxClippedRatio) {
      return result(NoiseFloorStatus.clipped);
    }
    final levels = _frameLevelsDb(samples, sampleRateHz)..sort();
    final floor = _percentile(levels, 0.5);
    final burst = _percentile(levels, 0.9);
    if (burst - floor > maxBurstSpreadDb) {
      return result(NoiseFloorStatus.activityDetected, floor, burst);
    }
    if (floor > maxUsableFloorDb) {
      return result(NoiseFloorStatus.tooNoisy, floor, burst);
    }
    return result(NoiseFloorStatus.calibrated, floor, burst);
  }
}

enum CaptureQualityStatus {
  usable,
  invalidInput,
  tooShort,
  silent,
  insufficientActivity,
  lowSignalToNoise,
  clipped,
  suspectedReferenceTail,
  calibrationRequired,
}

class CaptureQualityReport {
  const CaptureQualityReport._({
    required this.status,
    required this.calibrationState,
    required this.routeDecision,
    this.peakAbs,
    this.clippedSampleRatio,
    this.activeSeconds,
    this.activityOnsetSeconds,
    this.signalToNoiseDb,
    this.noiseFloorDb,
  });

  final CaptureQualityStatus status;
  final CalibrationState calibrationState;
  final RouteDecision routeDecision;
  final double? peakAbs;
  final double? clippedSampleRatio;

  /// Seconds of 20 ms frames above the activity threshold. Energy only: a
  /// cough, speech or reference bleed also counts. NOT voiced time.
  final double? activeSeconds;
  final double? activityOnsetSeconds;

  /// Median active-frame level minus the calibrated floor. Null uncalibrated.
  final double? signalToNoiseDb;
  final double? noiseFloorDb;

  /// Only `usable` may continue to pitch analysis; every other status is a
  /// neutral retry, never a student error or a zero score.
  bool get allowsAnalysis => status == CaptureQualityStatus.usable;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'version': CaptureQualityAssessor.version,
    'status': status.name,
    'calibrationState': calibrationState.name,
    'routeDecision': routeDecision.name,
    'peakAbs': peakAbs,
    'clippedSampleRatio': clippedSampleRatio,
    'activeSeconds': activeSeconds,
    'activityOnsetSeconds': activityOnsetSeconds,
    'signalToNoiseDb': signalToNoiseDb,
    'noiseFloorDb': noiseFloorDb,
  };
}

/// Gate between a captured answer and pitch analysis. Bounded O(n), pure.
class CaptureQualityAssessor {
  const CaptureQualityAssessor._();

  static const version = 'capture-quality-1';
  static const frameMs = 20;
  static const maxSeconds = 10.0;

  /// Hypotheses pending device benchmark (pre-registered, not result-tuned).
  static const maxClippedRatio = 0.001;
  static const clipLevel = 0.999;
  static const activityMarginDb = 10.0;
  static const uncalibratedActivityDb = -45.0;
  static const silenceDb = -60.0;
  static const minActiveSeconds = 0.4;
  static const minSignalToNoiseDb = 15.0;

  /// Faster than a deliberate vocal reaction (~150 ms hypothesis); on a
  /// loudspeaker route such early energy is attributed to the reference tail.
  static const minReactionSeconds = 0.15;

  static CaptureQualityReport assess({
    required List<double> samples,
    required int sampleRateHz,
    required AudioRouteSnapshot route,
    required DateTime now,
    CapturePurpose purpose = CapturePurpose.pitchResponse,
    NoiseFloorCalibration? calibration,
    bool requireCalibration = true,
  }) {
    final routeDecision = RoutePolicy.assess(route, purpose);
    final calibrationState =
        calibration?.stateFor(
          currentRoute: route,
          currentSampleRateHz: sampleRateHz,
          now: now,
        ) ??
        CalibrationState.missing;
    final calibrated = calibrationState == CalibrationState.valid;
    CaptureQualityReport report(
      CaptureQualityStatus status, {
      double? peak,
      double? clipped,
      double? active,
      double? onset,
      double? snr,
    }) => CaptureQualityReport._(
      status: status,
      calibrationState: calibrationState,
      routeDecision: routeDecision,
      peakAbs: peak,
      clippedSampleRatio: clipped,
      activeSeconds: active,
      activityOnsetSeconds: onset,
      signalToNoiseDb: snr,
      noiseFloorDb: calibrated ? calibration!.noiseFloorDb : null,
    );

    if (sampleRateHz < 8000 ||
        sampleRateHz > 192000 ||
        samples.length > sampleRateHz * maxSeconds ||
        !_allFinite(samples)) {
      return report(CaptureQualityStatus.invalidInput);
    }
    final frame = _frameSamples(sampleRateHz);
    if (samples.length < frame * 5) {
      return report(CaptureQualityStatus.tooShort);
    }
    if (routeDecision == RouteDecision.unsupported) {
      return report(CaptureQualityStatus.invalidInput);
    }
    if (requireCalibration && !calibrated) {
      return report(CaptureQualityStatus.calibrationRequired);
    }
    var peak = 0.0;
    for (final s in samples) {
      if (s.abs() > peak) peak = s.abs();
    }
    final clipped = _clippedRatio(samples);
    if (clipped > maxClippedRatio) {
      return report(CaptureQualityStatus.clipped, peak: peak, clipped: clipped);
    }
    final levels = _frameLevelsDb(samples, sampleRateHz);
    final frameSeconds = frame / sampleRateHz;
    final threshold = calibrated
        ? math.max(calibration!.noiseFloorDb! + activityMarginDb, silenceDb)
        : uncalibratedActivityDb;
    final active = <double>[];
    int? onsetFrame;
    for (var i = 0; i < levels.length; i++) {
      if (levels[i] >= threshold) {
        active.add(levels[i]);
        onsetFrame ??= i;
      }
    }
    final activeSeconds = active.length * frameSeconds;
    final onset = onsetFrame == null ? null : onsetFrame * frameSeconds;
    if (levels.every((level) => level < silenceDb)) {
      return report(
        CaptureQualityStatus.silent,
        peak: peak,
        clipped: clipped,
        active: activeSeconds,
      );
    }
    if (active.isEmpty) {
      return report(
        CaptureQualityStatus.insufficientActivity,
        peak: peak,
        clipped: clipped,
        active: activeSeconds,
      );
    }
    active.sort();
    final snr = calibrated
        ? _percentile(active, 0.5) - calibration!.noiseFloorDb!
        : null;
    if (routeDecision == RouteDecision.sequentialOnly &&
        onset! < minReactionSeconds) {
      return report(
        CaptureQualityStatus.suspectedReferenceTail,
        peak: peak,
        clipped: clipped,
        active: activeSeconds,
        onset: onset,
        snr: snr,
      );
    }
    if (activeSeconds < minActiveSeconds) {
      return report(
        CaptureQualityStatus.insufficientActivity,
        peak: peak,
        clipped: clipped,
        active: activeSeconds,
        onset: onset,
        snr: snr,
      );
    }
    if (snr != null && snr < minSignalToNoiseDb) {
      return report(
        CaptureQualityStatus.lowSignalToNoise,
        peak: peak,
        clipped: clipped,
        active: activeSeconds,
        onset: onset,
        snr: snr,
      );
    }
    return report(
      CaptureQualityStatus.usable,
      peak: peak,
      clipped: clipped,
      active: activeSeconds,
      onset: onset,
      snr: snr,
    );
  }
}

enum LatencyMethod { loopback, tapAlignment }

/// Independently measured output→input latency. The default is NOT measured;
/// callers must not substitute zero or silently shift answers.
class LatencyCalibration {
  const LatencyCalibration.notMeasured()
    : latencyMs = null,
      method = null,
      sampleCount = 0,
      stamp = null;

  LatencyCalibration.measured({
    required double this.latencyMs,
    required LatencyMethod this.method,
    required this.sampleCount,
    required CalibrationStamp this.stamp,
  }) {
    if (!latencyMs!.isFinite || latencyMs! < 0 || latencyMs! > maxLatencyMs) {
      throw ArgumentError('Latency outside 0–$maxLatencyMs ms');
    }
    if (sampleCount < minSamples) {
      throw ArgumentError('Latency needs at least $minSamples measurements');
    }
  }

  static const maxLatencyMs = 500.0;
  static const minSamples = 8;

  final double? latencyMs;
  final LatencyMethod? method;
  final int sampleCount;
  final CalibrationStamp? stamp;

  bool get isMeasured => latencyMs != null;

  /// Returns the correction only for the route/rate it was measured on.
  double? correctionMsFor({
    required AudioRouteSnapshot currentRoute,
    required int currentSampleRateHz,
    required DateTime now,
  }) =>
      isMeasured &&
          stamp!.stateFor(
                currentRoute: currentRoute,
                currentSampleRateHz: currentSampleRateHz,
                now: now,
              ) ==
              CalibrationState.valid
      ? latencyMs
      : null;
}

int _frameSamples(int sampleRateHz) =>
    (sampleRateHz * CaptureQualityAssessor.frameMs / 1000).round();

bool _allFinite(List<double> samples) {
  for (final s in samples) {
    if (!s.isFinite || s.abs() > 1) return false;
  }
  return true;
}

double _clippedRatio(List<double> samples) {
  if (samples.isEmpty) return 0;
  var clipped = 0;
  for (final s in samples) {
    if (s.abs() >= CaptureQualityAssessor.clipLevel) clipped++;
  }
  return clipped / samples.length;
}

/// Non-overlapping 20 ms frames; a trailing partial frame is ignored only if
/// shorter than half a frame, otherwise measured on its own length.
List<double> _frameLevelsDb(List<double> samples, int sampleRateHz) {
  final frame = _frameSamples(sampleRateHz);
  final levels = <double>[];
  for (var start = 0; start < samples.length; start += frame) {
    final end = math.min(start + frame, samples.length);
    if (end - start < frame ~/ 2) break;
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += samples[i] * samples[i];
    }
    final rms = math.sqrt(sum / (end - start));
    levels.add(rms <= 1e-6 ? -120.0 : 20 * math.log(rms) / math.ln10);
  }
  return levels;
}

double _percentile(List<double> sorted, double q) =>
    sorted[((sorted.length - 1) * q).floor()];
