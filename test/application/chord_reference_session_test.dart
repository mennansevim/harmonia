import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/chord_reference_session.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:harmonia/domain/models/exercise.dart';

class _Player implements ReferenceClipPlayer {
  final calls = <String>[];
  final received = <List<int>>[];
  Completer<PlaybackHandle>? start;
  Completer<void> end = Completer<void>();
  Object? startError;
  Object? stopError;
  Object? closeError;

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    calls.add('play');
    received.add(List<int>.from(wavBytes));
    if (startError case final error?) throw error;
    return start == null ? PlaybackHandle(end.future) : await start!.future;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (stopError case final error?) throw error;
  }

  @override
  Future<void> close() async {
    calls.add('close');
    if (closeError case final error?) throw error;
  }
}

ReviewedChordRecording _recording() => ReviewedChordRecording(
  id: 'triad-c-major',
  voiceCount: 3,
  relativePath: '3-notes/triad-c-major.wav',
  targetMidiNotes: [60, 64, 67],
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
  late _Player player;
  late Completer<void> delay;
  late ChordReferenceSession session;

  setUp(() {
    player = _Player();
    delay = Completer<void>();
    session = ChordReferenceSession(
      recording: _recording(),
      wavBytes: [82, 73, 70, 70],
      player: player,
      wait: (_) => delay.future,
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

  test(
    'has no autoplay and gates response until playback plus recall',
    () async {
      expect(player.calls, isEmpty);
      expect(session.canStartSequentialResponse, isFalse);

      final run = session.playReference();
      await _tick();
      expect(session.phase, ChordReferencePhase.playing);
      expect(session.canPlayReference, isFalse);
      expect(session.canStartSequentialResponse, isFalse);

      player.end.complete();
      await _tick();
      expect(session.phase, ChordReferencePhase.recallDelay);
      expect(session.canStartSequentialResponse, isFalse);
      expect(player.calls, ['play', 'stop']);

      delay.complete();
      await run;
      expect(session.phase, ChordReferencePhase.readyForSequentialResponse);
      expect(session.canStartSequentialResponse, isTrue);
      expect(session.referencePlays, 1);
      expect(session.referencePlayLimitReached, isTrue);
      expect(session.canPlayReference, isFalse);
    },
  );

  test(
    'copies WAV bytes and exposes only reviewed teaching metadata',
    () async {
      final source = <int>[1, 2, 3];
      await session.close();
      session = ChordReferenceSession(
        recording: _recording(),
        wavBytes: source,
        player: player,
        wait: (_) async {},
      );
      source[0] = 9;
      final run = session.playReference();
      await _tick();
      expect(player.received.single, [1, 2, 3]);
      expect(session.recording.targetMidiNotes, [60, 64, 67]);
      expect(session.recording.voiceCount, 3);
      player.end.complete();
      await run;
    },
  );

  test('rejects empty bytes and unsafe recall duration', () {
    expect(
      () => ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [],
        player: player,
      ),
      throwsArgumentError,
    );
    expect(
      () => ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [1],
        player: player,
        recallDelay: const Duration(seconds: 11),
      ),
      throwsArgumentError,
    );
  });

  test('ignores duplicate play while native playback is active', () async {
    final run = session.playReference();
    await _tick();
    await session.playReference();
    expect(player.calls.where((call) => call == 'play'), hasLength(1));
    player.end.complete();
    await _tick();
    delay.complete();
    await run;
  });

  test('stop before queued native start prevents late playback', () async {
    final run = session.playReference();
    await session.stop();
    await run;
    expect(player.calls, ['stop']);
    expect(session.phase, ChordReferencePhase.idle);
    expect(session.canStartSequentialResponse, isFalse);
    expect(session.referencePlays, 0);
  });

  test('route interruption cancels without waiting or auto-resuming', () async {
    final run = session.playReference();
    await _tick();
    await session.handleInterruption(AudioLabInterruption.routeChanged);
    await run;
    expect(session.phase, ChordReferencePhase.idle);
    expect(session.canStartSequentialResponse, isFalse);
    expect(session.referencePlays, 0);
    expect(player.end.isCompleted, isFalse);
    player.end.complete();
    await _tick();
    expect(player.calls, ['play', 'stop']);
  });

  test('cancel during recall delay revokes response readiness', () async {
    final run = session.playReference();
    await _tick();
    player.end.complete();
    await _tick();
    expect(session.phase, ChordReferencePhase.recallDelay);
    await session.stop();
    await run;
    expect(session.phase, ChordReferencePhase.idle);
    expect(session.canStartSequentialResponse, isFalse);
    expect(delay.isCompleted, isFalse);
    delay.completeError(StateError('late cancelled timer'));
    await _tick();
  });

  test('start failure is neutral, redacted and explicitly retryable', () async {
    player.startError = StateError('/private/path');
    await session.playReference();
    expect(session.failure, ChordReferenceFailure.playbackUnavailable);
    expect(session.referencePlays, 0);
    expect(session.canPlayReference, isTrue);
    expect(session.canStartSequentialResponse, isFalse);
    player.startError = null;
    final retry = session.playReference();
    await _tick();
    player.end.complete();
    await _tick();
    delay.complete();
    await retry;
    expect(session.failure, isNull);
    expect(session.referencePlays, 1);
  });

  test('cleanup failure fails closed and blocks replay', () async {
    final run = session.playReference();
    await _tick();
    player.stopError = StateError('native stop');
    player.end.complete();
    await run;
    expect(session.failure, ChordReferenceFailure.cleanupFailed);
    expect(session.phase, ChordReferencePhase.failed);
    expect(session.canPlayReference, isFalse);
    await session.playReference();
    expect(player.calls.where((call) => call == 'play'), hasLength(1));
    player.stopError = null;
  });

  test(
    'close serializes pending start and releases player exactly once',
    () async {
      player.start = Completer<PlaybackHandle>();
      final run = session.playReference();
      await _tick();
      final close = session.close();
      expect(session.close(), same(close));
      player.start!.complete(PlaybackHandle(player.end.future));
      await close;
      await run;
      player.end.completeError(StateError('late completion'));
      await _tick();
      expect(session.phase, ChordReferencePhase.closed);
      expect(session.canPlayReference, isFalse);
      expect(player.calls, ['play', 'stop', 'close']);
    },
  );

  test(
    'learning mode permits only its explicit completed-play quota',
    () async {
      await session.close();
      player = _Player();
      delay = Completer<void>();
      session = ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [1],
        player: player,
        maxReferencePlays: 2,
        wait: (_) => delay.future,
      );

      final first = session.playReference();
      await _tick();
      player.end.complete();
      await _tick();
      delay.complete();
      await first;
      expect(session.referencePlays, 1);
      expect(session.canPlayReference, isTrue);
      expect(session.canStartSequentialResponse, isTrue);

      player.end = Completer<void>();
      delay = Completer<void>();
      final second = session.playReference();
      expect(session.canStartSequentialResponse, isFalse);
      await _tick();
      player.end.complete();
      await _tick();
      delay.complete();
      await second;
      expect(session.referencePlays, 2);
      expect(session.referencePlayLimitReached, isTrue);
      expect(session.canPlayReference, isFalse);

      await session.playReference();
      expect(player.calls.where((call) => call == 'play'), hasLength(2));
    },
  );

  test('recall exam hides targets and is single-listen', () async {
    await session.close();
    player = _Player();
    session = ChordReferenceSession(
      recording: _recording(),
      wavBytes: const [1],
      player: player,
      mode: ExerciseMode.recallExam,
      wait: (_) async {},
    );
    expect(session.targetVisibleDuringResponse, isFalse);
    final run = session.playReference();
    await _tick();
    player.end.complete();
    await run;
    expect(session.referencePlays, 1);
    expect(session.canStartSequentialResponse, isTrue);
    expect(session.canPlayReference, isFalse);
  });

  test('learning target visibility and policy bounds are explicit', () {
    expect(session.targetVisibleDuringResponse, isTrue);
    for (final maxPlays in [0, 11]) {
      expect(
        () => ChordReferenceSession(
          recording: _recording(),
          wavBytes: const [1],
          player: player,
          maxReferencePlays: maxPlays,
        ),
        throwsArgumentError,
      );
    }
    for (final mode in [
      ExerciseMode.sightReading,
      ExerciseMode.choirPractice,
    ]) {
      expect(
        () => ChordReferenceSession(
          recording: _recording(),
          wavBytes: const [1],
          player: player,
          mode: mode,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ChordReferenceSession(
        recording: _recording(),
        wavBytes: const [1],
        player: player,
        mode: ExerciseMode.recallExam,
        maxReferencePlays: 2,
      ),
      throwsArgumentError,
    );
  });
}
