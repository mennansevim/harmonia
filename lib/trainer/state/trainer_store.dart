import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../infrastructure/storage/json_file_store.dart';
import '../audio/synth.dart';
import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';

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
  int dailyMinutes = 8;
  String? accountLabel;
  String username = '';
  bool trialAcknowledged = false;
  int trialReminderDays = 2;

  // Preferences.
  NoteNotation notation = NoteNotation.solfege;
  int transposition = 0;
  Timbre timbre = Timbre.piano;
  bool keyboard = false;
  bool hints = true;
  bool hintsPromptShown = false;
  bool notifications = false;

  // Progress.
  final Map<String, NodeProgress> nodes = {};
  final Map<String, Map<String, ItemStat>> stats = {};
  final Map<String, DayActivity> days = {};
  int xp = 0;
  String? lastTrainer;

  /// Choir part the learner picked (VoicePart.name), null = not chosen.
  String? voicePart;

  VoicePart? get part => VoicePart.values.asNameMap()[voicePart];
  final Set<String> seenTrainerSheets = {};
  String? lastStreakCelebrated;
  String? koroRange;

  /// Day key of the last finished breathing guide. Self-paced and unmeasured:
  /// it ticks today's route step only, never streak, XP or mastery.
  String? breathDay;
  bool get breathedToday => breathDay == dayKey(now);
  void markBreathDone() {
    breathDay = dayKey(now);
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
    dailyMinutes = 8;
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
    nodes.clear();
    stats.clear();
    days.clear();
    xp = 0;
    lastTrainer = null;
    voicePart = null;
    seenTrainerSheets.clear();
    lastStreakCelebrated = null;
    koroRange = null;
    breathDay = null;
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

  static int starsFor(double accuracy) => accuracy >= 0.95
      ? 3
      : accuracy >= 0.8
      ? 2
      : 1;

  /// Records a finished node. A passed gate completes every earlier node.
  /// Returns whether the node counts as passed.
  bool completeNode(LessonNode node, double accuracy) {
    final path = trainerPaths[node.trainer]!;
    final passed = node.isGate ? accuracy >= 0.8 : true;
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

  // ---- Practice evidence ----

  void recordAnswer(TrainerKind trainer, String itemId, bool correct) {
    final perTrainer = stats.putIfAbsent(trainer.id, () => {});
    final s = perTrainer.putIfAbsent(itemId, ItemStat.new);
    s.attempts++;
    if (correct) s.correct++;
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
    },
    'nodes': {for (final e in nodes.entries) e.key: e.value.toJson()},
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
    'breathDay': breathDay,
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
    dailyMinutes = get<int>(doc, 'dailyMinutes') ?? 8;
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
    nodes.clear();
    (get<Map<String, Object?>>(doc, 'nodes') ?? const {}).forEach((k, v) {
      if (v is Map<String, Object?>) {
        nodes[k] = NodeProgress(
          stars: (get<int>(v, 'stars') ?? 1).clamp(1, 3),
          review: get<bool>(v, 'review') ?? false,
        );
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
    breathDay = get<String>(doc, 'breathDay');
  }
}
