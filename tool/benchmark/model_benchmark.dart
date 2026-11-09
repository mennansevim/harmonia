// Scoring-weight, gate-statistics, curriculum-load and spaced-repetition
// analysis of the shipped Vocalart/Resonia trainer model. Uses the real domain
// classes. Every "singer"/"learner" below is a SIMULATION.
import 'dart:io';
import 'dart:math' as math;

import 'package:resonia/domain/audio/pitch_analyzer.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/scoring/pitch_exercise_scorer.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/review_memory.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/home/daily_route.dart';
import 'package:resonia/trainer/koro/range_ladder.dart';
import 'package:resonia/trainer/koro/range_score.dart';
import 'package:resonia/trainer/quiz/quiz.dart';

final out = StringBuffer();
void w([String s = '']) => out.writeln(s);
String f(num v, [int d = 1]) => v.isNaN ? '-' : v.toStringAsFixed(d);

double gauss(math.Random r) =>
    math.sqrt(-2 * math.log(1 - r.nextDouble())) *
    math.cos(2 * math.pi * r.nextDouble());

double midiHz(int m) => 440 * math.pow(2, (m - 69) / 12).toDouble();

// ------------------------------------------------------------ binomial utils
double logChoose(int n, int k) {
  var s = 0.0;
  for (var i = 1; i <= k; i++) {
    s += math.log(n - k + i) - math.log(i);
  }
  return s;
}

double binomPmf(int n, int k, double p) {
  if (p <= 0) return k == 0 ? 1 : 0;
  if (p >= 1) return k == n ? 1 : 0;
  return math.exp(
    logChoose(n, k) + k * math.log(p) + (n - k) * math.log(1 - p),
  );
}

double binomTail(int n, int kmin, double p) {
  var s = 0.0;
  for (var k = kmin; k <= n; k++) {
    s += binomPmf(n, k, p);
  }
  return s;
}

// ------------------------------------------------------------------ A. scorer
void scorerSection() {
  w('## A. PitchExerciseScorer (real class) — overall score vs error');
  const scorer = PitchExerciseScorer();
  const ex = Exercise(
    id: 'bench',
    skill: Skill.pitch,
    title: 'bench',
    difficulty: 1,
    targetNote: TargetNote(note: 'C4', frequencyHz: 261.63),
  );
  ({double overall, bool ok}) run(double cents, double stab) {
    final r = scorer.score(
      exercise: ex,
      sessionId: 's',
      pitch: PitchAnalysisResult(
        detectedFrequencyHz: 261.63 * math.pow(2, cents / 1200),
        centsDifference: cents,
        octaveOffset: 0,
        voicedRatio: .95,
        stabilityCents: stab,
        isNoisy: false,
      ),
      createdAt: DateTime(2026),
    );
    return (overall: r.scores.overall.value ?? double.nan, ok: r.isSuccess);
  }

  w(
    '| |cents| | stab SD 0 | SD 10 | SD 25 | SD 26 | SD 35 (±50c vibrato) | SD 71 (±100c vibrato) |',
  );
  w('|---|---|---|---|---|---|---|');
  for (final c in [0, 10, 25, 40, 49, 50, 51, 60, 100]) {
    final cells = [
      for (final s in [0, 10, 25, 26, 35, 71])
        () {
          final r = run(c.toDouble(), s.toDouble());
          return '${f(r.overall, 0)}${r.ok ? ' ✓' : ' ✗'}';
        }(),
    ];
    w('| $c | ${cells.join(' | ')} |');
  }
  final a = run(50, 0), b = run(50.5, 0);
  w(
    '\nCliff at the tolerance edge (stability perfect): 50 c → ${f(a.overall, 1)} (${a.ok ? 'success' : 'fail'}), 50.5 c → ${f(b.overall, 1)} (${b.ok ? 'success' : 'fail'}): a step of ${f(a.overall - b.overall, 1)} points for 0.5 cent.',
  );
  w(
    'Vibrato note: the stability term is capped at 25 c SD; a sinusoidal vibrato of extent ±A cents has SD = A/√2 (A=35 → 25 c).',
  );
  final vib = [
    for (final a in [20, 30, 35, 50, 70, 100]) a / math.sqrt2,
  ];
  w(
    'Vibrato extent ±20/30/35/50/70/100 c → SD ${vib.map((v) => f(v, 0)).join('/')} c. Flagged "unstable" when SD>25 c (extent > ±35 c).',
  );
}

