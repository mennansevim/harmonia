import 'melody_session.dart';

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
