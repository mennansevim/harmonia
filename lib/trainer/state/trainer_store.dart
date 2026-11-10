import 'dart:async';

import 'package:flutter/foundation.dart';

export '../domain/review_memory.dart' show ReviewCard;
import 'package:path_provider/path_provider.dart';

import '../../infrastructure/storage/json_file_store.dart';
import '../audio/synth.dart';
import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/review_memory.dart';
import '../domain/trainers.dart';
import '../home/daily_route.dart';
import '../koro/range_score.dart' show rangeScoreModelVersion;

/// Where the local document lives. Tests use [MemoryTrainerPersistence].
abstract interface class TrainerPersistence {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> document);
  Future<void> delete();
}

class FileTrainerPersistence implements TrainerPersistence {
  final _store = JsonFileStore(getApplicationSupportDirectory, 'ear_trainer');
  @override
  Future<Map<String, Object?>?> read() => _store.read();
  @override
  Future<void> write(Map<String, Object?> document) => _store.write(document);
  @override
  Future<void> delete() => _store.delete();
}

class MemoryTrainerPersistence implements TrainerPersistence {
  MemoryTrainerPersistence([this.document]);
  Map<String, Object?>? document;
  @override
  Future<Map<String, Object?>?> read() async => document;
  @override
  Future<void> write(Map<String, Object?> document) async =>
      this.document = document;
  @override
  Future<void> delete() async => document = null;
}

class NodeProgress {
  const NodeProgress({required this.stars, required this.review});
  final int stars;
  final bool review;
  Map<String, Object?> toJson() => {'stars': stars, 'review': review};
}

/// One finished attempt at a gate (checkpoint or final exam): questions
/// actually asked, how many were right, and the local day.
class GateAttempt {
  const GateAttempt({
    required this.correct,
    required this.total,
    required this.day,
  });
  final int correct;
  final int total;
  final String day;
  List<Object> toJson() => [correct, total, day];
}

/// Practice evidence for a gate across attempts. It is an indicator only:
/// it never locks, unlocks or routes anything.
class GateEvidence {
  const GateEvidence({
    required this.days,
    required this.questions,
    required this.correct,
  });
  final int days;
  final int questions;
  final int correct;
  double get accuracy => questions == 0 ? 0 : correct / questions;

  /// "Consolidated": confirmed on at least [minDays] separate days, at least
  /// [minQuestions] questions in all and at least [minAccuracy] combined.
  /// Draft hypothesis from LEARNING_MODEL.md (a skill shown on two separate
  /// days with enough valid questions), not an educator-validated mastery
  /// standard.
  bool get consolidated =>
      days >= minDays && questions >= minQuestions && accuracy >= minAccuracy;

  static const minDays = 2;
  static const minQuestions = 36;
  static const minAccuracy = 0.8;
}

class ItemStat {
  ItemStat([this.correct = 0, this.attempts = 0]);
  int correct;
  int attempts;
  double? get accuracy => attempts == 0 ? null : correct / attempts;
}

class DayActivity {
  DayActivity({this.questions = 0, this.correct = 0, this.sessions = 0});
  int questions;
  int correct;
  int sessions;

