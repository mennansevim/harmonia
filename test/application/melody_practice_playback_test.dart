import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/melody_practice.dart';
import 'package:resonia/application/melody_practice_playback.dart';
import 'package:resonia/application/melody_session.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/pitch_sequence_alignment.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

class _Player implements DiagnosticMelodyPracticePlayer {
  final calls = <String>[];
  Completer<PlaybackHandle>? start;
  Completer<void> end = Completer<void>();
  Object? startError, stopError, closeError;
  DiagnosticMelodyPractice? received;
  @override
  Future<PlaybackHandle> play(DiagnosticMelodyPractice practice) async {
    calls.add('play');
    received = practice;
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

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late _Player player;
  late DiagnosticMelodyReference reference;
  late DiagnosticMelodyPractice selection;
  late MelodyPracticePlayback controller;
  setUp(() {
    player = _Player();
    reference = DiagnosticMelodyReference(
      id: 'manual',
      contentVersion: '1',
      frequenciesHz: [440, 550, 660],
    );
    selection = DiagnosticMelodyPractice(
      reference: reference,
      startIndex: 1,
      endIndexExclusive: 3,
      repetitions: 2,
    );
    controller = MelodyPracticePlayback(reference: reference, player: player);
  });

  test(
    'candidate review selects two-note context without claiming a score',
    () {
      final longReference = DiagnosticMelodyReference(
        id: 'five',
        contentVersion: '1',
        frequenciesHz: [220, 330, 440, 550, 660],
      );
      final evidence = PitchSequenceAligner.align(
        reference: [
          for (var i = 0; i < longReference.frequenciesHz.length; i++)
            SequencePitchEvent(
              frequencyHz: longReference.frequenciesHz[i],
              onsetMs: i * 500,
              durationMs: 300,
            ),
        ],
        response: [
          for (var i = 0; i < 5; i++)
            SequencePitchEvent(
              frequencyHz: i == 2 ? 470 : longReference.frequenciesHz[i],
              onsetMs: i * 500,
              durationMs: 300,
            ),
        ],
        source: MeasurementSource.mock,
      );
      final suggestion = DiagnosticMelodyPracticeSuggestion.fromAlignment(
        reference: longReference,
        evidence: evidence,
      )!;
      expect(suggestion.referenceIndex, 2);
      expect(suggestion.kind, PitchSequenceStepKind.wrongPitch);
      expect(suggestion.practice.startIndex, 1);
      expect(suggestion.practice.endIndexExclusive, 3);
      expect(suggestion.practice.frequenciesHz, [330, 440]);
      expect(suggestion.practice.repetitions, 2);
    },
  );

  test('clean and extra-only comparisons do not invent a target range', () {
    PitchSequenceEvidence compare(List<double> response) =>
        PitchSequenceAligner.align(
          reference: [
            for (var i = 0; i < reference.frequenciesHz.length; i++)
              SequencePitchEvent(
                frequencyHz: reference.frequenciesHz[i],
                onsetMs: i * 500,
                durationMs: 300,
              ),
          ],
          response: [
            for (var i = 0; i < response.length; i++)
              SequencePitchEvent(
                frequencyHz: response[i],
                onsetMs: i * 500,
                durationMs: 300,
              ),
          ],
          source: MeasurementSource.mock,
        );
    expect(
      DiagnosticMelodyPracticeSuggestion.fromAlignment(
        reference: reference,
        evidence: compare([440, 550, 660]),
      ),
      isNull,
    );
    expect(
      DiagnosticMelodyPracticeSuggestion.fromAlignment(
        reference: reference,
        evidence: compare([440, 500, 550, 660]),
      ),
      isNull,
    );
  });
  tearDown(() async {
    try {
      await controller.close();
    } catch (_) {
      /* Explicit failure tests. */
    }
    controller.dispose();
  });

  test(
    'no autoplay; explicit selection plays once with no attempt outcome',
    () async {
      expect(player.calls, isEmpty);
      expect(controller.canPlay, isTrue);
      final run = controller.play(selection);
      await _tick();
      expect(controller.phase, MelodyPracticePhase.playing);
      expect(controller.canPlay, isFalse);
      expect(player.received, same(selection));
      await controller.play(selection);
      expect(player.calls, ['play']);
      player.end.complete();
      await run;
      expect(player.calls, ['play', 'stop']);
      expect(controller.phase, MelodyPracticePhase.idle);
      expect(controller.canPlay, isTrue);
    },
  );

  test('foreign reference rejected before resource mutation', () async {
    final foreign = DiagnosticMelodyReference(
      id: reference.id,
      contentVersion: reference.contentVersion,
      frequenciesHz: [880, 550, 660],
    );
    await expectLater(
      controller.play(
        DiagnosticMelodyPractice(
          reference: foreign,
          startIndex: 0,
          endIndexExclusive: 1,
        ),
      ),
      throwsArgumentError,
    );
    expect(player.calls, isEmpty);
    expect(controller.canPlay, isTrue);
  });

  test('stop before queued start prevents late autoplay', () async {
    final run = controller.play(selection);
    await controller.stop();
    await run;
    expect(player.calls, ['stop']);
    expect(controller.canPlay, isTrue);
  });

  test(
    'stop during pending start serializes cleanup and consumes late error',
    () async {
      player.start = Completer<PlaybackHandle>();
      final run = controller.play(selection);
      await _tick();
      final stop = controller.stop();
      await controller.play(selection);
      expect(controller.canPlay, isFalse);
      expect(player.calls, ['play']);
      player.start!.complete(PlaybackHandle(player.end.future));
      await stop;
      await run;
      player.end.completeError(StateError('late completion'));
      await _tick();
      expect(player.calls, ['play', 'stop']);
      expect(controller.failure, isNull);
      expect(controller.canPlay, isTrue);
    },
  );

  test(
    'background stop never waits for completion or automatically resumes',
    () async {
      final run = controller.play(selection);
      await _tick();
      await controller.stop();
      await run;
      expect(controller.phase, MelodyPracticePhase.idle);
      expect(player.end.isCompleted, isFalse);
      player.end.complete();
      await _tick();
      expect(player.calls, ['play', 'stop']);
    },
  );

  test('start failure cleans up and explicit retry can play', () async {
    player.startError = StateError('private/path');
    await controller.play(selection);
    expect(controller.failure, MelodyPracticeFailure.playbackUnavailable);
    expect(controller.canPlay, isTrue);
    expect(player.calls, ['play', 'stop']);
    player.startError = null;
    final retry = controller.play(selection);
    await _tick();
    expect(controller.failure, isNull);
    player.end.complete();
    await retry;
    expect(controller.canPlay, isTrue);
  });

  test(
    'completion failure is neutral and stop failure is fail-closed',
    () async {
      final run = controller.play(selection);
      await _tick();
      player.stopError = StateError('native cleanup');
      player.end.completeError(StateError('playback'));
      await run;
      expect(controller.failure, MelodyPracticeFailure.cleanupFailed);
      expect(controller.canPlay, isFalse);
      player.stopError = null;
      await controller.stop();
      await controller.play(selection);
      expect(controller.canPlay, isFalse);
      expect(player.calls.where((c) => c == 'play'), hasLength(1));
    },
  );

  test('natural completion cleanup failure also prevents restart', () async {
    final run = controller.play(selection);
    await _tick();
    player.stopError = StateError('stop');
    player.end.complete();
    await run;
    expect(controller.failure, MelodyPracticeFailure.cleanupFailed);
    expect(controller.canPlay, isFalse);
  });

  test(
    'close while start pending waits then closes once without notifications',
    () async {
      player.start = Completer<PlaybackHandle>();
      final run = controller.play(selection);
      await _tick();
      final close = controller.close();
      expect(controller.close(), same(close));
      var changes = 0;
      controller.addListener(() => changes++);
      player.start!.complete(PlaybackHandle(player.end.future));
      await close;
      await run;
      player.end.completeError(StateError('after close'));
      await _tick();
      expect(changes, 0);
      expect(player.calls, ['play', 'close']);
      expect(controller.phase, MelodyPracticePhase.closed);
      expect(controller.canPlay, isFalse);
    },
  );

  test('failed close is retained and cannot reopen resources', () async {
    player.closeError = StateError('close');
    final close = controller.close();
    await expectLater(close, throwsStateError);
    await expectLater(controller.close(), throwsStateError);
    await controller.play(selection);
    expect(player.calls, ['close']);
    expect(controller.canPlay, isFalse);
  });
}
