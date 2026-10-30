import 'dart:isolate';

import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../domain/models/measurement_provenance.dart';

/// Native VM only; no silent main-isolate fallback for web/worker failures.
/// One request at a time per instance, with bounded input copied before await.
/// No IO, upload, microphone, scoring or automatic source classification.
///
/// No hard cancellation yet: the eventual session owner must invalidate stale
/// results via an epoch. Isolate.run finishes/exits on completion or error.
class IsolateRecordingPitchWorker implements RecordingPitchWorker {
  bool _running = false;

  @override
  Future<RecordingPitchEvidence> analyze({
    required List<double> samples,
    required int sampleRateHz,
    MeasurementSource source = MeasurementSource.unverified,
  }) async {
    if (_running) throw StateError('Recording analysis already running');
    _running = true;
    try {
      // Never copy/transfer a recording outside the domain budget.
      if (sampleRateHz < 8000 ||
          sampleRateHz > 48000 ||
          samples.length >
              sampleRateHz * RecordingPitchAnalyzer.maxDurationSeconds) {
        return RecordingPitchAnalyzer().analyze(
          samples: samples,
          sampleRateHz: sampleRateHz,
          source: source,
        );
      }
      final snapshot = List<double>.unmodifiable(samples);
      return await _runSnapshot(snapshot, sampleRateHz, source);
    } finally {
      _running = false;
    }
  }
}

// Separate scope keeps plugin/UI/worker instance state out of closure capture.
Future<RecordingPitchEvidence> _runSnapshot(
  List<double> samples,
  int sampleRateHz,
  MeasurementSource source,
) => Isolate.run(
  () => RecordingPitchAnalyzer().analyze(
    samples: samples,
    sampleRateHz: sampleRateHz,
    source: source,
  ),
  debugName: 'resonia-recording-pitch',
);
