import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/chord_reference_session.dart';
import 'package:resonia/application/chord_response_capture_session.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

import '../support/fake_audio_lab_backend.dart';

class _Player implements ReferenceClipPlayer {
  _Player(this.timeline);
  final List<String> timeline;
  Completer<void> completed = Completer<void>();

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    timeline.add('reference');
    return PlaybackHandle(completed.future);
  }

  @override
  Future<void> stop() async => timeline.add('reference-stop');

  @override
  Future<void> close() async => timeline.add('reference-close');
}

class _Backend extends FakeAudioLabBackend {
  _Backend(this.timeline);
  final List<String> timeline;

  void nextClip(List<double> samples, {required int sampleRateHz}) {
    recordedSamples = samples;
    captured = CapturedAudio(
      sampleRateHz: sampleRateHz,
      sampleCount: samples.length,
    );
  }

  @override
  Future<bool> requestMicrophonePermission() async {
    timeline.add('permission');
    return super.requestMicrophonePermission();
  }

  @override
  Future<void> startCapture() async {
    timeline.add('capture-start');
    return super.startCapture();
  }

  @override
  Future<CapturedAudio> stopCapture() async {
    timeline.add('capture-stop');
    return super.stopCapture();
  }

  @override
  Future<CapturedAudioSamples> readRecording() async {
    timeline.add('capture-read');
    return super.readRecording();
  }

  @override
  Future<void> discardCapture() async {
    timeline.add('capture-discard');
    return super.discardCapture();
  }
}

class _RoutedBackend extends _Backend implements AudioRouteProbe {
  _RoutedBackend(super.timeline);

  AudioRouteSnapshot route = const AudioRouteSnapshot(
    input: AudioRouteKind.builtIn,
    output: AudioRouteKind.wired,
  );

  @override
  Future<AudioRouteSnapshot> currentRoute() async {
    timeline.add('route');
    return route;
  }
}

