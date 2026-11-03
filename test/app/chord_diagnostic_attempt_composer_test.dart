import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/chord_diagnostic_attempt_composer.dart';
import 'package:resonia/application/chord_response_attempt_coordinator.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/infrastructure/audio/reviewed_chord_recording_loader.dart';

import '../support/fake_audio_lab_backend.dart';

class _Player implements ReferenceClipPlayer {
  final calls = <String>[];

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    calls.add('play');
    return PlaybackHandle(Future<void>.value());
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> close() async => calls.add('close');
}

class _Worker implements RecordingPitchWorker {
  int calls = 0;

  @override
  Future<RecordingPitchEvidence> analyze({
    required List<double> samples,
    required int sampleRateHz,
    MeasurementSource source = MeasurementSource.unverified,
  }) async {
    calls++;
    return RecordingPitchAnalyzer().analyze(
      samples: samples,
      sampleRateHz: sampleRateHz,
      source: source,
    );
  }
}

class _UnreadableBackend implements AudioLabBackend {
  final calls = <String>[];
  final events = StreamController<AudioLabInterruption>.broadcast();

  @override
  Stream<AudioLabInterruption> get interruptions => events.stream;

  @override
  Future<void> close() async {
    calls.add('close');
    await events.close();
  }

  @override
  Future<void> discardCapture() async => calls.add('discard');

  @override
  Future<PlaybackHandle> playRecording() async =>
      PlaybackHandle(Future<void>.value());

  @override
  Future<PlaybackHandle> playReference() async =>
      PlaybackHandle(Future<void>.value());

  @override
  Future<bool> requestMicrophonePermission() async => true;

  @override
  Future<void> startCapture() async {}

  @override
  Future<CapturedAudio> stopCapture() async =>
      CapturedAudio(sampleRateHz: 16000, sampleCount: 16000);

  @override
  Future<void> stopPlayback() async {}
}

LoadedChordRecording _loaded() => LoadedChordRecording(
  recording: ReviewedChordRecording(
    id: 'reviewed-c-major',
    voiceCount: 3,
    relativePath: '3-notes/reviewed-c-major.wav',
    targetMidiNotes: const [60, 64, 67],
    sha256: 'a' * 64,
    sampleRateHz: 48000,
    channels: 1,
    sampleFrames: 96000,
    a4Hz: 440,
    rightsReference: 'rights/user-recorded',
    labelReviewReference: 'reviews/reviewed-c-major',
  ),
  header: const ChordWavHeader(
    sampleRateHz: 48000,
    channels: 1,
    sampleFrames: 96000,
  ),
  bytes: Uint8List.fromList(const [82, 73, 70, 70, 1]),
);

void main() {
  test('builds one owned attempt without starting player or backend', () async {
    final player = _Player();
    final backend = FakeRoutedAudioLabBackend();
    final worker = _Worker();
    final coordinator =
        await ChordDiagnosticAttemptComposer(
          createPlayer: () async => player,
          createBackend: () async => backend,
          createWorker: () => worker,
        ).create(
          loaded: _loaded(),
          mode: ExerciseMode.recallExam,
          responseOrder: ResponseOrder.anyOrder,
          wait: (_) async {},
        );

    expect(coordinator.phase, ChordResponseAttemptPhase.idle);
    expect(coordinator.responseOrder, ResponseOrder.anyOrder);
    expect(coordinator.session.recording.id, 'reviewed-c-major');
    expect(coordinator.session.reference.targetVisibleDuringResponse, isFalse);
    expect(player.calls, isEmpty);
    expect(backend.calls, isEmpty);
    expect(worker.calls, 0);

    await coordinator.close();
    expect(player.calls, ['stop', 'close']);
    expect(backend.calls, containsAllInOrder(['discard', 'close']));
  });

  test('rejects invalid policy before allocating native resources', () async {
    var playerCalls = 0;
    var backendCalls = 0;
    var workerCalls = 0;
    final composer = ChordDiagnosticAttemptComposer(
      createPlayer: () async {
        playerCalls++;
        return _Player();
      },
      createBackend: () async {
        backendCalls++;
        return FakeAudioLabBackend();
      },
      createWorker: () {
        workerCalls++;
        return _Worker();
      },
    );

    await expectLater(
      composer.create(
        loaded: _loaded(),
        mode: ExerciseMode.recallExam,
        maxReferencePlays: 2,
      ),
      throwsArgumentError,
    );
    await expectLater(
      composer.create(loaded: _loaded(), toleranceCents: double.nan),
      throwsArgumentError,
    );
    expect([playerCalls, backendCalls, workerCalls], [0, 0, 0]);
  });

  test('backend factory failure releases the allocated player', () async {
    final player = _Player();
    final composer = ChordDiagnosticAttemptComposer(
      createPlayer: () async => player,
      createBackend: () async => throw StateError('capture unavailable'),
      createWorker: _Worker.new,
    );

    await expectLater(composer.create(loaded: _loaded()), throwsStateError);
    expect(player.calls, ['stop', 'close']);
  });

  test(
    'backend without PCM reader is rejected and all resources close',
    () async {
      final player = _Player();
      final backend = _UnreadableBackend();
      final composer = ChordDiagnosticAttemptComposer(
        createPlayer: () async => player,
        createBackend: () async => backend,
        createWorker: _Worker.new,
      );

      await expectLater(composer.create(loaded: _loaded()), throwsStateError);
      expect(backend.calls, ['close']);
      expect(player.calls, ['stop', 'close']);
    },
  );

  test('worker construction failure closes capture ownership chain', () async {
    final player = _Player();
    final backend = FakeAudioLabBackend();
    final composer = ChordDiagnosticAttemptComposer(
      createPlayer: () async => player,
      createBackend: () async => backend,
      createWorker: () => throw StateError('worker unavailable'),
    );

    await expectLater(composer.create(loaded: _loaded()), throwsStateError);
    expect(player.calls, ['stop', 'close']);
    expect(backend.calls, containsAllInOrder(['discard', 'close']));
  });
}
