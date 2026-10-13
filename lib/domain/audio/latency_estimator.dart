import 'dart:math' as math;

import '../models/measurement_provenance.dart';
import 'capture_quality.dart';

/// Scheduled playback time is not the time audio was physically heard.
enum LatencyClockBasis { observedSharedClock, scheduledPlayback, unknown }

enum LatencyEstimateStatus {
  stableEstimate,
  insufficientTrials,
  invalidInput,
  unsupportedClock,
  unverifiedRoute,
  bindingMismatch,
  unstable,
}

/// Explicitly paired independent calibration events, never student answers.
/// The adapter must establish event pairing and a common monotonic clock.
class LatencyTrial {
  const LatencyTrial({
    required this.referenceTimestampUs,
    required this.responseTimestampUs,
    required this.referenceClockId,
    required this.responseClockId,
    required this.routeSignature,
    required this.sampleRateHz,
  });
  final int referenceTimestampUs, responseTimestampUs;
  final String referenceClockId, responseClockId, routeSignature;
  final int sampleRateHz;
}

/// Experimental diagnostic only. Not a LatencyCalibration and intentionally
/// has no conversion/correction method: no device evidence has been collected.
/// Tap alignment includes human motor bias; it cannot identify hardware delay.
class LatencyEstimate {
  LatencyEstimate._({
    required this.status,
    required this.method,
    required this.source,
    required this.stamp,
    required this.clockBasis,
    required this.trialCount,
    required List<int> rejectedTrialIndices,
    this.rawMedianMs,
    this.rawMadMs,
    this.rawCentralSpreadMs,
    this.retainedMedianMs,
  }) : rejectedTrialIndices = List.unmodifiable(rejectedTrialIndices);

  final LatencyEstimateStatus status;
  final LatencyMethod method;
  final MeasurementSource source;
  final CalibrationStamp stamp;
  final LatencyClockBasis clockBasis;
  final int trialCount;
  final List<int> rejectedTrialIndices;
  final double? rawMedianMs, rawMadMs, rawCentralSpreadMs, retainedMedianMs;
  int? get retainedTrialCount =>
      rawMedianMs == null ? null : trialCount - rejectedTrialIndices.length;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'version': LatencyEstimator.version,
    'status': status.name,
    'method': method.name,
    'source': source.name,
    'clockBasis': clockBasis.name,
    'trialCount': trialCount,
    'retainedTrialCount': retainedTrialCount,
    'rejectedTrialIndices': rejectedTrialIndices,
    'rawMedianMs': rawMedianMs,
    'rawMadMs': rawMadMs,
    'rawCentralSpreadMs': rawCentralSpreadMs,
    'retainedMedianMs': retainedMedianMs,
    'route': stamp.route.toJson(),
    'sampleRateHz': stamp.sampleRateHz,
    'measuredAt': stamp.measuredAt.toUtc().toIso8601String(),
    'correctionEnabled': false,
  };
}

/// CAL-03a bounded statistics, not capture, onset detection or device validation.
/// Thresholds are pre-registered hypotheses, not changes to student rubrics.
class LatencyEstimator {
  const LatencyEstimator._();
  static const version = 'latency-diagnostic-1/defaults-1';
  static const maxTrials = 64;
  static const minTrials = LatencyCalibration.minSamples;
  static const maxOffsetMs = LatencyCalibration.maxLatencyMs;
  static const maxRejectedFraction = 0.25;
  static const maxCentralSpreadMs = 20.0;
  static const maxMadMs = 5.0;
  static const minimumOutlierDistanceMs = 10.0;
  // Exact integer range also safe for a future JS consumer.
  static const maxTimestampUs = 9007199254740991;

