import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/melody_session.dart';
import 'package:resonia/application/single_tone_session.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/audio/pitch_segmenter.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

class _Backend extends FakeRoutedAudioLabBackend
    implements MelodyReferenceBackend {
  @override
  final reference = DiagnosticMelodyReference(
    id: 'synthetic-three-tone-test',
    contentVersion: 'test-1',
    frequenciesHz: [440, 550, 660],
  );
}

const _rate = 16000;
List<double> _tone(double hz) => List.generate(
  _rate ~/ 2,
  (i) => 0.2 * math.sin(2 * math.pi * hz * i / _rate),
);
List<double> _answer() => [
  ...List.filled(_rate ~/ 4, 0.0),
  ..._tone(440),
  ...List.filled(_rate ~/ 4, 0.0),
  ..._tone(550),
  ...List.filled(_rate ~/ 4, 0.0),
  ..._tone(660),
];
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late _Backend backend;
  late FakeRecordingPitchWorker worker;
  late MelodySessionController session;
  setUp(() {
    backend = _Backend();
    worker = FakeRecordingPitchWorker();
    session = MelodySessionController(
      backend: backend,
      worker: worker,
      responseDelay: const Duration(milliseconds: 1),
      responseWindow: const Duration(seconds: 8),
      calibrationDuration: const Duration(milliseconds: 1),
    );
  });
  tearDown(() async {
    await session.close();
    session.dispose();
  });
  Future<void> calibrate() async {
    backend.nextClip(List.filled(_rate * 2, 0.0));
    await session.calibrate();
    expect(session.calibration!.isUsable, isTrue);
  }

  Future<void> respond() async {
    backend.playbackEnd.complete();
    await _settle();
    expect(session.canFinishResponse, isTrue);
    session.finishResponse();
  }

  test('reference bounded, immutable and clearly diagnostic', () {
    final frequencies = [440.0, 550.0, 660.0];
    final r = DiagnosticMelodyReference(
      id: 'test',
      contentVersion: '1',
      frequenciesHz: frequencies,
    );
    frequencies[0] = 880;
    expect(r.frequenciesHz.first, 440);
    expect(() => r.frequenciesHz.add(880), throwsUnsupportedError);
    for (final bad in <List<double>>[
      [],
      [440, 550],
      [440, 550, double.nan],
      [79, 550, 660],
      [440, 550, 1201],
      [440, 550, 660, 770, 880, 990],
    ]) {
      expect(
        () => DiagnosticMelodyReference(
          id: 'test',
          contentVersion: '1',
          frequenciesHz: bad,
        ),
        throwsArgumentError,
      );
    }
    expect(MelodySessionOutcome.scoringEnabled, isFalse);
  });

  test('uncalibrated attempt never plays or captures', () async {
    await session.startAttempt();
    expect(
      session.outcome!.retryReason,
      SessionRetryReason.calibrationRequired,
    );
    expect(session.outcome!.referencePlays, 0);
    expect(backend.calls, isNot(contains('reference')));
    expect(worker.calls, 0);
  });

  test(
    'listen then capture, delete before DSP, publish only candidates',
    () async {
      await calibrate();
      backend.calls.clear();
      backend.nextClip(_answer());
      worker.gate = Completer();
      final run = session.startAttempt();
      await _settle();
      expect(session.phase, SingleToneSessionPhase.referencePlaying);
      expect(backend.calls, isNot(contains('start')));
      await respond();
      await _settle();
      expect(session.phase, SingleToneSessionPhase.analyzing);
      expect(backend.calls.last, 'discard');
      worker.gate!.complete(
        RecordingPitchAnalyzer().analyze(
          samples: _answer(),
          sampleRateHz: _rate,
          source: MeasurementSource.mock,
        ),
      );
      await run;
      final result = session.outcome!;
      expect(result.needsRetry, isFalse);
      expect(result.referencePlays, 1);
      expect(result.reference, same(backend.reference));
      expect(
        result.segments!.status,
        PitchSegmentationStatus.candidatesObserved,
      );
      expect(result.segments!.provenance.source, MeasurementSource.mock);
      expect(result.segments!.segments.length, 3);
      expect(result.alignment!.wholeSequenceCorrect, isTrue);
      expect(session.canStart, isTrue);
    },
  );

  test('silent answer remains neutral; no segmentation or score', () async {
    await calibrate();
    backend.nextClip(List.filled(_rate, 0.0));
    final run = session.startAttempt();
    await _settle();
    await respond();
    await run;
    expect(session.outcome!.retryReason, SessionRetryReason.quality);
    expect(session.outcome!.quality!.status, CaptureQualityStatus.silent);
    expect(session.outcome!.segments, isNull);
    expect(worker.calls, 0);
  });

  test(
    'cancel pending permission blocks restart until callback settles',
    () async {
      await calibrate();
      backend.calls.clear();
      backend.permissionGate = Completer<bool>();
      final run = session.startAttempt();
      await _settle();
      final cancellation = session.cancel();
      await _settle();
      expect(session.canStart, isFalse);
      await session.startAttempt();
      expect(backend.calls.where((c) => c == 'permission').length, 1);
      backend.permissionGate!.complete(true);
      await cancellation;
      await run;
      expect(session.outcome, isNull);
      expect(session.canStart, isTrue);
      expect(backend.calls, isNot(contains('reference')));
    },
  );

  test('reference cancellation does not count uncompleted playback', () async {
    await calibrate();
    final run = session.startAttempt();
    await _settle();
    await session.cancel();
    await run;
    backend.playbackEnd.complete();
    await _settle();
    expect(session.outcome, isNull);
    expect(session.phase, SingleToneSessionPhase.idle);
    expect(worker.calls, 0);
  });

  test('cancel discards after delayed native capture start', () async {
    await calibrate();
    backend.calls.clear();
    backend.startGate = Completer<void>();
    final run = session.startAttempt();
    await _settle();
    backend.playbackEnd.complete();
    await _settle();
    expect(backend.calls.last, 'start');
    final cancellation = session.cancel();
    await _settle();
    expect(session.canStart, isFalse);
    backend.capturing = true;
    backend.startGate!.complete();
    await cancellation;
    await run;
    expect(backend.capturing, isFalse);
    expect(
      backend.calls,
      containsAllInOrder(['start', 'stopPlayback', 'discard']),
    );
    expect(session.outcome, isNull);
    expect(session.canStart, isTrue);
  });

  test('failed capture command does not poison cleanup queue', () async {
    await calibrate();
    backend.nextClip(_answer());
    backend.stopFailure = StateError('native stop failed');
    final run = session.startAttempt();
    await _settle();
    await respond();
    await run;
    expect(session.outcome!.retryReason, SessionRetryReason.captureFailed);
    expect(backend.calls.last, 'discard');
    expect(backend.capturing, isFalse);
    expect(session.canStart, isTrue);
  });

  test(
    'late worker after route interruption cannot publish candidates',
    () async {
      await calibrate();
      backend.nextClip(_answer());
      worker.gate = Completer();
      final run = session.startAttempt();
      await _settle();
      await respond();
      await _settle();
      backend.events.add(AudioLabInterruption.routeChanged);
      await _settle();
      expect(session.outcome!.retryReason, SessionRetryReason.interrupted);
      expect(session.canStart, isFalse);
      worker.gate!.complete(
        RecordingPitchAnalyzer().analyze(
          samples: _answer(),
          sampleRateHz: _rate,
        ),
      );
      await run;
      expect(session.outcome!.segments, isNull);
      expect(session.outcome!.retryReason, SessionRetryReason.interrupted);
    },
  );

  test(
    'close while worker runs detaches notifications and clears outcome',
    () async {
      await calibrate();
      backend.nextClip(_answer());
      worker.gate = Completer();
      final run = session.startAttempt();
      await _settle();
      await respond();
      await _settle();
      await session.close();
      var changes = 0;
      session.addListener(() => changes++);
      worker.gate!.complete(
        RecordingPitchAnalyzer().analyze(
          samples: _answer(),
          sampleRateHz: _rate,
        ),
      );
      await run;
      expect(changes, 0);
      expect(session.outcome, isNull);
      expect(session.canStart, isFalse);
      expect(backend.calls.where((c) => c == 'close').length, 1);
    },
  );
}
