import 'capture_quality.dart';

/// MIC-01 microphone/room readiness check shown before voice exercises.
///
/// A pure mapping from the existing AUD-DEV-05 gates (noise-floor calibration
/// + capture-quality report) to a learner-facing status. It adds NO new
/// thresholds, is not voice detection, not a score and not a success. Every
/// non-[MicCheckStatus.ready] status is a neutral "not counted" hint.
enum MicCheckStatus {
  ready,
  noisyRoom,
  tooQuiet,
  tooLoud,
  permissionDenied,
  notMeasured,
}

/// Why a check ended as [MicCheckStatus.notMeasured]; null otherwise.
enum MicCheckGap {
  /// Sound during the "stay quiet" window: the floor is not trusted.
  activityDuringSilence,

  /// Energy right at the start of the voice window (possible speaker tail).
  earlyActivity,

  /// Route/sample rate changed or the floor expired between the two steps.
  calibrationLost,

  /// Too short, unreadable or out-of-contract PCM.
  invalidCapture,

  /// Recorder failed or the session was interrupted.
  captureFailed,
}

class MicCheckResult {
  const MicCheckResult._(this.status, {this.gap, this.floor, this.voice});

  const MicCheckResult.permissionDenied()
    : this._(MicCheckStatus.permissionDenied);

  const MicCheckResult.captureFailed()
    : this._(MicCheckStatus.notMeasured, gap: MicCheckGap.captureFailed);

  /// Result of the silence step alone. Null means the floor is usable and
  /// the voice step should run.
  static MicCheckResult? afterSilence(NoiseFloorCalibration floor) =>
      switch (floor.status) {
        NoiseFloorStatus.calibrated => null,
        NoiseFloorStatus.tooNoisy => MicCheckResult._(
          MicCheckStatus.noisyRoom,
          floor: floor,
        ),
        // Clipping while the user is silent: the input is overloaded.
        NoiseFloorStatus.clipped => MicCheckResult._(
          MicCheckStatus.tooLoud,
          floor: floor,
        ),
        NoiseFloorStatus.activityDetected => MicCheckResult._(
          MicCheckStatus.notMeasured,
          gap: MicCheckGap.activityDuringSilence,
          floor: floor,
        ),
        NoiseFloorStatus.tooShort ||
        NoiseFloorStatus.invalidInput => MicCheckResult._(
          MicCheckStatus.notMeasured,
          gap: MicCheckGap.invalidCapture,
          floor: floor,
        ),
      };

  /// Result of the voice step, assessed against the usable [floor].
  static MicCheckResult afterVoice(
    NoiseFloorCalibration floor,
    CaptureQualityReport voice,
  ) {
    MicCheckResult result(MicCheckStatus status, [MicCheckGap? gap]) =>
        MicCheckResult._(status, gap: gap, floor: floor, voice: voice);
    return switch (voice.status) {
      CaptureQualityStatus.usable => result(MicCheckStatus.ready),
      CaptureQualityStatus.clipped => result(MicCheckStatus.tooLoud),
      // The floor already passed, so a weak separation means a weak voice
      // at the microphone, not a loud room.
      CaptureQualityStatus.silent ||
      CaptureQualityStatus.insufficientActivity ||
      CaptureQualityStatus.lowSignalToNoise => result(MicCheckStatus.tooQuiet),
      CaptureQualityStatus.suspectedReferenceTail => result(
        MicCheckStatus.notMeasured,
        MicCheckGap.earlyActivity,
      ),
      CaptureQualityStatus.calibrationRequired => result(
        MicCheckStatus.notMeasured,
        MicCheckGap.calibrationLost,
      ),
      CaptureQualityStatus.invalidInput || CaptureQualityStatus.tooShort =>
        result(MicCheckStatus.notMeasured, MicCheckGap.invalidCapture),
    };
  }

  /// Not a score; scoring is deliberately unavailable.
  static const scoringEnabled = false;

  final MicCheckStatus status;
  final MicCheckGap? gap;
  final NoiseFloorCalibration? floor;
  final CaptureQualityReport? voice;

  bool get isReady => status == MicCheckStatus.ready;

  /// Device-uncalibrated dBFS; null when not measured.
  double? get noiseFloorDb => floor?.noiseFloorDb;
  double? get signalToNoiseDb => voice?.signalToNoiseDb;

  /// Raw values only; no audio is kept.
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'version': version,
    'status': status.name,
    'gap': gap?.name,
    'floor': floor?.toJson(),
    'voice': voice?.toJson(),
  };

  static const version = 'mic-check-1';
}
