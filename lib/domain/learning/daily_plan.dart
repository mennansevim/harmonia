import '../models/exercise_result.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'skill_graph.dart';

/// LEARN-03: a timed daily plan (5 / 12 / 15 min) over the goal's measured
/// skills. Rule-based and deterministic; no AI. Every number here is a
/// developer hypothesis awaiting educator review and a learning pilot
/// (LEARNING_MODEL: 1/3/7/14-day queue is a pilot hypothesis).
enum DailyBudget {
  five(5),
  twelve(12),
  fifteen(15);

  const DailyBudget(this.minutes);
  final int minutes;

  /// At most this many never-attempted exercises per day (draft).
  int get maxNew => this == DailyBudget.five ? 1 : 2;
}

enum PlanBlockKind {
  /// Mastered earlier; due today in the review queue. One round, one listen.
  retentionCheck,

  /// Attempted but not (or no longer) meeting the draft criterion.
  weakRepeat,

  /// Never attempted; the next exercise of its skill.
  newItem,
}

class PlanBlock {
  PlanBlock._({
    required this.kind,
    required this.node,
    required this.exercise,
    required this.rounds,
    required this.roundsDoneToday,
    this.lastResult,
    this.reviewIntervalDays,
  });
  final PlanBlockKind kind;
  final SkillNode node;
  final MeasuredExercise exercise;

  /// Planned rounds today (the draft criterion needs two clean rounds in a
  /// row, so repeats/new items may get two when the budget allows).
  final int rounds;

  /// Valid comparable rounds saved today (checks: only retention-flagged).
  final int roundsDoneToday;
  final ExerciseResult? lastResult;

  /// For checks: the queue interval that made it due (1/3/7/14 days).
  final int? reviewIntervalDays;

  int get minutes => rounds * exercise.draftMinutes;
  bool get done => roundsDoneToday >= rounds;
  bool get retention => kind == PlanBlockKind.retentionCheck;
}

enum DailyPlanStatus {
  /// Blocks were planned for today.
  planned,

  /// Every measurable exercise of the route is mastered and none is due.
  nothingDue,

  /// The route has no exercise this build can measure.
  noMeasuredContent,
}

class DailyPlan {
  DailyPlan._({
    required this.budget,
    required this.day,
    required List<PlanBlock> blocks,
    required this.status,
    this.nextReviewDay,
  }) : blocks = List.unmodifiable(blocks);
  final DailyBudget budget;

  /// Local calendar day the plan is for (midnight).
  final DateTime day;
  final List<PlanBlock> blocks;
  final DailyPlanStatus status;

  /// Earliest later day a mastered exercise becomes due (null if none).
  final DateTime? nextReviewDay;

  int get plannedMinutes => blocks.fold(0, (s, b) => s + b.minutes);

  /// Budget left unplanned; shown honestly instead of padding the day.
  int get freeMinutes => budget.minutes - plannedMinutes;
  bool get complete => blocks.isNotEmpty && blocks.every((b) => b.done);
}

class DailyPlanner {
  const DailyPlanner._();

  /// Review queue intervals in calendar days, indexed by the number of
  /// clean later-day retention checks already passed (capped at the end).
  static const reviewIntervalsDays = [1, 3, 7, 14];

