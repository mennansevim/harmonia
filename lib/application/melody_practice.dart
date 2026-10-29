import 'melody_session.dart';
import '../domain/audio/audio_capture.dart';
import '../domain/audio/pitch_sequence_alignment.dart';

/// Exclusive, reference-only resource. It exposes no microphone/assessment API.
/// The caller owns this player until close; never share it with a session.
abstract interface class DiagnosticMelodyPracticePlayer {
  Future<PlaybackHandle> play(DiagnosticMelodyPractice practice);
  Future<void> stop();
  Future<void> close();
}

/// Explicit learner-selected reference practice, NOT an inferred error region.
/// No capture, assessment, retention claim or ExerciseResult is produced.
class DiagnosticMelodyPractice {
  DiagnosticMelodyPractice({
    required this.reference,
    required this.startIndex,
    required this.endIndexExclusive,
    this.repetitions = 1,
  }) {
    if (startIndex < 0 ||
        endIndexExclusive <= startIndex ||
        endIndexExclusive > reference.frequenciesHz.length ||
        repetitions < 1 ||
        repetitions > maxRepetitions) {
      throw ArgumentError('Invalid diagnostic melody practice selection');
    }
  }

  static const maxRepetitions = 3;
  static const toneMs = 600;
  static const noteGapMs = 200;
  static const repeatGapMs = 1000;
  static const tailMs = 400;

  final DiagnosticMelodyReference reference;

  /// Zero-based, contiguous half-open range in the ORIGINAL reference.
  final int startIndex, endIndexExclusive;
  final int repetitions;
  int get noteCount => endIndexExclusive - startIndex;
  List<double> get frequenciesHz => List.unmodifiable(
    reference.frequenciesHz.sublist(startIndex, endIndexExclusive),
  );

  /// Nominal synthetic schedule, not physical playback/latency measurement.
  int get durationMs =>
      repetitions * (noteCount * toneMs + (noteCount - 1) * noteGapMs) +
      (repetitions - 1) * repeatGapMs +
      tailMs;
}

/// Converts symbolic candidate alignment into a small, reference-only review
/// range. This is an experimental listening suggestion, not a detected learner
/// error: segmentation/VAD and human-voice accuracy are not validated yet.
class DiagnosticMelodyPracticeSuggestion {
  const DiagnosticMelodyPracticeSuggestion._({
    required this.practice,
    required this.referenceIndex,
    required this.kind,
  });

  final DiagnosticMelodyPractice practice;
  final int referenceIndex;
  final PitchSequenceStepKind kind;

  static DiagnosticMelodyPracticeSuggestion? fromAlignment({
    required DiagnosticMelodyReference reference,
    required PitchSequenceEvidence evidence,
  }) {
    if (evidence.status != PitchSequenceStatus.aligned) return null;
    PitchSequenceStep? candidate;
    for (final step in evidence.steps) {
      if (step.kind != PitchSequenceStepKind.correct &&
          step.referenceIndex != null) {
        candidate = step;
        break;
      }
    }
    if (candidate == null) return null;
    final index = candidate.referenceIndex!;
    if (index < 0 || index >= reference.frequenciesHz.length) return null;

    // Preserve one adjacent reference as musical context. Extra-only response
    // events have no trustworthy reference index and therefore suggest nothing.
    final start = index == 0 ? 0 : index - 1;
    final end = (start + 2).clamp(1, reference.frequenciesHz.length);
    return DiagnosticMelodyPracticeSuggestion._(
      practice: DiagnosticMelodyPractice(
        reference: reference,
        startIndex: start,
        endIndexExclusive: end,
        repetitions: 2,
      ),
      referenceIndex: index,
      kind: candidate.kind,
    );
  }
}
