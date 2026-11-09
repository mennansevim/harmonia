import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/audio/audio_capture.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../domain/trainers.dart';
import '../../infrastructure/audio/pcm16_wav.dart';
import 'piano_notes.dart';
import 'piano_sampler.dart';
import 'synth.dart';
import 'ui_sounds.dart';

/// Plays trainer sounds. [playing] drives the wave animation; it flips back
/// after the rendered duration even when the platform player gives no event.
class TrainerAudio {
  TrainerAudio({
    ReferenceClipPlayer? player,
    this.synth = const TrainerSynth(),
    UiSounds? ui,
  })
    // ignore: prefer_initializing_formals
    : _player = player,
       ui = ui ?? UiSounds(),
       _silent = false;

  /// Silent instance for tests and previews.
  TrainerAudio.silent()
    : _player = null,
      synth = const TrainerSynth(),
      ui = UiSounds.silent(),
      _silent = true;

  ReferenceClipPlayer? _player;
  final TrainerSynth synth;

  /// Interface cues (taps, choices, steps); separate from reference audio.
  final UiSounds ui;
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
      final wav = (await render(spec)).encode();
      // A newer sound or a stop arrived while the recording loaded.
      if (epoch != _epoch) return;
      _player ??= JustAudioClipPlayer(fadeOnInterrupt: true);
      await _player!.playWav(wav);
    } catch (_) {
      // Audio failure must never break the quiz; the UI stays usable.
      if (epoch == _epoch) playing.value = false;
    }
  }

  /// Recorded piano notes, used by [playNote] and [render] when cleared.
  PianoNoteBank notes = PianoNoteBank();

  PianoSampler? _sampler;
  PianoSampler get _piano =>
      _sampler?.bank == notes ? _sampler! : _sampler = PianoSampler(notes);

  /// What [play] sends to the speaker. With the piano timbre, single-note
  /// sounds come from the cleared piano recordings; chords, harmonic
  /// intervals and notes the recordings cannot reach stay on the synth as
  /// a whole, so one sound never mixes the two.
  Future<Pcm16Wav> render(SoundSpec spec) async {
    if (timbre == Timbre.piano) {
      final recorded = await _piano.render(spec);
      if (recorded != null) return recorded;
    }
    return synth.render(spec, timbre);
  }

  /// Plays one piano note and completes when it has finished sounding, so a
  /// recording started afterwards does not capture the reference.
  Future<void> playNote(int midi, {double seconds = 1.3}) async {
    if (_silent) return;
    // Through the sampler, not the raw file: trimmed onset, eased start and
    // release, so a take that begins mid-attack does not pop.
    final recorded = await _piano.render(
      SoundSpec([
        ToneEvent(0, seconds, [midi]),
      ]),
    );
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
      _player ??= JustAudioClipPlayer(fadeOnInterrupt: true);
      final handle = await _player!.playWav(recorded.encode());
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
    await ui.close();
    try {
      await _player?.close();
    } catch (_) {}
  }
}