// ------------------------------------------------------------ B. range score
void rangeSection() {
  w('\n## B. RangeScore weights (width .60 / accuracy .25 / first-try .15)');
  RangeScore s(int semis, double acc, double first) => RangeScore(
    semitones: semis,
    width: math.min(1, semis / rangeScoreFullWidth) * 100,
    accuracy: acc,
    firstTry: first,
  );
  final loose = s(36, 60, 0), clean = s(14, 100, 100);
  w(
    'Source comment says a wide range sung loosely cannot beat a narrower clean one. Checked on the real formula:',
  );
  w(
    '- 36 semitones, accuracy 60 (lowest a matched take can have), 0% first-try → ${loose.points} pts',
  );
  w('- 14 semitones, accuracy 100, 100% first-try → ${clean.points} pts');
  w(
    '| semitones | loose (acc 60, first-try 0) | clean-14 | loose beats clean? |',
  );
  w('|---|---|---|---|');
  for (final semis in [14, 18, 22, 26, 30, 34, 36]) {
    final l = s(semis, 60, 0);
    w(
      '| $semis | ${l.points} | ${clean.points} | ${l.total > clean.total ? 'YES' : 'no'} |',
    );
  }
  // break-even
  for (var semis = 14; semis <= 36; semis++) {
    if (s(semis, 60, 0).total > clean.total) {
      w(
        'Break-even: a loosely-sung range of $semis semitones already outranks a clean 14-semitone range.',
      );
      break;
    }
  }
  w(
    'Maximum points from width alone: ${(rangeScoreWidthWeight * 100).round()} of 100; accuracy+first-try can add at most ${((rangeScoreAccuracyWeight + rangeScoreFirstTryWeight) * 100).round()}.',
  );
  w(
    'Accuracy part is bounded to [60,100] because only matched takes (≤40 c) count, so its real spread is ${((rangeScoreAccuracyWeight) * 40).round()} points.',
  );

  // Simulated singers through the REAL ladder.
  RangeScore? sim(int lo, int hi, double sigma, math.Random r) {
    final center = ((lo + hi) / 2).round();
    var ladder = RangeLadder.start(startFromComfort(midiHz(center)));
    var guard = 0;
    while (!ladder.done && guard++ < 400) {
      final t = ladder.currentMidi;
      final edge = t > hi ? hi : (t < lo ? lo : t);
      final hz = midiHz(edge) * math.pow(2, gauss(r) * sigma / 1200);
      ladder = ladder.record(hz);
    }
    return RangeScore.of(ladder);
  }

  final rnd = math.Random(7);
  const widths = [10, 14, 18, 22, 26, 30];
  const sigmas = [10.0, 20.0, 30.0, 40.0, 60.0];
  const runs = 300;
  w(
    '\nSimulated singers through the real RangeLadder (true comfortable range centred on A3; per-take pitch noise σ in cents; $runs runs per cell).',
  );
  w('Cell = mean measured semitones / mean points / SD points.');
  w(
    '| true range (semitones) | ${sigmas.map((s) => 'σ=${s.round()}c').join(' | ')} |',
  );
  w('|---|${sigmas.map((_) => '---').join('|')}|');
  final pts = <(int, double, double)>[]; // width, sigma, points
  for (final wd in widths) {
    final cells = <String>[];
    for (final sg in sigmas) {
      final semis = <double>[], p = <double>[];
      var none = 0;
      for (var i = 0; i < runs; i++) {
        final lo = 57 - wd ~/ 2, hi = lo + wd;
        final sc = sim(lo, hi, sg, rnd);
        if (sc == null) {
          none++;
          continue;
        }
        semis.add(sc.semitones.toDouble());
        p.add(sc.points.toDouble());
        pts.add((wd, sg, sc.points.toDouble()));
      }
      double mean(List<double> l) =>
          l.isEmpty ? double.nan : l.reduce((a, b) => a + b) / l.length;
      double sd(List<double> l) {
        if (l.length < 2) return double.nan;
        final m = mean(l);
        return math.sqrt(
          l.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / l.length,
        );
      }

      cells.add(
        '${f(mean(semis), 0)} / ${f(mean(p), 0)} / ${f(sd(p), 1)}${none > 0 ? ' (null ${(100 * none / runs).round()}%)' : ''}',
      );
    }
    w('| $wd | ${cells.join(' | ')} |');
  }
  // variance decomposition via OLS on standardised width and sigma
  final xs1 = pts.map((e) => e.$1.toDouble()).toList();
  final xs2 = pts.map((e) => e.$2).toList();
  final ys = pts.map((e) => e.$3).toList();
  double mean(List<double> l) => l.reduce((a, b) => a + b) / l.length;
  double sd(List<double> l) {
    final m = mean(l);
    return math.sqrt(
      l.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / l.length,
    );
  }

  double corr(List<double> a, List<double> b) {
    final ma = mean(a), mb = mean(b);
    var num = 0.0;
    for (var i = 0; i < a.length; i++) {
      num += (a[i] - ma) * (b[i] - mb);
    }
    return num / (a.length * sd(a) * sd(b));
  }

  w(
    '\nAcross all simulated singers: corr(points, true range)=${f(corr(ys, xs1), 2)}, corr(points, pitch noise σ)=${f(corr(ys, xs2), 2)}. A singer with a narrow range but steady pitch and one with a wide range but noisy pitch land on overlapping points.',
  );
  // test-retest
  final rep = <double>[], repSemis = <double>[];
  for (var i = 0; i < 400; i++) {
    final sc = sim(57 - 9, 57 + 9, 25, rnd);
    if (sc != null) {
      rep.add(sc.points.toDouble());
      repSemis.add(sc.semitones.toDouble());
    }
  }
  w(
    'Test–retest, one fixed singer (18-semitone range, σ=25 c), 400 repeats: points mean ${f(mean(rep), 1)}, SD ${f(sd(rep), 1)}; measured semitones mean ${f(mean(repSemis), 1)}, SD ${f(sd(repSemis), 1)}.',
  );
}

