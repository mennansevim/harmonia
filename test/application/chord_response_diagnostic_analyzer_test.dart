import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/chord_response_capture_session.dart';
import 'package:resonia/application/chord_response_diagnostic_analyzer.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/audio/chord_response_matcher.dart';
import 'package:resonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;
final _now = DateTime.utc(2026, 10, 28, 12);
const _route = AudioRouteSnapshot(
  input: AudioRouteKind.builtIn,
  output: AudioRouteKind.wired,
);

double _hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

List<double> _tone(int midi, double seconds, {double amplitude = 0.2}) =>
    List.generate(
      (_rate * seconds).round(),
      (i) => amplitude * math.sin(2 * math.pi * _hz(midi) * i / _rate),
    );

List<double> _response(List<int> notes) => [
  ...List<double>.filled((_rate * 0.2).round(), 0),
  for (final note in notes) ...[
    ..._tone(note, 0.55),
    ...List<double>.filled((_rate * 0.16).round(), 0),
  ],
];

ReviewedChordRecording _recording({List<int> notes = const [60, 67]}) =>
    ReviewedChordRecording(
      id: 'dyad-c-g',
      voiceCount: notes.length,
      relativePath: '${notes.length}-notes/dyad-c-g.wav',
      targetMidiNotes: notes,
      sha256: 'a' * 64,
      sampleRateHz: 48000,
      channels: 1,
      sampleFrames: 96000,
      a4Hz: 440,
      rightsReference: 'rights/user-recorded',
      labelReviewReference: 'reviews/dyad-c-g',
    );

ChordResponseCapture _capture(
  List<double> samples, {
  AudioRouteSnapshot route = _route,
  MeasurementSource source = MeasurementSource.synthetic,
}) => ChordResponseCapture(
  recording: _recording(),
  metadata: CapturedAudio(sampleRateHz: _rate, sampleCount: samples.length),
  route: route,
  samples: CapturedAudioSamples(
    sampleRateHz: _rate,
    samples: samples,
    source: source,
  ),
);

NoiseFloorCalibration _calibration({AudioRouteSnapshot route = _route}) =>
    NoiseFloorCalibrator.measure(
      samples: List<double>.filled(_rate * 2, 0.0001),
      sampleRateHz: _rate,
      route: route,
      measuredAt: _now,
    );

void main() {
  late FakeRecordingPitchWorker worker;
  late ChordResponseDiagnosticAnalyzer analyzer;

  setUp(() {
    worker = FakeRecordingPitchWorker();
    analyzer = ChordResponseDiagnosticAnalyzer(
      worker: worker,
      clock: () => _now.add(const Duration(minutes: 1)),
    );
  });

  test('missing calibration abstains before worker or matcher', () async {
    final result = await analyzer.analyze(
      capture: _capture(_response(const [60, 67])),
      calibration: null,
    );

    expect(result.status, ChordResponseDiagnosticStatus.qualityRejected);
    expect(result.quality.status, CaptureQualityStatus.calibrationRequired);
    expect(result.pitch, isNull);
    expect(result.comparison, isNull);
    expect(worker.calls, 0);
  });

  test('route-mismatched calibration abstains before DSP', () async {
    final result = await analyzer.analyze(
      capture: _capture(_response(const [60, 67])),
      calibration: _calibration(
        route: const AudioRouteSnapshot(
          input: AudioRouteKind.builtIn,
          output: AudioRouteKind.usb,
        ),
      ),
    );

    expect(result.status, ChordResponseDiagnosticStatus.qualityRejected);
    expect(result.quality.calibrationState, CalibrationState.routeChanged);
    expect(worker.calls, 0);
  });

  test('usable exact response reaches diagnostic comparison', () async {
    final result = await analyzer.analyze(
      capture: _capture(_response(const [60, 67])),
      calibration: _calibration(),
    );

    expect(result.status, ChordResponseDiagnosticStatus.diagnosticAvailable);
    expect(result.quality.status, CaptureQualityStatus.usable);
    expect(result.comparison?.status, ChordResponseStatus.candidatesCompared);
    expect(result.comparison?.diagnosticCandidateMatch, isTrue);
    expect(result.hasCandidateComparison, isTrue);
    expect(worker.calls, 1);
    expect(worker.receivedSource, MeasurementSource.synthetic);
  });

  test(
    'any-order preserves reverse response as set-only candidate match',
    () async {
      final result = await analyzer.analyze(
        capture: _capture(_response(const [67, 60])),
        calibration: _calibration(),
        responseOrder: ResponseOrder.anyOrder,
      );

      expect(result.comparison?.diagnosticCandidateMatch, isTrue);
      expect(result.comparison?.reorderedTargetCandidates, isTrue);
      expect(result.comparison?.responseOrder, ResponseOrder.anyOrder);
    },
  );

  test('silent capture is a neutral quality rejection', () async {
    final result = await analyzer.analyze(
      capture: _capture(List<double>.filled(_rate, 0)),
      calibration: _calibration(),
    );

    expect(result.status, ChordResponseDiagnosticStatus.qualityRejected);
    expect(result.quality.status, CaptureQualityStatus.silent);
    expect(worker.calls, 0);
  });

  test(
    'worker failure is unavailable, never a failed learner response',
    () async {
      worker.failure = StateError('/private/native-worker');
      final result = await analyzer.analyze(
        capture: _capture(_response(const [60, 67])),
        calibration: _calibration(),
      );

      expect(result.status, ChordResponseDiagnosticStatus.analysisUnavailable);
      expect(result.quality.status, CaptureQualityStatus.usable);
      expect(result.pitch, isNull);
      expect(result.comparison, isNull);
    },
  );

  test('worker cannot promote capture provenance', () async {
    final samples = _response(const [60, 67]);
    worker.gate = Completer<RecordingPitchEvidence>()
      ..complete(
        RecordingPitchAnalyzer().analyze(
          samples: samples,
          sampleRateHz: _rate,
          source: MeasurementSource.microphone,
        ),
      );

    final result = await analyzer.analyze(
      capture: _capture(samples, source: MeasurementSource.synthetic),
      calibration: _calibration(),
    );

    expect(result.status, ChordResponseDiagnosticStatus.analysisUnavailable);
    expect(result.pitch, isNull);
    expect(result.comparison, isNull);
  });
}
