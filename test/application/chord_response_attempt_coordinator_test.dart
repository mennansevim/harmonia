import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/chord_reference_session.dart';
import 'package:harmonia/application/chord_response_attempt_coordinator.dart';
import 'package:harmonia/application/chord_response_capture_session.dart';
import 'package:harmonia/application/chord_response_diagnostic_analyzer.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/audio/chord_response_matcher.dart';
import 'package:harmonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:harmonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:harmonia/domain/models/exercise_protocol.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;
final _now = DateTime.utc(2026, 10, 29, 6);

double _hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

List<double> _tone(int midi, double seconds) => List.generate(
  (_rate * seconds).round(),
  (i) => 0.2 * math.sin(2 * math.pi * _hz(midi) * i / _rate),
);

List<double> _response(List<int> notes) => [
  ...List<double>.filled((_rate * 0.2).round(), 0),
  for (final note in notes) ...[
    ..._tone(note, 0.55),
    ...List<double>.filled((_rate * 0.16).round(), 0),
  ],
];

ReviewedChordRecording _recording() => ReviewedChordRecording(
  id: 'dyad-c-g',
  voiceCount: 2,
  relativePath: '2-notes/dyad-c-g.wav',
  targetMidiNotes: const [60, 67],
  sha256: 'a' * 64,
  sampleRateHz: 48000,
  channels: 1,
  sampleFrames: 96000,
  a4Hz: 440,
  rightsReference: 'rights/user-recorded',
  labelReviewReference: 'reviews/dyad-c-g',
);

class _Player implements ReferenceClipPlayer {
  int plays = 0;
  int closes = 0;
  Completer<void> completed = Completer<void>();

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    plays++;
    return PlaybackHandle(completed.future);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() async => closes++;
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late _Player player;
  late FakeRoutedAudioLabBackend backend;
  late FakeRecordingPitchWorker worker;
  late ChordResponseCaptureSession session;
  late ChordResponseAttemptCoordinator coordinator;

  setUp(() {
    player = _Player();
    backend = FakeRoutedAudioLabBackend();
    worker = FakeRecordingPitchWorker();
    final reference = ChordReferenceSession(
      recording: _recording(),
      wavBytes: const [1, 2, 3],
      player: player,
      maxReferencePlays: 3,
      wait: (_) async {},
    );
    session = ChordResponseCaptureSession(
      reference: reference,
      backend: backend,
      wait: (_) async {},
      clock: () => _now,
    );
    coordinator = ChordResponseAttemptCoordinator(
      session: session,
      analyzer: ChordResponseDiagnosticAnalyzer(
        worker: worker,
        clock: () => _now.add(const Duration(minutes: 1)),
      ),
    );
  });

  tearDown(() async {
    try {
      await coordinator.close();
    } catch (_) {
      // Explicit cleanup behavior is tested through owned fakes elsewhere.
    }
    coordinator.dispose();
  });

  Future<void> calibrate() async {
    backend.nextClip(List<double>.filled(_rate * 2, 0.0001));
    await coordinator.calibrateEnvironment();
    expect(coordinator.canPlayReference, isTrue);
  }

  Future<void> listen() async {
    final run = coordinator.playReference();
    await _tick();
    player.completed.complete();
    await run;
    expect(coordinator.canStartResponse, isTrue);
  }

  Future<void> capture(List<double> samples) async {
    backend.nextClip(samples);
    await coordinator.startResponse();
    await session.stopResponse();
    expect(coordinator.canAnalyzeCapturedResponse, isTrue);
  }

  test('product flow blocks reference until explicit calibration', () async {
    await coordinator.playReference();
    expect(player.plays, 0);
    expect(backend.calls, isEmpty);

    await calibrate();
    await listen();

    expect(player.plays, 1);
    expect(session.calibration?.isUsable, isTrue);
  });

  test('stop and analyze publishes candidate-only exact diagnostic', () async {
    await calibrate();
    await listen();
    final samples = _response(const [60, 67]);
    backend.nextClip(samples);
    await coordinator.startResponse();

    await coordinator.stopAndAnalyze();

    expect(coordinator.phase, ChordResponseAttemptPhase.diagnosticAvailable);
    expect(coordinator.outcome?.hasCandidateComparison, isTrue);
    expect(
      coordinator.outcome?.comparison?.status,
      ChordResponseStatus.candidatesCompared,
    );
    expect(worker.calls, 1);
  });

  test('silent answer becomes quality retry without running worker', () async {
    await calibrate();
    await listen();
    await capture(List<double>.filled(_rate, 0));

    await coordinator.analyzeCapturedResponse();

    expect(coordinator.phase, ChordResponseAttemptPhase.qualityRetry);
    expect(worker.calls, 0);
    expect(coordinator.outcome?.hasCandidateComparison, isFalse);
  });

  test('worker failure is unavailable instead of learner failure', () async {
    await calibrate();
    await listen();
    await capture(_response(const [60, 67]));
    worker.failure = StateError('native worker unavailable');

    await coordinator.analyzeCapturedResponse();

    expect(coordinator.phase, ChordResponseAttemptPhase.analysisUnavailable);
    expect(coordinator.outcome?.comparison, isNull);
  });

  test('cancel while worker is pending suppresses stale diagnostic', () async {
    await calibrate();
    await listen();
    final samples = _response(const [60, 67]);
    await capture(samples);
    final source = session.response!.samples.source;
    worker.gate = Completer<RecordingPitchEvidence>();

    final analyzing = coordinator.analyzeCapturedResponse();
    await _tick();
    expect(coordinator.phase, ChordResponseAttemptPhase.analyzing);
    await coordinator.cancel();
    worker.gate!.complete(
      RecordingPitchAnalyzer().analyze(
        samples: samples,
        sampleRateHz: _rate,
        source: source,
      ),
    );
    await analyzing;

    expect(coordinator.phase, ChordResponseAttemptPhase.idle);
    expect(coordinator.outcome, isNull);
  });

  test(
    'close during worker analysis is idempotent and publishes nothing',
    () async {
      await calibrate();
      await listen();
      final samples = _response(const [60, 67]);
      await capture(samples);
      final source = session.response!.samples.source;
      worker.gate = Completer<RecordingPitchEvidence>();
      final analyzing = coordinator.analyzeCapturedResponse();
      await _tick();

      final closing = coordinator.close();
      expect(coordinator.close(), same(closing));
      worker.gate!.complete(
        RecordingPitchAnalyzer().analyze(
          samples: samples,
          sampleRateHz: _rate,
          source: source,
        ),
      );
      await analyzing;
      await closing;

      expect(coordinator.phase, ChordResponseAttemptPhase.closed);
      expect(coordinator.outcome, isNull);
      expect(player.closes, 1);
    },
  );

  test('constructor rejects post-hoc out-of-contract tolerance', () {
    expect(
      () => ChordResponseAttemptCoordinator(
        session: session,
        analyzer: ChordResponseDiagnosticAnalyzer(worker: worker),
        responseOrder: ResponseOrder.anyOrder,
        toleranceCents: 101,
      ),
      throwsArgumentError,
    );
  });
}
