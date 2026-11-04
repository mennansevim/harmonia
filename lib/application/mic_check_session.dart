import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/audio/capture_quality.dart';
import '../domain/audio/mic_check.dart';

enum MicCheckPhase {
  idle,
  permission,
  silence,
  getReady,
  voice,
  assessing,
  finished,
  closed,
}

/// MIC-01: permission → requested silence (noise floor) → a comfortable
/// "aaa" (level, clipping, separation) → neutral status. Only starts when the
/// user taps; each clip is read once and discarded right away (ADR-003). A
/// cancelled or interrupted run never publishes a late result.
class MicCheckController extends ChangeNotifier {
  MicCheckController({
    required this.backend,
    this.silenceDuration = const Duration(seconds: 3),
    this.getReadyDuration = const Duration(milliseconds: 800),
    this.voiceDuration = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    if (backend is! AudioRecordingReader) {
      throw ArgumentError('Mic check backend must expose its recording PCM');
    }
    if (silenceDuration <= Duration.zero ||
        voiceDuration <= Duration.zero ||
        voiceDuration > const Duration(seconds: 10) ||
        getReadyDuration.isNegative) {
      throw ArgumentError('Invalid mic check timing');
    }
    _interruptions = backend.interruptions.listen(
      (_) => _interrupt(),
      onError: (Object _) => _interrupt(),
    );
    final levels = backend;
    if (levels is InputLevelSource) {
      _levels = (levels as InputLevelSource).inputLevelDb.listen((db) {
        if (_capturing && !_closed) {
          level = db;
          notifyListeners();
        }
      }, onError: (Object _) {});
    }
  }

  final AudioLabBackend backend;
  final Duration silenceDuration;
  final Duration getReadyDuration;
  final Duration voiceDuration;
  final DateTime Function() _now;
  late final StreamSubscription<AudioLabInterruption> _interruptions;
  StreamSubscription<double>? _levels;

  MicCheckPhase phase = MicCheckPhase.idle;
  MicCheckResult? result;

  /// Live input level (dBFS) while recording. Display only, never assessed.
  double? level;

  int _epoch = 0;
  Timer? _timer;
  Completer<void>? _wake;
  bool _capturing = false;

  bool get _closed => phase == MicCheckPhase.closed;
  bool get canStart =>
      phase == MicCheckPhase.idle || phase == MicCheckPhase.finished;
  bool get isRunning => !canStart && !_closed;

  /// True when the live meter is available for this backend.
  bool get hasLevel => _levels != null;

  void _set(MicCheckPhase next) {
    if (_closed) return;
    phase = next;
    notifyListeners();
  }

  bool _stale(int epoch) => epoch != _epoch || _closed;

  Future<AudioRouteSnapshot> _route() async {
    final probe = backend;
    if (probe is! AudioRouteProbe) return const AudioRouteSnapshot.unknown();
    try {
      return await (probe as AudioRouteProbe).currentRoute();
    } catch (_) {
      return const AudioRouteSnapshot.unknown();
    }
  }

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

  void _finish(int epoch, MicCheckResult value) {
    if (_stale(epoch)) return;
    result = value;
    level = null;
    _set(MicCheckPhase.finished);
  }

  /// Records [duration], reads the PCM once and deletes the clip.
  Future<CapturedAudioSamples?> _record(int epoch, Duration duration) async {
    await backend.startCapture();
    _capturing = true;
    if (_stale(epoch)) return null;
    await _sleep(duration);
    if (_stale(epoch)) return null;
    _capturing = false;
    final wav = await backend.stopCapture();
    final pcm = await (backend as AudioRecordingReader).readRecording();
    await backend.discardCapture();
    if (_stale(epoch)) return null;
    if (pcm.sampleRateHz != wav.sampleRateHz ||
        pcm.samples.length != wav.sampleCount) {
      throw const FormatException('Mic check metadata mismatch');
    }
    return pcm;
  }

  Future<void> start() async {
    if (!canStart) return;
    final epoch = ++_epoch;
    result = null;
    level = null;
    _set(MicCheckPhase.permission);
    try {
      final allowed = await backend.requestMicrophonePermission();
      if (_stale(epoch)) return;
      if (!allowed) {
        _finish(epoch, const MicCheckResult.permissionDenied());
        return;
      }
      final route = await _route();
      if (_stale(epoch)) return;
      _set(MicCheckPhase.silence);
      final silence = await _record(epoch, silenceDuration);
      if (silence == null) return;
      final floor = NoiseFloorCalibrator.measure(
        samples: silence.samples,
        sampleRateHz: silence.sampleRateHz,
        route: route,
        measuredAt: _now(),
      );
      final early = MicCheckResult.afterSilence(floor);
      if (early != null) {
        _finish(epoch, early);
        return;
      }
      _set(MicCheckPhase.getReady);
      await _sleep(getReadyDuration);
      if (_stale(epoch)) return;
      // Re-read: a route change between the steps invalidates the floor.
      final voiceRoute = await _route();
      if (_stale(epoch)) return;
      _set(MicCheckPhase.voice);
      final voice = await _record(epoch, voiceDuration);
      if (voice == null) return;
      _set(MicCheckPhase.assessing);
      final report = CaptureQualityAssessor.assess(
        samples: voice.samples,
        sampleRateHz: voice.sampleRateHz,
        route: voiceRoute,
        now: _now(),
        calibration: floor,
      );
      _finish(epoch, MicCheckResult.afterVoice(floor, report));
    } catch (_) {
      await _safeCleanup();
      _finish(epoch, const MicCheckResult.captureFailed());
    }
  }

  Future<void> _safeCleanup() async {
    _capturing = false;
    try {
      await backend.discardCapture();
    } catch (_) {
      // Reported as captureFailed; nothing else to release.
    }
  }

  void _interrupt() {
    if (!isRunning) return;
    final epoch = ++_epoch;
    _wakeUp();
    unawaited(
      _safeCleanup().then((_) {
        if (epoch != _epoch || _closed) return;
        result = const MicCheckResult.captureFailed();
        level = null;
        _set(MicCheckPhase.finished);
      }),
    );
  }

  /// User cancel: deletes any capture and returns to idle without a result.
  Future<void> cancel() async {
    if (_closed) return;
    final epoch = ++_epoch;
    _wakeUp();
    result = null;
    level = null;
    await _safeCleanup();
    if (epoch == _epoch) _set(MicCheckPhase.idle);
  }

  Future<void> close() async {
    if (_closed) return;
    ++_epoch;
    _wakeUp();
    _capturing = false;
    phase = MicCheckPhase.closed;
    // Release the microphone first; listener teardown may finish later.
    final levels = _levels?.cancel();
    final interruptions = _interruptions.cancel();
    try {
      await backend.discardCapture();
    } finally {
      await backend.close();
      await levels;
      await interruptions;
    }
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Mic check cleanup failed; retry device resource check.');
      }),
    );
    super.dispose();
  }
}
