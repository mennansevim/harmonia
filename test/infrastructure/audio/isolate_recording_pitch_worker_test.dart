import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/infrastructure/audio/isolate_recording_pitch_worker.dart';

List<double> tone() =>
    List.generate(1600, (i) => 0.25 * math.sin(2 * math.pi * 440 * i / 8000));

void main() {
  test(
    'native worker produces identical evidence to the synchronous core',
    () async {
      final samples = tone();
      final worker = IsolateRecordingPitchWorker();
      final result = await worker.analyze(
        samples: samples,
        sampleRateHz: 8000,
        source: MeasurementSource.synthetic,
      );
      final expected = RecordingPitchAnalyzer().analyze(
        samples: samples,
        sampleRateHz: 8000,
        source: MeasurementSource.synthetic,
      );
      expect(jsonEncode(result.toJson()), jsonEncode(expected.toJson()));
      expect(() => result.frames.clear(), throwsUnsupportedError);
      expect(() => result.frameCounts.clear(), throwsUnsupportedError);
    },
  );
  test(
    'input snapshot is taken before caller can mutate pending PCM',
    () async {
      final samples = tone();
      final worker = IsolateRecordingPitchWorker();
      final pending = worker.analyze(samples: samples, sampleRateHz: 8000);
      samples.fillRange(0, samples.length, 0);
      final result = await pending;
      expect(result.status, RecordingPitchStatus.periodicSignalObserved);
      expect(result.representativeFrequencyHz, closeTo(440, 2));
      expect(result.provenance.source, MeasurementSource.unverified);
    },
  );
  test(
    'one worker rejects concurrent requests then accepts a later request',
    () async {
      final worker = IsolateRecordingPitchWorker();
      final pending = worker.analyze(samples: tone(), sampleRateHz: 8000);
      await expectLater(
        worker.analyze(samples: tone(), sampleRateHz: 8000),
        throwsStateError,
      );
      await pending;
      final next = await worker.analyze(
        samples: List.filled(1600, 0),
        sampleRateHz: 8000,
      );
      expect(next.status, RecordingPitchStatus.noPeriodicSignal);
    },
  );
  test(
    'invalid domain input does not become an invented success or stuck worker',
    () async {
      final worker = IsolateRecordingPitchWorker();
      for (final input in [
        <double>[double.nan],
        List<double>.filled(80001, 0),
      ]) {
        final result = await worker.analyze(samples: input, sampleRateHz: 8000);
        expect(result.status, RecordingPitchStatus.invalidInput);
        expect(result.frames, isEmpty);
      }
      expect(
        (await worker.analyze(samples: [], sampleRateHz: 96000)).status,
        RecordingPitchStatus.invalidInput,
      );
      expect(
        (await worker.analyze(samples: tone(), sampleRateHz: 8000)).status,
        RecordingPitchStatus.periodicSignalObserved,
      );
    },
  );
}
