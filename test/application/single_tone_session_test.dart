import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/single_tone_session.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/audio/capture_quality.dart';
import 'package:harmonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;
const _c4 = 261.63;

List<double> _noise(double seconds, {double rms = 0.001, int seed = 5}) {
  var state = seed;
  final amp = rms * math.sqrt(3);
  return List.generate((seconds * _rate).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return amp * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _tone(double seconds, double hz) => List.generate(
  (seconds * _rate).round(),
  (i) => 0.2 * math.sin(2 * math.pi * hz * i / _rate),
);

List<double> _answer(double hz) => [..._noise(0.3), ..._tone(1.2, hz)];

Future<void> _settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeRoutedAudioLabBackend backend;
  late FakeRecordingPitchWorker worker;
  late SingleToneSessionController session;
  var now = DateTime.utc(2026, 10, 11, 12);

  SingleToneSessionController build({
    Duration window = const Duration(milliseconds: 5),
  }) => SingleToneSessionController(
    backend: backend,
    worker: worker,
    targetHz: _c4,
    responseDelay: const Duration(milliseconds: 1),
    responseWindow: window,
    calibrationDuration: const Duration(milliseconds: 1),
    clock: () => now,
  );

  setUp(() {
    now = DateTime.utc(2026, 10, 11, 12);
    backend = FakeRoutedAudioLabBackend();
    worker = FakeRecordingPitchWorker();
    session = build();
  });
  tearDown(() async {
    await session.close();
    session.dispose();
  });

  Future<void> calibrate() async {
    backend.nextClip(_noise(2));
    await session.calibrate();
    expect(session.calibration!.isUsable, isTrue);
    expect(session.phase, SingleToneSessionPhase.idle);
  }

  Future<SingleToneSessionOutcome> attempt(List<double> answer) async {
    backend.nextClip(answer);
    final run = session.startAttempt();
    await _settle(5);
    backend.playbackEnd.complete();
    await run;
    return session.outcome!;
  }

  test('without calibration nothing plays or records', () async {
    await session.startAttempt();
    expect(
      session.outcome!.retryReason,
      SessionRetryReason.calibrationRequired,
    );
    expect(backend.calls, isNot(contains('permission')));
    expect(backend.calls, isNot(contains('reference')));
    expect(SingleToneSessionOutcome.scoringEnabled, isFalse);
  });

  test('capture opens only after the reference ends; raw answer deleted '
      'before analysis', () async {
    await calibrate();
    backend.calls.clear();
    worker.gate = Completer();
    backend.nextClip(_answer(_c4));
    final run = session.startAttempt();
    await _settle(5);
    expect(session.phase, SingleToneSessionPhase.referencePlaying);
    expect(backend.calls, isNot(contains('start')));
    backend.playbackEnd.complete();
    await _settle();
    expect(session.phase, SingleToneSessionPhase.analyzing);
    final order = backend.calls;
    expect(
      order.sublist(order.indexOf('reference')),
      containsAllInOrder(['reference', 'start', 'stop', 'read', 'discard']),
    );
    expect(order.last, 'discard');
    worker.gate!.complete(
      RecordingPitchAnalyzer().analyze(
        samples: _answer(_c4),
        sampleRateHz: _rate,
        source: MeasurementSource.mock,
      ),
    );
    await run;
    final o = session.outcome!;
    expect(o.needsRetry, isFalse);
    expect(o.quality!.status, CaptureQualityStatus.usable);
    expect(o.deviation!.absoluteCents.abs(), lessThan(20));
  });

  test(
    'wrong octave keeps its octave offset; nothing is marked success',
    () async {
      await calibrate();
      final o = await attempt(_answer(_c4 / 2));
      expect(o.needsRetry, isFalse);
      expect(o.deviation!.octaveOffset, -1);
      expect(o.deviation!.absoluteCents, closeTo(-1200, 20));
    },
  );

  test('silent answer is a neutral quality retry; worker never runs', () async {
    await calibrate();
    final o = await attempt(_noise(1.5));
    expect(o.retryReason, SessionRetryReason.quality);
    expect(o.quality!.status, CaptureQualityStatus.insufficientActivity);
    expect(o.evidence, isNull);
    expect(worker.calls, 0);
    expect(backend.calls.last, 'discard');
  });

  test('loudspeaker: immediate energy is a suspected reference tail', () async {
    backend.route = const AudioRouteSnapshot(
      input: AudioRouteKind.builtIn,
      output: AudioRouteKind.builtIn,
    );
    await calibrate();
    final o = await attempt(_tone(1.5, _c4));
    expect(o.routeDecision, RouteDecision.sequentialOnly);
    expect(o.quality!.status, CaptureQualityStatus.suspectedReferenceTail);
    expect(worker.calls, 0);
  });

  test(
    'route change or expiry after calibration requires recalibration',
    () async {
      await calibrate();
      backend.route = const AudioRouteSnapshot(
        input: AudioRouteKind.builtIn,
        output: AudioRouteKind.bluetooth,
      );
      await session.startAttempt();
      expect(
        session.outcome!.retryReason,
        SessionRetryReason.calibrationRequired,
      );
      backend.route = const AudioRouteSnapshot(
        input: AudioRouteKind.builtIn,
        output: AudioRouteKind.wired,
      );
      now = now.add(const Duration(minutes: 31));
      await session.startAttempt();
      expect(
        session.outcome!.retryReason,
        SessionRetryReason.calibrationRequired,
      );
    },
  );

  test('sample-rate change is caught by the quality gate', () async {
    await calibrate();
    backend.nextClip(
      List.generate(
        48000,
        (i) => 0.2 * math.sin(2 * math.pi * _c4 * i / 48000),
      ),
      sampleRateHz: 48000,
    );
    final run = session.startAttempt();
    await _settle(5);
    backend.playbackEnd.complete();
    await run;
    final o = session.outcome!;
    expect(o.retryReason, SessionRetryReason.quality);
    expect(o.quality!.calibrationState, CalibrationState.sampleRateChanged);
    expect(o.quality!.status, CaptureQualityStatus.calibrationRequired);
    expect(worker.calls, 0);
  });

  test('permission denial stops before the reference plays', () async {
    await calibrate();
    backend.calls.clear();
    backend.permission = false;
    await session.startAttempt();
    expect(session.outcome!.retryReason, SessionRetryReason.permissionDenied);
    expect(backend.calls, isNot(contains('reference')));
  });

  test(
    'cancel during a reference that never completes returns to idle',
    () async {
      await calibrate();
      backend.calls.clear();
      final run = session.startAttempt();
      await _settle(5);
      expect(session.phase, SingleToneSessionPhase.referencePlaying);
      await session.cancel();
      await run;
      expect(session.phase, SingleToneSessionPhase.idle);
      expect(session.outcome, isNull);
      expect(backend.calls, isNot(contains('start')));
      expect(backend.calls, containsAllInOrder(['stopPlayback', 'discard']));
    },
  );

  test('interruption while answering discards and reports neutrally', () async {
    final s = build(window: const Duration(seconds: 5));
    backend.nextClip(_noise(2));
    await s.calibrate();
    backend.nextClip(_answer(_c4));
    final run = s.startAttempt();
    await _settle(5);
    backend.playbackEnd.complete();
    await _settle();
    expect(s.phase, SingleToneSessionPhase.responding);
    backend.events.add(AudioLabInterruption.routeChanged);
    await run;
    await _settle();
    expect(s.outcome!.retryReason, SessionRetryReason.interrupted);
    expect(backend.capturing, isFalse);
    expect(worker.calls, 0);
    await s.close();
    s.dispose();
  });

  test('finishResponse ends the answer window early', () async {
    final s = build(window: const Duration(seconds: 9));
    backend.nextClip(_noise(2));
    await s.calibrate();
    backend.nextClip(_answer(_c4));
    final run = s.startAttempt();
    await _settle(5);
    backend.playbackEnd.complete();
    await _settle();
    expect(s.canFinishResponse, isTrue);
    s.finishResponse();
    await run.timeout(const Duration(seconds: 1));
    expect(s.outcome!.needsRetry, isFalse);
    await s.close();
    s.dispose();
  });

  test('late worker result after interruption cannot publish', () async {
    await calibrate();
    worker.gate = Completer();
    backend.nextClip(_answer(_c4));
    final run = session.startAttempt();
    await _settle(5);
    backend.playbackEnd.complete();
    await _settle();
    expect(session.phase, SingleToneSessionPhase.analyzing);
    backend.events.add(AudioLabInterruption.audioFocusLost);
    await _settle();
    expect(session.outcome!.retryReason, SessionRetryReason.interrupted);
    expect(session.canStart, isFalse, reason: 'bounded worker still busy');
    worker.gate!.complete(
      RecordingPitchAnalyzer().analyze(
        samples: _answer(_c4),
        sampleRateHz: _rate,
      ),
    );
    await run;
    expect(session.outcome!.retryReason, SessionRetryReason.interrupted);
    expect(session.outcome!.evidence, isNull);
    expect(session.canStart, isTrue);
  });

  test('worker failure is an analysis retry, not a score', () async {
    await calibrate();
    worker.failure = StateError('isolate died');
    final o = await attempt(_answer(_c4));
    expect(o.retryReason, SessionRetryReason.analysisFailed);
    expect(o.quality!.allowsAnalysis, isTrue);
  });

  test('metadata mismatch or capture error fails closed', () async {
    await calibrate();
    backend.stopFailure = const FormatException('bad wav');
    final o = await attempt(_answer(_c4));
    expect(o.retryReason, SessionRetryReason.captureFailed);
    expect(backend.capturing, isFalse);
  });

  test('constructor rejects non-reader backends and bad targets', () {
    expect(
      () => SingleToneSessionController(
        backend: _NoReader(),
        worker: worker,
        targetHz: _c4,
      ),
      throwsArgumentError,
    );
    expect(
      () => SingleToneSessionController(
        backend: FakeAudioLabBackend(),
        worker: worker,
        targetHz: double.nan,
      ),
      throwsArgumentError,
    );
  });
}

class _NoReader implements AudioLabBackend {
  @override
  Stream<AudioLabInterruption> get interruptions => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  Future<void> discardCapture() async {}
  @override
  Future<PlaybackHandle> playRecording() async =>
      PlaybackHandle(Future.value());
  @override
  Future<PlaybackHandle> playReference() async =>
      PlaybackHandle(Future.value());
  @override
  Future<bool> requestMicrophonePermission() async => true;
  @override
  Future<void> startCapture() async {}
  @override
  Future<CapturedAudio> stopCapture() async =>
      CapturedAudio(sampleRateHz: _rate, sampleCount: _rate);
  @override
  Future<void> stopPlayback() async {}
}
