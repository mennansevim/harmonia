import '../models/measurement_provenance.dart';
import 'visual_feedback_frame.dart';

/// Converts the recorder's display-only dBFS stream into UI frames.
///
/// This projection deliberately has no pitch, confidence or stability. Its
/// linear level mapping is not calibrated across devices and must never feed
/// scoring, VAD, lesson progress or mastery.
class LiveVisualFeedbackProjector {
  const LiveVisualFeedbackProjector({this.floorDb = -60});

  final double floorDb;

  VisualFeedbackFrame? project({
    required String sessionId,
    required VisualFeedbackPhase phase,
    required double levelDb,
    required MeasurementProvenance provenance,
  }) {
    if (sessionId.trim().isEmpty ||
        !floorDb.isFinite ||
        floorDb >= 0 ||
        !levelDb.isFinite ||
        levelDb > 0 ||
        phase == VisualFeedbackPhase.diagnostic) {
      return null;
    }
    final level01 = ((levelDb - floorDb) / -floorDb).clamp(0.0, 1.0);
    return VisualFeedbackFrame(
      sessionId: sessionId,
      phase: phase,
      level01: level01,
      signedCents: null,
      confidence01: null,
      stability01: null,
      activeNoteIndex: null,
      completedNotes: 0,
      provenance: provenance,
    );
  }
}