  /// Per-trainer accuracy samples for the trend charts: trainer -> [c, n].
  final Map<String, List<int>> byTrainer = {};
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The whole ear-trainer state: onboarding answers, preferences, lesson
/// progress and practice evidence. Stored only on this device.
class TrainerStore extends ChangeNotifier {
  TrainerStore(this._persistence, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TrainerPersistence _persistence;
  final DateTime Function() _clock;
  DateTime get now => _clock();

  bool loaded = false;
  bool loadFailed = false;

  // Onboarding and setup.
  bool onboardingDone = false;
  bool setupDone = false;
  final Map<String, Object?> answers = {};

  /// How the learner uses Vocalart (onboarding, multi-select). Older saves
  /// kept a single string under the same key.
  Set<String> get roles => switch (answers['role']) {
    final String r => {r},
    final List l => l.whereType<String>().toSet(),
    _ => const {},
  };

  /// Said they sing in or lead a choir.
  bool get inChoir => roles.contains('singer') || roles.contains('conductor');
  int dailyMinutes = 10;
  String? accountLabel;
  String username = '';
  bool trialAcknowledged = false;
  int trialReminderDays = 2;

  // Preferences.
  NoteNotation _notation = NoteNotation.solfege;

  /// Note naming; also sets [NoteNames.current] so every label agrees.
  NoteNotation get notation => _notation;
  set notation(NoteNotation value) {
    _notation = value;
    NoteNames.current = value;
  }

  int transposition = 0;
  Timbre timbre = Timbre.piano;
  bool keyboard = false;
  bool hints = true;
  bool hintsPromptShown = false;
  bool notifications = false;

  /// Short interface sounds (taps, choices, steps). Never reference pitches.
  bool uiSounds = true;

  // Progress.
  final Map<String, NodeProgress> nodes = {};
  final Map<String, Map<String, ItemStat>> stats = {};

  /// Review-card memory per trainer and item ([memoryModelVersion]).
  final Map<String, Map<String, ItemMemory>> memory = {};

  /// Day key of the last finished review round.
  String? reviewDay;

  /// Minute of day of recent practice (newest last, at most 30): the
  /// reminder planner's habitual time.
  final List<int> practiceMinutes = [];

  /// Reminder plan as scheduled: kind name and local time. Entries already
  /// in the past were delivered and count for freshness.
  final List<(String, DateTime)> reminderPlan = [];
  final Map<String, DayActivity> days = {};
  int xp = 0;
  String? lastTrainer;

  /// Choir part the learner picked (VoicePart.name), null = not chosen.
  String? voicePart;

  VoicePart? get part => VoicePart.values.asNameMap()[voicePart];
  final Set<String> seenTrainerSheets = {};
  String? lastStreakCelebrated;
  String? koroRange;

  /// RANGE-04 range test scores (0–100), oldest first, last [maxRangeScores].
  final List<int> rangeScores = [];
  static const maxRangeScores = 50;

  void addRangeScore(int points) {
    rangeScores.add(points.clamp(0, 100));
    if (rangeScores.length > maxRangeScores) {
      rangeScores.removeRange(0, rangeScores.length - maxRangeScores);
    }
  }

  /// Melody echo level reached (0-based). Practice progress only: it never
  /// feeds XP, streak, mastery or history.
  int melodyEchoLevel = 0;

  /// Clap-back rhythm reached (0-based, easy to hard). Practice progress only.
  int clapLevel = 0;

  /// Look of the clapping hands the learner picked (a `ClapStyle` name),
  /// or null for the default. Cosmetic only. Replaces build 19's int
  /// `clapStyle`, which saved 0 even for learners who never picked.
  String? clapLook;

  /// App language picked in Settings: 'tr', 'en', or null for the device's.
  String? language;

  /// Day key of the last finished breathing guide. Self-paced and unmeasured:
  /// it ticks today's route step only, never streak, XP or mastery.
  String? breathDay;
  bool get breathedToday => breathDay == dayKey(now);
  void markBreathDone() {
    breathDay = dayKey(now);
    save();
  }

  /// Today's route for the stored goal and minutes, echo step included.
  DailyRoute get route => routeFor(
    answers,
    dailyMinutes,
    lastEcho: echoLast,
    echoDoneToday: echoedToday,
  );

  /// Last finished echo exercise (exam route, P4): its kind and day key.
  /// "Done", not "measured": it ticks the route step only, never XP, streak,
  /// mastery or history.
  EchoStep? echoLast;
  String? echoDay;
  bool get echoedToday => echoDay == dayKey(now);
  void markEchoDone(EchoStep kind) {
    echoLast = kind;
    echoDay = dayKey(now);
    save();
  }

  Future<void> load() async {
    try {
      final doc = await _persistence.read();
      if (doc != null) _decode(doc);
      loadFailed = false;
    } catch (_) {
      loadFailed = true;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void>? _pending;
  bool _dirty = false;

  /// Serialised, coalesced writes so rapid answers never interleave.
  void save() {
    notifyListeners();
    _dirty = true;
    _pending ??= _flush();
  }

  Future<void> _flush() async {
    try {
      while (_dirty) {
        _dirty = false;
        try {
          await _persistence.write(_encode());
        } catch (_) {
          // Kept in memory; the next save retries.
        }
      }
    } finally {
      _pending = null;
    }
  }

  Future<void> flush() async {
    while (_pending != null) {
      await _pending;
    }
  }

  Future<void> resetAll() async {
    await flush();
    await _persistence.delete();
    onboardingDone = false;
    setupDone = false;
    answers.clear();
    dailyMinutes = 10;
    accountLabel = null;
    username = '';
    trialAcknowledged = false;
    notation = NoteNotation.solfege;
    transposition = 0;
    timbre = Timbre.piano;
    keyboard = false;
    hints = true;
    hintsPromptShown = false;
    notifications = false;
    uiSounds = true;
    nodes.clear();
    gateAttempts.clear();
    stats.clear();
    days.clear();
    xp = 0;
    lastTrainer = null;
    voicePart = null;
    seenTrainerSheets.clear();
    lastStreakCelebrated = null;
    koroRange = null;
    rangeScores.clear();
    melodyEchoLevel = 0;
    clapLevel = 0;
    clapLook = null;
    breathDay = null;
    echoLast = null;
    echoDay = null;
    language = null;
    memory.clear();
    reviewDay = null;
    practiceMinutes.clear();
    reminderPlan.clear();
    notifyListeners();
  }

  // ---- Lessons ----

  NodeProgress? progressOf(String nodeId) => nodes[nodeId];
  bool isComplete(String nodeId) => nodes.containsKey(nodeId);

  /// A node is open when it is first, or the previous node is complete.
  /// Gates can always be attempted to test out of a section.
  bool isUnlocked(LessonNode node) {
    final path = trainerPaths[node.trainer]!;
    final i = path.indexOf(node.id);
    if (i <= 0 || node.isGate) return true;
    return isComplete(path.nodes[i - 1].id);
  }

  LessonNode? nextNode(TrainerKind trainer) {
    final path = trainerPaths[trainer]!;
    for (final n in path.nodes) {
      if (!isComplete(n.id)) return n;
    }
    return null;
  }

  LessonNode? nextNodeAfterIntro(TrainerKind trainer) => trainerPaths[trainer]!
      .nodes
      .where((n) => n.kind != NodeKind.intro && !isComplete(n.id))
      .firstOrNull;

  int completedCount(TrainerKind trainer) =>
      trainerPaths[trainer]!.nodes.where((n) => isComplete(n.id)).length;

  double mastery(TrainerKind trainer) =>
      completedCount(trainer) / trainerPaths[trainer]!.lessonCount;

  /// Stars show how clean one round was; they are a practice indicator, not
  /// proof of mastery (that is [gateEvidence]). 3 stars at 90% means at most
  /// one miss in 10 or 12 questions and two in 20: a 95% cut made 3 stars
  /// depend mostly on luck (at a true 90% only about one round in three
  /// reached it, VOCAL_MODEL_BENCHMARK §4.3).
  static const threeStarAccuracy = 0.9;
  static const twoStarAccuracy = 0.8;

  static int starsFor(double accuracy) => accuracy >= threeStarAccuracy
      ? 3
      : accuracy >= twoStarAccuracy
      ? 2
      : 1;

  /// Records a finished node. A passed gate completes every earlier node.
  /// Returns whether the node counts as passed.
  ///
  /// [correct] and [total] (questions actually asked) feed the gate attempt
  /// log; [accuracy] alone decides pass and stars, as before. Lessons are not
  /// logged.
  bool completeNode(
    LessonNode node,
    double accuracy, {
    int? correct,
    int? total,
  }) {
    final path = trainerPaths[node.trainer]!;
    final passed = node.isGate ? accuracy >= 0.8 : true;
    if (node.isGate && correct != null && total != null && total > 0) {
      _logGateAttempt(node.id, correct.clamp(0, total), total);
    }
    if (!passed) {
      save();
      return false;
    }
    final stars = node.kind == NodeKind.intro ? 3 : starsFor(accuracy);
    final previous = nodes[node.id];
    nodes[node.id] = NodeProgress(
      stars: previous == null
          ? stars
          : (stars > previous.stars ? stars : previous.stars),
      review: node.kind == NodeKind.lesson && accuracy < 0.7,
    );
    if (node.isGate) {
      for (final n in path.nodes.take(path.indexOf(node.id))) {
        nodes.putIfAbsent(
          n.id,
          () => const NodeProgress(stars: 1, review: false),
        );
      }
    }
    lastTrainer = node.trainer.id;
    save();
    return true;
  }

  // ---- Gate attempt log (mastery indicator) ----

  /// Last attempts per gate, oldest first, at most [maxGateAttempts].
  final Map<String, List<GateAttempt>> gateAttempts = {};
  static const maxGateAttempts = 3;

  void _logGateAttempt(String nodeId, int correct, int total) {
    final list = gateAttempts.putIfAbsent(nodeId, () => []);
    list.add(GateAttempt(correct: correct, total: total, day: dayKey(now)));
    if (list.length > maxGateAttempts) {
      list.removeRange(0, list.length - maxGateAttempts);
    }
  }

  /// Evidence over the logged attempts of a gate; null without any.
  GateEvidence? gateEvidence(String nodeId) {
    final list = gateAttempts[nodeId];
    if (list == null || list.isEmpty) return null;
    return GateEvidence(
      days: {for (final a in list) a.day}.length,
      questions: list.fold(0, (n, a) => n + a.total),
      correct: list.fold(0, (n, a) => n + a.correct),
    );
  }

  // ---- Practice evidence ----

  void recordAnswer(TrainerKind trainer, String itemId, bool correct) {
    final perTrainer = stats.putIfAbsent(trainer.id, () => {});
    final s = perTrainer.putIfAbsent(itemId, ItemStat.new);
    s.attempts++;
    if (correct) s.correct++;
    final mem = memory.putIfAbsent(trainer.id, () => {});
    final before = mem[itemId];
    mem[itemId] =
        before?.answered(correct, now) ?? ItemMemory.first(correct, now);
    final day = days.putIfAbsent(dayKey(now), DayActivity.new);
    day.questions++;
    if (correct) day.correct++;
    final t = day.byTrainer.putIfAbsent(trainer.id, () => [0, 0]);
    t[1]++;
    if (correct) t[0]++;
    xp += correct ? 10 : 2;
    lastTrainer = trainer.id;
    save();
  }

  void recordSession() {
    days.putIfAbsent(dayKey(now), DayActivity.new).sessions++;
    _notePracticeTime();
    save();
  }

  void _notePracticeTime() {
    practiceMinutes.add(now.hour * 60 + now.minute);
    if (practiceMinutes.length > 30) practiceMinutes.removeAt(0);
  }

  /// Last day with any answered question.
  DateTime? get lastPracticeDay {
    final active = days.entries.where((e) => e.value.questions > 0);
    if (active.isEmpty) return null;
    final k = active
        .map((e) => e.key)
        .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    return DateTime.tryParse(k);
  }

  int get activeDayCount => days.values.where((d) => d.questions > 0).length;

  /// Cards due now, interleaved across trainers.
  List<ReviewCard> get dueReview => dueCards(memory, now);

  bool get reviewedToday => reviewDay == dayKey(now);

  void markReviewDone() {
    reviewDay = dayKey(now);
    _notePracticeTime();
    save();
  }

  bool get practicedToday => (days[dayKey(now)]?.questions ?? 0) > 0;
  bool get sessionToday => (days[dayKey(now)]?.sessions ?? 0) > 0;

  /// Consecutive active days ending today (or yesterday if not yet today).
  int get streak {
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.containsKey(dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while ((days[dayKey(cursor)]?.questions ?? 0) > 0) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  bool activeOn(DateTime d) => (days[dayKey(d)]?.questions ?? 0) > 0;

  int get totalQuestions => days.values.fold(0, (sum, d) => sum + d.questions);

  int weeklyXp() {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    var sum = 0;
    for (var i = 0; i < 7; i++) {
      final d = days[dayKey(monday.add(Duration(days: i)))];
      if (d != null) sum += d.correct * 10 + (d.questions - d.correct) * 2;
    }
    return sum;
  }

  Map<String, ItemStat> itemStats(TrainerKind trainer) =>
      stats[trainer.id] ?? const {};

  int trainerReps(TrainerKind trainer) =>
      itemStats(trainer).values.fold(0, (s, i) => s + i.attempts);

  /// Per-day accuracy for one trainer over the last [span] days (null = idle).
  List<double?> trend(TrainerKind trainer, {int span = 14}) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var i = span - 1; i >= 0; i--)
        () {
          final t = days[dayKey(today.subtract(Duration(days: i)))]
              ?.byTrainer[trainer.id];
          return t == null || t[1] == 0 ? null : t[0] / t[1];
        }(),
    ];
  }

  // ---- Encoding ----

  Map<String, Object?> _encode() => {
    'version': 1,
    'onboardingDone': onboardingDone,
    'setupDone': setupDone,
    'answers': answers,
    'dailyMinutes': dailyMinutes,
    'accountLabel': accountLabel,
    'username': username,
    'trialAcknowledged': trialAcknowledged,
    'trialReminderDays': trialReminderDays,
    'prefs': {
      'notation': notation.name,
      'transposition': transposition,
      'timbre': timbre.name,
      'keyboard': keyboard,
      'hints': hints,
      'hintsPromptShown': hintsPromptShown,
      'notifications': notifications,
      'uiSounds': uiSounds,
    },
    'nodes': {for (final e in nodes.entries) e.key: e.value.toJson()},
    'gateAttempts': {
      for (final e in gateAttempts.entries)
        e.key: [for (final a in e.value) a.toJson()],
    },
    'stats': {
      for (final t in stats.entries)
        t.key: {
          for (final i in t.value.entries)
            i.key: [i.value.correct, i.value.attempts],
        },
    },
    'days': {
      for (final d in days.entries)
        d.key: {
          'q': d.value.questions,
          'c': d.value.correct,
          's': d.value.sessions,
          't': d.value.byTrainer,
        },
    },
    'xp': xp,
    'lastTrainer': lastTrainer,
    'voicePart': voicePart,
    'seenSheets': seenTrainerSheets.toList(),
    'lastStreakCelebrated': lastStreakCelebrated,
    'koroRange': koroRange,
    'rangeScores': rangeScores,
    'rangeScoreModel': rangeScoreModelVersion,
    'melodyEchoLevel': melodyEchoLevel,
    'clapLevel': clapLevel,
    'clapLook': clapLook,
    'breathDay': breathDay,
    'echoLast': echoLast?.id,
    'echoDay': echoDay,
    'language': language,
    'memoryModel': memoryModelVersion,
    'memory': {
      for (final t in memory.entries)
        t.key: {for (final i in t.value.entries) i.key: i.value.toJson()},
    },
    'reviewDay': reviewDay,
    'practiceMinutes': practiceMinutes,
    'reminderPlan': [
      for (final (k, t) in reminderPlan) [k, t.toUtc().millisecondsSinceEpoch],
    ],
  };

  void _decode(Map<String, Object?> doc) {
    T? get<T>(Map<String, Object?> m, String k) {
      final v = m[k];
      return v is T ? v : null;
    }

    onboardingDone = get<bool>(doc, 'onboardingDone') ?? false;
    setupDone = get<bool>(doc, 'setupDone') ?? false;
    answers
      ..clear()
      ..addAll(get<Map<String, Object?>>(doc, 'answers') ?? const {});
    dailyMinutes = get<int>(doc, 'dailyMinutes') ?? 10;
    accountLabel = get<String>(doc, 'accountLabel');
    username = get<String>(doc, 'username') ?? '';
    trialAcknowledged = get<bool>(doc, 'trialAcknowledged') ?? false;
    trialReminderDays = get<int>(doc, 'trialReminderDays') ?? 2;
    final prefs = get<Map<String, Object?>>(doc, 'prefs') ?? const {};
    notation =
        NoteNotation.values.asNameMap()[get<String>(prefs, 'notation')] ??
        NoteNotation.solfege;
    transposition = (get<int>(prefs, 'transposition') ?? 0) % 12;
    timbre =
        Timbre.values.asNameMap()[get<String>(prefs, 'timbre')] ?? Timbre.piano;
    keyboard = get<bool>(prefs, 'keyboard') ?? false;
    hints = get<bool>(prefs, 'hints') ?? true;
    hintsPromptShown = get<bool>(prefs, 'hintsPromptShown') ?? false;
    notifications = get<bool>(prefs, 'notifications') ?? false;
    uiSounds = get<bool>(prefs, 'uiSounds') ?? true;
    nodes.clear();
    (get<Map<String, Object?>>(doc, 'nodes') ?? const {}).forEach((k, v) {
      if (v is Map<String, Object?>) {
        nodes[k] = NodeProgress(
          stars: (get<int>(v, 'stars') ?? 1).clamp(1, 3),
          review: get<bool>(v, 'review') ?? false,
        );
      }
    });
    gateAttempts.clear();
    (get<Map<String, Object?>>(doc, 'gateAttempts') ?? const {}).forEach((
      id,
      v,
    ) {
      if (v is! List) return;
      final list = <GateAttempt>[
        for (final a in v)
          if (a is List &&
              a.length == 3 &&
              a[0] is int &&
              a[1] is int &&
              a[2] is String &&
              (a[1] as int) > 0 &&
              (a[0] as int) >= 0 &&
              (a[0] as int) <= (a[1] as int))
            GateAttempt(
              correct: a[0] as int,
              total: a[1] as int,
              day: a[2] as String,
            ),
      ];
      if (list.isNotEmpty) {
        gateAttempts[id] = list.length > maxGateAttempts
            ? list.sublist(list.length - maxGateAttempts)
            : list;
      }
    });
    stats.clear();
    (get<Map<String, Object?>>(doc, 'stats') ?? const {}).forEach((t, items) {
      if (items is! Map<String, Object?>) return;
      final m = stats.putIfAbsent(t, () => {});
      items.forEach((id, v) {
        if (v is List && v.length == 2 && v[0] is int && v[1] is int) {
          m[id] = ItemStat(v[0] as int, v[1] as int);
        }
      });
    });
    days.clear();
    (get<Map<String, Object?>>(doc, 'days') ?? const {}).forEach((k, v) {
      if (v is! Map<String, Object?>) return;
      final d = DayActivity(
        questions: get<int>(v, 'q') ?? 0,
        correct: get<int>(v, 'c') ?? 0,
        sessions: get<int>(v, 's') ?? 0,
      );
      (get<Map<String, Object?>>(v, 't') ?? const {}).forEach((t, cn) {
        if (cn is List && cn.length == 2 && cn[0] is int && cn[1] is int) {
          d.byTrainer[t] = [cn[0] as int, cn[1] as int];
        }
      });
      days[k] = d;
    });
    xp = get<int>(doc, 'xp') ?? 0;
    lastTrainer = get<String>(doc, 'lastTrainer');
    voicePart =
        VoicePart.values.asNameMap().containsKey(get<String>(doc, 'voicePart'))
        ? get<String>(doc, 'voicePart')
        : null;
    seenTrainerSheets
      ..clear()
      ..addAll(
        (get<List<Object?>>(doc, 'seenSheets') ?? const []).whereType<String>(),
      );
    lastStreakCelebrated = get<String>(doc, 'lastStreakCelebrated');
    koroRange = get<String>(doc, 'koroRange');
    // Scores of another formula (the pre-match-1 scale included width) are
    // not comparable: drop them rather than mix scales.
    rangeScores
      ..clear()
      ..addAll(
        (get<String>(doc, 'rangeScoreModel') != rangeScoreModelVersion
                ? const <Object?>[]
                : get<List<Object?>>(doc, 'rangeScores') ?? const [])
            .whereType<int>()
            .where((p) => p >= 0 && p <= 100)
            .take(maxRangeScores),
      );
    melodyEchoLevel = (get<int>(doc, 'melodyEchoLevel') ?? 0).clamp(0, 99);
    clapLevel = (get<int>(doc, 'clapLevel') ?? 0).clamp(0, 99);
    clapLook = get<String>(doc, 'clapLook');
    breathDay = get<String>(doc, 'breathDay');
    echoLast = EchoStepInfo.fromId(get<String>(doc, 'echoLast'));
    echoDay = get<String>(doc, 'echoDay');
    memory.clear();
    // Another model version's half-lives mean something else: start over
    // rather than reinterpret them.
    if (get<String>(doc, 'memoryModel') == memoryModelVersion) {
      (get<Map<String, Object?>>(doc, 'memory') ?? const {}).forEach((
        t,
        items,
      ) {
        if (items is! Map<String, Object?>) return;
        final m = <String, ItemMemory>{};
        items.forEach((id, v) {
          final parsed = ItemMemory.fromJson(v);
          if (parsed != null) m[id] = parsed;
        });
        if (m.isNotEmpty) memory[t] = m;
      });
    }
    reviewDay = get<String>(doc, 'reviewDay');
    practiceMinutes
      ..clear()
      ..addAll(
        (get<List<Object?>>(doc, 'practiceMinutes') ?? const [])
            .whereType<int>()
            .where((m) => m >= 0 && m < 24 * 60),
      );
    reminderPlan.clear();
    for (final e in get<List<Object?>>(doc, 'reminderPlan') ?? const []) {
      if (e is List && e.length == 2 && e[0] is String && e[1] is int) {
        reminderPlan.add((
          e[0] as String,
          DateTime.fromMillisecondsSinceEpoch(
            e[1] as int,
            isUtc: true,
          ).toLocal(),
        ));
      }
    }
    final lang = get<String>(doc, 'language');
    language = lang == 'tr' || lang == 'en' ? lang : null;
  }
}
