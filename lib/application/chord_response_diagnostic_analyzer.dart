import '../domain/audio/capture_quality.dart';
import '../domain/audio/chord_response_matcher.dart';
import '../domain/audio/pitch_segmenter.dart';
import '../domain/audio/pitch_sequence_alignment.dart';
import '../domain/audio/recording_pitch_analyzer.dart';
import '../domain/models/exercise_protocol.dart';
import 'chord_response_capture_session.dart';

enum ChordResponseDiagnosticStatus {
  qualityRejected,
  analysisUnavailable,
  diagnosticAvailable,
}

/// Quality-gated diagnostic evidence. Even a candidate match is not a score,
/// learner identity/voice decision, memory result, history or mastery update.
class ChordResponseDiagnosticOutcome {
  const ChordResponseDiagnosticOutcome._({
    required this.status,
    required this.quality,
    this.pitch,
    this.segmentation,
    this.comparison,
  });

  final ChordResponseDiagnosticStatus status;
  final CaptureQualityReport quality;
  final RecordingPitchEvidence? pitch;
  final PitchSegmentationEvidence? segmentation;
  final ChordResponseEvidence? comparison;

  bool get hasCandidateComparison =>
      status == ChordResponseDiagnosticStatus.diagnosticAvailable &&
      comparison?.status == ChordResponseStatus.candidatesCompared;
}

/// CONS-02d: ephemeral capture → quality → worker → segment → matcher.
///
/// Thresholds remain the pre-registered diagnostic hypotheses in the existing
/// components. This service does not persist, score or send audio anywhere.
class ChordResponseDiagnosticAnalyzer {
  ChordResponseDiagnosticAnalyzer({
    required this.worker,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final RecordingPitchWorker worker;
  final DateTime Function() _now;

  Future<ChordResponseDiagnosticOutcome> analyze({
    required ChordResponseCapture capture,
    required NoiseFloorCalibration? calibration,
    ResponseOrder responseOrder = ResponseOrder.exact,
    double toleranceCents = PitchSequenceAligner.defaultToleranceCents,
  }) async {
    final quality = CaptureQualityAssessor.assess(
      samples: capture.samples.samples,
      sampleRateHz: capture.samples.sampleRateHz,
      route: capture.route,
      now: _now(),
      calibration: calibration,
      purpose: CapturePurpose.pitchResponse,
    );
    if (!quality.allowsAnalysis) {
      return ChordResponseDiagnosticOutcome._(
        status: ChordResponseDiagnosticStatus.qualityRejected,
        quality: quality,
      );
    }

    RecordingPitchEvidence pitch;
    try {
      pitch = await worker.analyze(
        samples: capture.samples.samples,
        sampleRateHz: capture.samples.sampleRateHz,
        source: capture.samples.source,
      );
    } catch (_) {
      return ChordResponseDiagnosticOutcome._(
        status: ChordResponseDiagnosticStatus.analysisUnavailable,
        quality: quality,
      );
    }
    if (pitch.sampleRateHz != capture.metadata.sampleRateHz ||
        pitch.sampleCount != capture.metadata.sampleCount ||
        pitch.provenance.source != capture.samples.source) {
      return ChordResponseDiagnosticOutcome._(
        status: ChordResponseDiagnosticStatus.analysisUnavailable,
        quality: quality,
      );
    }

    final segmentation = PitchSegmenter.fromRecording(pitch);
    final comparison = ChordResponseMatcher.compare(
      recording: capture.recording,
      segmentation: segmentation,
      responseOrder: responseOrder,
      toleranceCents: toleranceCents,
    );
    return ChordResponseDiagnosticOutcome._(
      status: ChordResponseDiagnosticStatus.diagnosticAvailable,
      quality: quality,
      pitch: pitch,
      segmentation: segmentation,
      comparison: comparison,
    );
  }
}
