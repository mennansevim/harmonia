import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/audio/audio_capture.dart';

/// Writes each clip to its own temp directory and plays it; only that file
/// and directory are ever deleted. Device latency is NOT measured here.
class JustAudioClipPlayer implements ReferenceClipPlayer {
  /// [fadeOnInterrupt]: a clip still sounding is turned down over ~30 ms
  /// before the next one or a stop, instead of being cut mid-waveform (an
  /// audible pop). Off by default so measured flows keep exact start
  /// timing; trainer listening sounds turn it on.
  JustAudioClipPlayer({this.fadeOnInterrupt = false});

  final bool fadeOnInterrupt;
  AudioPlayer? _player;
  Directory? _directory;

  File get _file => File('${_directory!.path}/clip.wav');

  Future<void> _quiet() async {
    final player = _player;
    if (player == null) return;
    if (fadeOnInterrupt && player.playing) {
      for (final v in const [0.6, 0.3, 0.1, 0.0]) {
        await player.setVolume(v);
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
    }
    await player.stop();
    if (fadeOnInterrupt) await player.setVolume(1);
  }

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    _directory ??= await (await getTemporaryDirectory()).createTemp(
      'resonia-clip-',
    );
    _player ??= AudioPlayer(handleInterruptions: false);
    await _quiet();
    await _file.writeAsBytes(wavBytes, flush: true);
    await _player!.setFilePath(_file.path);
    return PlaybackHandle(_player!.play());
  }

  @override
  Future<void> stop() => _quiet();

  @override
  Future<void> close() async {
    Object? failure;
    try {
      await _player?.dispose();
    } catch (e) {
      failure = e;
    }
    final dir = _directory;
    if (dir != null) {
      try {
        if (await _file.exists()) await _file.delete();
        await dir.delete();
      } catch (e) {
        failure ??= e;
      }
    }
    if (failure != null) throw failure;
  }
}
