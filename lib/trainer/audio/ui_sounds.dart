import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../infrastructure/audio/pcm16_wav.dart';
import '../domain/music.dart';

/// One short tone inside a [UiCue]: a soft mallet-like bell.
class UiBlip {
  const UiBlip(
    this.at,
    this.midi, {
    this.seconds = 0.18,
    this.gain = 1,
    this.glide = 0,
  });

  /// Start, in seconds from the cue's start.
  final double at;
  final int midi;
  final double seconds;
  final double gain;

  /// Upward pitch glide into the note, as a fraction of its frequency; a
  /// small glide reads as a voice "chirp" rather than an instrument.
  final double glide;
}

/// A named interface sound (UX-MOTION-01). All cues are synthesised here;
/// no recorded or licensed sound ships with the app. Cues are short and
/// quiet: they confirm a touch, they never carry a score or a reference
/// pitch the learner is meant to judge.
final class UiCue {
  const UiCue._(this.id, this.blips, {this.level = 0.3});

  final String id;
  final List<UiBlip> blips;

  /// Peak level of the rendered cue, 0..1.
  final double level;

  /// A light tick for a plain button.
  static const tap = UiCue._('tap', [
    UiBlip(0, 93, seconds: 0.05),
  ], level: 0.16);

  /// An option was chosen: two notes up.
  static const select = UiCue._('select', [
    UiBlip(0, 79, seconds: 0.12),
    UiBlip(0.06, 86, seconds: 0.2),
  ], level: 0.26);

  /// An option was cleared: two notes down.
  static const deselect = UiCue._('deselect', [
    UiBlip(0, 84, seconds: 0.1),
    UiBlip(0.05, 79, seconds: 0.16),
  ], level: 0.18);

  /// Moving to the next step.
  static const advance = UiCue._('advance', [
    UiBlip(0, 72, seconds: 0.12, gain: 0.8),
    UiBlip(0.07, 79, seconds: 0.24),
  ], level: 0.24);

  /// Going back a step.
  static const back = UiCue._('back', [
    UiBlip(0, 79, seconds: 0.1, gain: 0.8),
    UiBlip(0.06, 72, seconds: 0.2),
  ], level: 0.2);

  /// The guide "speaks": three quick gliding chirps.
  static const chatter = UiCue._('chatter', [
    UiBlip(0, 84, seconds: 0.07, glide: 0.06),
    UiBlip(0.075, 88, seconds: 0.07, glide: 0.06),
    UiBlip(0.15, 86, seconds: 0.11, glide: 0.08),
  ], level: 0.2);

  /// First hello on the welcome screen: a light rising run.
  static const hello = UiCue._('hello', [
    UiBlip(0, 72, seconds: 0.16, gain: 0.7),
    UiBlip(0.07, 76, seconds: 0.16, gain: 0.75),
    UiBlip(0.14, 79, seconds: 0.16, gain: 0.8),
    UiBlip(0.21, 84, seconds: 0.4),
  ], level: 0.22);

  /// Setup finished: a rising major arpeggio that lands on a chord.
  static const success = UiCue._('success', [
    UiBlip(0, 72, seconds: 0.5),
    UiBlip(0.08, 76, seconds: 0.5),
    UiBlip(0.16, 79, seconds: 0.5),
    UiBlip(0.24, 84, seconds: 0.9),
    UiBlip(0.32, 88, seconds: 1.1, gain: 0.9),
    UiBlip(0.32, 79, seconds: 1.1, gain: 0.5),
  ], level: 0.34);

  /// A passed checkpoint or finale: the arpeggio climbs an octave higher
  /// and rings longer.
  static const fanfare = UiCue._('fanfare', [
    UiBlip(0, 67, seconds: 0.3, gain: 0.8),
    UiBlip(0.09, 72, seconds: 0.3, gain: 0.85),
    UiBlip(0.18, 76, seconds: 0.3, gain: 0.9),
    UiBlip(0.27, 79, seconds: 0.3),
    UiBlip(0.36, 84, seconds: 1.1),
    UiBlip(0.36, 76, seconds: 1.1, gain: 0.55),
    UiBlip(0.36, 72, seconds: 1.1, gain: 0.45),
  ], level: 0.36);

  /// C major pentatonic from C5: every run of these sounds consonant.
  static const pentatonic = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93];

  /// The [degree]th pentatonic step (wrapping after ten), for letters of a
  /// name or rising choices.
  static UiCue note(int degree) {
    final i = degree % pentatonic.length;
    return _notes[i];
  }

  static final _notes = [
    for (var i = 0; i < pentatonic.length; i++)
      UiCue._('note$i', [UiBlip(0, pentatonic[i], seconds: 0.32)], level: 0.26),
  ];

  static List<UiCue> get named => const [
    tap,
    select,
    deselect,
    advance,
    back,
    chatter,
    hello,
    success,
    fanfare,
  ];

  double get durationSeconds => blips.fold(
    0,
    (end, b) => math.max(end, b.at + b.seconds + _UiVoice.tail),
  );
}