ReviewedChordRecording _recording() => ReviewedChordRecording(
  id: 'triad-c-major',
  voiceCount: 3,
  relativePath: '3-notes/triad-c-major.wav',
  targetMidiNotes: const [60, 64, 67],
  sha256: 'a' * 64,
  sampleRateHz: 48000,
  channels: 1,
  sampleFrames: 96000,
  a4Hz: 440,
  rightsReference: 'rights/user-recorded',
  labelReviewReference: 'reviews/triad-c-major',
);

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late List<String> timeline;
  late _Player player;
  late _Backend backend;
  late ChordReferenceSession reference;
  late ChordResponseCaptureSession session;

  setUp(() {
    timeline = [];
    player = _Player(timeline);
    backend = _Backend(timeline);
    reference = ChordReferenceSession(
      recording: _recording(),
      wavBytes: const [1, 2, 3],
      player: player,
      maxReferencePlays: 2,
      wait: (_) async {},
    );
    session = ChordResponseCaptureSession(
      reference: reference,
      backend: backend,
      wait: (_) async {},
    );
  });

  tearDown(() async {
    try {
      await session.close();
    } catch (_) {
      // Explicit cleanup-failure tests.
    }
    session.dispose();
  });

  Future<void> makeReady() async {
    final run = session.playReference();
    await _tick();
    player.completed.complete();
    await run;
    expect(session.phase, ChordResponseCapturePhase.readyForResponse);
  }

  test(
    'does nothing until explicit listen and asks permission first',
    () async {
      expect(timeline, isEmpty);
      expect(session.canStartResponse, isFalse);

      final run = session.playReference();
      await _tick();
      expect(timeline.take(3), ['capture-discard', 'permission', 'reference']);
      expect(session.canStartResponse, isFalse);
      player.completed.complete();
      await run;

      expect(session.canStartResponse, isTrue);
      expect(backend.capturing, isFalse);
    },
  );

  test(
    'explicit room calibration snapshots silence and deletes native clip',
    () async {
      await session.close();
      session.dispose();
      final routed = _RoutedBackend(timeline);
      backend = routed;
      reference = ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [1, 2, 3],
        player: player,
        maxReferencePlays: 2,
        wait: (_) async {},
      );
      final measuredAt = DateTime.utc(2026, 10, 29, 1);
      session = ChordResponseCaptureSession(
        reference: reference,
        backend: backend,
        wait: (_) async {},
        clock: () => measuredAt,
      );
      routed.nextClip(List<double>.filled(32000, 0.0001), sampleRateHz: 16000);

      await session.calibrateEnvironment();

      expect(session.phase, ChordResponseCapturePhase.calibrationReady);
      expect(session.calibration?.isUsable, isTrue);
      expect(session.calibration?.stamp.measuredAt, measuredAt);
      expect(
        session.calibration?.stamp.route.signature,
        'builtIn>wired/reported',
      );
      expect(timeline.sublist(timeline.length - 7), [
        'capture-discard',
        'permission',
        'route',
        'capture-start',
        'capture-stop',
        'capture-read',
        'capture-discard',
      ]);
      expect(timeline.where((item) => item == 'reference'), isEmpty);
      expect(backend.capturing, isFalse);
    },
  );

  test(
    'noisy calibration is a neutral retry and never plays reference',
    () async {
      await session.close();
      session.dispose();
      final routed = _RoutedBackend(timeline);
      backend = routed;
      reference = ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [1, 2, 3],
        player: player,
        wait: (_) async {},
      );
      session = ChordResponseCaptureSession(
        reference: reference,
        backend: backend,
        wait: (_) async {},
      );
      routed.nextClip(List<double>.filled(32000, 0.02), sampleRateHz: 16000);

      await session.calibrateEnvironment();

      expect(session.phase, ChordResponseCapturePhase.failed);
      expect(session.failure, ChordResponseCaptureFailure.calibrationRejected);
      expect(session.calibration?.status, NoiseFloorStatus.tooNoisy);
      expect(session.canCalibrateEnvironment, isTrue);
      expect(timeline.where((item) => item == 'reference'), isEmpty);
    },
  );

  test('calibration permission denial never opens capture', () async {
    backend.permission = false;

    await session.calibrateEnvironment();

    expect(session.failure, ChordResponseCaptureFailure.permissionDenied);
    expect(backend.calls.where((call) => call == 'start'), isEmpty);
    expect(session.calibration, isNull);
  });

  test('invalid calibration metadata abstains after deleting clip', () async {
    backend.captured = CapturedAudio(sampleRateHz: 16000, sampleCount: 32000);
    backend.recordedSamples = List<double>.filled(31999, 0.0001);

    await session.calibrateEnvironment();

    expect(session.failure, ChordResponseCaptureFailure.calibrationUnavailable);
    expect(session.calibration, isNull);
    expect(backend.calls.where((call) => call == 'discard'), hasLength(2));
    expect(backend.capturing, isFalse);
  });

  test(
    'interruption invalidates calibration attempt without auto resume',
    () async {
      final waiting = Completer<void>();
      await session.close();
      session.dispose();
      backend = _Backend(timeline)
        ..nextClip(List<double>.filled(88200, 0.0001), sampleRateHz: 44100);
      reference = ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [1, 2, 3],
        player: player,
        wait: (_) async {},
      );
      session = ChordResponseCaptureSession(
        reference: reference,
        backend: backend,
        wait: (_) => waiting.future,
      );

      final calibration = session.calibrateEnvironment();
      await _tick();
      expect(session.phase, ChordResponseCapturePhase.calibrating);
      backend.events.add(AudioLabInterruption.routeChanged);
      await _tick();
      waiting.complete();
      await calibration;
      await _tick();

      expect(session.failure, ChordResponseCaptureFailure.interrupted);
      expect(session.calibration, isNull);
      expect(backend.capturing, isFalse);
    },
  );

  test(
    'successful calibration survives reference and permission is reused',
    () async {
      backend.nextClip(List<double>.filled(88200, 0.0001), sampleRateHz: 44100);
      await session.calibrateEnvironment();
      expect(session.calibration?.isUsable, isTrue);

      final listen = session.playReference();
      await _tick();
      player.completed.complete();
      await listen;

      expect(session.phase, ChordResponseCapturePhase.readyForResponse);
      expect(session.calibration?.isUsable, isTrue);
      expect(timeline.where((item) => item == 'permission'), hasLength(1));
    },
  );

  test('permission denial never plays reference or starts capture', () async {
    backend.permission = false;
    await session.playReference();

    expect(session.failure, ChordResponseCaptureFailure.permissionDenied);
    expect(timeline, ['capture-discard', 'permission']);
    expect(backend.capturing, isFalse);
  });

  test('capture is gated until full reference and recall completion', () async {
    final listen = session.playReference();
    await _tick();
    await session.startResponse();
    expect(backend.calls.where((call) => call == 'start'), isEmpty);

    player.completed.complete();
    await listen;
    await session.startResponse();
    expect(session.phase, ChordResponseCapturePhase.capturing);
    expect(backend.capturing, isTrue);
  });

  test(
    'stop snapshots immutable PCM then discards backend recording',
    () async {
      backend.nextClip([0.1, 0.2, 0.3], sampleRateHz: 16000);
      await makeReady();
      await session.startResponse();
      await session.stopResponse();

      expect(session.phase, ChordResponseCapturePhase.captured);
      expect(session.response?.recordingId, 'triad-c-major');
      expect(session.response?.route.signature, contains('unknown'));
      expect(session.response?.samples.samples, [0.1, 0.2, 0.3]);
      backend.recordedSamples![0] = 0.9;
      expect(session.response?.samples.samples, [0.1, 0.2, 0.3]);
      expect(timeline.sublist(timeline.indexOf('capture-stop')), [
        'capture-stop',
        'capture-read',
        'capture-discard',
      ]);
      expect(backend.capturing, isFalse);
    },
  );

  test('replay revokes readiness and never overlaps capture', () async {
    await makeReady();
    player.completed = Completer<void>();

    final replay = session.playReference();
    await _tick();
    expect(session.canStartResponse, isFalse);
    await session.startResponse();
    expect(backend.calls.where((call) => call == 'start'), isEmpty);
    player.completed.complete();
    await replay;
    expect(session.canStartResponse, isTrue);
  });

  test(
    'invalid capture metadata abstains after deleting native clip',
    () async {
      backend.captured = CapturedAudio(sampleRateHz: 16000, sampleCount: 3);
      backend.readGate = Completer<CapturedAudioSamples>()
        ..complete(
          CapturedAudioSamples(
            sampleRateHz: 16000,
            samples: const [0.1, 0.2],
            source: MeasurementSource.mock,
          ),
        );

      await makeReady();
      await session.startResponse();
      await session.stopResponse();

      expect(session.phase, ChordResponseCapturePhase.failed);
      expect(session.failure, ChordResponseCaptureFailure.invalidCapture);
      expect(session.response, isNull);
      expect(backend.calls.where((call) => call == 'discard'), hasLength(2));
      expect(backend.capturing, isFalse);
    },
  );

  test(
    'interruption cancels capture and clears response without resume',
    () async {
      await makeReady();
      await session.startResponse();
      backend.events.add(AudioLabInterruption.audioFocusLost);
      await _tick();
      await _tick();

      expect(session.failure, ChordResponseCaptureFailure.interrupted);
      expect(session.response, isNull);
      expect(backend.capturing, isFalse);
      expect(reference.canStartSequentialResponse, isFalse);
    },
  );

  test('cancel waits for a pending native start then discards it', () async {
    await makeReady();
    backend.startGate = Completer<void>();

    final starting = session.startResponse();
    await _tick();
    final cancelling = session.cancel();
    expect(backend.capturing, isTrue);
    backend.startGate!.complete();
    await starting;
    await cancelling;

    expect(session.phase, ChordResponseCapturePhase.idle);
    expect(session.response, isNull);
    expect(backend.capturing, isFalse);
    expect(reference.canStartSequentialResponse, isFalse);
  });

  test(
    'cleanup failure blocks the attempt without playing reference',
    () async {
      backend.cleanupFails = true;

      await session.playReference();

      expect(session.phase, ChordResponseCapturePhase.failed);
      expect(session.failure, ChordResponseCaptureFailure.cleanupFailed);
      expect(timeline.where((item) => item == 'reference'), isEmpty);
      expect(session.canStartResponse, isFalse);
      expect(session.canPlayReference, isFalse);
      backend.cleanupFails = false;
    },
  );

  test('close owns reference and capture resources exactly once', () async {
    final close = session.close();
    expect(session.close(), same(close));
    await close;

    expect(session.phase, ChordResponseCapturePhase.closed);
    expect(timeline.where((item) => item == 'reference-close'), hasLength(1));
    expect(backend.calls.where((item) => item == 'close'), hasLength(1));
  });
}
