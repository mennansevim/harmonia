import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/live_visual_feedback.dart';
import 'package:resonia/domain/audio/visual_feedback_frame.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

void main() {
  const projector = LiveVisualFeedbackProjector();
  const provenance = MeasurementProvenance(
    source: MeasurementSource.microphone,
    analyzerVersion: 'level-test',
  );

  test('dBFS becomes level-only responding evidence', () {
    final frame = projector.project(
      sessionId: 'local-attempt',
      phase: VisualFeedbackPhase.responding,
      levelDb: -30,
      provenance: provenance,
    )!;

    expect(frame.phase, VisualFeedbackPhase.responding);
    expect(frame.level01, 0.5);
    expect(frame.signedCents, isNull);
    expect(frame.confidence01, isNull);
    expect(frame.stability01, isNull);
    expect(frame.provenance, same(provenance));
  });

  test('level is bounded and invalid plugin events abstain', () {
    expect(
      projector
          .project(
            sessionId: 'local-attempt',
            phase: VisualFeedbackPhase.responding,
            levelDb: -160,
            provenance: provenance,
          )!
          .level01,
      0,
    );
    expect(
      projector.project(
        sessionId: 'local-attempt',
        phase: VisualFeedbackPhase.responding,
        levelDb: 1,
        provenance: provenance,
      ),
      isNull,
    );
    expect(
      projector.project(
        sessionId: 'local-attempt',
        phase: VisualFeedbackPhase.responding,
        levelDb: double.nan,
        provenance: provenance,
      ),
      isNull,
    );
  });
}
