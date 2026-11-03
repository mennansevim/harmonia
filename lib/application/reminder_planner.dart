import 'dart:math' as math;

import '../domain/lang.dart';

/// Local, rule-based reminder planning (ENGAGEMENT_RESEARCH §4.2), after the
/// two ideas of Duolingo's notification bandit (Yancey & Settles, KDD 2020)
/// without a server or a model:
/// * **eligibility** — a message is only a candidate when it is true for the
///   learner (due cards, a streak worth keeping, a choir deadline…);
/// * **freshness** — a message sent recently loses weight, so the same text
///   does not come back day after day.
///
/// The plan covers the next week day by day, then backs off to weekly: a
/// learner who has not opened the app for a week is not reminded daily.
/// Nothing here guilts or threatens; every text is plain and optional.
enum ReminderKind { review, streak, choir, comeBack, range, routine, weekly }

class PlannedReminder {
  const PlannedReminder(this.at, this.kind, this.title, this.body);
  final DateTime at;
  final ReminderKind kind;
  final String title;
  final String body;
}

/// What the planner may know. All fields come from local data.
class ReminderContext {
  const ReminderContext({
    required this.now,
    required this.chosenMinute,
    this.dueCards = 0,
    this.streak = 0,
    this.practicedToday = false,
    this.lastPractice,
    this.choirDue,
    this.choirTitle,
    this.rangeMeasured = true,
    this.activeDays = 0,
    this.sessionMinutes = const [],
    this.lastSent = const {},
  });

  final DateTime now;

  /// Minute of day the learner picked for reminders.
  final int chosenMinute;
  final int dueCards;
  final int streak;
  final bool practicedToday;
  final DateTime? lastPractice;

  /// Nearest choir deadline with work still to send.
  final DateTime? choirDue;
  final String? choirTitle;
  final bool rangeMeasured;

  /// Days with any practice, ever.
  final int activeDays;

  /// Minute of day of recent practice starts, newest last.
  final List<int> sessionMinutes;

  /// When each kind was last planned to fire.
  final Map<ReminderKind, DateTime> lastSent;
}

/// Daily reminders for this many days, then [weeklyAfter] weekly ones.
const dailyDays = 7;
const weeklyAfter = 2;

/// Days a kind stays "stale" after it was sent.
const freshnessDays = 7;

/// Practice starts needed before the habitual time replaces the chosen one.
const habitSamples = 5;

/// The learner's usual practice minute, 30 minutes early, kept between
/// 08:00 and 21:30; the chosen minute until there are [habitSamples] starts.
int reminderMinute(ReminderContext c) {
  final recent = c.sessionMinutes.length > 14
      ? c.sessionMinutes.sublist(c.sessionMinutes.length - 14)
      : c.sessionMinutes;
  if (recent.length < habitSamples) return c.chosenMinute;
  final sorted = [...recent]..sort();
  final median = sorted[sorted.length ~/ 2];
  return (median - 30).clamp(8 * 60, 21 * 60 + 30);
}

int _days(DateTime from, DateTime to) => DateTime(
  to.year,
  to.month,
  to.day,
).difference(DateTime(from.year, from.month, from.day)).inDays;

/// Base weights: specific, time-bound messages first.
const _weight = {
  ReminderKind.choir: 5.0,
  ReminderKind.review: 4.0,
  ReminderKind.streak: 3.0,
  ReminderKind.comeBack: 3.0,
  ReminderKind.range: 2.0,
  ReminderKind.routine: 1.0,
};

/// The message for one future day, assuming the learner does not open the
/// app before then (the plan is rebuilt whenever they do).
PlannedReminder? _forDay(
  ReminderContext c,
  DateTime at,
  Map<ReminderKind, DateTime> sent,
) {
  final idle = c.lastPractice == null ? 99 : _days(c.lastPractice!, at);
  // A streak survives only if the learner practised yesterday relative to
  // this day: true for the first day only (or today, before practice).
  final streakAlive = c.streak >= 3 && idle <= 1;
  final choirIn = c.choirDue == null ? null : _days(at, c.choirDue!);
  final eligible = <ReminderKind>[
    if (choirIn != null && choirIn >= 0 && choirIn <= 2) ReminderKind.choir,
    if (c.dueCards >= 3) ReminderKind.review,
    if (streakAlive) ReminderKind.streak,
    if (idle >= 3 && idle < 99) ReminderKind.comeBack,
    if (!c.rangeMeasured && c.activeDays >= 3) ReminderKind.range,
    ReminderKind.routine,
  ];
  ReminderKind? best;
  var bestScore = double.negativeInfinity;
  for (final k in eligible) {
    final last = sent[k];
    final age = last == null ? freshnessDays : _days(last, at);
    // Sent today or yesterday: nearly silent, so the next day says
    // something else. Then a linear recovery to full weight after a week.
    final fresh = math.min(1.0, math.max(0, age) / freshnessDays);
    final score = _weight[k]! * (age <= 1 ? 0.1 : 0.15 + 0.85 * fresh);
    if (score > bestScore) {
      bestScore = score;
      best = k;
    }
  }
  if (best == null) return null;
  final (title, body) = reminderText(best, c, choirIn: choirIn);
  return PlannedReminder(at, best, title, body);
}