// ---------------------------------------------------------- C. gates & stars
void gateSection() {
  w('\n## C. Gate / star statistics on the shipped lesson paths');
  w(
    'Rules copied from trainer_store.dart: gate passes at ≥80% (checkpoint 12 q, final 20 q); lesson = always completes (10 q); stars ≥95% → 3, ≥80% → 2, else 1; review flag <70%.',
  );
  w(
    '| trainer | gate | n | pool (chance = 1/pool) | pass cut | P(pass by guessing) | P(pass | true 70%) | P(pass | 80%) | P(pass | 85%) | P(pass | 90%) |',
  );
  w('|---|---|---|---|---|---|---|---|---|---|');
  for (final e in trainerPaths.entries) {
    for (final node in e.value.nodes.where((n) => n.isGate)) {
      final n = QuizConfig.forNode(node).length;
      final cut = (0.8 * n).ceil();
      final pool = node.items.length;
      w(
        '| ${e.key.id} | ${node.id.split('-').last} | $n | $pool (${f(100 / pool, 0)}%) | $cut/$n | ${f(100 * binomTail(n, cut, 1 / pool), 3)}% | ${f(100 * binomTail(n, cut, .7), 1)}% | ${f(100 * binomTail(n, cut, .8), 1)}% | ${f(100 * binomTail(n, cut, .85), 1)}% | ${f(100 * binomTail(n, cut, .9), 1)}% |',
      );
    }
  }
  w(
    '\n3-star probability (needs ≥95%): n=10 lesson: needs 10/10; n=12: 12/12; n=20: ≥19/20.',
  );
  w(
    '| true accuracy | P(3★) lesson n=10 | P(3★) checkpoint n=12 | P(3★) final n=20 | P(≥2★) lesson | P(review flag) lesson |',
  );
  w('|---|---|---|---|---|---|');
  for (final p in [.7, .8, .85, .9, .95, .98]) {
    w(
      '| ${f(p * 100, 0)}% | ${f(100 * binomTail(10, 10, p), 0)}% | ${f(100 * binomTail(12, 12, p), 0)}% | ${f(100 * binomTail(20, 19, p), 0)}% | ${f(100 * binomTail(10, 8, p), 0)}% | ${f(100 * (1 - binomTail(10, 7, p)), 0)}% |',
    );
  }
  w(
    '\nSample size needed: cut-off c of n questions that rejects a 60%-learner (≤5% false pass) while passing an 80%-learner ≥80% of the time:',
  );
  for (var n = 10; n <= 80; n++) {
    var found = false;
    for (var c = 0; c <= n; c++) {
      if (binomTail(n, c, .6) <= .05 && binomTail(n, c, .8) >= .8) {
        w(
          '- smallest n = $n (pass at ≥$c correct = ${f(100 * c / n, 0)}%): false-pass(60%) ${f(100 * binomTail(n, c, .6), 1)}%, pass(80%) ${f(100 * binomTail(n, c, .8), 1)}%. The shipped 12-q gate: false-pass(60%) ${f(100 * binomTail(12, 10, .6), 1)}%, pass(80%) ${f(100 * binomTail(12, 10, .8), 1)}%.',
        );
        found = true;
        break;
      }
    }
    if (found) break;
  }
  w('\nXP economics (trainer_store.recordAnswer): +10 correct, +2 wrong.');
  for (final k in [2, 3, 6, 12]) {
    final chance = 1 / k;
    final xpRandom = 10 * chance + 2 * (1 - chance);
    w(
      '- random clicking with $k options: ${f(xpRandom, 1)} XP/question = ${f(100 * xpRandom / 10, 0)}% of a perfect run; at 1 s/click vs a careful 15 s/question that is ${f(xpRandom * 3600 / 1, 0)} vs ${f(10 * 3600 / 15, 0)} XP/hour.',
    );
  }
}

