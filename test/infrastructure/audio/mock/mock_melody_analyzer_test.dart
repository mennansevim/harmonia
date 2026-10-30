import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/melody_analyzer.dart';
import 'package:resonia/domain/audio/pitch_analyzer.dart';
import 'package:resonia/domain/models/score_metric.dart';
import 'package:resonia/infrastructure/audio/mock/mock_melody_analyzer.dart';

void main() {
  test(
    'matching note counts cannot manufacture order, timing or memory',
    () async {
      final result = await MockMelodyAnalyzer().analyze(
        const MelodyAnalysisRequest(
          targetNotes: [
            MelodyNoteTarget(
              note: 'C4',
              frequencyHz: 261.63,
              expectedOnsetMs: 0,
            ),
          ],
          detectedNotes: [
            DetectedMelodyNote(
              onsetMs: 999,
              pitchResult: PitchAnalysisResult(
                detectedFrequencyHz: 440,
                centsDifference: 0,
                octaveOffset: 0,
                voicedRatio: 0.9,
                stabilityCents: 8,
                isNoisy: false,
              ),
            ),
          ],
        ),
      );
      expect(result.noteOrderCorrect, isNull);
      expect(result.pitchAccuracy.status, ScoreMetricStatus.notMeasured);
      expect(result.timingAccuracy.status, ScoreMetricStatus.notMeasured);
      expect(result.memoryScore.status, ScoreMetricStatus.notMeasured);
      expect(result.measurementReason, 'sequence_analyzer_not_implemented');
    },
  );

  test(
    'empty placeholder input cannot manufacture a zero learner grade',
    () async {
      final result = await MockMelodyAnalyzer().analyze(
        const MelodyAnalysisRequest(targetNotes: [], detectedNotes: []),
      );
      expect(result.memoryScore.value, isNull);
      expect(result.noteOrderCorrect, isNull);
    },
  );
}
