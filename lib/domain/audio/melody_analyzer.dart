import 'pitch_analyzer.dart';
import '../models/score_metric.dart';

/// One note of a reference melody (PRODUCT_SPEC.md: 3–5 note melody
/// repetition exercise).
class MelodyNoteTarget {
  const MelodyNoteTarget({
    required this.note,
    required this.frequencyHz,
    required this.expectedOnsetMs,
  });

  final String note;
  final double frequencyHz;
  final int expectedOnsetMs;
}

/// One note the user sang back, as extracted upstream by the pitch engine.
class DetectedMelodyNote {
  const DetectedMelodyNote({required this.onsetMs, required this.pitchResult});

  final int onsetMs;
  final PitchAnalysisResult pitchResult;
}

class MelodyAnalysisRequest {
  const MelodyAnalysisRequest({
    required this.targetNotes,
    required this.detectedNotes,
  });

  final List<MelodyNoteTarget> targetNotes;
  final List<DetectedMelodyNote> detectedNotes;
}

/// Deterministic output of comparing a sung melody to its reference.
///
/// Combines per-note pitch accuracy with note-order/memory correctness,
/// kept separate per PRODUCT_SPEC.md § Puanlama ("Melody memory" as its own
/// score rather than folded into pitch accuracy).
class MelodyAnalysisResult {
  const MelodyAnalysisResult({
    required this.perNoteResults,
    required this.noteOrderCorrect,
    required this.pitchAccuracy,
    required this.timingAccuracy,
    required this.memoryScore,
    this.measurementReason,
  });

  final List<PitchAnalysisResult> perNoteResults;

  /// False for a measured sequence error; null if sequence analysis is absent.
  final bool? noteOrderCorrect;

  /// 0–100 average pitch accuracy across matched notes.
  final ScoreMetric pitchAccuracy;

  /// 0–100 onset timing accuracy across matched notes.
  final ScoreMetric timingAccuracy;

  /// 0–100 score reflecting whether the whole sequence was recalled
  /// correctly, independent of individual pitch accuracy.
  final ScoreMetric memoryScore;
  final String? measurementReason;
}

/// Contract for melody-sequence matching engines. See [PitchAnalyzer] for
/// the same deterministic/testable requirement.
abstract class MelodyAnalyzer {
  Future<MelodyAnalysisResult> analyze(MelodyAnalysisRequest request);
}
