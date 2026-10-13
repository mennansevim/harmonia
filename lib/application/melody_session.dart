import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/audio/capture_quality.dart';
import '../domain/audio/pitch_segmenter.dart';
import '../domain/audio/recording_pitch_analyzer.dart';
import 'single_tone_session.dart';

/// Declares the reference bound to this backend. A declaration is not content
/// review, rights verification or proof of physical playback.
class DiagnosticMelodyReference {
  DiagnosticMelodyReference({
    required this.id,
    required this.contentVersion,
    required List<double> frequenciesHz,
  }) : frequenciesHz = List.unmodifiable(frequenciesHz) {
    if (id.trim().isEmpty ||
        contentVersion.trim().isEmpty ||
        frequenciesHz.length < 3 ||
        frequenciesHz.length > 5 ||
        frequenciesHz.any((hz) => !hz.isFinite || hz < 80 || hz > 1200)) {
      throw ArgumentError('Need an identified 3–5 note diagnostic reference');
    }
  }
  final String id, contentVersion;
  final List<double> frequenciesHz;
}

/// playReference must play exactly [reference], not the default single C4.
/// Production adapter/content review remains a separate CORE-04b gate.
abstract interface class MelodyReferenceBackend implements AudioLabBackend {
  DiagnosticMelodyReference get reference;
}

class MelodySessionOutcome {
  const MelodySessionOutcome._({
    required this.reference,
    required this.referencePlays,
    required this.routeDecision,
    this.retryReason,
    this.quality,
    this.segments,
  });
  static const scoringEnabled = false;
  final DiagnosticMelodyReference reference;

  /// Completed player callbacks in this attempt, not measured hearing/recall.
  final int referencePlays;
  final RouteDecision routeDecision;
  final SessionRetryReason? retryReason;
  final CaptureQualityReport? quality;
  final PitchSegmentationEvidence? segments;
  bool get needsRetry => retryReason != null;
}

/// CORE-04a local, unscored diagnostic session. Reuses SESSION-01 capture,
/// calibration/quality and epoch invalidation; its representative deviation is
/// deliberately discarded. No sequence aligner, ExerciseResult or history.
/// Owns backend + delegate; do not use either concurrently outside this facade.
class MelodySessionController extends ChangeNotifier {
  MelodySessionController({
    required MelodyReferenceBackend backend,
    required RecordingPitchWorker worker,
    Duration responseDelay = const Duration(milliseconds: 500),
    Duration responseWindow = const Duration(seconds: 8),
    Duration calibrationDuration = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : reference = backend.reference,
       _session = SingleToneSessionController(
         backend: _SerializedMelodyBackend(backend),
         worker: worker,
         // Only an internal unused representative diagnostic, never a melody
         // target match. Segmentation itself is entirely target-independent.
         targetHz: backend.reference.frequenciesHz.first,
         responseDelay: responseDelay,
         responseWindow: responseWindow,
         calibrationDuration: calibrationDuration,
         clock: clock,
       ) {
    _session.addListener(_changed);
  }
  final DiagnosticMelodyReference reference;
  final SingleToneSessionController _session;
  MelodySessionOutcome? outcome;
  int _epoch = 0, _referencePlays = 0;
  bool _busy = false, _closed = false;
  SingleToneSessionPhase _previous = SingleToneSessionPhase.idle;

  SingleToneSessionPhase get phase => _session.phase;
  NoiseFloorCalibration? get calibration => _session.calibration;
  bool get canStart => !_closed && !_busy && _session.canStart;
  bool get canFinishResponse => !_closed && _session.canFinishResponse;

  void _changed() {
    if (_closed) return;
    if (phase == SingleToneSessionPhase.waiting &&
        _previous == SingleToneSessionPhase.referencePlaying) {
      _referencePlays++;
    }
    _previous = phase;
    final raw = _session.outcome;
    if (raw != null && phase == SingleToneSessionPhase.finished) {
      final evidence = raw.evidence;
      final segments = evidence == null
          ? null
          : PitchSegmenter.fromRecording(evidence);
      outcome = MelodySessionOutcome._(
        reference: reference,
        referencePlays: _referencePlays,
        routeDecision: raw.routeDecision,
        retryReason:
            raw.retryReason ??
            (segments?.status == PitchSegmentationStatus.invalidInput
                ? SessionRetryReason.analysisFailed
                : null),
        quality: raw.quality,
        segments: segments,
      );
    }
    notifyListeners();
  }

  Future<void> calibrate() => _run(_session.calibrate);
  Future<void> startAttempt() => _run(_session.startAttempt);

  Future<void> _run(Future<void> Function() action) async {
    if (!canStart) return;
    final epoch = ++_epoch;
    _busy = true;
    outcome = null;
    _referencePlays = 0;
    try {
      await action();
    } finally {
      // Keep native ownership exclusive until the old operation settles,
      // including permission/read callbacks after cancel. No early restart.
      _busy = false;
      if (!_closed) {
        if (epoch != _epoch && phase == SingleToneSessionPhase.idle) {
          outcome = null;
        }
        notifyListeners();
      }
    }
  }

  void finishResponse() {
    if (!_closed) _session.finishResponse();
  }

  Future<void> cancel() async {
    if (_closed) return;
    ++_epoch;
    outcome = null;
    await _session.cancel();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    ++_epoch;
    outcome = null;
    _session.removeListener(_changed);
    await _session.close();
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Melody session cleanup failed; retry resource check.');
      }),
    );
    // Delegate is detached before asynchronous close; no UI notifications.
    _session.dispose();
    super.dispose();
  }
}

/// Serializes native mutations/reads, not playback completion or DSP. Cancel
/// can invalidate the epoch immediately but must discard *after* a pending
/// startCapture finishes. A failed command must not poison later cleanup.
class _SerializedMelodyBackend
    implements AudioLabBackend, AudioRecordingReader, AudioRouteProbe {
  _SerializedMelodyBackend(this.delegate) {
    if (delegate is! AudioRecordingReader) {
      throw ArgumentError('Melody backend must expose owned recording PCM');
    }
  }
  final MelodyReferenceBackend delegate;
  Future<void> _tail = Future.value();
  Future<T> _queue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Stream<AudioLabInterruption> get interruptions => delegate.interruptions;
  @override
  Future<bool> requestMicrophonePermission() =>
      _queue(delegate.requestMicrophonePermission);
  @override
  Future<void> startCapture() => _queue(delegate.startCapture);
  @override
  Future<CapturedAudio> stopCapture() => _queue(delegate.stopCapture);
  @override
  Future<void> discardCapture() => _queue(delegate.discardCapture);
  @override
  Future<PlaybackHandle> playReference() => _queue(delegate.playReference);
  @override
  Future<PlaybackHandle> playRecording() => _queue(delegate.playRecording);
  @override
  Future<void> stopPlayback() => _queue(delegate.stopPlayback);
  @override
  Future<void> close() => _queue(delegate.close);
  @override
  Future<CapturedAudioSamples> readRecording() =>
      _queue((delegate as AudioRecordingReader).readRecording);
  @override
  Future<AudioRouteSnapshot> currentRoute() => _queue(() async {
    final probe = delegate;
    return probe is AudioRouteProbe
        ? (probe as AudioRouteProbe).currentRoute()
        : const AudioRouteSnapshot.unknown();
  });
}
