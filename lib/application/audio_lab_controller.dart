import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/audio/audio_capture.dart';

enum AudioLabPhase {
  idle,
  requestingPermission,
  referencePlaying,
  recording,
  stopping,
  recorded,
  recordingPlaying,
  cancelling,
  error,
  closed,
}

enum AudioLabError {
  permissionDenied,
  unsupportedFormat,
  unavailable,
  cleanupFailed,
}

/// Serializes resource changes; cancel invalidates pending permission/load/end
/// callbacks immediately. Playback completion does not hold the command queue.
class AudioLabController extends ChangeNotifier {
  AudioLabController(
    this.backend, {
    this.recordingLimit = const Duration(seconds: 10),
  }) {
    if (recordingLimit <= Duration.zero ||
        recordingLimit > const Duration(seconds: 10)) {
      throw ArgumentError('Recording limit must be 0–10 seconds');
    }
    _interruptions = backend.interruptions.listen(
      (_) {
        if (phase != AudioLabPhase.idle &&
            phase != AudioLabPhase.recorded &&
            phase != AudioLabPhase.error &&
            !_closed) {
          unawaited(cancel());
        }
      },
      onError: (Object error) {
        if (!_closed) unawaited(cancel());
      },
    );
  }
  final AudioLabBackend backend;
  final Duration recordingLimit;
  late final StreamSubscription<AudioLabInterruption> _interruptions;
  AudioLabPhase phase = AudioLabPhase.idle;
  AudioLabError? error;
  CapturedAudio? recording;
  Future<void> _pending = Future.value();
  Future<void>? _shutdown;
  Timer? _limitTimer;
  int _epoch = 0;
  bool _closed = false;
  bool get canStart =>
      !_closed &&
      [
        AudioLabPhase.idle,
        AudioLabPhase.recorded,
        AudioLabPhase.error,
      ].contains(phase);

  void _set(AudioLabPhase next, {AudioLabError? failure}) {
    if (_closed) return;
    phase = next;
    error = failure;
    notifyListeners();
  }

  Future<void> _queue(Future<void> Function() action) {
    _pending = _pending.then((_) => action());
    return _pending;
  }

  Future<void> _cleanup() async {
    try {
      await backend.stopPlayback();
    } finally {
      await backend.discardCapture();
    }
  }

  Future<void> _fail(Object cause, int epoch) async {
    var failure = cause is FormatException
        ? AudioLabError.unsupportedFormat
        : AudioLabError.unavailable;
    _limitTimer?.cancel();
    recording = null;
    try {
      await _cleanup();
    } catch (_) {
      failure = AudioLabError.cleanupFailed;
    }
    if (epoch == _epoch) _set(AudioLabPhase.error, failure: failure);
  }

  Future<void> startRecording() {
    final epoch = _epoch;
    return _queue(() async {
      if (epoch != _epoch || !canStart) return;
      try {
        await _cleanup();
        recording = null;
        if (epoch != _epoch || _closed) return;
        _set(AudioLabPhase.requestingPermission);
        final allowed = await backend.requestMicrophonePermission();
        if (epoch != _epoch || _closed) return;
        if (!allowed) {
          _set(AudioLabPhase.error, failure: AudioLabError.permissionDenied);
          return;
        }
        await backend.startCapture();
        if (epoch != _epoch || _closed) return;
        _set(AudioLabPhase.recording);
        _limitTimer = Timer(recordingLimit, () {
          unawaited(stopRecording());
        });
      } catch (cause) {
        await _fail(cause, epoch);
      }
    });
  }

  Future<void> stopRecording() {
    final epoch = _epoch;
    return _queue(() async {
      if (epoch != _epoch || _closed || phase != AudioLabPhase.recording) {
        return;
      }
      _limitTimer?.cancel();
      _set(AudioLabPhase.stopping);
      try {
        final wav = await backend.stopCapture();
        if (wav.sampleCount == 0 || wav.durationSeconds > 11) {
          throw const FormatException('Empty/oversized capture');
        }
        if (epoch != _epoch || _closed) return;
        recording = wav;
        _set(AudioLabPhase.recorded);
      } catch (cause) {
        await _fail(cause, epoch);
      }
    });
  }

  Future<void> playReference() => _play(false);
  Future<void> playRecording() => _play(true);
  Future<void> _play(bool replay) {
    final epoch = _epoch;
    return _queue(() async {
      if (epoch != _epoch || !canStart || (replay && recording == null)) return;
      final playingPhase = replay
          ? AudioLabPhase.recordingPlaying
          : AudioLabPhase.referencePlaying;
      _set(playingPhase);
      try {
        final handle = replay
            ? await backend.playRecording()
            : await backend.playReference();
        unawaited(
          handle.completed.then(
            (_) => epoch != _epoch || _closed
                ? Future<void>.value()
                : _queue(() async {
                    if (epoch == _epoch && !_closed && phase == playingPhase) {
                      _set(
                        recording == null
                            ? AudioLabPhase.idle
                            : AudioLabPhase.recorded,
                      );
                    }
                  }),
            onError: (Object cause) => epoch != _epoch || _closed
                ? Future<void>.value()
                : _queue(() async {
                    if (epoch == _epoch && !_closed) await _fail(cause, epoch);
                  }),
          ),
        );
      } catch (cause) {
        await _fail(cause, epoch);
      }
    });
  }

  /// Cancels and deletes the current capture, including completed recordings.
  Future<void> cancel() {
    if (_closed) return _shutdown ?? Future.value();
    final epoch = ++_epoch;
    _limitTimer?.cancel();
    recording = null;
    _set(AudioLabPhase.cancelling);
    return _queue(() async {
      try {
        await _cleanup();
        if (epoch == _epoch) _set(AudioLabPhase.idle);
      } catch (_) {
        if (epoch == _epoch) {
          _set(AudioLabPhase.error, failure: AudioLabError.cleanupFailed);
        }
      }
    });
  }

  Future<void> shutdown() {
    if (_shutdown != null) return _shutdown!;
    _closed = true;
    ++_epoch;
    _limitTimer?.cancel();
    recording = null;
    phase = AudioLabPhase.closed;
    _shutdown = _queue(() async {
      await _interruptions.cancel();
      await backend.close();
    });
    return _shutdown!;
  }

  @override
  void dispose() {
    unawaited(
      shutdown().catchError((Object _) {
        debugPrint('Audio lab cleanup failed; retry device resource check.');
      }),
    );
    super.dispose();
  }
}
