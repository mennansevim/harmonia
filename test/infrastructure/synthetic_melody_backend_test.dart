import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/melody_session.dart';
import 'package:harmonia/application/melody_practice.dart';
import 'package:harmonia/application/single_tone_session.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/audio/capture_quality.dart';
import 'package:harmonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:harmonia/domain/audio/pitch_deviation.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/infrastructure/audio/pcm16_wav.dart';
import 'package:harmonia/infrastructure/audio/synthetic_melody_backend.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_clip_player.dart';
import '../support/fake_recording_pitch_worker.dart';

class _Player extends FakeClipPlayer {
  List<int>? bytes;
  Object? stopFailure, closeFailure;
  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) {
    bytes = wavBytes;
    return super.playWav(wavBytes);
  }

  @override
  Future<void> stop() async {
    await super.stop();
    if (stopFailure != null) throw stopFailure!;
  }

  @override
  Future<void> close() async {
    await super.close();
    if (closeFailure != null) throw closeFailure!;
  }
}

DiagnosticMelodyReference _reference(int count) => DiagnosticMelodyReference(
  id: 'synthetic-$count',
  contentVersion: 'test-1',
  frequenciesHz: <double>[440, 550, 660, 440, 330].take(count).toList(),
);

void main() {
  test(
    'dedicated practice adapter plays exact excerpt WAV without capture',
    () async {
      final player = _Player();
      final adapter = SyntheticMelodyPracticePlayer(player);
      final selection = DiagnosticMelodyPractice(
        reference: _reference(5),
        startIndex: 1,
        endIndexExclusive: 4,
        repetitions: 2,
      );
      expect(player.calls, isEmpty);
      final handle = await adapter.play(selection);
      expect(
        player.bytes,
        orderedEquals(renderDiagnosticMelodyPractice(selection).encode()),
      );
      expect(() => player.bytes![0] = 0, throwsUnsupportedError);
      expect(player.calls, ['play']);
      await adapter.stop();
      player.end.complete();
      await handle.completed;
      await adapter.close();
      await adapter.close();
      expect(player.calls, ['play', 'stop', 'close']);
      expect(() => adapter.play(selection), throwsStateError);
    },
  );

  test(
    'practice adapter forwards load failure and still releases its player',
    () async {
      final player = _Player()..playFailure = StateError('load');
      final adapter = SyntheticMelodyPracticePlayer(player);
      final selection = DiagnosticMelodyPractice(
        reference: _reference(3),
        startIndex: 0,
        endIndexExclusive: 1,
      );
      await expectLater(adapter.play(selection), throwsStateError);
      await adapter.stop();
      await adapter.close();
      expect(player.calls, ['play', 'stop', 'close']);
    },
  );

  test(
    'bound player completion opens session capture, cancel releases both',
    () async {
      final capture = FakeRoutedAudioLabBackend();
      final player = _Player();
      final backend = SyntheticMelodyBackend(
        reference: _reference(3),
        capture: capture,
        player: player,
      );
      final session = MelodySessionController(
        backend: backend,
        worker: FakeRecordingPitchWorker(),
        calibrationDuration: const Duration(milliseconds: 1),
        responseDelay: const Duration(milliseconds: 1),
      );
      capture.nextClip(List.filled(32000, 0.0));
      await session.calibrate();
      capture.calls.clear();
      final run = session.startAttempt();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session.phase, SingleToneSessionPhase.referencePlaying);
      expect(capture.calls, isNot(contains('start')));
      expect(capture.calls, isNot(contains('reference')));
      player.end.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session.phase, SingleToneSessionPhase.responding);
      await session.cancel();
      await run;
      expect(capture.capturing, isFalse);
      expect(capture.calls.last, 'discard');
      expect(player.calls, contains('stop'));
      expect(session.outcome, isNull);
      await session.close();
      session.dispose();
    },
  );

  test('3/4/5 note WAV preserves order, exact gaps and raw frequencies', () {
    for (final rate in [8000, 48000]) {
      for (final count in [3, 4, 5]) {
        final r = _reference(count);
        final wav = renderDiagnosticMelody(r, sampleRateHz: rate);
        final decoded = Pcm16Wav.decode(wav.encode());
        expect(decoded.sampleRateHz, rate);
        expect(decoded.samples.length, rate * (count * 800 + 200) ~/ 1000);
        final detector = YinPitchFrameAnalyzer();
        final window = detector.recommendedFrameSamples(rate);
        for (var i = 0; i < count; i++) {
          final start = rate * i * 800 ~/ 1000;
          final pitch = detector.analyze(
            decoded.samples.sublist(
              start + rate ~/ 10,
              start + rate ~/ 10 + window,
            ),
            sampleRateHz: rate,
          );
          expect(pitch.status, PitchFrameStatus.pitched);
          expect(
            PitchDeviation(
              detectedHz: pitch.frequencyHz!,
              targetHz: r.frequenciesHz[i],
            ).absoluteCents.abs(),
            lessThan(15),
          );
          final gapStart = start + rate * 600 ~/ 1000;
          final gapEnd = i == count - 1
              ? decoded.samples.length
              : start + rate * 800 ~/ 1000;
          expect(
            decoded.samples.sublist(gapStart, gapEnd).every((s) => s == 0),
            isTrue,
          );
        }
        expect(wav.samples.every((s) => s.abs() <= 0.25), isTrue);
        expect(
          wav.encode(),
          orderedEquals(renderDiagnosticMelody(r, sampleRateHz: rate).encode()),
        );
      }
    }
  });

  test('renderer rejects unsupported sample rates before allocation', () {
    for (final rate in [0, 7999, 48001, 192000]) {
      expect(
        () => renderDiagnosticMelody(_reference(3), sampleRateHz: rate),
        throwsArgumentError,
      );
    }
  });

  test(
    'bound reference uses immutable WAV, never default capture reference',
    () async {
      final capture = FakeRoutedAudioLabBackend();
      final player = _Player();
      final r = _reference(3);
      final backend = SyntheticMelodyBackend(
        reference: r,
        capture: capture,
        player: player,
      );
      final handle = await backend.playReference();
      expect(backend.reference, same(r));
      expect(
        SyntheticMelodyBackend.referenceSource,
        MeasurementSource.synthetic,
      );
      expect(capture.calls, isNot(contains('reference')));
      expect(player.bytes, orderedEquals(renderDiagnosticMelody(r).encode()));
      expect(() => player.bytes![0] = 0, throwsUnsupportedError);
      var ended = false;
      unawaited(handle.completed.then((_) => ended = true));
      await Future<void>.delayed(Duration.zero);
      expect(ended, isFalse);
      player.end.complete();
      await handle.completed;
      await backend.close();
    },
  );

  test(
    'capture PCM, origin, route, replay and interruptions forwarded',
    () async {
      final capture = FakeRoutedAudioLabBackend();
      final backend = SyntheticMelodyBackend(
        reference: _reference(3),
        capture: capture,
        player: _Player(),
      );
      expect(await backend.requestMicrophonePermission(), isTrue);
      capture.nextClip([0, 0.1, 0.2]);
      await backend.startCapture();
      final metadata = await backend.stopCapture();
      final pcm = await backend.readRecording();
      expect(metadata.sampleCount, 3);
      expect(pcm.samples, [0, 0.1, 0.2]);
      expect(pcm.source, MeasurementSource.mock);
      expect(await backend.currentRoute(), same(capture.route));
      final interrupted = backend.interruptions.first;
      capture.events.add(AudioLabInterruption.routeChanged);
      expect(await interrupted, AudioLabInterruption.routeChanged);
      await backend.playRecording();
      expect(capture.calls, contains('replay'));
      await backend.discardCapture();
      expect(capture.calls.last, 'discard');
      await backend.close();
    },
  );

  test(
    'unknown route stays unverified rather than inferred as headphones',
    () async {
      final backend = SyntheticMelodyBackend(
        reference: _reference(3),
        capture: FakeAudioLabBackend(),
        player: _Player(),
      );
      final route = await backend.currentRoute();
      expect(
        RoutePolicy.assess(route, CapturePurpose.pitchResponse),
        RouteDecision.unverified,
      );
      await backend.close();
    },
  );

  test('play failure never falls back to a single tone', () async {
    final capture = FakeAudioLabBackend();
    final player = _Player()..playFailure = StateError('player failed');
    final backend = SyntheticMelodyBackend(
      reference: _reference(3),
      capture: capture,
      player: player,
    );
    await expectLater(backend.playReference(), throwsStateError);
    expect(capture.calls, isNot(contains('reference')));
    await backend.close();
  });

  test(
    'stop and close failures still release both resources; close once',
    () async {
      final capture = FakeAudioLabBackend();
      final player = _Player()
        ..stopFailure = StateError('stop')
        ..closeFailure = StateError('close');
      final backend = SyntheticMelodyBackend(
        reference: _reference(3),
        capture: capture,
        player: player,
      );
      await expectLater(backend.stopPlayback(), throwsStateError);
      expect(capture.calls.last, 'stopPlayback');
      await expectLater(backend.close(), throwsStateError);
      await expectLater(backend.close(), throwsStateError);
      expect(player.calls.where((c) => c == 'close').length, 1);
      expect(capture.calls.where((c) => c == 'close').length, 1);
      await expectLater(backend.playReference(), throwsStateError);
      await expectLater(backend.startCapture(), throwsStateError);
    },
  );
}
