import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/audio/capture_quality.dart';
import '../domain/audio/pitch_deviation.dart';
import '../domain/audio/recording_pitch_analyzer.dart';

enum SingleToneSessionPhase {
  idle,
  calibrating,
  preparing,
  referencePlaying,
  waiting,
  responding,
  assessing,
  analyzing,
  finished,
  closed,
}

/// Every reason is a neutral retry, never a student error or a zero score.
enum SessionRetryReason {
  calibrationRequired,
  permissionDenied,
  routeUnsupported,
  interrupted,
  captureFailed,
  quality,
  analysisFailed,
}

class SingleToneSessionOutcome {
  const SingleToneSessionOutcome._({
    this.retryReason,
    this.quality,
    this.evidence,
    this.deviation,
    required this.routeDecision,
  });

  /// SESSION-01 produces no score or success until VAD-01 + BENCH-01 pass and
  /// a reviewed decision connects CORE-01. Do not flip without that evidence.
  static const scoringEnabled = false;

  final SessionRetryReason? retryReason;
  final CaptureQualityReport? quality;
  final RecordingPitchEvidence? evidence;

  /// Representative observed Hz vs target, octave preserved. Diagnostic only.
  final PitchDeviation? deviation;
  final RouteDecision routeDecision;

  bool get needsRetry => retryReason != null;
}

/// Product single-tone attempt: reference → wait → answer window → quality
/// gate → unscored diagnostics or neutral retry. Capture never overlaps the
/// reference, the raw answer is deleted right after it is read (ADR-003) and
/// a cancelled attempt cannot publish late results.
class SingleToneSessionController extends ChangeNotifier {
  SingleToneSessionController({
    required this.backend,
    required this.worker,
    required this.targetHz,
    this.responseDelay = const Duration(milliseconds: 500),
    this.responseWindow = const Duration(seconds: 4),
    this.calibrationDuration = const Duration(seconds: 2),
    DateTime Function()? clock,
    this.calibration,
  }) : _now = clock ?? DateTime.now {
    if (!targetHz.isFinite || targetHz <= 0) {
      throw ArgumentError('Target must be a finite positive frequency');
    }
    if (responseWindow <= Duration.zero ||
        responseWindow > const Duration(seconds: 10) ||
        responseDelay.isNegative ||
        calibrationDuration < const Duration(milliseconds: 1)) {
      throw ArgumentError('Invalid session timing');
    }
    if (backend is! AudioRecordingReader) {
      throw ArgumentError('Session backend must expose its recording PCM');
    }
    _interruptions = backend.interruptions.listen(
      (_) => _interrupt(),
      onError: (Object _) => _interrupt(),
    );
  }

  final AudioLabBackend backend;
  final RecordingPitchWorker worker;
  final double targetHz;
  final Duration responseDelay;
  final Duration responseWindow;
  final Duration calibrationDuration;
  final DateTime Function() _now;
  late final StreamSubscription<AudioLabInterruption> _interruptions;

  SingleToneSessionPhase phase = SingleToneSessionPhase.idle;
  NoiseFloorCalibration? calibration;
  SingleToneSessionOutcome? outcome;
  int _epoch = 0;
  Timer? _timer;
  Completer<void>? _wake;
  bool _workerBusy = false;

  bool get _closed => phase == SingleToneSessionPhase.closed;
  bool get canStart =>
      !_workerBusy &&
      (phase == SingleToneSessionPhase.idle ||
          phase == SingleToneSessionPhase.finished);
  bool get canFinishResponse => phase == SingleToneSessionPhase.responding;

  void _set(SingleToneSessionPhase next) {
    if (_closed) return;
    phase = next;
    notifyListeners();
  }

  Future<AudioRouteSnapshot> _route() async {
    final probe = backend;
    if (probe is! AudioRouteProbe) return const AudioRouteSnapshot.unknown();
    try {
      return await (probe as AudioRouteProbe).currentRoute();
    } catch (_) {
      return const AudioRouteSnapshot.unknown();
    }
  }

