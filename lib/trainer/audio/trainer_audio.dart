import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/audio/audio_capture.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../domain/trainers.dart';
import 'piano_notes.dart';
import 'synth.dart';

/// Plays trainer sounds. [playing] drives the wave animation; it flips back
/// after the rendered duration even when the platform player gives no event.
class TrainerAudio {
  TrainerAudio({ReferenceClipPlayer? player, this.synth = const TrainerSynth()})
    // ignore: prefer_initializing_formals
    : _player = player,
      _silent = false;

  /// Silent instance for tests and previews.
  TrainerAudio.silent()
    : _player = null,
      synth = const TrainerSynth(),
      _silent = true;

  ReferenceClipPlayer? _player;
  final TrainerSynth synth;
  final bool _silent;
  Timbre timbre = Timbre.piano;
  final ValueNotifier<bool> playing = ValueNotifier(false);
  Timer? _timer;
  int _epoch = 0;

  Future<void> play(SoundSpec spec) async {
    final epoch = ++_epoch;
    _timer?.cancel();
    playing.value = true;
    _timer = Timer(
      Duration(milliseconds: (spec.durationSeconds * 1000).round() + 150),
      () {
        if (epoch == _epoch) playing.value = false;
      },
    );
    if (_silent) return;
    try {
      final wav = synth.render(spec, timbre).encode();
      _player ??= JustAudioClipPlayer();
      await _player!.playWav(wav);
    } catch (_) {
      // Audio failure must never break the quiz; the UI stays usable.
      if (epoch == _epoch) playing.value = false;
    }
  }

  /// Recorded piano notes, used by [playNote] when cleared for use.
  PianoNoteBank notes = PianoNoteBank();

  /// Plays one piano note and completes when it has finished sounding, so a
  /// recording started afterwards does not capture the reference.
  Future<void> playNote(int midi, {double seconds = 1.3}) async {
    if (_silent) return;
    final recorded = await notes.wav(midi);
    if (recorded == null) {
      await play(
        SoundSpec([
          ToneEvent(0, seconds, [midi]),
        ]),
      );
      await Future<void>.delayed(
        Duration(milliseconds: (seconds * 1000).round() + 150),
      );
      return;
    }
    final epoch = ++_epoch;
    _timer?.cancel();
    playing.value = true;
    try {
      _player ??= JustAudioClipPlayer();
      final handle = await _player!.playWav(recorded);
      await handle.completed.timeout(const Duration(seconds: 6));
    } catch (_) {
      // A failed reference must not hang the exercise.
    } finally {
      if (epoch == _epoch) playing.value = false;
    }
  }

  Future<void> stop() async {
    _epoch++;
    _timer?.cancel();
    playing.value = false;
    if (_silent) return;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _timer?.cancel();
    playing.dispose();
    try {
      await _player?.close();
    } catch (_) {}
  }
}