(String, String) reminderText(
  ReminderKind kind,
  ReminderContext c, {
  int? choirIn,
}) => switch (kind) {
  ReminderKind.review => (
    tr('Tekrar kartların hazır', 'Your review cards are ready'),
    // No count: by the time this fires, more cards may be due.
    tr(
      'Unutmaya başladığın kartlar seni bekliyor; birkaç dakika sürer.',
      'Cards you are starting to forget are waiting; a few minutes.',
    ),
  ),
  ReminderKind.streak => (
    tr(
      '${c.streak} günlük düzenin sürüyor',
      'Your ${c.streak}-day run continues',
    ),
    tr(
      'Bugünkü kısa rotan hazır. İstersen yalnız tekrar kartlarını yap.',
      'Today\'s short route is ready. Just the review cards is fine too.',
    ),
  ),
  ReminderKind.choir => (
    choirIn == 0
        ? tr('Koro ödevi bugün teslim', 'Choir work is due today')
        : tr(
            'Koro ödevine $choirIn gün kaldı',
            'Choir work due in $choirIn days',
          ),
    tr(
      '${c.choirTitle ?? 'Ödev'}: partini dinle, sonra eşlikle söyle.',
      '${c.choirTitle ?? 'Assignment'}: hear your part, then sing along.',
    ),
  ),
  ReminderKind.comeBack => (
    tr('Kaldığın yer hazır', 'Your place is saved'),
    tr(
      'Birkaç gün ara verdin; kısa bir dersle yeniden ısın.',
      'You took a few days off; warm up again with a short lesson.',
    ),
  ),
  ReminderKind.range => (
    tr('Ses aralığını ölçmek ister misin?', 'Want to measure your range?'),
    tr(
      'Piyano çalar, sen tekrar edersin. Dersler senin aralığında çalar.',
      'The piano plays, you repeat. Lessons then play in your range.',
    ),
  ),
  ReminderKind.routine => (
    tr('Bugünkü kısa çalışman hazır', 'Your short practice for today is ready'),
    tr(
      'Kulak ve ses çalışmana kaldığın yerden devam et.',
      'Pick up your ear and voice practice where you left off.',
    ),
  ),
  ReminderKind.weekly => (
    tr('Haftalık hatırlatma', 'Weekly reminder'),
    tr(
      'Seni rahatsız etmemek için artık haftada bir yazıyoruz. Hazır olduğunda buradayız.',
      'To not bother you, we now write once a week. We are here when you are ready.',
    ),
  ),
};

/// The next week of reminders, then weekly ones. The first day is today if
/// the learner has not practised yet and the time is still ahead.
List<PlannedReminder> planReminders(ReminderContext c) {
  final minute = reminderMinute(c);
  DateTime atDay(int offset) => DateTime(
    c.now.year,
    c.now.month,
    c.now.day + offset,
    minute ~/ 60,
    minute % 60,
  );
  final firstOffset = !c.practicedToday && atDay(0).isAfter(c.now) ? 0 : 1;
  final sent = {...c.lastSent};
  final out = <PlannedReminder>[];
  for (var d = firstOffset; d < firstOffset + dailyDays; d++) {
    final r = _forDay(c, atDay(d), sent);
    if (r == null) continue;
    out.add(r);
    sent[r.kind] = r.at;
  }
  final (title, body) = reminderText(ReminderKind.weekly, c);
  for (var w = 1; w <= weeklyAfter; w++) {
    out.add(
      PlannedReminder(
        atDay(firstOffset + dailyDays - 1 + 7 * w),
        ReminderKind.weekly,
        title,
        body,
      ),
    );
  }
  return out;
}
