import '../models/exercise.dart';
import '../models/exercise_protocol.dart';

/// Educator sign-off state. Drafts may appear only with a visible label and
/// never as exam content (EDU-01).
enum ContentReviewStatus { draftAwaitingEducator, educatorApproved }

class RhythmPattern {
  RhythmPattern({
    required this.title,
    required this.description,
    required this.exercise,
    this.review = ContentReviewStatus.draftAwaitingEducator,
  }) {
    if (exercise.exercise.skill != Skill.rhythm) {
      throw ArgumentError('Rhythm pattern must bind a rhythm exercise');
    }
    if (review != ContentReviewStatus.educatorApproved &&
        exercise.exercise.mode == ExerciseMode.recallExam) {
      throw ArgumentError('Unreviewed content cannot be exam content');
    }
  }
  final String title;
  final String description;
  final ConfiguredExercise exercise;
  final ContentReviewStatus review;
}

RhythmPattern _draft(
  String id,
  String title,
  String description,
  List<double> beats, {
  double bpm = 80,
  int difficulty = 1,
}) => RhythmPattern(
  title: title,
  description: description,
  exercise: ConfiguredExercise(
    exercise: Exercise(
      id: id,
      skill: Skill.rhythm,
      title: title,
      difficulty: difficulty,
      contentVersion: 'draft-1',
    ),
    protocol: ExerciseProtocol(
      mode: ExerciseMode.learning,
      notes: const [],
      rhythmOnsetsBeats: beats,
      tempoBpm: bpm,
      maxReferencePlays: 3,
    ),
  ),
);

/// Developer drafts for the code path only; NOT educator-approved content.
final List<RhythmPattern> draftRhythmPatterns = List.unmodifiable([
  _draft('draft-rhythm-quarters', 'Dört dörtlük', 'Eşit aralıklı dört vuruş.', [
    0,
    1,
    2,
    3,
  ]),
  _draft(
    'draft-rhythm-eighths',
    'Sekizlik çifti',
    'Üçüncü vuruşta iki hızlı vuruş.',
    [0, 1, 2, 2.5, 3],
  ),
  _draft(
    'draft-rhythm-syncopation',
    'Kısa senkop',
    'Vuruş arasına düşen bir giriş.',
    [0, 1.5, 2, 3],
    difficulty: 2,
  ),
]);
