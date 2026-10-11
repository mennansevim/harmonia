import '../../../domain/audio/melody_analyzer.dart';
import '../../../domain/models/score_metric.dart';

/// Placeholder [MelodyAnalyzer] used until real melody-sequence scoring
/// (ARCHITECTURE.md, PRODUCT_SPEC.md § Egzersiz türleri "Ezgi") is built in
/// a later phase.
///
/// Preserves upstream diagnostics but deliberately leaves all scores and
/// sequence correctness unmeasured. Matching counts are not melody analysis.
class MockMelodyAnalyzer implements MelodyAnalyzer {
  @override
  Future<MelodyAnalysisResult> analyze(MelodyAnalysisRequest request) async {
    // Until sequence alignment exists, absence of analysis is explicit.
    // Equal note counts are not evidence of correct pitch, timing or memory.
    return MelodyAnalysisResult(
      perNoteResults: request.detectedNotes.map((n) => n.pitchResult).toList(),
      noteOrderCorrect: null,
      pitchAccuracy: const ScoreMetric.notMeasured(),
      timingAccuracy: const ScoreMetric.notMeasured(),
      memoryScore: const ScoreMetric.notMeasured(),
      measurementReason: 'sequence_analyzer_not_implemented',
    );
  }
}
