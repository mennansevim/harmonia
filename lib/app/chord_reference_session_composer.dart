import '../application/chord_reference_session.dart';
import '../domain/audio/audio_capture.dart';
import '../domain/models/exercise.dart';
import '../infrastructure/audio/reviewed_chord_recording_loader.dart';

typedef ChordReferencePlayerFactory = Future<ReferenceClipPlayer> Function();

/// Composition boundary between a verified local recording and its playback
/// session. Each call must receive a fresh player from [createPlayer].
///
/// Creating a session does not play audio, request microphone access or score
/// a response. The session owns the returned player after creation succeeds.
class ChordReferenceSessionComposer {
  const ChordReferenceSessionComposer({required this.createPlayer});

  final ChordReferencePlayerFactory createPlayer;

  Future<ChordReferenceSession> create({
    required LoadedChordRecording loaded,
    Duration recallDelay = const Duration(milliseconds: 650),
    ExerciseMode mode = ExerciseMode.learning,
    int maxReferencePlays = 1,
    ChordRecallDelay? wait,
  }) async {
    final bytes = loaded.bytes;
    ChordReferenceSession.validateInput(
      wavBytes: bytes,
      recallDelay: recallDelay,
      mode: mode,
      maxReferencePlays: maxReferencePlays,
    );

    ReferenceClipPlayer? player;
    try {
      player = await createPlayer();
      return ChordReferenceSession(
        recording: loaded.recording,
        wavBytes: bytes,
        player: player,
        recallDelay: recallDelay,
        mode: mode,
        maxReferencePlays: maxReferencePlays,
        wait: wait,
      );
    } catch (_) {
      if (player != null) await _release(player);
      rethrow;
    }
  }
}

Future<void> _release(ReferenceClipPlayer player) async {
  try {
    await player.stop();
  } catch (_) {
    // Preserve the creation failure while still attempting final disposal.
  }
  try {
    await player.close();
  } catch (_) {
    // Creation failure remains the actionable error at this boundary.
  }
}