  static LatencyEstimate estimate({
    required List<LatencyTrial> trials,
    required CalibrationStamp stamp,
    required LatencyMethod method,
    required MeasurementSource source,
    required LatencyClockBasis clockBasis,
  }) {
    LatencyEstimate report(
      LatencyEstimateStatus status, {
      List<int> rejected = const [],
      double? median,
      double? mad,
      double? spread,
      double? retained,
    }) => LatencyEstimate._(
      status: status,
      method: method,
      source: source,
      stamp: stamp,
      clockBasis: clockBasis,
      trialCount: trials.length,
      rejectedTrialIndices: rejected,
      rawMedianMs: median,
      rawMadMs: mad,
      rawCentralSpreadMs: spread,
      retainedMedianMs: retained,
    );
    // Check count before traversing or copying untrusted input.
    if (trials.length > maxTrials) {
      return report(LatencyEstimateStatus.invalidInput);
    }
    if (clockBasis != LatencyClockBasis.observedSharedClock) {
      return report(LatencyEstimateStatus.unsupportedClock);
    }
    if (stamp.route.certainty != RouteCertainty.reported ||
        stamp.route.input == AudioRouteKind.unknown ||
        stamp.route.output == AudioRouteKind.unknown) {
      return report(LatencyEstimateStatus.unverifiedRoute);
    }
    final offsets = <double>[];
    String? clockId;
    int? previousReference, previousResponse;
    for (final trial in trials) {
      final reference = trial.referenceTimestampUs;
      final response = trial.responseTimestampUs;
      if (reference < 0 ||
          reference > maxTimestampUs ||
          response < 0 ||
          response > maxTimestampUs ||
          (previousReference != null && reference <= previousReference) ||
          (previousResponse != null && response <= previousResponse)) {
        return report(LatencyEstimateStatus.invalidInput);
      }
      if (!_validClockId(trial.referenceClockId) ||
          trial.referenceClockId != trial.responseClockId ||
          (clockId != null && trial.referenceClockId != clockId)) {
        return report(LatencyEstimateStatus.unsupportedClock);
      }
      if (trial.routeSignature != stamp.route.signature ||
          trial.sampleRateHz != stamp.sampleRateHz) {
        return report(LatencyEstimateStatus.bindingMismatch);
      }
      final offset = (response - reference) / 1000.0;
      // Never trim malformed/anticipatory trials into a trusted clean prefix.
      if (offset < 0 || offset > maxOffsetMs) {
        return report(LatencyEstimateStatus.invalidInput);
      }
      offsets.add(offset);
      clockId = trial.referenceClockId;
      previousReference = reference;
      previousResponse = response;
    }
    if (offsets.length < minTrials) {
      return report(LatencyEstimateStatus.insufficientTrials);
    }
    final sorted = [...offsets]..sort();
    final median = _median(sorted);
    final deviations = [for (final offset in offsets) (offset - median).abs()]
      ..sort();
    final mad = _median(deviations);
    final spread = _quantile(sorted, 0.9) - _quantile(sorted, 0.1);
    final distance = math.max(minimumOutlierDistanceMs, 3 * 1.4826 * mad);
    final rejected = <int>[];
    final kept = <double>[];
    for (var i = 0; i < offsets.length; i++) {
      if ((offsets[i] - median).abs() > distance) {
        rejected.add(i);
      } else {
        kept.add(offsets[i]);
      }
    }
    // Stability uses the RAW distribution, not a sanitized post-trim spread.
    final stable =
        kept.length >= minTrials &&
        rejected.length / offsets.length <= maxRejectedFraction &&
        mad <= maxMadMs &&
        spread <= maxCentralSpreadMs;
    kept.sort();
    return report(
      stable
          ? LatencyEstimateStatus.stableEstimate
          : LatencyEstimateStatus.unstable,
      rejected: rejected,
      median: median,
      mad: mad,
      spread: spread,
      retained: stable ? _median(kept) : null,
    );
  }
}

bool _validClockId(String value) =>
    RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(value);
double _median(List<double> sorted) => sorted.length.isOdd
    ? sorted[sorted.length ~/ 2]
    : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
double _quantile(List<double> sorted, double q) {
  final position = (sorted.length - 1) * q;
  final lo = position.floor(), hi = position.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (position - lo);
}
