import 'dart:math' as math;

enum PitchFrameStatus {
  pitched,
  silence,
  insufficientData,
  invalidInput,
  clipped,
  unreliable,
}

/// Diagnostic evidence only: a periodic signal is not necessarily a singer.
/// This frame is neither a voiced-ratio measurement nor an exercise score.
class PitchFrameEstimate {
  const PitchFrameEstimate._({
    required this.status,
    this.frequencyHz,
    this.rmsDb,
    this.periodicity = 0,
  });

  final PitchFrameStatus status;
  final double? frequencyHz;
  final double? rmsDb;

  /// 1 - CMNDF at the selected integer lag; NOT probability of correct pitch,
  /// human voice, or passing an exercise. Zero when no candidate is accepted.
  final double periodicity;
}

/// Experimental, target-independent YIN-style difference/CMNDF frame core.
/// Uses threshold + local minimum + parabolic lag interpolation; omits YIN's
/// best-local-estimate search and temporal tracking. No fallback guesses.
///
/// Synchronous bounded computation; the caller must schedule off the UI isolate
/// before integrating capture. No resampling, VAD, source inference or scoring.
class YinPitchFrameAnalyzer {
  YinPitchFrameAnalyzer({
    this.minFrequencyHz = 50,
    this.maxFrequencyHz = 2000,
    this.silenceDb = -50,
    this.differenceThreshold = 0.15,
    this.maxClippedRatio = 0.01,
  }) {
    if (!minFrequencyHz.isFinite ||
        !maxFrequencyHz.isFinite ||
        minFrequencyHz < 40 ||
        maxFrequencyHz > 2000 ||
        minFrequencyHz >= maxFrequencyHz ||
        !silenceDb.isFinite ||
        silenceDb < -120 ||
        silenceDb > -10 ||
        !differenceThreshold.isFinite ||
        differenceThreshold <= 0 ||
        differenceThreshold > 0.3 ||
        !maxClippedRatio.isFinite ||
        maxClippedRatio < 0 ||
        maxClippedRatio > 0.05) {
      throw ArgumentError('Invalid experimental frame configuration');
    }
  }

  static const version = 'yin-frame-experimental-1';
  static const maxFrameSamples = 8192;
  final double minFrequencyHz;
  final double maxFrequencyHz;
  final double silenceDb;
  final double differenceThreshold;
  final double maxClippedRatio;

  /// Three periods at the lowest configured frequency, plus interpolation room.
  int minimumFrameSamples(int sampleRateHz) {
    _validateRate(sampleRateHz);
    return (3 * sampleRateHz / minFrequencyHz).ceil() + 2;
  }

  int recommendedFrameSamples(int sampleRateHz) {
    final minimum = minimumFrameSamples(sampleRateHz);
    var size = 1;
    while (size < minimum) {
      size *= 2;
    }
    return size;
  }

  void _validateRate(int sampleRateHz) {
    if (sampleRateHz < 8000 || sampleRateHz > 48000) {
      throw ArgumentError.value(sampleRateHz, 'sampleRateHz', '8–48 kHz only');
    }
  }

  PitchFrameEstimate analyze(
    List<double> samples, {
    required int sampleRateHz,
  }) {
    // Validate bounds before reading or allocating for an untrusted buffer.
    if (sampleRateHz < 8000 ||
        sampleRateHz > 48000 ||
        samples.length > maxFrameSamples) {
      return const PitchFrameEstimate._(status: PitchFrameStatus.invalidInput);
    }
    var sum = 0.0;
    var clipped = 0;
    for (final sample in samples) {
      if (!sample.isFinite || sample.abs() > 1) {
        return const PitchFrameEstimate._(
          status: PitchFrameStatus.invalidInput,
        );
      }
      sum += sample;
      if (sample.abs() >= 0.999) clipped++;
    }
    if (samples.length < minimumFrameSamples(sampleRateHz)) {
      return const PitchFrameEstimate._(
        status: PitchFrameStatus.insufficientData,
      );
    }
    final mean = sum / samples.length;
    final centered = List<double>.generate(
      samples.length,
      (i) => samples[i] - mean,
      growable: false,
    );
    var energy = 0.0;
    for (final sample in centered) {
      energy += sample * sample;
    }
    // Finite dB floor: zero/DC never becomes -Infinity in serialized evidence.
    final rms = math.sqrt(energy / samples.length);
    final rmsDb = rms <= 1e-6
        ? -120.0
        : math.max(-120.0, 20 * math.log(rms) / math.ln10);
    if (clipped / samples.length > maxClippedRatio) {
      return PitchFrameEstimate._(
        status: PitchFrameStatus.clipped,
        rmsDb: rmsDb,
      );
    }
    if (rmsDb <= silenceDb) {
      return PitchFrameEstimate._(
        status: PitchFrameStatus.silence,
        rmsDb: rmsDb,
      );
    }

    // One guard bin on either side permits interpolation at band boundaries.
    final minLag = math.max(2, (sampleRateHz / maxFrequencyHz).floor());
    final maxLag = (sampleRateHz / minFrequencyHz).ceil();
    final window = samples.length - maxLag - 1;
    final normalized = List<double>.filled(maxLag + 2, 1);
    var cumulative = 0.0;
    for (var lag = 1; lag <= maxLag + 1; lag++) {
      var difference = 0.0;
      for (var i = 0; i < window; i++) {
        final delta = centered[i] - centered[i + lag];
        difference += delta * delta;
      }
      cumulative += difference;
      normalized[lag] = cumulative > 0 ? difference * lag / cumulative : 1;
    }
    for (var lag = minLag; lag <= maxLag; lag++) {
      if (normalized[lag] >= differenceThreshold) continue;
      while (lag < maxLag && normalized[lag + 1] < normalized[lag]) {
        lag++;
      }
      final left = normalized[lag - 1];
      final middle = normalized[lag];
      final right = normalized[lag + 1];
      final denominator = left - 2 * middle + right;
      final adjustment = denominator > 0
          ? ((left - right) / (2 * denominator)).clamp(-0.5, 0.5)
          : 0.0;
      final frequency = sampleRateHz / (lag + adjustment);
      // Do not search a later octave to force an out-of-band candidate in-band.
      if (frequency < minFrequencyHz || frequency > maxFrequencyHz) break;
      return PitchFrameEstimate._(
        status: PitchFrameStatus.pitched,
        frequencyHz: frequency,
        rmsDb: rmsDb,
        periodicity: (1 - middle).clamp(0.0, 1.0),
      );
    }
    return PitchFrameEstimate._(
      status: PitchFrameStatus.unreliable,
      rmsDb: rmsDb,
    );
  }
}
