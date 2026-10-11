import 'dart:math' as math;

import '../models/measurement_provenance.dart';
import 'yin_pitch_frame_analyzer.dart';

enum RecordingPitchStatus {
  invalidInput,
  insufficientData,
  noPeriodicSignal,
  periodicSignalObserved,
}

/// Async execution boundary for native DSP; fake workers can drive later
/// session/cancel tests without invoking a microphone or a native isolate.
abstract class RecordingPitchWorker {
  Future<RecordingPitchEvidence> analyze({
    required List<double> samples,
    required int sampleRateHz,
    MeasurementSource source = MeasurementSource.unverified,
  });
}

class RecordingPitchFrame {
  const RecordingPitchFrame._({
    required this.startSample,
    required this.sampleCount,
    required this.estimate,
  });

  final int startSample;
  final int sampleCount;
  final PitchFrameEstimate estimate;

  Map<String, Object?> toJson() => {
    'startSample': startSample,
    'sampleCount': sampleCount,
    'status': estimate.status.name,
    'frequencyHz': estimate.frequencyHz,
    'rmsDb': estimate.rmsDb,
    'periodicity': estimate.periodicity,
  };
}

/// Local diagnostics, not an ExerciseResult, VAD decision or success score.
/// PCM is not retained. Overlapping frame counts are NOT independent trials.
class RecordingPitchEvidence {
  RecordingPitchEvidence._({
    required this.status,
    required this.sampleRateHz,
    required this.sampleCount,
    required this.frameSize,
    required this.hopSize,
    required this.provenance,
    required List<RecordingPitchFrame> frames,
    required Map<PitchFrameStatus, int> frameCounts,
    this.representativeFrequencyHz,
    this.pitchDispersionCents,
  }) : frames = List.unmodifiable(frames),
       frameCounts = Map.unmodifiable(frameCounts);

  final RecordingPitchStatus status;
  final int sampleRateHz;
  final int sampleCount;
  final int frameSize;
  final int hopSize;
  final MeasurementProvenance provenance;
  final List<RecordingPitchFrame> frames;
  final Map<PitchFrameStatus, int> frameCounts;

  /// Lower median of observed Hz: never invent a midpoint between two octaves.
  /// A representative is not proof of one note; inspect frames and dispersion.
  final double? representativeFrequencyHz;

  /// Population std-dev of log2 Hz in cents across accepted periodic frames.
  /// Null with fewer than two. NOT voice stability, timing or memory evidence.
  final double? pitchDispersionCents;

  /// Count-based ratio over ALL analyzed full frames, including silence,
  /// clipped and unreliable. NOT voicedRatio, elapsed-time coverage or VAD.
  double? get periodicFrameRatio => frames.isEmpty
      ? null
      : frameCounts[PitchFrameStatus.pitched]! / frames.length;

  /// Explicit export only: does not upload or feed AI/progress automatically.
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'status': status.name,
    'sampleRateHz': sampleRateHz,
    'sampleCount': sampleCount,
    'frameSize': frameSize,
    'hopSize': hopSize,
    'provenance': provenance.toJson(),
    'representativeFrequencyHz': representativeFrequencyHz,
    'pitchDispersionCents': pitchDispersionCents,
    'periodicFrameRatio': periodicFrameRatio,
    'frameCounts': {
      for (final entry in frameCounts.entries) entry.key.name: entry.value,
    },
    'frames': [for (final frame in frames) frame.toJson()],
  };
}

/// Fixed-config, bounded synchronous recording diagnostics. Deliberately does
/// NOT implement PitchAnalyzer: periodicFrameRatio cannot become voicedRatio.
/// Schedule in a worker isolate before connecting to capture or UI.
class RecordingPitchAnalyzer {
  static const version =
      'recording-pitch-evidence-1/yin-frame-experimental-1/defaults-1';
  static const maxDurationSeconds = 10;
  static const maxFrames = 512;

