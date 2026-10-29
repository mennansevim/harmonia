import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/audio/reviewed_chord_recording_manifest.dart';
import '../domain/models/exercise.dart';

enum ChordReferencePhase {
  idle,
  loading,
  playing,
  recallDelay,
  readyForSequentialResponse,
  stopping,
  failed,
  closed,
}

enum ChordReferenceFailure { playbackUnavailable, cleanupFailed }

typedef ChordRecallDelay = Future<void> Function(Duration duration);

/// Owns playback for one reviewed 2/3/4-note piano reference.
///
/// It never starts automatically and never opens the microphone, scores a
/// response or writes progress. A sequential-response UI may become available
/// only after the complete reference and configured recall delay have finished.
class ChordReferenceSession extends ChangeNotifier {
  ChordReferenceSession({
    required this.recording,
    required List<int> wavBytes,
    required this.player,
    this.recallDelay = const Duration(milliseconds: 650),
    this.mode = ExerciseMode.learning,
    this.maxReferencePlays = 1,
    ChordRecallDelay? wait,
  }) : _wavBytes = Uint8List.fromList(wavBytes),
       _wait = wait ?? Future<void>.delayed {
    validateInput(
      wavBytes: wavBytes,
      recallDelay: recallDelay,
      mode: mode,
      maxReferencePlays: maxReferencePlays,
    );
  }

  /// Shared by composition code so invalid policy never allocates a player.
  static void validateInput({
    required List<int> wavBytes,
    required Duration recallDelay,
    required ExerciseMode mode,
    required int maxReferencePlays,
  }) {
    if (wavBytes.isEmpty ||
        recallDelay.isNegative ||
        recallDelay > const Duration(seconds: 10) ||
        (mode != ExerciseMode.learning && mode != ExerciseMode.recallExam) ||
        maxReferencePlays < 1 ||
        maxReferencePlays > 10 ||
        (mode == ExerciseMode.recallExam && maxReferencePlays != 1)) {
      throw ArgumentError('Invalid chord reference session input');
    }
  }

  final ReviewedChordRecording recording;
  final ReferenceClipPlayer player;
  final Duration recallDelay;
  final ExerciseMode mode;
  final int maxReferencePlays;
  final Uint8List _wavBytes;
  final ChordRecallDelay _wait;

  ChordReferencePhase phase = ChordReferencePhase.idle;
  ChordReferenceFailure? failure;
  int referencePlays = 0;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  Future<void>? _stopping;
  Completer<void>? _wake;
  bool _active = false;
  int _epoch = 0;

  bool get canPlayReference =>
      !_active &&
      _closing == null &&
      referencePlays < maxReferencePlays &&
      failure != ChordReferenceFailure.cleanupFailed &&
      (phase == ChordReferencePhase.idle ||
          phase == ChordReferencePhase.readyForSequentialResponse ||
          phase == ChordReferencePhase.failed);

  bool get canStartSequentialResponse =>
      !_active &&
      _closing == null &&
      failure == null &&
      phase == ChordReferencePhase.readyForSequentialResponse;

  bool get referencePlayLimitReached => referencePlays >= maxReferencePlays;

  bool get targetVisibleDuringResponse => mode != ExerciseMode.recallExam;

  Future<T> _queue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  bool _current(int epoch) => _closing == null && epoch == _epoch;

  void _set(ChordReferencePhase next) {
    phase = next;
    notifyListeners();
  }

  /// Explicit user action. Repeated calls while a run is active are ignored.
  Future<void> playReference() async {
    if (!canPlayReference) return;
    final epoch = ++_epoch;
    final wake = _wake = Completer<void>();
    _active = true;
    failure = null;
    _set(ChordReferencePhase.loading);
    try {
      final handle = await _queue(() async {
        if (!_current(epoch)) return null;
        final result = await player.playWav(Uint8List.fromList(_wavBytes));
        // Always observe a late native completion after stop/close wins.
        result.completed.ignore();
        return result;
      });
      if (!_current(epoch) || handle == null) return;
      _set(ChordReferencePhase.playing);
      await Future.any([handle.completed, wake.future]);
      if (!_current(epoch)) return;
      referencePlays++;

      try {
        await _queue(player.stop);
      } catch (_) {
        if (_current(epoch)) {
          failure = ChordReferenceFailure.cleanupFailed;
          _set(ChordReferencePhase.failed);
        }
        return;
      }
      if (!_current(epoch)) return;

      _set(ChordReferencePhase.recallDelay);
      final delayed = _wait(recallDelay);
      delayed.ignore();
      await Future.any([delayed, wake.future]);
      if (_current(epoch)) {
        _set(ChordReferencePhase.readyForSequentialResponse);
      }
    } catch (_) {
      if (!_current(epoch)) return;
      failure = ChordReferenceFailure.playbackUnavailable;
      try {
        await _queue(player.stop);
      } catch (_) {
        if (_current(epoch)) failure = ChordReferenceFailure.cleanupFailed;
      }
      if (_current(epoch)) _set(ChordReferencePhase.failed);
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

  /// Used for explicit cancel, app backgrounding and audio-route interruption.
  /// A stopped reference never resumes and never leaves response input ready.
  Future<void> stop() {
    if (_closing case final closing?) return closing;
    if (_stopping case final stopping?) return stopping;
    _invalidate();
    _set(ChordReferencePhase.stopping);
    return _stopping = _stop();
  }

  Future<void> _stop() async {
    try {
      await _queue(player.stop);
      if (_closing == null) {
        _set(
          failure == ChordReferenceFailure.cleanupFailed
              ? ChordReferencePhase.failed
              : ChordReferencePhase.idle,
        );
      }
    } catch (_) {
      if (_closing == null) {
        failure = ChordReferenceFailure.cleanupFailed;
        _set(ChordReferencePhase.failed);
      }
    } finally {
      _stopping = null;
    }
  }

  Future<void> handleInterruption(AudioLabInterruption _) => stop();

  Future<void> close() {
    if (_closing case final closing?) return closing;
    _invalidate();
    phase = ChordReferencePhase.closed;
    return _closing = _queue(() async {
      Object? firstFailure;
      try {
        await player.stop();
      } catch (error) {
        firstFailure = error;
      }
      try {
        await player.close();
      } catch (error) {
        firstFailure ??= error;
      }
      if (firstFailure != null) throw firstFailure;
    });
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Chord reference cleanup failed; retry resource check.');
      }),
    );
    super.dispose();
  }
}
