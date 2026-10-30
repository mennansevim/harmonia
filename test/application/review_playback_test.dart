import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/review_playback.dart';
import 'package:resonia/domain/audio/audio_capture.dart';

class _ControlledPlayer implements ReferenceClipPlayer {
  final calls = <String>[];
  final loads = <Completer<PlaybackHandle>>[];
  Object? stopFailure;

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) {
    calls.add('play:${wavBytes.single}');
    final load = Completer<PlaybackHandle>();
    loads.add(load);
    return load.future;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (stopFailure case final failure?) throw failure;
  }

  @override
  Future<void> close() async => calls.add('close');
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _ControlledPlayer player;
  late ReviewPlaybackCoordinator review;
  late int changes;
  setUp(() {
    player = _ControlledPlayer();
    changes = 0;
    review = ReviewPlaybackCoordinator(
      player: player,
      onChanged: () => changes++,
    );
  });

  test(
    'one review reports loading, playing and idle without autoplay',
    () async {
      expect(player.calls, isEmpty);
      final run = review.play(itemIndex: 2, clipId: 'reference', wavBytes: [7]);
      expect(review.state, ReviewPlaybackState.loading);
      await flush();
      expect(player.calls, ['stop', 'play:7']);
      final ended = Completer<void>();
      player.loads.single.complete(PlaybackHandle(ended.future));
      await flush();
      expect(review.state, ReviewPlaybackState.playing);
      expect(review.itemIndex, 2);
      ended.complete();
      await run;
      expect(review.state, ReviewPlaybackState.idle);
      expect(review.itemIndex, isNull);
      expect(changes, greaterThanOrEqualTo(3));
    },
  );

  test(
    'latest request wins even while the old native load is pending',
    () async {
      final first = review.play(
        itemIndex: 0,
        clipId: 'reference',
        wavBytes: [1],
      );
      await flush();
      final second = review.play(
        itemIndex: 3,
        clipId: 'selected',
        wavBytes: [2],
      );
      expect(review.itemIndex, 3);
      expect(player.loads, hasLength(1), reason: 'loads are serialized');
      player.loads.first.complete(PlaybackHandle(Future<void>.value()));
      await first;
      await flush();
      expect(player.loads, hasLength(2));
      final ended = Completer<void>();
      player.loads.last.complete(PlaybackHandle(ended.future));
      await flush();
      expect(review.state, ReviewPlaybackState.playing);
      expect(review.itemIndex, 3);
      expect(review.clipId, 'selected');
      ended.complete();
      await second;
      expect(review.state, ReviewPlaybackState.idle);
    },
  );

  test('stop/load failure is recoverable and does not throw', () async {
    player.stopFailure = StateError('private native detail');
    await review.play(itemIndex: 1, clipId: 'reference', wavBytes: [1]);
    expect(review.state, ReviewPlaybackState.failed);
    expect(review.itemIndex, 1);
    player.stopFailure = null;
    final retry = review.play(itemIndex: 1, clipId: 'reference', wavBytes: [2]);
    await flush();
    player.loads.single.complete(PlaybackHandle(Future<void>.value()));
    await retry;
    expect(review.state, ReviewPlaybackState.idle);
  });

  test(
    'cancel and close stop queued work; detached close has no callback',
    () async {
      final run = review.play(itemIndex: 0, clipId: 'reference', wavBytes: [1]);
      await flush();
      player.stopFailure = StateError('cancel stop failed');
      final cancel = review.cancel();
      player.loads.single.complete(PlaybackHandle(Future<void>.value()));
      await run;
      await cancel;
      expect(review.state, ReviewPlaybackState.idle);
      player.stopFailure = null;
      final before = changes;
      review.detach();
      await review.close();
      expect(review.state, ReviewPlaybackState.closed);
      expect(changes, before);
      await review.play(itemIndex: 0, clipId: 'reference', wavBytes: [9]);
      expect(player.calls.where((c) => c == 'play:9'), isEmpty);
    },
  );
}