  RecordingPitchEvidence analyze({
    required List<double> samples,
    required int sampleRateHz,
    MeasurementSource source = MeasurementSource.unverified,
  }) {
    final provenance = MeasurementProvenance(
      source: source,
      analyzerVersion: version,
    );
    RecordingPitchEvidence empty(RecordingPitchStatus status, {int size = 0}) =>
        RecordingPitchEvidence._(
          status: status,
          sampleRateHz: sampleRateHz,
          sampleCount: samples.length,
          frameSize: size,
          hopSize: size ~/ 2,
          provenance: provenance,
          frames: const [],
          frameCounts: {
            for (final status in PitchFrameStatus.values) status: 0,
          },
        );

    // Check duration/rate before traversing or copying input. This is a local
    // laboratory budget, not a limit on future Plus/sequence recording length.
    if (sampleRateHz < 8000 ||
        sampleRateHz > 48000 ||
        samples.length > sampleRateHz * maxDurationSeconds) {
      return empty(RecordingPitchStatus.invalidInput);
    }
    // Validate the ENTIRE recording before any DSP, including the final tail.
    // A bad late sample cannot turn a clean prefix into trusted evidence.
    for (final sample in samples) {
      if (!sample.isFinite || sample.abs() > 1) {
        return empty(RecordingPitchStatus.invalidInput);
      }
    }
    final detector = YinPitchFrameAnalyzer();
    final size = detector.recommendedFrameSamples(sampleRateHz);
    if (samples.length < size) {
      return empty(RecordingPitchStatus.insufficientData, size: size);
    }
    final hop = size ~/ 2;
    final lastStart = samples.length - size;
    final gridCount = lastStart ~/ hop + 1;
    final extraTail = lastStart % hop != 0;
    if (gridCount + (extraTail ? 1 : 0) > maxFrames) {
      return empty(RecordingPitchStatus.invalidInput, size: size);
    }
    final starts = <int>[
      for (var start = 0; start <= lastStart; start += hop) start,
    ];
    // End-anchor one additional full window when needed; no zero padding,
    // duplicated start, incomplete window or silently discarded tail.
    if (extraTail) starts.add(lastStart);
    final counts = {for (final status in PitchFrameStatus.values) status: 0};
    final frames = <RecordingPitchFrame>[];
    final frequencies = <double>[];
    for (final start in starts) {
      final estimate = detector.analyze(
        samples.sublist(start, start + size),
        sampleRateHz: sampleRateHz,
      );
      counts[estimate.status] = counts[estimate.status]! + 1;
      frames.add(
        RecordingPitchFrame._(
          startSample: start,
          sampleCount: size,
          estimate: estimate,
        ),
      );
      if (estimate.status == PitchFrameStatus.pitched) {
        frequencies.add(estimate.frequencyHz!);
      }
    }
    double? representative;
    double? dispersion;
    if (frequencies.isNotEmpty) {
      frequencies.sort();
      representative = frequencies[(frequencies.length - 1) ~/ 2];
      if (frequencies.length >= 2) {
        // Welford's population variance on log frequency; raw octave shifts
        // contribute ~1200 cents instead of vanishing through pitch-class fold.
        var mean = 0.0;
        var m2 = 0.0;
        var count = 0;
        for (final hz in frequencies) {
          final cents = 1200 * math.log(hz) / math.ln2;
          count++;
          final delta = cents - mean;
          mean += delta / count;
          m2 += delta * (cents - mean);
        }
        dispersion = math.sqrt(math.max(0, m2 / count));
      }
    }
    return RecordingPitchEvidence._(
      status: frequencies.isEmpty
          ? RecordingPitchStatus.noPeriodicSignal
          : RecordingPitchStatus.periodicSignalObserved,
      sampleRateHz: sampleRateHz,
      sampleCount: samples.length,
      frameSize: size,
      hopSize: hop,
      provenance: provenance,
      frames: frames,
      frameCounts: counts,
      representativeFrequencyHz: representative,
      pitchDispersionCents: dispersion,
    );
  }
}
