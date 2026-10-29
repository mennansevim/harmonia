import 'dart:async';

import '../domain/audio/audio_capture.dart';

enum ReviewPlaybackState { idle, loading, playing, failed, closed }

/// Serializes optional post-result listening on an already-owned player.
/// Review never owns scoring/history; callers provide immutable rendered clips.
class ReviewPlaybackCoordinator {
  ReviewPlaybackCoordinator({required this.player, required this.onChanged});

  final ReferenceClipPlayer player;
  void Function()? onChanged;
  ReviewPlaybackState state = ReviewPlaybackState.idle;
  int? itemIndex;
  String? clipId;
  Future<void> _tail = Future<void>.value();
  Completer<void>? _wake;
  int _generation = 0;

  bool get busy =>
      state == ReviewPlaybackState.loading ||
      state == ReviewPlaybackState.playing;

  void _publish() => onChanged?.call();

  Future<void> play({
    required int itemIndex,
    required String clipId,
    required List<int> wavBytes,
  }) {
    if (state == ReviewPlaybackState.closed || wavBytes.isEmpty) {
      return Future<void>.value();
    }
    final token = ++_generation;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    this.itemIndex = itemIndex;
    this.clipId = clipId;
    state = ReviewPlaybackState.loading;
    _publish();
    final run = _tail.then(
      (_) => _perform(
        token: token,
        itemIndex: itemIndex,
        clipId: clipId,
        wavBytes: wavBytes,
      ),
    );
    _tail = run.catchError((Object _) {});
    return run;
  }

  Future<void> _perform({
    required int token,
    required int itemIndex,
    required String clipId,
    required List<int> wavBytes,
  }) async {
    if (token != _generation || state == ReviewPlaybackState.closed) return;
    try {
      await player.stop();
      if (token != _generation || state == ReviewPlaybackState.closed) return;
      final handle = await player.playWav(wavBytes);
      if (token != _generation || state == ReviewPlaybackState.closed) {
        await player.stop();
        return;
      }
      this.itemIndex = itemIndex;
      this.clipId = clipId;
      state = ReviewPlaybackState.playing;
      _publish();
      final wake = _wake = Completer<void>();
      await Future.any([handle.completed, wake.future]);
      if (token != _generation || state == ReviewPlaybackState.closed) return;
      state = ReviewPlaybackState.idle;
      this.itemIndex = null;
      this.clipId = null;
      _publish();
    } catch (_) {
      if (token != _generation || state == ReviewPlaybackState.closed) return;
      state = ReviewPlaybackState.failed;
      this.itemIndex = itemIndex;
      this.clipId = clipId;
      _publish();
    }
  }

  Future<void> cancel() {
    if (state == ReviewPlaybackState.closed) return _tail;
    ++_generation;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    state = ReviewPlaybackState.idle;
    itemIndex = null;
    clipId = null;
    _publish();
    final run = _tail.then((_) async {
      try {
        await player.stop();
      } catch (_) {
        // Cancellation is best-effort. The generation token still prevents a
        // stale native completion from publishing playback state.
      }
    });
    _tail = run.catchError((Object _) {});
    return run;
  }

  Future<void> close() async {
    if (state == ReviewPlaybackState.closed) return;
    ++_generation;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    state = ReviewPlaybackState.closed;
    itemIndex = null;
    clipId = null;
    await _tail;
    try {
      await player.stop();
    } catch (_) {}
  }

  void detach() => onChanged = null;
}
