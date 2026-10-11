import 'dart:async';
import 'package:harmonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';

class FakeRecordingPitchWorker implements RecordingPitchWorker {
  int calls = 0;
  Completer<RecordingPitchEvidence>? gate;
  Object? failure;
  MeasurementSource? receivedSource;
  @override
  Future<RecordingPitchEvidence> analyze({
    required List<double> samples,
    required int sampleRateHz,
    MeasurementSource source = MeasurementSource.unverified,
  }) async {
    calls++;
    receivedSource = source;
    if (failure != null) throw failure!;
    return gate == null
        ? RecordingPitchAnalyzer().analyze(
            samples: samples,
            sampleRateHz: sampleRateHz,
            source: source,
          )
        : await gate!.future;
  }
}
