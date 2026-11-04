import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'click_track.dart';

/// Plays the reference click on every tap, so the learner hears the same
/// "tak" they are echoing. Feedback only: tap times come from the pointer
/// event, never from this sound.
abstract interface class TapSound {
  void tap();
  Future<void> close();
}

/// A few preloaded players taken in turn: a fast tap does not cut the
/// previous click off, and no file is loaded at tap time.
class JustAudioTapSound implements TapSound {
  final _players = <AudioPlayer>[];
  int _next = 0;
  Future<void>? _ready;
  Directory? _directory;

  Future<void> _load() async {
    _directory = await (await getTemporaryDirectory()).createTemp(
      'resonia-tap-',
    );
    final file = File('${_directory!.path}/tap.wav');
    await file.writeAsBytes(
      renderClickTrack(const [0], tailMs: 60).encode(),
      flush: true,
    );
    for (var i = 0; i < 3; i++) {
      final player = AudioPlayer(handleInterruptions: false);
      await player.setFilePath(file.path);
      _players.add(player);
    }
  }

  /// Loads ahead of the first tap; safe to call more than once. Without a
  /// working player (no device audio) taps simply stay silent.
  Future<void> warmUp() => _ready ??= _load().catchError((Object _) {});

  @override
  void tap() {
    warmUp();
    if (_players.isEmpty) return;
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    player
      ..seek(Duration.zero)
      ..play();
  }

  @override
  Future<void> close() async {
    for (final p in _players) {
      await p.dispose();
    }
    _players.clear();
    try {
      await _directory?.delete(recursive: true);
    } catch (_) {}
  }
}
