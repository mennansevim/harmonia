import '../models/measurement_provenance.dart';

/// A window of captured audio to analyze against a target pitch.
class PitchAnalysisRequest {
  const PitchAnalysisRequest({
    required this.samples,
    required this.sampleRateHz,
    required this.targetFrequencyHz,
  });

  /// Mono PCM samples, normalized to [-1.0, 1.0].
  final List<double> samples;
  final int sampleRateHz;
  final double targetFrequencyHz;
}

/// Deterministic output of a pitch analysis pass.
///
/// This is the `detected` block of the AI Coach input contract
/// (AI_COACH.md § AI'ye giden veri) before it is turned into an
/// [ExerciseResult] by a scorer. AI never produces or edits these values
/// (ADR-001).
class PitchAnalysisResult {
  const PitchAnalysisResult({
    required this.detectedFrequencyHz,
    required this.centsDifference,
    required this.octaveOffset,
    required this.voicedRatio,
    required this.stabilityCents,
    required this.isNoisy,
    this.provenance = const MeasurementProvenance(),
  });

  /// Null when no stable voiced pitch could be extracted at all.
  final double? detectedFrequencyHz;

  /// Signed distance in cents from the target frequency, ignoring octave
  /// (i.e. compared to the target's pitch class). Null when unvoiced.
  final double? centsDifference;

  /// 0 = correct octave, -1/+1 = one octave below/above, etc.
  /// ARCHITECTURE.md: octave errors must never be silently tolerated as
  /// success (ADR-006).
  final int octaveOffset;

  /// Fraction (0.0–1.0) of analyzed frames classified as voiced signal
  /// versus silence/noise.
  final double voicedRatio;

  /// Standard deviation of detected pitch (in cents) across the voiced
  /// frames — lower is steadier.
  final double stabilityCents;

  /// True when the input was dominated by non-voice noise (low voiced
  /// ratio, no reliable fundamental).
  final bool isNoisy;
  final MeasurementProvenance provenance;
}

/// Contract for pitch detection engines.
///
/// Implementations must be deterministic and testable
/// (ARCHITECTURE.md § Mimari prensipler #1). The first real implementation
/// will run DSP (e.g. autocorrelation/YIN) on captured microphone frames;
/// until then, [MockPitchAnalyzer] stands in so UI and scoring can be
/// built and tested independently of the audio engine.
abstract class PitchAnalyzer {
  Future<PitchAnalysisResult> analyze(PitchAnalysisRequest request);
}
