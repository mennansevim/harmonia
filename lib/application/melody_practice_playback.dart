import 'dart:async';

import 'package:flutter/foundation.dart';

import 'melody_practice.dart';
import 'melody_session.dart';

enum MelodyPracticePhase { idle, loading, playing, stopping, failed, closed }

enum MelodyPracticeFailure { playbackUnavailable, cleanupFailed }

/// Reference-only rehearsal, never an attempt or a completed learning event.
/// Owns one dedicated player; pending native calls serialize with stop/close,
/// while cancellation never waits for a playback-completion callback.
class MelodyPracticePlayback extends ChangeNotifier {
  MelodyPracticePlayback({required this.reference, required this.player});

  final DiagnosticMelodyReference reference;
  final DiagnosticMelodyPracticePlayer player;
  MelodyPracticePhase phase = MelodyPracticePhase.idle;
  MelodyPracticeFailure? failure;
  DiagnosticMelodyPractice? selection;
  Future<void> _tail = Future.value();
  Future<void>? _closing, _stopping;
  Completer<void>? _wake;
  bool _active = false;
  int _epoch = 0;

  bool get canPlay =>
      !_active &&
      _closing == null &&
      failure != MelodyPracticeFailure.cleanupFailed &&
      (phase == MelodyPracticePhase.idle ||
          phase == MelodyPracticePhase.failed);

  Future<T> _queue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool _current(int epoch) => _closing == null && epoch == _epoch;
  void _set(MelodyPracticePhase next) {
    phase = next;
    notifyListeners();
  }

  Future<void> play(DiagnosticMelodyPractice practice) async {
    if (!identical(practice.reference, reference)) {
      throw ArgumentError('Practice must use the bound reference');
    }
    if (!canPlay) return;
    final epoch = ++_epoch;
    final wake = _wake = Completer<void>();
    _active = true;
    selection = practice;
    failure = null;
    _set(MelodyPracticePhase.loading);
    try {
      final handle = await _queue(() async {
        if (!_current(epoch)) return null;
        final result = await player.play(practice);
        // A delayed native start may return an already-failed completion after
        // stop/close invalidated this run. Observe it even when never awaited.
        result.completed.ignore();
        return result;
      });
      if (!_current(epoch) || handle == null) return;
      _set(MelodyPracticePhase.playing);
      await Future.any([handle.completed, wake.future]);
      if (!_current(epoch)) return;
      try {
        await _queue(player.stop);
      } catch (_) {
        if (_current(epoch)) {
          failure = MelodyPracticeFailure.cleanupFailed;
          _set(MelodyPracticePhase.failed);
        }
        return;
      }
      if (_current(epoch)) _set(MelodyPracticePhase.idle);
    } catch (_) {
      if (!_current(epoch)) return;
      failure = MelodyPracticeFailure.playbackUnavailable;
      try {
        await _queue(player.stop);
      } catch (_) {
        if (_current(epoch)) failure = MelodyPracticeFailure.cleanupFailed;
      }
      if (_current(epoch)) _set(MelodyPracticePhase.failed);
    } finally {
      _active = false;
      if (_closing == null) notifyListeners();
    }
  }

  void _invalidate() {
    ++_epoch;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  /// Also used on background/focus loss. Does not automatically resume.
  Future<void> stop() {
    if (_closing case final closing?) return closing;
    if (_stopping case final stopping?) return stopping;
    _invalidate();
    _set(MelodyPracticePhase.stopping);
    return _stopping = _stop();
  }

  Future<void> _stop() async {
    try {
      await _queue(player.stop);
      if (_closing == null) {
        // Once cleanup failed, only close can recover resource ownership.
        _set(
          failure == MelodyPracticeFailure.cleanupFailed
              ? MelodyPracticePhase.failed
              : MelodyPracticePhase.idle,
        );
      }
    } catch (_) {
      if (_closing == null) {
        failure = MelodyPracticeFailure.cleanupFailed;
        _set(MelodyPracticePhase.failed);
      }
    } finally {
      _stopping = null;
    }
  }

  Future<void> close() {
    if (_closing case final closing?) return closing;
    _invalidate();
    // Publish no further changes, including after ChangeNotifier disposal.
    phase = MelodyPracticePhase.closed;
    return _closing = _queue(player.close);
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Melody rehearsal cleanup failed; retry resource check.');
      }),
    );
    super.dispose();
  }
}
