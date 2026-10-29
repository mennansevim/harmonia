import 'dart:math' as math;

import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';

enum QuestionType { identify, yesNo, find }

class QuizQuestion {
  QuizQuestion.identify({
    required this.trainer,
    required this.answer,
    required this.options,
    required SoundSpec sound,
  }) : type = QuestionType.identify,
       target = answer,
       sounds = [sound],
       correctIndex = 0,
       isMatch = true;

  QuizQuestion.yesNo({
    required this.trainer,
    required this.target,
    required this.answer,
    required SoundSpec sound,
  }) : type = QuestionType.yesNo,
       options = const [],
       sounds = [sound],
       correctIndex = 0,
       isMatch = answer == target;

  QuizQuestion.find({
    required this.trainer,
    required this.target,
    required this.options,
    required this.sounds,
    required this.correctIndex,
  }) : type = QuestionType.find,
       answer = target,
       isMatch = true;

  final QuestionType type;
  final TrainerKind trainer;

  /// The item actually played (identify/yes-no) or sought (find).
  final String answer;

  /// The item named on screen (yes-no/find).
  final String target;

  /// Selectable item ids (identify) or the item behind each sound (find).
  final List<String> options;
  final List<SoundSpec> sounds;
  final int correctIndex;
  final bool isMatch;

  SoundSpec get sound => sounds.first;
}

/// Settings that shape how questions sound.
class QuizConfig {
  const QuizConfig({
    required this.trainer,
    required this.pool,
    this.registers = const [Register.medium],
    this.direction = IntervalDirection.ascending,
    this.reference = false,
    this.inversions = false,
    this.timeLimitSeconds,
    this.length = 10,
  });

  final TrainerKind trainer;
  final List<String> pool;
  final List<Register> registers;
  final IntervalDirection direction;
  final bool reference;
  final bool inversions;
  final int? timeLimitSeconds;
  final int length;

  /// [voice] moves playback into the learner's choir part.
  factory QuizConfig.forNode(
    LessonNode node, {
    int? length,
    VoicePart? voice,
  }) => QuizConfig(
    trainer: node.trainer,
    pool: node.items,
    registers: [for (final r in node.registers) voice?.fit(r) ?? r],
    direction: node.direction,
    length:
        length ??
        switch (node.kind) {
          NodeKind.finalExam => 20,
          NodeKind.checkpoint => 12,
          _ => 10,
        },
  );
}

class QuizGenerator {
  QuizGenerator(QuizConfig config, {math.Random? random})
    : this._(config, random ?? math.Random());
  QuizGenerator._(this.config, this.random) : sounds = SoundFactory(random);

  final QuizConfig config;
  final math.Random random;
  final SoundFactory sounds;
  String? _last;

  Register get _register =>
      config.registers[random.nextInt(config.registers.length)];

  SoundSpec soundOf(String item) => sounds.item(
    config.trainer,
    item,
    register: _register,
    direction: config.direction,
    reference: config.reference,
    inversions: config.inversions,
  );

  /// Avoids asking the same item twice in a row when the pool allows it.
  String _pick(List<String> from) {
    if (from.length == 1) return from.first;
    String pick;
    do {
      pick = from[random.nextInt(from.length)];
    } while (pick == _last);
    return _last = pick;
  }

  /// Items that are not [item]: the pool first, then the whole trainer.
  List<String> distractors(String item, int count) {
    final fromPool = config.pool.where((i) => i != item).toList()
      ..shuffle(random);
    final others =
        config.trainer.allItems
            .where((i) => i != item && !fromPool.contains(i))
            .toList()
          ..shuffle(random);
    return [...fromPool, ...others].take(count).toList();
  }

  QuizQuestion identify() {
    final item = _pick(config.pool);
    return QuizQuestion.identify(
      trainer: config.trainer,
      answer: item,
      options: config.pool,
      sound: soundOf(item),
    );
  }

  QuizQuestion yesNo({String? target}) {
    final t = target ?? _pick(config.pool);
    final match = random.nextBool();
    final played = match ? t : distractors(t, 1).first;
    return QuizQuestion.yesNo(
      trainer: config.trainer,
      target: t,
      answer: played,
      sound: soundOf(played),
    );
  }

  QuizQuestion find({String? target, int choices = 4}) {
    final t = target ?? _pick(config.pool);
    final options = [t, ...distractors(t, choices - 1)]..shuffle(random);
    return QuizQuestion.find(
      trainer: config.trainer,
      target: t,
      options: options,
      sounds: [for (final o in options) soundOf(o)],
      correctIndex: options.indexOf(t),
    );
  }

  /// Practice/test sequence. Single-item pools cannot use identify, so they
  /// alternate yes/no and find (the lesson format).
  List<QuizQuestion> session() {
    final out = <QuizQuestion>[];
    for (var i = 0; i < config.length; i++) {
      if (config.pool.length == 1) {
        out.add(i.isEven ? yesNo() : find());
      } else {
        out.add(identify());
      }
    }
    return out;
  }

  /// A lesson's "Ayırt et" block: mostly naming from the whole pool, every
  /// third question a pick-the-sound on a new item. Single-item pools
  /// alternate find and yes/no.
  List<QuizQuestion> lessonPractice(LessonNode node) {
    final focus = node.newItems.isEmpty ? node.items : node.newItems;
    final out = <QuizQuestion>[];
    for (var i = 0; i < config.length; i++) {
      final target = focus[random.nextInt(focus.length)];
      if (config.pool.length == 1) {
        out.add(
          i.isEven ? find(target: target, choices: 3) : yesNo(target: target),
        );
      } else if (i % 3 == 2) {
        out.add(find(target: target, choices: 3));
      } else {
        out.add(identify());
      }
    }
    return out;
  }
}

/// Outcome of one question (first attempt counts).
class AnswerRecord {
  const AnswerRecord(this.question, this.correct, {this.chosen});
  final QuizQuestion question;
  final bool correct;
  final String? chosen;
}

class QuizSummary {
  QuizSummary(this.records);
  final List<AnswerRecord> records;
  int get correct => records.where((r) => r.correct).length;
  int get total => records.length;
  double get accuracy => total == 0 ? 0 : correct / total;

  /// item -> (correct, total), keyed by what was actually played.
  Map<String, (int, int)> byItem() {
    final m = <String, (int, int)>{};
    for (final r in records) {
      final key = r.question.type == QuestionType.yesNo
          ? r.question.target
          : r.question.answer;
      final (c, n) = m[key] ?? (0, 0);
      m[key] = (c + (r.correct ? 1 : 0), n + 1);
    }
    return m;
  }
}
