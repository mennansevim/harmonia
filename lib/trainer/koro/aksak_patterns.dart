import '../../domain/content/rhythm_patterns.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_protocol.dart';
import '../../domain/lang.dart';

/// Turkish aksak (limping) meters as two-bar tap patterns. Onsets are in
/// eighth notes; the tempo is eighth notes per minute, so every group start
/// is one tap. Developer drafts, NOT educator-approved content.
RhythmPattern _aksak(
  String id,
  String title,
  String description,
  List<double> eighths, {
  double eighthBpm = 220,
  int difficulty = 2,
}) => RhythmPattern(
  title: title,
  description: description,
  exercise: ConfiguredExercise(
    exercise: Exercise(
      id: id,
      skill: Skill.rhythm,
      title: title,
      difficulty: difficulty,
      contentVersion: 'draft-aksak-1',
    ),
    protocol: ExerciseProtocol(
      mode: ExerciseMode.learning,
      notes: const [],
      rhythmOnsetsBeats: eighths,
      tempoBpm: eighthBpm,
      maxReferencePlays: 3,
    ),
  ),
);

/// Built once per wording language: descriptions are part of the pattern.
final _aksakByLang = <bool, List<RhythmPattern>>{};

List<RhythmPattern> get draftAksakPatterns =>
    _aksakByLang[Lang.en] ??= _buildAksak();

List<RhythmPattern> _buildAksak() => List.unmodifiable([
  _aksak(
    'draft-aksak-5-8',
    '5/8 (2+3)',
    tr(
      'Kısa–uzun. İki ölçü, her grup başı bir vuruş.',
      'Short–long. Two bars, one beat at the start of each group.',
    ),
    [0, 2, 5, 7, 10],
  ),
  _aksak(
    'draft-aksak-7-8',
    '7/8 (2+2+3)',
    tr(
      'Kısa–kısa–uzun. Balkan ve Rumeli ezgilerinin yürüyüşü.',
      'Short–short–long. The gait of Balkan and Rumelian tunes.',
    ),
    [0, 2, 4, 7, 9, 11, 14],
  ),
  _aksak(
    'draft-aksak-7-8-b',
    '7/8 (3+2+2)',
    tr(
      'Uzun–kısa–kısa. Aynı ölçü, farklı ağırlık.',
      'Long–short–short. The same metre, a different weight.',
    ),
    [0, 3, 5, 7, 10, 12, 14],
    difficulty: 3,
  ),
  _aksak(
    'draft-aksak-9-8',
    '9/8 (2+2+2+3)',
    tr(
      'Karşılama ölçüsü: üç kısa, bir uzun.',
      'The karşılama metre: three short, one long.',
    ),
    [0, 2, 4, 6, 9, 11, 13, 15, 18],
    difficulty: 3,
  ),
  _aksak(
    'draft-aksak-10-8',
    '10/8 (3+2+2+3)',
    tr(
      'Aksak semai kalıbı: uzun–kısa–kısa–uzun.',
      'The aksak semai pattern: long–short–short–long.',
    ),
    [0, 3, 5, 7, 10, 13, 15, 17, 20],
    eighthBpm: 240,
    difficulty: 3,
  ),
]);