  /// Waits [duration] unless cancelled or woken early (finishResponse).
  Future<void> _sleep(Duration duration) {
    final wake = _wake = Completer<void>();
    _timer = Timer(duration, () {
      if (!wake.isCompleted) wake.complete();
    });
    return wake.future;
  }

  void _wakeUp() {
    _timer?.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
  }

  Future<void> _cleanup() async {
    try {
      await backend.stopPlayback();
    } finally {
      await backend.discardCapture();
    }
  }

  void _finish(int epoch, SingleToneSessionOutcome result) {
    if (epoch != _epoch || _closed) return;
    outcome = result;
    _set(SingleToneSessionPhase.finished);
  }

  SingleToneSessionOutcome _retry(
    SessionRetryReason reason,
    RouteDecision route, {
    CaptureQualityReport? quality,
  }) => SingleToneSessionOutcome._(
    retryReason: reason,
    routeDecision: route,
    quality: quality,
  );

  Future<bool> _permission(int epoch, RouteDecision route) async {
    final allowed = await backend.requestMicrophonePermission();
    if (epoch != _epoch || _closed) return false;
    if (!allowed) {
      _finish(epoch, _retry(SessionRetryReason.permissionDenied, route));
    }
    return allowed;
  }

  /// Records requested silence for the noise floor and deletes the clip.
  Future<void> calibrate() async {
    if (!canStart) return;
    final epoch = ++_epoch;
    outcome = null;
    calibration = null;
    _set(SingleToneSessionPhase.calibrating);
    final route = await _route();
    final decision = RoutePolicy.assess(route, CapturePurpose.pitchResponse);
    try {
      if (!await _permission(epoch, decision)) return;
      await backend.startCapture();
      if (epoch != _epoch || _closed) return;
      await _sleep(calibrationDuration);
      if (epoch != _epoch || _closed) return;
      final wav = await backend.stopCapture();
      final pcm = await (backend as AudioRecordingReader).readRecording();
      await backend.discardCapture();
      if (epoch != _epoch || _closed) return;
      if (pcm.sampleRateHz != wav.sampleRateHz ||
          pcm.samples.length != wav.sampleCount) {
        throw const FormatException('Calibration metadata mismatch');
      }
      calibration = NoiseFloorCalibrator.measure(
        samples: pcm.samples,
        sampleRateHz: pcm.sampleRateHz,
        route: route,
        measuredAt: _now(),
      );
      _set(SingleToneSessionPhase.idle);
    } catch (_) {
      await _safeCleanup();
      _finish(epoch, _retry(SessionRetryReason.captureFailed, decision));
    }
  }

  /// One attempt. Calibration must be usable for the current route/age; the
  /// sample-rate binding is re-checked by the quality gate after capture.
  Future<void> startAttempt() async {
    if (!canStart) return;
    final epoch = ++_epoch;
    outcome = null;
    _set(SingleToneSessionPhase.preparing);
    final route = await _route();
    if (epoch != _epoch || _closed) return;
    final decision = RoutePolicy.assess(route, CapturePurpose.pitchResponse);
    if (decision == RouteDecision.unsupported) {
      _finish(epoch, _retry(SessionRetryReason.routeUnsupported, decision));
      return;
    }
    final c = calibration;
    final calibrated =
        c != null &&
        c.isUsable &&
        c.stamp.stateFor(
              currentRoute: route,
              currentSampleRateHz: c.stamp.sampleRateHz,
              now: _now(),
            ) ==
            CalibrationState.valid;
    if (!calibrated) {
      _finish(epoch, _retry(SessionRetryReason.calibrationRequired, decision));
      return;
    }
    try {
      // Ask before the reference so a permission dialog never splits
      // listening from answering.
      if (!await _permission(epoch, decision)) return;
      final handle = await backend.playReference();
      if (epoch != _epoch || _closed) return;
      _set(SingleToneSessionPhase.referencePlaying);
      // Cancel/interrupt wakes this wait even if the player never completes.
      final wake = _wake = Completer<void>();
      await Future.any([handle.completed, wake.future]);
      if (epoch != _epoch || _closed) return;
      _set(SingleToneSessionPhase.waiting);
      await _sleep(responseDelay);
      if (epoch != _epoch || _closed) return;
      await backend.startCapture();
      if (epoch != _epoch || _closed) return;
      _set(SingleToneSessionPhase.responding);
      await _sleep(responseWindow);
      if (epoch != _epoch || _closed) return;
      _set(SingleToneSessionPhase.assessing);
      final wav = await backend.stopCapture();
      final pcm = await (backend as AudioRecordingReader).readRecording();
      await backend.discardCapture();
      if (epoch != _epoch || _closed) return;
      if (pcm.sampleRateHz != wav.sampleRateHz ||
          pcm.samples.length != wav.sampleCount) {
        throw const FormatException('Answer metadata mismatch');
      }
      final quality = CaptureQualityAssessor.assess(
        samples: pcm.samples,
        sampleRateHz: pcm.sampleRateHz,
        route: route,
        now: _now(),
        calibration: c,
      );
      if (!quality.allowsAnalysis) {
        _finish(
          epoch,
          _retry(SessionRetryReason.quality, decision, quality: quality),
        );
        return;
      }
      _set(SingleToneSessionPhase.analyzing);
      await _analyze(epoch, pcm, quality, decision);
    } catch (_) {
      await _safeCleanup();
      _finish(epoch, _retry(SessionRetryReason.captureFailed, decision));
    }
  }