// -------------------------------------------------------- D. curriculum load
void curriculumSection() {
  w('\n## D. Curriculum structure and load (real trainerPaths)');
  w(
    '| trainer | stages(items) | nodes | intro | lessons (new / review / drill) | checkpoints | final | questions if every node done once | options shown per question (min–max) |',
  );
  w('|---|---|---|---|---|---|---|---|---|');
  var totalQ = 0, totalNodes = 0;
  for (final e in trainerPaths.entries) {
    final nodes = e.value.nodes;
    final lessons = nodes.where((n) => n.kind == NodeKind.lesson).toList();
    final nw = lessons.where((n) => n.newItems.isNotEmpty).length;
    final rev = lessons
        .where(
          (n) =>
              n.newItems.isEmpty &&
              n.title.contains(RegExp('tekrar|review', caseSensitive: false)),
        )
        .length;
    final dr = lessons.length - nw - rev;
    final cps = nodes.where((n) => n.kind == NodeKind.checkpoint).length;
    final q = nodes
        .where((n) => n.kind != NodeKind.intro)
        .fold<int>(0, (s, n) => s + QuizConfig.forNode(n).length);
    totalQ += q;
    totalNodes += nodes.length;
    final opts = [
      for (final n in nodes.where((n) => n.kind != NodeKind.intro))
        n.items.length,
    ];
    w(
      '| ${e.key.id} | ${e.key.allItems.length} items | ${nodes.length} | 1 | ${lessons.length} ($nw / $rev / $dr) | $cps | 1 | $q | ${opts.reduce(math.min)}–${opts.reduce(math.max)} |',
    );
  }
  w(
    'Total: $totalNodes nodes, $totalQ scored questions, all five paths are LISTENING tasks (name/recognise what you hear).',
  );

  // Exposure per item over the whole path.
  w(
    '\nExpected scored exposures per item when every node is played once (3000 simulated paths):',
  );
  final rnd = math.Random(11);
  for (final e in trainerPaths.entries) {
    final counts = <String, double>{};
    const reps = 300;
    for (var r = 0; r < reps; r++) {
      for (final node in e.value.nodes.where((n) => n.kind != NodeKind.intro)) {
        final gen = QuizGenerator(QuizConfig.forNode(node), random: rnd);
        final qs =
            (node.isGate || node.kind == NodeKind.lesson) &&
                node.kind == NodeKind.lesson
            ? gen.lessonPractice(node)
            : gen.session();
        for (final q in qs) {
          final key = q.type == QuestionType.yesNo ? q.target : q.answer;
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    final order = <String>[];
    for (final n in e.value.nodes) {
      for (final i in n.newItems) {
        if (!order.contains(i)) order.add(i);
      }
    }
    final line = [
      for (final i in order)
        '${itemLabel(e.key, i)}:${f((counts[i] ?? 0) / reps, 0)}',
    ];
    final first = (counts[order.first] ?? 0) / reps,
        last = (counts[order.last] ?? 0) / reps;
    w(
      '- **${e.key.id}** (introduction order → exposures): ${line.join('  ')}  → first/last ratio ${f(first / last, 1)}×',
    );
  }

  // New-item share inside "New:" lessons.
  w(
    '\nShare of a "New: X" lesson spent on the new item (lessonPractice, 10 q; 2000 sims per lesson, mean over the path):',
  );
  for (final e in trainerPaths.entries) {
    final shares = <double>[];
    final firstShare = <double>[];
    for (final node in e.value.nodes.where(
      (n) => n.kind == NodeKind.lesson && n.newItems.isNotEmpty,
    )) {
      var onNew = 0, tot = 0;
      for (var r = 0; r < 600; r++) {
        final gen = QuizGenerator(QuizConfig.forNode(node), random: rnd);
        for (final q in gen.lessonPractice(node)) {
          final key = q.type == QuestionType.yesNo ? q.target : q.answer;
          tot++;
          if (node.newItems.contains(key)) onNew++;
        }
      }
      shares.add(onNew / tot);
      if (shares.length == 1) firstShare.add(onNew / tot);
    }
    final mean = shares.reduce((a, b) => a + b) / shares.length;
    w(
      '- ${e.key.id}: mean ${f(100 * mean, 0)}% on the new item (min ${f(100 * shares.reduce(math.min), 0)}%, max ${f(100 * shares.reduce(math.max), 0)}%); uniform baseline for the last stage would be ${f(100 / e.value.nodes.last.items.length, 0)}%.',
    );
  }

  // Audio seconds per question.
  w(
    '\nStimulus audio per question (sum of sound durations incl. all "find" candidates), seeded sim:',
  );
  w(
    '| trainer | identify: sound s (min / mean / max) | find (3 choices): total s | yes/no: s |',
  );
  w('|---|---|---|---|');
  for (final k in TrainerKind.values) {
    final cfg = QuizConfig(
      trainer: k,
      pool: k.allItems,
      registers: const [],
      length: 1,
    );
    final gen = QuizGenerator(
      QuizConfig(trainer: k, pool: k.allItems),
      random: rnd,
    );
    final d = <double>[];
    for (var i = 0; i < 400; i++) {
      d.add(
        gen.sounds
            .item(k, k.allItems[rnd.nextInt(k.allItems.length)])
            .durationSeconds,
      );
    }
    final fnd = <double>[];
    for (var i = 0; i < 100; i++) {
      final q = gen.find(choices: 3);
      fnd.add(q.sounds.fold(0.0, (s, e) => s + e.durationSeconds));
    }
    final mean = d.reduce((a, b) => a + b) / d.length;
    w(
      '| ${k.id} | ${f(d.reduce(math.min), 1)} / ${f(mean, 1)} / ${f(d.reduce(math.max), 1)} | ${f(fnd.reduce((a, b) => a + b) / fnd.length, 1)} | ${f(mean, 1)} |',
    );
    cfg.length;
  }

  // Daily route.
  w(
    '\nDaily route by goal and minutes (DailyRoute.plan, real). B=breath s, L=ear lesson, V=voice step.',
  );
  w('| goal | 3 min | 5 min | 10 min | 15 min | 20 min |');
  w('|---|---|---|---|---|---|');
  for (final g in PracticeGoal.values) {
    final cells = [
      for (final m in dailyMinuteChoices)
        () {
          final r = DailyRoute.plan(goal: g, minutes: m);
          return '${r.breathSeconds > 0 ? 'B${r.breathSeconds}' : '-'} ${r.lesson ? 'L' : '-'} ${r.voiceStep ? 'V' : '-'}';
        }(),
    ];
    w('| ${g.id} | ${cells.join(' | ')} |');
  }
  w(
    'Note: the route is the same for 10, 15 and 20 minutes (steps are fixed); only the unmeasured breath guide differs between 5 and 10+ minutes.',
  );
}

// ---------------------------------------------------------- E. spaced review
void memorySection() {
  w('\n## E. Review scheduler (real ItemMemory / dueCards)');
  w(
    'Constants: due when recall < $reviewTarget; half-life ×2 on a correct answer only if the gap ≥ half-life/2 ("spaced"), ÷2 on a wrong one; bounds $minHalfLifeDays–$maxHalfLifeDays days; round cap $reviewRoundSize.',
  );
  final dueAfter = math.log(1 / reviewTarget) / math.ln2;
  w(
    'A card becomes due after ${f(dueAfter, 3)}×h (= ${f(dueAfter * 24, 1)} h for h=1 d), but half-life only grows if it is answered after ≥0.5×h. Due-time answers (${f(dueAfter, 2)}h–0.50h) do not grow it.',
  );

  final t0 = DateTime(2026, 11, 1, 8);
  w(
    '\nSingle card, learner opens the review round every N days (answers always correct) — reviews and half-life over 90 days:',
  );
  w('| check-in every | reviews in 90 d | final half-life (d) | review days |');
  w('|---|---|---|---|');
  for (final every in [1, 2, 3, 7]) {
    var m = ItemMemory.first(true, t0);
    var reviews = 0;
    final days = <int>[];
    for (var d = every; d <= 90; d += every) {
      final now = t0.add(Duration(days: d));
      if (m.isDue(now)) {
        m = m.answered(true, now);
        reviews++;
        days.add(d);
      }
    }
    w(
      '| ${every}d | $reviews | ${f(m.halfLifeDays, 1)} | ${days.take(14).join(',')}${days.length > 14 ? '…' : ''} |',
    );
  }
  // reference expanding schedule
  w(
    'Reference: a 1/3/7/14/30/60-day expanding schedule (LEARNING_MODEL.md suggestion) would need 6 reviews in 90 days.',
  );

  // Same with 85% accuracy (random lapses) averaged.
  final rnd = math.Random(3);
  for (final acc in [.95, .85, .7]) {
    var tot = 0.0, hl = 0.0;
    const runs = 400;
    for (var r = 0; r < runs; r++) {
      var m = ItemMemory.first(true, t0);
      for (var d = 1; d <= 90; d++) {
        final now = t0.add(Duration(days: d));
        if (m.isDue(now)) {
          m = m.answered(rnd.nextDouble() < acc, now);
          tot++;
        }
      }
      hl += m.halfLifeDays;
    }
    w(
      '- daily check-in, answer accuracy ${f(acc * 100, 0)}%: ${f(tot / runs, 1)} reviews per card in 90 d, mean final half-life ${f(hl / runs, 1)} d.',
    );
  }

  // 12 cards learned on day 0, daily round.
  w(
    '\nDaily review backlog: 12 notes answered correctly on day 0, learner does one round per day (≤$reviewRoundSize cards, all correct):',
  );
  final mem = <String, Map<String, ItemMemory>>{
    'pitch': {for (var i = 0; i < 12; i++) '$i': ItemMemory.first(true, t0)},
  };
  final perDay = <int>[], dueBefore = <int>[];
  for (var d = 1; d <= 60; d++) {
    final now = t0.add(Duration(days: d));
    final totalDue = mem['pitch']!.values.where((m) => m.isDue(now)).length;
    dueBefore.add(totalDue);
    final round = dueCards(mem, now);
    for (final c in round) {
      mem['pitch']![c.item] = mem['pitch']![c.item]!.answered(true, now);
    }
    perDay.add(round.length);
  }
  w(
    '- reviews/day, weeks 1–8 (avg per week): ${[for (var wk = 0; wk < 8; wk++) f(perDay.skip(wk * 7).take(7).reduce((a, b) => a + b) / 7, 1)].join(', ')} cards/day; total ${perDay.reduce((a, b) => a + b)} reviews = ${f(perDay.reduce((a, b) => a + b) / 12, 1)} per card in 60 d.',
  );
  w(
    '- cards due before the cap, peak ${dueBefore.reduce(math.max)}; days with backlog above the cap: ${dueBefore.where((x) => x > reviewRoundSize).length}.',
  );
  w(
    '- final half-lives: ${mem['pitch']!.values.map((m) => f(m.halfLifeDays, 0)).join(', ')} d.',
  );
}

void main() {
  scorerSection();
  rangeSection();
  gateSection();
  curriculumSection();
  memorySection();
  stdout.write(out);
}
