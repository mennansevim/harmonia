import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/audio/audio_capture.dart';
import '../domain/audio/capture_quality.dart';
import '../domain/audio/recording_pitch_analyzer.dart';

enum AudioLabPhase {
  idle,
  requestingPermission,
  referencePlaying,
  recording,
  calibrating,
  stopping,
  recorded,
  recordingPlaying,
  analyzing,
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

enum AudioLabAnalysisError { unsupportedInput, unavailable }

/// Serializes resource changes; cancel invalidates pending permission/load/end
/// callbacks immediately. Playback completion does not hold the command queue.
class AudioLabController extends ChangeNotifier {
  AudioLabController(
    this.backend, {
    this.recordingLimit = const Duration(seconds: 10),
    this.worker,
    this.calibrationDuration = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
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
  final RecordingPitchWorker? worker;
  final Duration calibrationDuration;
  final DateTime Function() _now;
  RecordingPitchEvidence? diagnostics;

  /// Lab-only: survives cancel/delete; route/rate/age validity is re-checked
  /// against the recording when quality is assessed.
  NoiseFloorCalibration? calibration;
  CaptureQualityReport? quality;
  AudioRouteSnapshot _recordingRoute = const AudioRouteSnapshot.unknown();
  AudioLabAnalysisError? analysisError;
  bool _analysisInFlight = false;
  bool get analysisInFlight => _analysisInFlight;
  bool get canAnalyze =>
      !_closed &&
      !_analysisInFlight &&
      phase == AudioLabPhase.recorded &&
      recording != null &&
      backend is AudioRecordingReader &&
      worker != null;
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
    diagnostics = null;
    quality = null;
    analysisError = null;
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
        diagnostics = null;
        quality = null;
        analysisError = null;
        if (epoch != _epoch || _closed) return;
        _set(AudioLabPhase.requestingPermission);
        final allowed = await backend.requestMicrophonePermission();
        if (epoch != _epoch || _closed) return;
        if (!allowed) {
          _set(AudioLabPhase.error, failure: AudioLabError.permissionDenied);
          return;
        }
        _recordingRoute = await _route();
        if (epoch != _epoch || _closed) return;
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

  bool get canCalibrate => canStart && backend is AudioRecordingReader;

  Future<AudioRouteSnapshot> _route() async {
    final probe = backend;
    if (probe is! AudioRouteProbe) return const AudioRouteSnapshot.unknown();
    try {
      return await (probe as AudioRouteProbe).currentRoute();
    } catch (_) {
      return const AudioRouteSnapshot.unknown();
    }
  }

  /// Records [calibrationDuration] of requested silence, measures the floor
  /// and deletes the clip. Replaces any current recording (UI says so).
  Future<void> calibrateNoiseFloor() {
    final epoch = _epoch;
    return _queue(() async {
      if (epoch != _epoch || !canCalibrate) return;
      try {
        await _cleanup();
        recording = null;
        diagnostics = null;
        quality = null;
        analysisError = null;
        calibration = null;
        if (epoch != _epoch || _closed) return;
        _set(AudioLabPhase.requestingPermission);
        final allowed = await backend.requestMicrophonePermission();
        if (epoch != _epoch || _closed) return;
        if (!allowed) {
          _set(AudioLabPhase.error, failure: AudioLabError.permissionDenied);
          return;
        }
        final route = await _route();
        if (epoch != _epoch || _closed) return;
        await backend.startCapture();
        if (epoch != _epoch || _closed) return;
        _set(AudioLabPhase.calibrating);
        _limitTimer = Timer(calibrationDuration, () {
          unawaited(_finishCalibration(epoch, route));
        });
      } catch (cause) {
        await _fail(cause, epoch);
      }
    });
  }

  Future<void> _finishCalibration(int epoch, AudioRouteSnapshot route) =>
      _queue(() async {
        if (epoch != _epoch || _closed || phase != AudioLabPhase.calibrating) {
          return;
        }
        _set(AudioLabPhase.stopping);
        try {
          final wav = await backend.stopCapture();
          final pcm = await (backend as AudioRecordingReader).readRecording();
          if (epoch != _epoch || _closed) return;
          if (pcm.sampleRateHz != wav.sampleRateHz ||
              pcm.samples.length != wav.sampleCount) {
            throw const FormatException('Calibration metadata mismatch');
          }
          final measured = NoiseFloorCalibrator.measure(
            samples: pcm.samples,
            sampleRateHz: pcm.sampleRateHz,
            route: route,
            measuredAt: _now(),
          );
          await backend.discardCapture();
          if (epoch != _epoch || _closed) return;
          calibration = measured;
          _set(AudioLabPhase.idle);
        } catch (cause) {
          await _fail(cause, epoch);
        }
      });

  Future<void> playReference() => _play(false);

  /// Only file loading holds the resource queue. DSP completion never delays
  /// deletion/close; a cancelled bounded worker may finish but cannot publish.
  Future<void> analyzeRecording() async {
    final epoch = _epoch;
    Future<void>? job;
    await _queue(() async {
      if (epoch != _epoch || !canAnalyze) return;
      final captured = recording!;
      _analysisInFlight = true;
      diagnostics = null;
      quality = null;
      analysisError = null;
      _set(AudioLabPhase.analyzing);
      try {
        final pcm = await (backend as AudioRecordingReader).readRecording();
        if (epoch != _epoch || _closed) {
          _analysisInFlight = false;
          return;
        }
        if (pcm.sampleRateHz != captured.sampleRateHz ||
            pcm.samples.length != captured.sampleCount ||
            pcm.sampleRateHz > 48000 ||
            pcm.sampleRateHz < 8000 ||
            pcm.samples.length > pcm.sampleRateHz * 10) {
          throw const FormatException('Recording analysis budget/metadata');
        }
        // Lab: uncalibrated runs are allowed but labelled; product sessions
        // must require calibration and stop at !allowsAnalysis.
        quality = CaptureQualityAssessor.assess(
          samples: pcm.samples,
          sampleRateHz: pcm.sampleRateHz,
          route: _recordingRoute,
          now: _now(),
          calibration: calibration,
          requireCalibration: false,
        );
        job = _analyzeSnapshot(pcm, epoch);
      } catch (cause) {
        _analysisInFlight = false;
        if (epoch == _epoch && !_closed) {
          analysisError = cause is FormatException
              ? AudioLabAnalysisError.unsupportedInput
              : AudioLabAnalysisError.unavailable;
          _set(AudioLabPhase.recorded);
        }
      }
    });
    await job;
  }

  Future<void> _analyzeSnapshot(CapturedAudioSamples pcm, int epoch) async {
    try {
      final result = await worker!.analyze(
        samples: pcm.samples,
        sampleRateHz: pcm.sampleRateHz,
        source: pcm.source,
      );
      if (epoch == _epoch && !_closed) {
        diagnostics = result;
        _set(AudioLabPhase.recorded);
      }
    } catch (_) {
      if (epoch == _epoch && !_closed) {
        analysisError = AudioLabAnalysisError.unavailable;
        _set(AudioLabPhase.recorded);
      }
    } finally {
      _analysisInFlight = false;
      if (!_closed) notifyListeners();
    }
  }

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
    diagnostics = null;
    quality = null;
    analysisError = null;
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
    diagnostics = null;
    quality = null;
    analysisError = null;
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
