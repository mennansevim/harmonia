import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/chord_reference_session_composer.dart';
import 'package:harmonia/application/chord_reference_session.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/infrastructure/audio/reviewed_chord_recording_loader.dart';

class _Player implements ReferenceClipPlayer {
  final calls = <String>[];
  final played = <List<int>>[];
  final completed = Completer<void>();

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    calls.add('play');
    played.add(List<int>.from(wavBytes));
    return PlaybackHandle(completed.future);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> close() async => calls.add('close');
}

LoadedChordRecording _loaded() {
  final recording = ReviewedChordRecording(
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
  return LoadedChordRecording(
    recording: recording,
    header: const ChordWavHeader(
      sampleRateHz: 48000,
      channels: 1,
      sampleFrames: 96000,
    ),
    bytes: Uint8List.fromList(const [82, 73, 70, 70, 1]),
  );
}

void main() {
  test('binds loaded bytes and metadata without autoplay', () async {
    final player = _Player();
    final composer = ChordReferenceSessionComposer(
      createPlayer: () async => player,
    );

    final session = await composer.create(
      loaded: _loaded(),
      wait: (_) async {},
    );

    expect(session.recording.id, 'triad-c-major');
    expect(session.recording.targetMidiNotes, [60, 64, 67]);
    expect(session.phase, ChordReferencePhase.idle);
    expect(player.calls, isEmpty);

    final playback = session.playReference();
    await Future<void>.delayed(Duration.zero);
    expect(player.played.single, [82, 73, 70, 70, 1]);
    player.completed.complete();
    await playback;
    await session.close();
  });

  test('forwards recall-exam policy and keeps the target hidden', () async {
    final player = _Player();
    final session = await ChordReferenceSessionComposer(
      createPlayer: () async => player,
    ).create(loaded: _loaded(), mode: ExerciseMode.recallExam);

    expect(session.mode, ExerciseMode.recallExam);
    expect(session.maxReferencePlays, 1);
    expect(session.targetVisibleDuringResponse, isFalse);
    await session.close();
    expect(player.calls, ['stop', 'close']);
  });

  test('rejects invalid policy before allocating a player', () async {
    var factoryCalls = 0;
    final composer = ChordReferenceSessionComposer(
      createPlayer: () async {
        factoryCalls++;
        return _Player();
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
    expect(factoryCalls, 0);
  });

  test('does not turn player construction failure into a session', () async {
    final composer = ChordReferenceSessionComposer(
      createPlayer: () async => throw StateError('native unavailable'),
    );

    await expectLater(composer.create(loaded: _loaded()), throwsStateError);
  });

  test('allocates an independent owned player for each session', () async {
    final players = <_Player>[];
    final composer = ChordReferenceSessionComposer(
      createPlayer: () async {
        final player = _Player();
        players.add(player);
        return player;
      },
    );

    final first = await composer.create(loaded: _loaded());
    final second = await composer.create(loaded: _loaded());
    expect(players, hasLength(2));
    expect(first.player, isNot(same(second.player)));

    await first.close();
    expect(players.first.calls, ['stop', 'close']);
    expect(players.last.calls, isEmpty);
    await second.close();
    expect(players.last.calls, ['stop', 'close']);
  });
}
