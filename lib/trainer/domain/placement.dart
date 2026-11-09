import 'curriculum.dart';
import '../../domain/lang.dart';

/// Where the learner says they start (PLACE-01). Independent of the goal:
/// the goal picks the track, the level picks the starting point on it. It
/// never changes a tolerance, a pass mark or the lesson content.
enum ExperienceLevel { beginner, some, experienced }

extension ExperienceLevelInfo on ExperienceLevel {
  String get id => name;

  static ExperienceLevel? fromId(Object? id) =>
      id is String ? ExperienceLevel.values.asNameMap()[id] : null;

  String get title => switch (this) {
    ExperienceLevel.beginner => tr('Yeni başlıyorum', 'I am just starting'),
    ExperienceLevel.some => tr('Biraz biliyorum', 'I know a little'),
    ExperienceLevel.experienced => tr('Tecrübeliyim', 'I am experienced'),
  };

  String get subtitle => switch (this) {
    ExperienceLevel.beginner => tr(
      'En baştan başla; test yok',
      'Start at the beginning; no test',
    ),
    ExperienceLevel.some => tr(
      'Nota okuyorum ya da bir enstrüman çalıyorum; kısa test isteğe bağlı',
      'I read music or play an instrument; a short test is optional',
    ),
    ExperienceLevel.experienced => tr(
      'Müzik eğitimi aldım; kısa test bildiklerini atlatır',
      'I have trained in music; a short test skips what you know',
    ),
  };

  /// Whether onboarding offers the placement test at all.
  bool get offersPlacement => this != ExperienceLevel.beginner;
}

/// Early stop for a gate. The pass mark stays exactly the gate's own rule
/// (accuracy over the full length >= 80%, see TrainerStore.completeNode);
/// the test only ends once the verdict can no longer change.
class GateStop {
  const GateStop(this.length);

  /// Questions the full gate would ask (12 for a checkpoint, 20 final).
  final int length;

  /// Correct answers that guarantee a pass: ceil(0.8 * length).
  int get needed => (4 * length + 4) ~/ 5;

  /// Wrong answers that make a pass impossible.
  int get failAt => length - needed + 1;

  /// true = passed, false = failed, null = keep asking.
  bool? verdict(int correct, int wrong) {
    if (correct >= needed) return true;
    if (wrong >= failAt) return false;
    if (correct + wrong >= length) return correct >= needed;
    return null;
  }

  /// Accuracy over the full length, so an early stop scores exactly as the
  /// full gate would have at worst: 10/12 correct is 0.83 (2 stars), never
  /// an inflated 10/10.
  double accuracy(int correct) => correct / length;
}

/// One placement run on a single path (PLACE-01). Pure and deterministic:
/// it only decides which gate comes next. Results are written through the
/// store's normal gate rule, so a passed gate completes the nodes before
/// it, exactly as a gate taken from the path would.
///
/// - some: starts at the first checkpoint and climbs while it passes.
/// - experienced: starts at the second-to-last checkpoint; passing climbs
///   (up to the final), failing steps down one checkpoint at a time until
///   one passes or the first one fails.
///
/// With 12 questions a gate separates 70% from 85% learners poorly, so a
/// placement can be one checkpoint off; it is presented as approximate.
class PlacementRun {
  PlacementRun(this.path, this.level)
    : gates = [
        for (final n in path.nodes)
          if (n.isGate) n,
      ] {
    final checkpoints = gates
        .where((g) => g.kind == NodeKind.checkpoint)
        .length;
    _current = gates.isEmpty || !level.offersPlacement
        ? null
        : level == ExperienceLevel.experienced
        ? (checkpoints - 2).clamp(0, gates.length - 1)
        : 0;
  }

  final TrainerPath path;
  final ExperienceLevel level;

  /// Checkpoints in path order, then the final.
  final List<LessonNode> gates;

  int? _current;
  bool _descending = false;
  final _tried = <int>{};
  LessonNode? _placed;

  /// The gate to take now; null = the run is over.
  LessonNode? get current => _current == null ? null : gates[_current!];

  bool get done => _current == null;

  /// Highest gate passed in this run; null = none.
  LessonNode? get placed => _placed;

  int get attempted => _tried.length;

  void record(bool passed) {
    final i = _current;
    if (i == null) return;
    _tried.add(i);
    int? next;
    if (passed) {
      _placed = gates[i];
      next = _descending ? null : i + 1;
    } else if (_placed == null &&
        i > 0 &&
        (_descending || _tried.length == 1)) {
      // Failed with nothing passed yet: step one checkpoint down.
      _descending = true;
      next = i - 1;
    }
    _current = next == null || next >= gates.length || _tried.contains(next)
        ? null
        : next;
  }

  /// The learner chose to stop here.
  void stop() => _current = null;
}
