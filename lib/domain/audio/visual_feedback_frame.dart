import '../models/measurement_provenance.dart';

enum VisualFeedbackPhase { calibrating, responding, diagnostic }

enum VisualFeedbackError { octaveDifference, invalidSignal }

/// One-way evidence projection for UI. It is never a score and must not be
/// used to alter analyzer output, lesson progress or mastery.
class VisualFeedbackFrame {
  VisualFeedbackFrame({
    required this.sessionId,
    required this.phase,
    required this.level01,
    required this.completedNotes,
    required this.provenance,
    this.signedCents,
    this.confidence01,
    this.stability01,
    this.activeNoteIndex,
    this.errorType,
  }) {
    bool unit(double? value) =>
        value == null || (value.isFinite && value >= 0 && value <= 1);
    if (sessionId.trim().isEmpty ||
        !level01.isFinite ||
        level01 < 0 ||
        level01 > 1 ||
        !unit(confidence01) ||
        !unit(stability01) ||
        (signedCents != null && !signedCents!.isFinite) ||
        completedNotes < 0 ||
        (activeNoteIndex != null && activeNoteIndex! < 0)) {
      throw ArgumentError('Invalid visual feedback frame');
    }
  }

  final String sessionId;
  final VisualFeedbackPhase phase;
  final double level01;
  final double? signedCents;

  /// Null means not measured. Periodic-frame ratio is not promoted here.
  final double? confidence01;

  /// Null means not measured. Pitch dispersion is not vocal stability.
  final double? stability01;
  final int? activeNoteIndex;
  final int completedNotes;
  final VisualFeedbackError? errorType;
  final MeasurementProvenance provenance;

  double get displayOffset => ((signedCents ?? 0) / 100).clamp(-1.0, 1.0);
}
