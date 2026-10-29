import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/audio/pitch_sequence_alignment.dart';
import '../domain/models/exercise_protocol.dart';
import 'chord_response_capture_session.dart';
import 'chord_response_diagnostic_analyzer.dart';

enum ChordResponseAttemptPhase {
  idle,
  analyzing,
  qualityRetry,
  analysisUnavailable,
  diagnosticAvailable,
  closed,
}

/// CONS-02f composition boundary for one reviewed chord attempt.
///
/// The coordinator enforces calibrate → listen → sequential response →
/// quality-gated diagnostic analysis. It never converts candidate evidence
/// into a score, result-history row, mastery state, admission claim or AI input.
class ChordResponseAttemptCoordinator extends ChangeNotifier {
  ChordResponseAttemptCoordinator({
    required this.session,
    required this.analyzer,
    this.responseOrder = ResponseOrder.exact,
    this.toleranceCents = PitchSequenceAligner.defaultToleranceCents,
  }) {
    if (!toleranceCents.isFinite ||
        toleranceCents < 0 ||
        toleranceCents > 100) {
      throw ArgumentError('Invalid chord response tolerance');
    }
    session.addListener(_sessionChanged);
  }

  final ChordResponseCaptureSession session;
  final ChordResponseDiagnosticAnalyzer analyzer;
  final ResponseOrder responseOrder;
  final double toleranceCents;

  ChordResponseAttemptPhase phase = ChordResponseAttemptPhase.idle;
  ChordResponseDiagnosticOutcome? outcome;

  int _analysisEpoch = 0;
  ChordResponseCapture? _activeCapture;
  Future<void>? _closing;
  bool _disposed = false;

  bool get isClosed => phase == ChordResponseAttemptPhase.closed;

  bool get canCalibrateEnvironment =>
      !isClosed &&
      phase != ChordResponseAttemptPhase.analyzing &&
      session.canCalibrateEnvironment;

  /// Product flow requires a usable room measurement before reference audio.
  bool get canPlayReference =>
      !isClosed &&
      phase != ChordResponseAttemptPhase.analyzing &&
      session.calibration?.isUsable == true &&
      session.canPlayReference;

  bool get canStartResponse =>
      !isClosed &&
      phase != ChordResponseAttemptPhase.analyzing &&
      session.calibration?.isUsable == true &&
      session.canStartResponse;

  bool get canStopAndAnalyze =>
      !isClosed &&
      phase != ChordResponseAttemptPhase.analyzing &&
      session.canStopResponse;

  bool get canAnalyzeCapturedResponse =>
      !isClosed &&
      phase != ChordResponseAttemptPhase.analyzing &&
      session.phase == ChordResponseCapturePhase.captured &&
      session.response != null;

  Future<void> calibrateEnvironment() async {
    if (!canCalibrateEnvironment) return;
    _clearAnalysis();
    await session.calibrateEnvironment();
  }

  Future<void> playReference() async {
    if (!canPlayReference) return;
    _clearAnalysis();
    await session.playReference();
  }

  Future<void> startResponse() async {
    if (!canStartResponse) return;
    _clearAnalysis();
    await session.startResponse();
  }

  /// Stops capture first. Analysis starts only if the session produced one
  /// complete immutable response snapshot.
  Future<void> stopAndAnalyze() async {
    if (!canStopAndAnalyze) return;
    await session.stopResponse();
    if (canAnalyzeCapturedResponse) await analyzeCapturedResponse();
  }

  Future<void> analyzeCapturedResponse() async {
    if (!canAnalyzeCapturedResponse) return;
    final capture = session.response!;
    final calibration = session.calibration;
    final epoch = ++_analysisEpoch;
    _activeCapture = capture;
    outcome = null;
    phase = ChordResponseAttemptPhase.analyzing;
    _notify();

    final result = await analyzer.analyze(
      capture: capture,
      calibration: calibration,
      responseOrder: responseOrder,
      toleranceCents: toleranceCents,
    );
    if (isClosed ||
        epoch != _analysisEpoch ||
        !identical(session.response, capture) ||
        session.phase != ChordResponseCapturePhase.captured) {
      return;
    }
    _activeCapture = null;
    outcome = result;
    phase = switch (result.status) {
      ChordResponseDiagnosticStatus.qualityRejected =>
        ChordResponseAttemptPhase.qualityRetry,
      ChordResponseDiagnosticStatus.analysisUnavailable =>
        ChordResponseAttemptPhase.analysisUnavailable,
      ChordResponseDiagnosticStatus.diagnosticAvailable =>
        ChordResponseAttemptPhase.diagnosticAvailable,
    };
    _notify();
  }

  Future<void> cancel() async {
    if (isClosed) return;
    _clearAnalysis();
    await session.cancel();
  }

  void _sessionChanged() {
    if (isClosed) return;
    final responseStillCurrent =
        session.phase == ChordResponseCapturePhase.captured &&
        identical(session.response, _activeCapture);
    if (phase == ChordResponseAttemptPhase.analyzing && !responseStillCurrent) {
      _clearAnalysis(notify: false);
    } else if (phase != ChordResponseAttemptPhase.analyzing &&
        (session.phase != ChordResponseCapturePhase.captured ||
            session.response == null)) {
      outcome = null;
      if (phase != ChordResponseAttemptPhase.idle) {
        phase = ChordResponseAttemptPhase.idle;
      }
    }
    _notify();
  }

  void _clearAnalysis({bool notify = true}) {
    _analysisEpoch++;
    _activeCapture = null;
    outcome = null;
    if (!isClosed) phase = ChordResponseAttemptPhase.idle;
    if (notify) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> close() {
    if (_closing case final closing?) return closing;
    _analysisEpoch++;
    _activeCapture = null;
    outcome = null;
    phase = ChordResponseAttemptPhase.closed;
    session.removeListener(_sessionChanged);
    _notify();
    return _closing = session.close();
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Chord attempt cleanup failed; retry resource check.');
      }),
    );
    _disposed = true;
    super.dispose();
  }
}
