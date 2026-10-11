import '../../../domain/audio/rhythm_analyzer.dart';
import '../../../domain/audio/event_rhythm_analyzer.dart';

/// Demo-compatible adapter to the deterministic event matcher.
/// It does not capture taps or extract clap onsets from microphone samples.
class MockRhythmAnalyzer implements RhythmAnalyzer {
  @override
  Future<RhythmAnalysisResult> analyze(RhythmAnalysisRequest request) async {
    return EventRhythmAnalyzer().analyze(request);
  }
}
