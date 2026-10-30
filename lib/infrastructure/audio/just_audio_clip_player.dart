import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/audio/audio_capture.dart';

/// Writes each clip to its own temp directory and plays it; only that file
/// and directory are ever deleted. Device latency is NOT measured here.
class JustAudioClipPlayer implements ReferenceClipPlayer {
  AudioPlayer? _player;
  Directory? _directory;

  File get _file => File('${_directory!.path}/clip.wav');

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    _directory ??= await (await getTemporaryDirectory()).createTemp(
      'resonia-clip-',
    );
    _player ??= AudioPlayer(handleInterruptions: false);
    await _player!.stop();
    await _file.writeAsBytes(wavBytes, flush: true);
    await _player!.setFilePath(_file.path);
    return PlaybackHandle(_player!.play());
  }

  @override
  Future<void> stop() async => _player?.stop();

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
