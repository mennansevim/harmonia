import 'dart:math' as math;

/// Per-item forgetting model for review cards (ENGAGEMENT_RESEARCH §4.1).
///
/// A simplified half-life model after Settles & Meeder (ACL 2016): the
/// chance of recalling an item decays as `p = 2^(−Δ/h)`, where Δ is the time
/// since it was last answered and h its half-life. A card is due when p
/// falls below [reviewTarget]. A correct answer grows the half-life only once
/// the card was due (Δ ≥ [dueFraction]·h); an earlier, same-session answer is
/// massed practice. Deterministic and versioned; parameters are draft
/// defaults until a learner benchmark tunes them.
const memoryModelVersion = 'hlr-lite-2';

/// Recall probability below which a card is due.
const reviewTarget = 0.85;

/// Fraction of a half-life after which a card is due:
/// `2^(−f) = reviewTarget` ⇒ `f = log2(1 / reviewTarget)` (≈ 0.234). Moves
/// with [reviewTarget]; it is also the growth threshold in [ItemMemory.answered].
final double dueFraction = -math.log(reviewTarget) / math.ln2;

/// Half-life bounds and the starting value, in days.
const minHalfLifeDays = 0.5;
const maxHalfLifeDays = 60.0;
const startHalfLifeDays = 1.0;

/// Cards offered in one review round.
const reviewRoundSize = 8;

class ItemMemory {
  const ItemMemory({
    required this.halfLifeDays,
    required this.lastSeen,
    this.reps = 0,
    this.lapses = 0,
  });

  final double halfLifeDays;
  final DateTime lastSeen;

  /// Answers that grew the half-life.
  final int reps;

  /// Wrong answers.
  final int lapses;

  double _days(DateTime now) =>
      math.max(0, now.difference(lastSeen).inMinutes) / (24 * 60);

  /// Estimated chance of recalling the item at [now].
  double recall(DateTime now) => math.pow(2, -_days(now) / halfLifeDays) * 1.0;

  bool isDue(DateTime now) => recall(now) < reviewTarget;

  /// The first answer for an item starts its memory.
  static ItemMemory first(bool correct, DateTime now) => ItemMemory(
    halfLifeDays: correct ? startHalfLifeDays : minHalfLifeDays,
    lastSeen: now,
    reps: correct ? 1 : 0,
    lapses: correct ? 0 : 1,
  );

  /// A first-attempt answer at [now]. A correct answer doubles the half-life
  /// only once the card was due ([dueFraction] of a half-life has passed):
  /// answering before that (the same session) is massed practice and builds
  /// no spacing. A wrong answer always halves it.
  ItemMemory answered(bool correct, DateTime now) {
    if (!correct) {
      return ItemMemory(
        halfLifeDays: math.max(minHalfLifeDays, halfLifeDays / 2),
        lastSeen: now,
        reps: reps,
        lapses: lapses + 1,
      );
    }
    final spaced = _days(now) >= halfLifeDays * dueFraction;
    return ItemMemory(
      halfLifeDays: spaced
          ? math.min(maxHalfLifeDays, halfLifeDays * 2)
          : halfLifeDays,
      lastSeen: now,
      reps: spaced ? reps + 1 : reps,
      lapses: lapses,
    );
  }

  List<Object> toJson() => [
    halfLifeDays,
    lastSeen.toUtc().millisecondsSinceEpoch,
    reps,
    lapses,
  ];

  static ItemMemory? fromJson(Object? v) {
    if (v is! List || v.length != 4) return null;
    final [h, t, r, l] = v;
    if (h is! num || t is! int || r is! int || l is! int) return null;
    if (!h.isFinite || h < minHalfLifeDays || h > maxHalfLifeDays) return null;
    if (r < 0 || l < 0) return null;
    return ItemMemory(
      halfLifeDays: h.toDouble(),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(t, isUtc: true).toLocal(),
      reps: r,
      lapses: l,
    );
  }
}

/// One due item: [trainer] is a `TrainerKind.id`.
class ReviewCard {
  const ReviewCard(this.trainer, this.item, this.recall);
  final String trainer;
  final String item;
  final double recall;
}

/// Due cards, the most forgotten first, at most [max]. Trainers are
/// interleaved so two cards of one kind do not follow each other while
/// another kind is waiting (mixed review, Carter & Grahn 2016).
List<ReviewCard> dueCards(
  Map<String, Map<String, ItemMemory>> memory,
  DateTime now, {
  int max = reviewRoundSize,
}) {
  final due =
      <ReviewCard>[
        for (final t in memory.entries)
          for (final i in t.value.entries)
            if (i.value.isDue(now))
              ReviewCard(t.key, i.key, i.value.recall(now)),
      ]..sort((a, b) {
        final byRecall = a.recall.compareTo(b.recall);
        return byRecall != 0
            ? byRecall
            : '${a.trainer}/${a.item}'.compareTo('${b.trainer}/${b.item}');
      });
  final picked = due.take(max).toList();
  final out = <ReviewCard>[];
  while (picked.isNotEmpty) {
    final last = out.isEmpty ? null : out.last.trainer;
    final i = picked.indexWhere((c) => c.trainer != last);
    out.add(picked.removeAt(i < 0 ? 0 : i));
  }
  return out;
}
