import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/audio/capture_quality.dart';
import '../domain/audio/reviewed_chord_recording_manifest.dart';
import 'chord_reference_session.dart';

enum ChordResponseCapturePhase {
  idle,
  requestingPermission,
  calibrating,
  calibrationReady,
  referencePlaying,
  readyForResponse,
  startingCapture,
  capturing,
  finalizing,
  captured,
  failed,
  closed,
}

enum ChordResponseCaptureFailure {
  permissionDenied,
  calibrationUnavailable,
  calibrationRejected,
  referenceUnavailable,
  captureUnavailable,
  invalidCapture,
  interrupted,
  cleanupFailed,
}

/// Ephemeral response snapshot. The native/backend recording has already been
/// discarded; this object is not persisted and is not a score or voice claim.
class ChordResponseCapture {
  ChordResponseCapture({
    required this.recording,
    required this.metadata,
    required this.route,
    required CapturedAudioSamples samples,
  }) : samples = CapturedAudioSamples(
         sampleRateHz: samples.sampleRateHz,
         samples: samples.samples,
         source: samples.source,
       );

  final ReviewedChordRecording recording;
  final CapturedAudio metadata;
  final AudioRouteSnapshot route;
  final CapturedAudioSamples samples;

  String get recordingId => recording.id;
}

/// Coordinates reviewed chord playback and one sequential monophonic answer.
///
/// Permission is requested before the first reference so a system dialog never
/// splits listening from recall. Capture is impossible until the complete
/// reference and recall gate are ready. No analysis, score, history or mastery
/// write occurs here.
class ChordResponseCaptureSession extends ChangeNotifier {
  ChordResponseCaptureSession({
    required this.reference,
    required this.backend,
    this.maxResponseDuration = const Duration(seconds: 10),
    this.calibrationDuration = const Duration(seconds: 2),
    ChordRecallDelay? wait,
    DateTime Function()? clock,
  }) : _wait = wait ?? Future<void>.delayed,
       _now = clock ?? DateTime.now {
    if (backend is! AudioRecordingReader ||
        maxResponseDuration <= Duration.zero ||
        maxResponseDuration > const Duration(seconds: 10) ||
        calibrationDuration < const Duration(milliseconds: 1500) ||
        calibrationDuration > const Duration(seconds: 5)) {
      throw ArgumentError('Invalid chord response capture session input');
    }
    _interruptions = backend.interruptions.listen(
      (_) => _interrupt(),
      onError: (Object _) => _interrupt(),
    );
  }

  final ChordReferenceSession reference;
  final AudioLabBackend backend;
  final Duration maxResponseDuration;
  final Duration calibrationDuration;
  final ChordRecallDelay _wait;
  final DateTime Function() _now;
  late final StreamSubscription<AudioLabInterruption> _interruptions;

  ChordResponseCapturePhase phase = ChordResponseCapturePhase.idle;
  ChordResponseCaptureFailure? failure;
  ChordResponseCapture? response;
  NoiseFloorCalibration? calibration;

  Future<void> _captureTail = Future<void>.value();
  Future<void>? _closing;
  Timer? _limitTimer;
  int _epoch = 0;
  bool _busy = false;
  bool _permissionGranted = false;
  AudioRouteSnapshot _captureRoute = const AudioRouteSnapshot.unknown();

  ReviewedChordRecording get recording => reference.recording;
  bool get isClosed => phase == ChordResponseCapturePhase.closed;

  bool get canPlayReference =>
      !isClosed &&
      !_busy &&
      reference.canPlayReference &&
      failure != ChordResponseCaptureFailure.cleanupFailed &&
      phase != ChordResponseCapturePhase.startingCapture &&
      phase != ChordResponseCapturePhase.capturing &&
      phase != ChordResponseCapturePhase.finalizing &&
      phase != ChordResponseCapturePhase.calibrating;

  bool get canCalibrateEnvironment =>
      !isClosed &&
      !_busy &&
      reference.canPlayReference &&
      (phase == ChordResponseCapturePhase.idle ||
          phase == ChordResponseCapturePhase.calibrationReady ||
          phase == ChordResponseCapturePhase.failed);

  bool get canStartResponse =>
      !isClosed &&
      !_busy &&
      phase == ChordResponseCapturePhase.readyForResponse &&
      _permissionGranted &&
      reference.canStartSequentialResponse;

  bool get canStopResponse =>
      !isClosed && !_busy && phase == ChordResponseCapturePhase.capturing;

  void _set(
    ChordResponseCapturePhase next, {
    ChordResponseCaptureFailure? error,
  }) {
    if (isClosed) return;
    phase = next;
    failure = error;
    notifyListeners();
  }