/// Additive mallet: fundamental, a soft octave and a bright inharmonic
/// partial that dies fast, like a marimba bar.
abstract final class _UiVoice {
  static const partials = [(1.0, 1.0, 0.0), (2.0, 0.22, 6.0), (3.9, 0.1, 22.0)];
  static const attack = 0.003;
  static const decay = 9.0;

  /// Ring-out after a blip's nominal length.
  static const tail = 0.12;
}

/// Renders cues to mono PCM16 WAV. Pure and deterministic, so tests can
/// check the sound without a speaker.
class UiCueRenderer {
  const UiCueRenderer({this.sampleRateHz = 22050});
  final int sampleRateHz;

  Pcm16Wav render(UiCue cue) {
    final total = (cue.durationSeconds * sampleRateHz).ceil();
    final out = List<double>.filled(total, 0);
    for (final b in cue.blips) {
      final start = (b.at * sampleRateHz).round();
      final length = ((b.seconds + _UiVoice.tail) * sampleRateHz).round();
      final f0 = midiToHz(b.midi);
      // Higher notes die sooner so a cue never rings shrilly.
      final decay = _UiVoice.decay * math.pow(f0 / 523, 0.5) / b.seconds / 5;
      for (final (ratio, amp, extra) in _UiVoice.partials) {
        if (f0 * ratio >= sampleRateHz * 0.45) continue;
        var phase = 0.0;
        for (var i = 0; i < length; i++) {
          final at = start + i;
          if (at >= total) break;
          final t = i / sampleRateHz;
          // Glide reaches the target within the first 40 ms.
          final bend = b.glide == 0 ? 1.0 : 1 - b.glide * math.exp(-t / 0.012);
          phase += 2 * math.pi * f0 * ratio * bend / sampleRateHz;
          var env = math.exp(-(decay + extra) * t);
          if (t < _UiVoice.attack) env *= t / _UiVoice.attack;
          // Short linear fade at the very end: no click.
          final left = length - i;
          if (left < 220) env *= left / 220;
          out[at] += b.gain * amp * env * math.sin(phase);
        }
      }
    }
    var peak = 0.0;
    for (final s in out) {
      peak = math.max(peak, s.abs());
    }
    final scale = peak > 0 ? cue.level / peak : 0.0;
    return Pcm16Wav(
      sampleRateHz: sampleRateHz,
      samples: [for (final s in out) (s * scale).clamp(-1.0, 1.0)],
    );
  }
}

/// Plays interface cues on its own small player pool, apart from the
/// trainer's reference audio, so a tick never cuts a note being learned.
/// The players leave the audio session alone: on iOS a cue follows the
/// current category and the ring/silent switch.
class UiSounds {
  UiSounds({this.renderer = const UiCueRenderer(), this.poolSize = 3})
    : _silent = false;

  /// Plays nothing; used by tests and previews.
  UiSounds.silent()
    : renderer = const UiCueRenderer(),
      poolSize = 0,
      _silent = true;

  final UiCueRenderer renderer;
  final int poolSize;
  final bool _silent;

  /// Cues played so far, newest last (bounded); lets tests see the sound
  /// design without audio output.
  final List<String> log = [];

  final _players = <AudioPlayer>[];
  final _files = <String, Future<String>>{};
  Directory? _dir;
  int _next = 0;
  bool _closed = false;

  Future<void> play(UiCue cue) async {
    if (_closed) return;
    log.add(cue.id);
    if (log.length > 64) log.removeAt(0);
    if (_silent) return;
    try {
      final path = await (_files[cue.id] ??= _write(cue));
      if (_closed) return;
      if (_players.length < poolSize) {
        _players.add(
          AudioPlayer(
            handleInterruptions: false,
            handleAudioSessionActivation: false,
          ),
        );
      }
      final player = _players[_next++ % _players.length];
      await player.stop();
      await player.setFilePath(path);
      unawaited(player.play());
    } catch (_) {
      // A missing cue must never break a screen.
      _files.remove(cue.id);
    }
  }

  Future<String> _write(UiCue cue) async {
    _dir ??= await Directory(
      '${(await getTemporaryDirectory()).path}/resonia-ui-cues',
    ).create(recursive: true);
    final file = File('${_dir!.path}/${cue.id}.wav');
    final Uint8List bytes = renderer.render(cue).encode();
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> close() async {
    _closed = true;
    for (final p in _players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
