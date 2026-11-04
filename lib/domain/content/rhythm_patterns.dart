import '../models/exercise.dart';
import '../models/exercise_protocol.dart';
import '../lang.dart';

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
/// Built once per wording language: titles are part of the pattern.
final _draftByLang = <bool, List<RhythmPattern>>{};

List<RhythmPattern> get draftRhythmPatterns =>
    _draftByLang[Lang.en] ??= _buildDraftRhythm();

List<RhythmPattern> _buildDraftRhythm() => List.unmodifiable([
  _draft(
    'draft-rhythm-quarters',
    tr('Dört dörtlük', 'Four quarters'),
    tr('Eşit aralıklı dört vuruş.', 'Four evenly spaced beats.'),
    [0, 1, 2, 3],
  ),
  _draft(
    'draft-rhythm-eighths',
    tr('Sekizlik çifti', 'Eighth-note pair'),
    tr('Üçüncü vuruşta iki hızlı vuruş.', 'Two quick taps on the third beat.'),
    [0, 1, 2, 2.5, 3],
  ),
  _draft(
    'draft-rhythm-syncopation',
    tr('Kısa senkop', 'Short syncopation'),
    tr('Vuruş arasına düşen bir giriş.', 'An entry that falls between beats.'),
    [0, 1.5, 2, 3],
    difficulty: 2,
  ),
]);

/// Deterministic easy→hard key, derived only from the pattern's own data:
/// the authored difficulty tag, then syncopated entries (an off-beat onset
/// whose beat has no onset), then off-beat subdivisions, then the shortest
/// gap between onsets in ms (shorter is harder), then the onset count.
/// A content-ordering heuristic, not a measured difficulty or a rubric.
class RhythmPatternDifficulty implements Comparable<RhythmPatternDifficulty> {
  RhythmPatternDifficulty.of(RhythmPattern p)
    : authored = p.exercise.exercise.difficulty,
      syncopations = _syncopations(p.exercise.protocol.rhythmOnsetsBeats),
      offBeats = p.exercise.protocol.rhythmOnsetsBeats
          .where((b) => b != b.floorToDouble())
          .length,
      shortestGapMs = _shortestGapMs(p.exercise.protocol),
      onsets = p.exercise.protocol.rhythmOnsetsBeats.length;

  final int authored, syncopations, offBeats, onsets;
  final double shortestGapMs;

  static int _syncopations(List<double> beats) {
    final onBeats = {
      for (final b in beats)
        if (b == b.floorToDouble()) b,
    };
    return beats
        .where(
          (b) => b != b.floorToDouble() && !onBeats.contains(b.floorToDouble()),
        )
        .length;
  }

  static double _shortestGapMs(ExerciseProtocol protocol) {
    final beats = protocol.rhythmOnsetsBeats;
    final bpm = protocol.tempoBpm;
    if (beats.length < 2) return double.infinity;
    var gap = double.infinity;
    for (var i = 1; i < beats.length; i++) {
      final d = beats[i] - beats[i - 1];
      if (d < gap) gap = d;
    }
    return gap * 60000 / bpm;
  }

  @override
  int compareTo(RhythmPatternDifficulty o) {
    for (final c in [
      authored.compareTo(o.authored),
      syncopations.compareTo(o.syncopations),
      offBeats.compareTo(o.offBeats),
      o.shortestGapMs.compareTo(shortestGapMs),
      onsets.compareTo(o.onsets),
    ]) {
      if (c != 0) return c;
    }
    return 0;
  }
}

/// [patterns] from easy to hard; ties keep their catalog order.
List<RhythmPattern> orderedEasyToHard(List<RhythmPattern> patterns) {
  final indexed = [
    for (final (i, p) in patterns.indexed)
      (i, p, RhythmPatternDifficulty.of(p)),
  ];
  indexed.sort((a, b) {
    final c = a.$3.compareTo(b.$3);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return List.unmodifiable([for (final e in indexed) e.$2]);
}
