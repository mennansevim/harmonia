import 'dart:async';

import 'package:harmonia/domain/audio/audio_capture.dart';

class FakeClipPlayer implements ReferenceClipPlayer {
  final calls = <String>[];
  Completer<void> end = Completer();
  Object? playFailure;
  int lastBytes = 0;
  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    calls.add('play');
    lastBytes = wavBytes.length;
    if (playFailure != null) throw playFailure!;
    return PlaybackHandle(end.future);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> close() async => calls.add('close');
}
