import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/audio_lab_controller.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/infrastructure/audio/isolate_recording_pitch_worker.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';
import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
RecordingPitchEvidence result() => RecordingPitchAnalyzer().analyze(
  samples: List.filled(8000, 0),
  sampleRateHz: 8000,
  source: MeasurementSource.mock,
);
void main() {
  late FakeAudioLabBackend backend;
  late FakeRecordingPitchWorker worker;
  late AudioLabController controller;
  bool disposed = false;
  setUp(() {
    disposed = false;
    backend = FakeAudioLabBackend();
    worker = FakeRecordingPitchWorker();
    controller = AudioLabController(backend, worker: worker);
  });
  tearDown(() async {
    await controller.shutdown();
    if (!disposed) controller.dispose();
  });
  Future<void> record() async {
    await controller.startRecording();
    await controller.stopRecording();
  }

  test(
    'explicit analysis retains mock origin and never runs at capture end',
    () async {
      await record();
      expect(worker.calls, 0);
      await controller.analyzeRecording();
      expect(worker.receivedSource, MeasurementSource.mock);
      expect(controller.diagnostics!.provenance.source, MeasurementSource.mock);
      expect(controller.diagnostics!.representativeFrequencyHz, isNull);
      expect(controller.phase, AudioLabPhase.recorded);
      expect(controller.canAnalyze, isTrue);
    },
  );
  test(
    'delete finishes without waiting for DSP; stale result cannot revive recording',
    () async {
      await record();
      worker.gate = Completer();
      final analysis = controller.analyzeRecording();
      await flush();
      await controller.cancel();
      expect(controller.recording, isNull);
      expect(controller.analysisInFlight, isTrue);
      await record();
      expect(controller.canAnalyze, isFalse);
      await controller.analyzeRecording();
      expect(worker.calls, 1);
      worker.gate!.complete(result());
      await analysis;
      expect(controller.diagnostics, isNull);
      expect(controller.phase, AudioLabPhase.recorded);
      expect(controller.canAnalyze, isTrue);
    },
  );
  test('duplicate analyze starts one worker', () async {
    await record();
    worker.gate = Completer();
    final first = controller.analyzeRecording();
    await flush();
    await controller.analyzeRecording();
    expect(worker.calls, 1);
    worker.gate!.complete(result());
    await first;
  });
  test('delete during file load never starts worker', () async {
    await record();
    backend.readGate = Completer();
    final analysis = controller.analyzeRecording();
    await flush();
    final cancel = controller.cancel();
    backend.readGate!.complete(
      CapturedAudioSamples(
        sampleRateHz: 44100,
        samples: List.filled(44100, 0),
        source: MeasurementSource.mock,
      ),
    );
    await analysis;
    await cancel;
    expect(worker.calls, 0);
    expect(controller.analysisInFlight, isFalse);
    expect(controller.phase, AudioLabPhase.idle);
  });
  test('load failure preserves recording and permits retry/replay', () async {
    await record();
    backend.readFailure = const FormatException('bad');
    await controller.analyzeRecording();
    expect(controller.analysisError, AudioLabAnalysisError.unsupportedInput);
    expect(controller.recording, isNotNull);
    expect(controller.canAnalyze, isTrue);
    await controller.playRecording();
    expect(controller.phase, AudioLabPhase.recordingPlaying);
  });
  test(
    'mismatched metadata and over budget recordings never reach worker',
    () async {
      for (final captured in [
        CapturedAudio(sampleRateHz: 96000, sampleCount: 96000),
        CapturedAudio(sampleRateHz: 48000, sampleCount: 48000 * 11),
        CapturedAudio(sampleRateHz: 44100, sampleCount: 44100),
      ]) {
        backend.captured = captured;
        await record();
        if (captured.sampleRateHz == 44100) {
          backend.readGate = Completer()
            ..complete(
              CapturedAudioSamples(
                sampleRateHz: 8000,
                samples: List.filled(8000, 0),
                source: MeasurementSource.mock,
              ),
            );
        }
        await controller.analyzeRecording();
        expect(
          controller.analysisError,
          AudioLabAnalysisError.unsupportedInput,
        );
        expect(controller.recording, isNotNull);
        expect(worker.calls, 0);
      }
    },
  );
  test('worker error preserves recording and releases busy', () async {
    await record();
    worker.failure = StateError('worker failed');
    await controller.analyzeRecording();
    expect(controller.analysisError, AudioLabAnalysisError.unavailable);
    expect(controller.canAnalyze, isTrue);
    expect(controller.recording, isNotNull);
  });
  test(
    'route interruption discards analysis; late error is consumed',
    () async {
      await record();
      worker.gate = Completer();
      final analysis = controller.analyzeRecording();
      await flush();
      backend.events.add(AudioLabInterruption.routeChanged);
      await flush();
      expect(controller.phase, AudioLabPhase.idle);
      worker.gate!.completeError(StateError('late'));
      await analysis;
      expect(controller.analysisError, isNull);
      expect(controller.diagnostics, isNull);
    },
  );
  test('shutdown does not wait for DSP or publish after dispose', () async {
    await record();
    worker.gate = Completer();
    final analysis = controller.analyzeRecording();
    await flush();
    await controller.shutdown();
    controller.dispose();
    disposed = true;
    worker.gate!.complete(result());
    await analysis;
    expect(controller.phase, AudioLabPhase.closed);
    expect(controller.diagnostics, isNull);
  });
  test('PCM snapshot is immutable', () {
    final input = <double>[0];
    final pcm = CapturedAudioSamples(
      sampleRateHz: 8000,
      samples: input,
      source: MeasurementSource.mock,
    );
    input[0] = 1;
    expect(pcm.samples.single, 0);
    expect(() => pcm.samples[0] = 1, throwsUnsupportedError);
  });
  test(
    'synthetic WAV snapshot reaches real native worker without changing origin',
    () async {
      final wav = Pcm16Wav.decode(
        Pcm16Wav.tone(frequencyHz: 440, sampleRateHz: 8000).encode(),
      );
      final nativeBackend = FakeAudioLabBackend()
        ..captured = CapturedAudio(
          sampleRateHz: wav.sampleRateHz,
          sampleCount: wav.samples.length,
        )
        ..readGate = (Completer<CapturedAudioSamples>()
          ..complete(
            CapturedAudioSamples(
              sampleRateHz: wav.sampleRateHz,
              samples: wav.samples,
              source: MeasurementSource.synthetic,
            ),
          ));
      final nativeController = AudioLabController(
        nativeBackend,
        worker: IsolateRecordingPitchWorker(),
      );
      try {
        await nativeController.startRecording();
        await nativeController.stopRecording();
        await nativeController.analyzeRecording();
        final diagnostic = nativeController.diagnostics!;
        expect(diagnostic.status, RecordingPitchStatus.periodicSignalObserved);
        expect(diagnostic.representativeFrequencyHz, closeTo(440, 2));
        expect(diagnostic.provenance.source, MeasurementSource.synthetic);
      } finally {
        await nativeController.shutdown();
        nativeController.dispose();
      }
    },
  );
  test('playback failure also clears previous diagnostic evidence', () async {
    await record();
    await controller.analyzeRecording();
    expect(controller.diagnostics, isNotNull);
    await controller.playRecording();
    backend.playbackEnd.completeError(StateError('playback failed'));
    await flush();
    expect(controller.phase, AudioLabPhase.error);
    expect(controller.diagnostics, isNull);
    expect(controller.recording, isNull);
  });
}