  Future<void> _analyze(
    int epoch,
    CapturedAudioSamples pcm,
    CaptureQualityReport quality,
    RouteDecision decision,
  ) async {
    _workerBusy = true;
    try {
      final evidence = await worker.analyze(
        samples: pcm.samples,
        sampleRateHz: pcm.sampleRateHz,
        source: pcm.source,
      );
      final hz = evidence.representativeFrequencyHz;
      _finish(
        epoch,
        SingleToneSessionOutcome._(
          quality: quality,
          evidence: evidence,
          deviation: hz == null
              ? null
              : PitchDeviation(detectedHz: hz, targetHz: targetHz),
          routeDecision: decision,
        ),
      );
    } catch (_) {
      _finish(
        epoch,
        _retry(SessionRetryReason.analysisFailed, decision, quality: quality),
      );
    } finally {
      _workerBusy = false;
      if (!_closed) notifyListeners();
    }
  }

  /// Ends the answer window early; the recording is assessed as usual.
  void finishResponse() {
    if (phase == SingleToneSessionPhase.responding) _wakeUp();
  }

  Future<void> _safeCleanup() async {
    try {
      await _cleanup();
    } catch (_) {
      // Surfaced as captureFailed by the caller; nothing else to release.
    }
  }

  void _interrupt() {
    if (_closed) return;
    final active = const {
      SingleToneSessionPhase.calibrating,
      SingleToneSessionPhase.preparing,
      SingleToneSessionPhase.referencePlaying,
      SingleToneSessionPhase.waiting,
      SingleToneSessionPhase.responding,
      SingleToneSessionPhase.assessing,
      SingleToneSessionPhase.analyzing,
    }.contains(phase);
    if (!active) return;
    final epoch = ++_epoch;
    _wakeUp();
    outcome = null;
    unawaited(
      _safeCleanup().then((_) {
        if (epoch != _epoch || _closed) return;
        outcome = _retry(
          SessionRetryReason.interrupted,
          RouteDecision.unverified,
        );
        _set(SingleToneSessionPhase.finished);
      }),
    );
  }

  /// User cancel: stops audio, deletes any capture, returns to idle.
  Future<void> cancel() async {
    if (_closed) return;
    final epoch = ++_epoch;
    _wakeUp();
    outcome = null;
    await _safeCleanup();
    if (epoch == _epoch) _set(SingleToneSessionPhase.idle);
  }

  Future<void> close() async {
    if (_closed) return;
    ++_epoch;
    _wakeUp();
    phase = SingleToneSessionPhase.closed;
    await _interruptions.cancel();
    await backend.close();
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Session cleanup failed; retry device resource check.');
      }),
    );
    super.dispose();
  }
}