  Future<T> _queueCapture<T>(Future<T> Function() action) {
    final result = _captureTail.then((_) => action());
    _captureTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  bool _current(int epoch) => !isClosed && epoch == _epoch;

  /// Explicit two-second room check. It records silence, snapshots PCM and
  /// deletes the backend-owned file before deriving an in-memory noise floor.
  /// A successful calibration is still not a voice, pitch or score claim.
  Future<void> calibrateEnvironment() async {
    if (!canCalibrateEnvironment) return;
    final epoch = ++_epoch;
    _busy = true;
    response = null;
    calibration = null;
    failure = null;
    try {
      await _queueCapture(backend.discardCapture);
      if (!_current(epoch)) return;
      if (!_permissionGranted) {
        _set(ChordResponseCapturePhase.requestingPermission);
        final allowed = await _queueCapture(
          backend.requestMicrophonePermission,
        );
        if (!_current(epoch)) return;
        if (!allowed) {
          _set(
            ChordResponseCapturePhase.failed,
            error: ChordResponseCaptureFailure.permissionDenied,
          );
          return;
        }
        _permissionGranted = true;
      }

      final route = await _queueCapture(_readRoute);
      if (!_current(epoch)) return;
      _set(ChordResponseCapturePhase.calibrating);
      await _queueCapture(backend.startCapture);
      if (!_current(epoch)) {
        await _queueCapture(backend.discardCapture);
        return;
      }
      await _wait(calibrationDuration);
      if (!_current(epoch)) return;
      final result = await _queueCapture(() async {
        final metadata = await backend.stopCapture();
        final samples = await (backend as AudioRecordingReader).readRecording();
        await backend.discardCapture();
        return (metadata: metadata, samples: samples);
      });
      if (!_current(epoch)) return;
      if (!_validCalibrationCapture(result.metadata, result.samples)) {
        _set(
          ChordResponseCapturePhase.failed,
          error: ChordResponseCaptureFailure.calibrationUnavailable,
        );
        return;
      }
      calibration = NoiseFloorCalibrator.measure(
        samples: result.samples.samples,
        sampleRateHz: result.samples.sampleRateHz,
        route: route,
        measuredAt: _now(),
      );
      if (calibration!.isUsable) {
        _set(ChordResponseCapturePhase.calibrationReady);
      } else {
        _set(
          ChordResponseCapturePhase.failed,
          error: ChordResponseCaptureFailure.calibrationRejected,
        );
      }
    } catch (_) {
      if (_current(epoch)) {
        await _failAndDiscard(
          epoch,
          ChordResponseCaptureFailure.calibrationUnavailable,
        );
      }
    } finally {
      _busy = false;
      if (_current(epoch)) notifyListeners();
    }
  }

  bool _validCalibrationCapture(
    CapturedAudio metadata,
    CapturedAudioSamples samples,
  ) =>
      metadata.sampleRateHz == samples.sampleRateHz &&
      metadata.sampleCount == samples.samples.length &&
      samples.sampleRateHz >= 8000 &&
      samples.sampleRateHz <= 48000 &&
      metadata.durationSeconds >= NoiseFloorCalibrator.minSeconds &&
      metadata.durationSeconds <= NoiseFloorCalibrator.maxSeconds;

  /// Explicit listen/replay action. It never starts response capture.
  Future<void> playReference() async {
    if (!canPlayReference) return;
    final epoch = ++_epoch;
    _busy = true;
    response = null;
    failure = null;
    try {
      await _queueCapture(backend.discardCapture);
      if (!_current(epoch)) return;
      if (!_permissionGranted) {
        _set(ChordResponseCapturePhase.requestingPermission);
        final allowed = await _queueCapture(
          backend.requestMicrophonePermission,
        );
        if (!_current(epoch)) return;
        if (!allowed) {
          _set(
            ChordResponseCapturePhase.failed,
            error: ChordResponseCaptureFailure.permissionDenied,
          );
          return;
        }
        _permissionGranted = true;
      }
      _set(ChordResponseCapturePhase.referencePlaying);
      await reference.playReference();
      if (!_current(epoch)) return;
      if (reference.canStartSequentialResponse) {
        _set(ChordResponseCapturePhase.readyForResponse);
      } else {
        _set(
          ChordResponseCapturePhase.failed,
          error: ChordResponseCaptureFailure.referenceUnavailable,
        );
      }
    } catch (_) {
      if (_current(epoch)) {
        await _failAndDiscard(
          epoch,
          ChordResponseCaptureFailure.referenceUnavailable,
        );
      }
    } finally {
      _busy = false;
      if (_current(epoch)) notifyListeners();
    }
  }

  /// Starts a single continuous recording for the student's sequential notes.
  Future<void> startResponse() async {
    if (!canStartResponse) return;
    final epoch = _epoch;
    _busy = true;
    _set(ChordResponseCapturePhase.startingCapture);
    try {
      _captureRoute = await _queueCapture(_readRoute);
      if (!_current(epoch) || !reference.canStartSequentialResponse) return;
      await _queueCapture(backend.startCapture);
      if (!_current(epoch) || !reference.canStartSequentialResponse) {
        await _queueCapture(backend.discardCapture);
        return;
      }
      _set(ChordResponseCapturePhase.capturing);
      _limitTimer = Timer(maxResponseDuration, () {
        unawaited(stopResponse());
      });
    } catch (_) {
      if (_current(epoch)) {
        await _failAndDiscard(
          epoch,
          ChordResponseCaptureFailure.captureUnavailable,
        );
      }
    } finally {
      _busy = false;
      if (_current(epoch)) notifyListeners();
    }
  }

  /// Stops, snapshots and deletes the backend-owned recording. The snapshot is
  /// input for a later diagnostic worker; this method does not analyze it.
  Future<void> stopResponse() async {
    if (!canStopResponse) return;
    final epoch = _epoch;
    _busy = true;
    _limitTimer?.cancel();
    _set(ChordResponseCapturePhase.finalizing);
    try {
      final result = await _queueCapture(() async {
        final metadata = await backend.stopCapture();
        final samples = await (backend as AudioRecordingReader).readRecording();
        await backend.discardCapture();
        return (metadata: metadata, samples: samples);
      });
      if (!_current(epoch)) return;
      final metadata = result.metadata;
      final samples = result.samples;
      if (metadata.sampleRateHz != samples.sampleRateHz ||
          metadata.sampleCount != samples.samples.length ||
          samples.sampleRateHz < 8000 ||
          samples.sampleRateHz > 48000 ||
          metadata.sampleCount == 0 ||
          metadata.durationSeconds > maxResponseDuration.inMicroseconds / 1e6) {
        _set(
          ChordResponseCapturePhase.failed,
          error: ChordResponseCaptureFailure.invalidCapture,
        );
        return;
      }
      response = ChordResponseCapture(
        recording: recording,
        metadata: metadata,
        route: _captureRoute,
        samples: samples,
      );
      _set(ChordResponseCapturePhase.captured);
    } catch (_) {
      if (_current(epoch)) {
        await _failAndDiscard(
          epoch,
          ChordResponseCaptureFailure.captureUnavailable,
        );
      }
    } finally {
      _busy = false;
      if (_current(epoch)) notifyListeners();
    }
  }

  Future<void> _failAndDiscard(
    int epoch,
    ChordResponseCaptureFailure reason,
  ) async {
    var resolved = reason;
    try {
      await _queueCapture(backend.discardCapture);
    } catch (_) {
      resolved = ChordResponseCaptureFailure.cleanupFailed;
    }
    if (_current(epoch)) {
      response = null;
      _set(ChordResponseCapturePhase.failed, error: resolved);
    }
  }

  Future<AudioRouteSnapshot> _readRoute() async {
    final probe = backend;
    if (probe is! AudioRouteProbe) return const AudioRouteSnapshot.unknown();
    try {
      return await (probe as AudioRouteProbe).currentRoute();
    } catch (_) {
      return const AudioRouteSnapshot.unknown();
    }
  }

  Future<void> cancel() => _cancel(interrupted: false);

  Future<void> _cancel({required bool interrupted}) async {
    if (isClosed) return;
    final epoch = ++_epoch;
    _busy = true;
    _limitTimer?.cancel();
    response = null;
    calibration = null;
    Object? cleanupFailure;
    try {
      await reference.stop();
    } catch (error) {
      cleanupFailure = error;
    }
    try {
      await _queueCapture(backend.discardCapture);
    } catch (error) {
      cleanupFailure ??= error;
    }
    if (_current(epoch)) {
      _busy = false;
      if (cleanupFailure != null) {
        _set(
          ChordResponseCapturePhase.failed,
          error: ChordResponseCaptureFailure.cleanupFailed,
        );
      } else if (interrupted) {
        _set(
          ChordResponseCapturePhase.failed,
          error: ChordResponseCaptureFailure.interrupted,
        );
      } else {
        _set(ChordResponseCapturePhase.idle);
      }
    }
  }

  void _interrupt() {
    if (!isClosed) unawaited(_cancel(interrupted: true));
  }

  Future<void> close() {
    if (_closing case final closing?) return closing;
    ++_epoch;
    _busy = true;
    _limitTimer?.cancel();
    response = null;
    calibration = null;
    phase = ChordResponseCapturePhase.closed;
    return _closing = _close();
  }

  Future<void> _close() async {
    Object? firstFailure;
    try {
      await _interruptions.cancel();
    } catch (error) {
      firstFailure = error;
    }
    try {
      await reference.close();
    } catch (error) {
      firstFailure ??= error;
    }
    try {
      await _queueCapture(() async {
        try {
          await backend.discardCapture();
        } finally {
          await backend.close();
        }
      });
    } catch (error) {
      firstFailure ??= error;
    }
    if (firstFailure != null) throw firstFailure;
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Chord capture cleanup failed; retry resource check.');
      }),
    );
    super.dispose();
  }
}