  /// The plan is fixed for the day: it is built from results saved before
  /// local midnight; today's results only mark progress.
  static DailyPlan plan({
    required SkillGraph graph,
    required PracticeGoal goal,
    required List<ExerciseResult> results,
    required DateTime now,
    required DailyBudget budget,
    List<MeasuredExercise>? catalog,
  }) {
    final day = _dayOf(now);
    final before = <ExerciseResult>[];
    final today = <ExerciseResult>[];
    for (final r in results) {
      final d = _dayOf(r.createdAt);
      if (d.isBefore(day)) {
        before.add(r);
      } else if (d == day) {
        today.add(r);
      }
    }
    final known = {
      for (final e in catalog ?? defaultMeasuredCatalog()) e.exerciseId: e,
    };

    final checks = <(_Candidate, int)>[]; // (candidate, overdue days)
    final weak = <_Candidate>[];
    final fresh = <_Candidate>[];
    final seen = <String>{};
    DateTime? nextReview;
    var anyMeasured = false;

    for (final node in graph.forGoal(goal)) {
      if (node.support != MeasurementSupport.measuredInApp) continue;
      var nodeHasWeak = false;
      _Candidate? nodeNew;
      for (final id in node.exerciseIds) {
        final e = known[id];
        if (e == null || !seen.add(id)) continue;
        anyMeasured = true;
        final all = comparableResults(before, e);
        final valid = all.where((r) => r.isValid).toList();
        final state = SkillStatusEvaluator.exerciseState(e, before);
        final mastered =
            state == MasteryState.supported ||
            state == MasteryState.independent ||
            state == MasteryState.retained;
        if (mastered && all.last.isValid) {
          final interval =
              reviewIntervalsDays[_passedChecks(
                e,
                valid,
              ).clamp(0, reviewIntervalsDays.length - 1)];
          final last = _dayOf(valid.last.createdAt);
          final due = DateTime(last.year, last.month, last.day + interval);
          final overdue = _daysBetween(due, day);
          if (overdue >= 0) {
            checks.add((
              _Candidate(node, e, valid.last, interval: interval),
              overdue,
            ));
          } else if (nextReview == null || due.isBefore(nextReview)) {
            nextReview = due;
          }
        } else if (all.isEmpty) {
          nodeNew ??= _Candidate(node, e, null);
        } else {
          nodeHasWeak = true;
          weak.add(_Candidate(node, e, valid.isEmpty ? null : valid.last));
        }
      }
      // One skill at a time: a new level waits while a sibling is weak.
      if (nodeNew != null && !nodeHasWeak) fresh.add(nodeNew);
    }

    if (!anyMeasured) {
      return DailyPlan._(
        budget: budget,
        day: day,
        blocks: const [],
        status: DailyPlanStatus.noMeasuredContent,
      );
    }

    // Most overdue first; route order breaks ties (stable sort).
    checks.sort((a, b) => b.$2.compareTo(a.$2));
    final orderedChecks = [for (final c in checks) c.$1];
    final newAllowed = fresh.take(budget.maxNew).toList();

    // Priority balances recall, repair and one new thing before more of
    // the same kind.
    final priority = <(_Candidate, PlanBlockKind)>[
      if (orderedChecks.isNotEmpty)
        (orderedChecks.first, PlanBlockKind.retentionCheck),
      if (weak.isNotEmpty) (weak.first, PlanBlockKind.weakRepeat),
      for (final c in newAllowed) (c, PlanBlockKind.newItem),
      for (final c in orderedChecks.skip(1)) (c, PlanBlockKind.retentionCheck),
      for (final c in weak.skip(1)) (c, PlanBlockKind.weakRepeat),
    ];

    var left = budget.minutes;
    final chosen = <(_Candidate, PlanBlockKind)>[];
    final rounds = <int>[];
    for (final p in priority) {
      final m = p.$1.exercise.draftMinutes;
      if (m <= left) {
        chosen.add(p);
        rounds.add(1);
        left -= m;
      }
    }
    // Second round where the criterion needs two in a row (not for checks).
    for (var i = 0; i < chosen.length; i++) {
      final (c, kind) = chosen[i];
      if (kind == PlanBlockKind.retentionCheck) continue;
      if (c.exercise.draftMinutes <= left) {
        rounds[i] = 2;
        left -= c.exercise.draftMinutes;
      }
    }

    final blocks = <PlanBlock>[
      for (var i = 0; i < chosen.length; i++)
        PlanBlock._(
          kind: chosen[i].$2,
          node: chosen[i].$1.node,
          exercise: chosen[i].$1.exercise,
          rounds: rounds[i],
          roundsDoneToday: _doneToday(
            chosen[i].$1.exercise,
            today,
            retention: chosen[i].$2 == PlanBlockKind.retentionCheck,
          ),
          lastResult: chosen[i].$1.last,
          reviewIntervalDays: chosen[i].$2 == PlanBlockKind.retentionCheck
              ? chosen[i].$1.interval
              : null,
        ),
    ];
    // Session order: hint-free recall first, then repair, then new.
    final sorted = [
      for (final k in PlanBlockKind.values) ...blocks.where((b) => b.kind == k),
    ];
    return DailyPlan._(
      budget: budget,
      day: day,
      blocks: sorted,
      status: sorted.isEmpty
          ? DailyPlanStatus.nothingDue
          : DailyPlanStatus.planned,
      nextReviewDay: nextReview,
    );
  }

  /// Clean retention checks on a later day than an earlier clean result.
  static int _passedChecks(MeasuredExercise e, List<ExerciseResult> valid) {
    var n = 0;
    for (final r in valid) {
      if (r.measurements['retentionCheck'] != true || !e.isClean(r)) continue;
      final hasEarlier = valid.any(
        (x) =>
            e.isClean(x) && _dayOf(x.createdAt).isBefore(_dayOf(r.createdAt)),
      );
      if (hasEarlier) n++;
    }
    return n;
  }

  static int _doneToday(
    MeasuredExercise e,
    List<ExerciseResult> today, {
    required bool retention,
  }) => comparableResults(today, e)
      .where(
        (r) =>
            r.isValid &&
            (!retention || r.measurements['retentionCheck'] == true),
      )
      .length;

  static DateTime _dayOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// Calendar days from [a] to [b] (DST-safe).
  static int _daysBetween(DateTime a, DateTime b) =>
      (b.difference(a).inHours / 24).round();
}

class _Candidate {
  _Candidate(this.node, this.exercise, this.last, {this.interval});
  final SkillNode node;
  final MeasuredExercise exercise;
  final ExerciseResult? last;
  final int? interval;
}
