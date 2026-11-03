import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/visual_feedback_frame.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

void main() {
  test('diagnostic position is bounded without changing raw cents', () {
    final frame = VisualFeedbackFrame(
      sessionId: 'attempt-local-1',
      phase: VisualFeedbackPhase.diagnostic,
      level01: 0.4,
      signedCents: 1234,
      confidence01: null,
      stability01: null,
      completedNotes: 0,
      errorType: VisualFeedbackError.octaveDifference,
      provenance: const MeasurementProvenance(
        source: MeasurementSource.microphone,
        analyzerVersion: 'diagnostic-1',
      ),
    );

    expect(frame.signedCents, 1234);
    expect(frame.displayOffset, 1);
    expect(frame.confidence01, isNull);
    expect(frame.stability01, isNull);
  });

  test('invalid UI values fail before painting', () {
    VisualFeedbackFrame build({double level = 0.5, double? confidence}) =>
        VisualFeedbackFrame(
          sessionId: 'attempt-local-1',
          phase: VisualFeedbackPhase.diagnostic,
          level01: level,
          confidence01: confidence,
          completedNotes: 0,
          provenance: const MeasurementProvenance(),
        );

    expect(() => build(level: -0.1), throwsArgumentError);
    expect(() => build(confidence: 1.1), throwsArgumentError);
  });
}
