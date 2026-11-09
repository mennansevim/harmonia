// Rhythm-module benchmark: ladder facts, EventRhythmAnalyzer behaviour, a
// simulated-performer pass-rate study (first-clap anchored, as the app does)
// and ClapOnsetDetector accuracy on independently synthesised claps.
//
// Everything is SIMULATED or SYNTHETIC. The human timing model is a
// Wing–Kristofferson-style sensitivity grid, not a measurement of real
// learners; the detector is not tested on recorded human claps or devices.
//
//   dart compile exe tool/benchmark/rhythm_benchmark.dart -o /tmp/rhythm_benchmark
//   /tmp/rhythm_benchmark
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:resonia/domain/audio/clap_onset_detector.dart';
import 'package:resonia/domain/audio/event_rhythm_analyzer.dart';
import 'package:resonia/domain/audio/rhythm_analyzer.dart';
import 'package:resonia/domain/content/rhythm_patterns.dart';
import 'package:resonia/trainer/koro/aksak_patterns.dart';

final out = StringBuffer();
void w([String s = '']) => out.writeln(s);
String f(num v, [int d = 1]) => v.isNaN ? '-' : v.toStringAsFixed(d);

double gauss(math.Random r) =>
    math.sqrt(-2 * math.log(1 - r.nextDouble())) *
    math.cos(2 * math.pi * r.nextDouble());

// ------------------------------------------------------------------ ladder

typedef Rhythm = ({String id, List<double> beats, double bpm});

/// The clap ladder as in lib/trainer/koro/clap_rhythm.dart `clapRhythms`.
/// That file imports Flutter, so tresillo, son clave, waltz and sofyan are
/// copied here (keep in sync); the draft and aksak patterns are the real data.
List<Rhythm> clapLadderSource() => [
  for (final p in [...draftRhythmPatterns, ...draftAksakPatterns])
    (
      id: p.exercise.exercise.id,
      beats: p.exercise.protocol.rhythmOnsetsBeats,
      bpm: p.exercise.protocol.tempoBpm,
    ),
  (id: 'draft-clap-tresillo', beats: [0, 1.5, 3, 4, 5.5, 7], bpm: 90),
  (id: 'draft-clap-son-clave', beats: [0, 1.5, 3, 5, 6], bpm: 100),
  (id: 'draft-clap-waltz', beats: [0, 1, 2, 3, 4, 5], bpm: 120),
  (id: 'draft-clap-sofyan', beats: [0, 2, 3, 4, 6, 7], bpm: 90),
];

List<int> onsetsMs(Rhythm r) => [
  for (final b in r.beats) (b * 60000 / r.bpm).round(),
];

/// Same ordering key as `clapRhythmsEasyToHard`.
List<Rhythm> easyToHard(List<Rhythm> all) {
  (int, int, double, int) key(Rhythm r) {
    final onBeat = {
      for (final b in r.beats)
        if (b == b.floorToDouble()) b,
    };
    final off = r.beats.where((b) => b != b.floorToDouble());
    var gap = double.infinity;
    for (var i = 1; i < r.beats.length; i++) {
      gap = math.min(gap, (r.beats[i] - r.beats[i - 1]) * 60000 / r.bpm);
    }
    return (
      off.where((b) => !onBeat.contains(b.floorToDouble())).length,
      off.length,
      -gap,
      r.beats.length,
    );
  }

  final idx = all.indexed.toList()
    ..sort((a, b) {
      final ka = key(a.$2), kb = key(b.$2);
      for (final c in [
        ka.$1.compareTo(kb.$1),
        ka.$2.compareTo(kb.$2),
        ka.$3.compareTo(kb.$3),
        ka.$4.compareTo(kb.$4),
        a.$1.compareTo(b.$1),
      ]) {
        if (c != 0) return c;
      }
      return 0;
    });
  return [for (final e in idx) e.$2];
}

void ladderSection(List<Rhythm> ladder) {
  w('## A. Clap ladder (12 rhythms, easy → hard as the app orders them)');
  w(
    'Match window ±${RhythmAnalysisDefaults.toleranceMs} ms, on-time deadband ±${RhythmAnalysisDefaults.onTimeToleranceMs} ms. First clap is the anchor (time 0).',
  );
  w(
    '| level | id | claps | bpm | span ms | shortest IOI ms | longest IOI ms | window as % of span |',
  );
  w('|---|---|---|---|---|---|---|---|');
  for (final (i, r) in ladder.indexed) {
    final o = onsetsMs(r);
    var lo = 1 << 30, hi = 0;
    for (var k = 1; k < o.length; k++) {
      lo = math.min(lo, o[k] - o[k - 1]);
      hi = math.max(hi, o[k] - o[k - 1]);
    }
    w(
      '| ${i + 1} | ${r.id.replaceAll('draft-', '')} | ${o.length} | ${r.bpm.round()} | ${o.last} | $lo | $hi | ${f(100 * RhythmAnalysisDefaults.toleranceMs / o.last)}% |',
    );
  }
  w(
    '\nShortest IOI is always ≥ 2×window (${2 * RhythmAnalysisDefaults.toleranceMs} ms) → a user clap cannot be ambiguous between two reference onsets. Last-clap window as a share of the span is the tempo accuracy an unpaced performer needs: ±(window / span).',
  );
}

// ------------------------------------------------------------ analyzer facts

Future<void> analyzerSection(List<Rhythm> ladder) async {
  w('\n## B. EventRhythmAnalyzer (real class) — one clap displaced');
  final tres = ladder.firstWhere((r) => r.id.contains('tresillo'));
  final ref = onsetsMs(tres);
  w(
    'Reference: tresillo ${ref.join(',')} ms. Clap #4 displaced by d ms, others exact. Pass = all matched, 0 missed, 0 extra (the app\'s rule).',
  );
  w('| d (ms) | matched | missed | extra | timing accuracy | app pass? |');
  w('|---|---|---|---|---|---|');
  for (final d in [0, 10, 25, 50, 80, 110, 119, 121, 150, 250, 400]) {
    final user = [...ref]..[3] += d;
    final r = await EventRhythmAnalyzer().analyze(
      RhythmAnalysisRequest(expectedOnsetsMs: ref, userOnsetsMs: user),
    );
    final pass =
        r.matchedCount == ref.length && r.missedCount == 0 && r.extraCount == 0;
    w(
      '| $d | ${r.matchedCount} | ${r.missedCount} | ${r.extraCount} | ${f(r.timingAccuracy.value ?? double.nan)} | ${pass ? 'PASS' : 'fail'} |',
    );
  }
  w(
    'Score is continuous across the ±120 ms edge (119 ms ≈ 121 ms), but the binary pass is not: any one clap outside the window fails the whole rhythm.',
  );
}

// ------------------------------------------------- simulated performer study

class Profile {
  const Profile(this.name, this.clockCv, this.motorMs, this.tempoBias);
  final String name;
  final double clockCv; // per-interval clock noise, fraction of interval
  final double motorMs; // motor delay SD per tap
  final double tempoBias; // SD of a whole-performance tempo error
}

List<int> perform(List<int> ref, Profile p, math.Random r) {
  final bias = gauss(r) * p.tempoBias;
  final times = <double>[0];
  var t = 0.0;
  for (var i = 1; i < ref.length; i++) {
    final interval = (ref[i] - ref[i - 1]).toDouble();
    t += interval * (1 + bias) * (1 + p.clockCv * gauss(r));
    times.add(t);
  }
  final claps = [for (final t in times) (t + gauss(r) * p.motorMs).round()]
    ..sort();
  return claps;
}

enum Regime { shipped, tempoNormalised, fitScaleOffset }

Future<bool> passes(List<int> ref, List<int> claps, Regime regime) async {
  if (claps.length != ref.length) return false;
  var user = [for (final c in claps) c - claps.first + ref.first];
  if (regime == Regime.tempoNormalised) {
    final k = (ref.last - ref.first) / (user.last - user.first);
    user = [for (final u in user) ((u - user.first) * k).round() + ref.first];
  } else if (regime == Regime.fitScaleOffset) {
    // least squares user ≈ a·ref + b → undo a, b
    final n = ref.length;
    final mr = ref.reduce((a, b) => a + b) / n;
    final mu = user.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (ref[i] - mr) * (user[i] - mu);
      den += (ref[i] - mr) * (ref[i] - mr);
    }
    final a = num / den, b = mu - a * mr;
    user = [for (final u in user) ((u - b) / a).round()];
  }
  // The analyzer rejects negative times; a fitted offset can push the first
  // onset below zero, so shift reference and user together (a pure time shift
  // changes no distance).
  final shift = user.reduce(math.min) < 0 ? -user.reduce(math.min) : 0;
  final r = await EventRhythmAnalyzer().analyze(
    RhythmAnalysisRequest(
      expectedOnsetsMs: [for (final e in ref) e + shift],
      userOnsetsMs: [for (final u in user) u + shift],
    ),
  );
  return r.matchedCount == ref.length &&
      r.missedCount == 0 &&
      r.extraCount == 0;
}

Future<void> performerSection(List<Rhythm> ladder) async {
  w('\n## C. Simulated performers who know the rhythm perfectly');
  w(
    'Wing–Kristofferson-style model: each interval = reference × (1 + tempo bias) × (1 + clock CV·ε); each clap + motor jitter. First clap anchors (as the app does). Profiles are sensitivity settings, NOT measurements of real learners: untrained adults tap a metronome at ≈4% CV (secondary source), unpaced production adds drift, musicians are lower.',
  );
  const profiles = [
    Profile('skilled (CV 2.5%, motor 8 ms, bias SD 2%)', .025, 8, .02),
    Profile('typical (CV 4%, motor 12 ms, bias SD 3%)', .04, 12, .03),
    Profile('novice (CV 6%, motor 18 ms, bias SD 5%)', .06, 18, .05),
  ];
  const n = 2000;
  final rnd = math.Random(21);
  w(
    '\nPass % of a perfect-knowledge performer, shipped rule (anchor on first clap, ±120 ms absolute):',
  );
  w(
    '| level | rhythm | span ms | ${profiles.map((p) => p.name.split(' (').first).join(' | ')} |',
  );
  w('|---|---|---|${profiles.map((_) => '---').join('|')}|');
  final totals = {
    for (final p in profiles) p.name: [0, 0],
  };
  final typicalPass = <double>[], spans = <double>[];
  for (final (i, rh) in ladder.indexed) {
    final ref = onsetsMs(rh);
    final cells = <String>[];
    for (final p in profiles) {
      var ok = 0;
      for (var k = 0; k < n; k++) {
        if (await passes(ref, perform(ref, p, rnd), Regime.shipped)) ok++;
      }
      totals[p.name]![0] += ok;
      totals[p.name]![1] += n;
      if (p == profiles[1]) {
        typicalPass.add(100 * ok / n);
        spans.add(ref.last.toDouble());
      }
      cells.add('${f(100 * ok / n, 0)}%');
    }
    w(
      '| ${i + 1} | ${rh.id.replaceAll('draft-', '')} | ${ref.last} | ${cells.join(' | ')} |',
    );
  }
  w(
    '| mean | | | ${profiles.map((p) => '${f(100 * totals[p.name]![0] / totals[p.name]![1], 0)}%').join(' | ')} |',
  );

  double corr(List<double> a, List<double> b) {
    final ma = a.reduce((x, y) => x + y) / a.length;
    final mb = b.reduce((x, y) => x + y) / b.length;
    var num = 0.0, da = 0.0, db = 0.0;
    for (var i = 0; i < a.length; i++) {
      num += (a[i] - ma) * (b[i] - mb);
      da += (a[i] - ma) * (a[i] - ma);
      db += (b[i] - mb) * (b[i] - mb);
    }
    return num / math.sqrt(da * db);
  }

  final levels = [for (var i = 1; i <= ladder.length; i++) i.toDouble()];
  w(
    '\nWhat predicts failure for the typical performer: corr(pass %, app level) = ${f(corr(typicalPass, levels), 2)}, corr(pass %, rhythm span) = ${f(corr(typicalPass, spans), 2)}. The app orders levels by syncopation, off-beats, shortest gap and clap count — not by span.',
  );

  w(
    '\nSensitivity of the shipped rule (mean pass % over all 12 rhythms, perfect-knowledge performer, motor SD 12 ms): rows = whole-performance tempo error SD, columns = per-interval clock CV.',
  );
  w('| tempo error SD \\ clock CV | 2% | 4% | 6% |');
  w('|---|---|---|---|');
  for (final bias in [0.0, .01, .02, .03, .05]) {
    final cells = <String>[];
    for (final cv in [.02, .04, .06]) {
      final prof = Profile('grid', cv, 12, bias);
      var ok = 0, tot = 0;
      for (final rh in ladder) {
        final ref = onsetsMs(rh);
        for (var k = 0; k < 300; k++) {
          tot++;
          if (await passes(ref, perform(ref, prof, rnd), Regime.shipped)) ok++;
        }
      }
      cells.add('${f(100 * ok / tot, 0)}%');
    }
    w('| ${f(bias * 100, 0)}% | ${cells.join(' | ')} |');
  }

  w(
    '\nSame performers under alternative decision rules (mean over all 12 rhythms) and wrong-rhythm acceptance:',
  );
  w(
    'Wrong rhythm = skilled performer with ONE middle clap displaced by ±150 ms or ±250 ms (never reordering), or one clap missing.',
  );
  w(
    '| rule | skilled pass | typical pass | novice pass | wrong-rhythm accepted (150 ms) | (250 ms) | (clap missing) |',
  );
  w('|---|---|---|---|---|---|---|');
  for (final regime in Regime.values) {
    final pass = <double>[];
    for (final p in profiles) {
      var ok = 0, tot = 0;
      for (final rh in ladder) {
        final ref = onsetsMs(rh);
        for (var k = 0; k < 600; k++) {
          tot++;
          if (await passes(ref, perform(ref, p, rnd), regime)) ok++;
        }
      }
      pass.add(100 * ok / tot);
    }
    final wrong = <double>[];
    for (final mode in ['150', '250', 'missing']) {
      var acc = 0, tot = 0;
      for (final rh in ladder) {
        final ref = onsetsMs(rh);
        for (var k = 0; k < 600; k++) {
          var claps = perform(ref, profiles.first, rnd);
          final j = 1 + rnd.nextInt(ref.length - 2); // a middle clap
          if (mode == 'missing') {
            claps = [...claps]..removeAt(j);
          } else {
            final d = int.parse(mode) * (rnd.nextBool() ? 1 : -1);
            final lo = claps[j - 1] + 20, hi = claps[j + 1] - 20;
            claps = [...claps]..[j] = (claps[j] + d).clamp(lo, hi);
          }
          tot++;
          if (await passes(ref, claps, regime)) acc++;
        }
      }
      wrong.add(100 * acc / tot);
    }
    w(
      '| ${regime.name} | ${f(pass[0], 0)}% | ${f(pass[1], 0)}% | ${f(pass[2], 0)}% | ${f(wrong[0], 0)}% | ${f(wrong[1], 0)}% | ${f(wrong[2], 0)}% |',
    );
  }
  w(
    'shipped = absolute timeline from the first clap; tempoNormalised = rescale user span to the reference span; fitScaleOffset = least-squares tempo+offset fit. Alternatives are NOT in the app; they only show how much of the failure is tempo drift.',
  );
}

// ------------------------------------------------------------- clap detector

Float64List bandpass(Float64List x, double fc, double q, int sr) {
  final w0 = 2 * math.pi * fc / sr;
  final alpha = math.sin(w0) / (2 * q);
  final a0 = 1 + alpha, a1 = -2 * math.cos(w0) / a0, a2 = (1 - alpha) / a0;
  final b0 = alpha / a0, b2 = -alpha / a0;
  final y = Float64List(x.length);
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (var i = 0; i < x.length; i++) {
    final v = b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = x[i];
    y2 = y1;
    y1 = v;
    y[i] = v;
  }
  return y;
}

double dbToAmp(double db) => math.pow(10, db / 20).toDouble();

Float64List pinkNoise(int n, math.Random r, double rmsDb) {
  final o = Float64List(n);
  double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  var s = 0.0;
  for (var i = 0; i < n; i++) {
    final x = r.nextDouble() * 2 - 1;
    b0 = .99886 * b0 + x * .0555179;
    b1 = .99332 * b1 + x * .0750759;
    b2 = .969 * b2 + x * .153852;
    b3 = .8665 * b3 + x * .3104856;
    b4 = .55 * b4 + x * .5329522;
    b5 = -.7616 * b5 - x * .016898;
    o[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + x * .5362;
    b6 = x * .115926;
    s += o[i] * o[i];
  }
  final k = dbToAmp(rmsDb) / math.sqrt(s / n);
  for (var i = 0; i < n; i++) {
    o[i] *= k;
  }
  return o;
}

/// A hand clap, independent of the app's renderer: 2–4 noise bursts of 1–3 ms
/// within the first 12 ms (palms meeting), then a band-passed body with
/// exponential decay [tau] around [fc]. Peak scaled to [peakDb] dBFS.
Float64List synthClap(
  math.Random r,
  int sr,
  double peakDb,
  double tau,
  double fc,
) {
  final n = (0.25 * sr).round();
  final x = Float64List(n);
  final bursts = 2 + r.nextInt(3);
  for (var b = 0; b < bursts; b++) {
    final start = (r.nextDouble() * .012 * sr).round();
    final len = ((1 + r.nextDouble() * 2) / 1000 * sr).round();
    for (var i = 0; i < len && start + i < n; i++) {
      x[start + i] += (r.nextDouble() * 2 - 1) * (1 - i / len);
    }
  }
  for (var i = 0; i < n; i++) {
    x[i] += (r.nextDouble() * 2 - 1) * .6 * math.exp(-i / sr / tau);
  }
  final y = bandpass(x, fc, 1.2, sr);
  var peak = 0.0;
  for (final v in y) {
    peak = math.max(peak, v.abs());
  }
  final k = dbToAmp(peakDb) / peak;
  for (var i = 0; i < n; i++) {
    y[i] *= k;
  }
  return y;
}

/// Silence before the first clap in a synthetic track.
const clapLeadMs = 500;

({Float64List x, List<double> trueMs}) track(
  math.Random r,
  int sr,
  List<int> onsets,
  double peakDb,
  double floorDb, {
  double levelJitterDb = 3,
}) {
  final n = ((onsets.last + 1400) / 1000 * sr).round();
  final x = pinkNoise(n, r, floorDb);
  final trueMs = <double>[];
  for (final o in onsets) {
    final clap = synthClap(
      r,
      sr,
      peakDb + (r.nextDouble() * 2 - 1) * levelJitterDb,
      [.012, .025, .045][r.nextInt(3)],
      [900.0, 1500.0, 2600.0][r.nextInt(3)],
    );
    // Random sub-hop phase (0–10 ms) so claps are NOT aligned to the
    // detector's 5 ms grid.
    final start = ((o + clapLeadMs) / 1000 * sr).round() + r.nextInt(480);
    trueMs.add(start / sr * 1000);
    for (var i = 0; i < clap.length && start + i < n; i++) {
      x[start + i] += clap[i];
    }
  }
  return (x: x, trueMs: trueMs);
}

({List<int> found, int sr}) detect(Float64List x, {int sr = 48000}) {
  final found = <int>[];
  final d = ClapOnsetDetector(onClap: found.add);
  for (var i = 0; i < x.length; i += 1024) {
    d.add(
      List<double>.generate(
        math.min(1024, x.length - i),
        (k) => x[i + k].clamp(-1.0, 1.0),
        growable: false,
      ),
      sr,
    );
  }
  return (found: found, sr: sr);
}

void detectorSection(List<Rhythm> ladder) {
  w(
    '\n## D. ClapOnsetDetector on independently synthesised claps (not recorded human claps)',
  );
  final r = math.Random(5);
  final ref = onsetsMs(ladder.firstWhere((x) => x.id.contains('tresillo')));
  // 8-clap reference list (tresillo twice trimmed to 8 with 700 ms spacing)
  final onsets = [for (var i = 0; i < 8; i++) 700 * i + (i.isOdd ? 120 : 0)];
  w(
    'Each cell: 20 tracks × 8 claps (random clap shape: 2–4 contact bursts, body τ 12/25/45 ms, centre 0.9/1.5/2.6 kHz, ±3 dB level jitter). Pink room noise at the given RMS floor. Hit = detection within −15…+60 ms of the true onset. Cell = hit % / extra detections per 8 claps.',
  );
  const peaks = [-6.0, -12.0, -18.0, -24.0, -30.0, -36.0];
  const floors = [-80.0, -60.0, -50.0, -40.0, -30.0];
  w(
    '| clap peak dBFS \\ room floor dBFS RMS | ${floors.map((x) => x.round()).join(' | ')} |',
  );
  w('|---|${floors.map((_) => '---').join('|')}|');
  final offs = <double>[];
  for (final p in peaks) {
    final cells = <String>[];
    for (final fl in floors) {
      var hit = 0, tot = 0, extra = 0;
      for (var t = 0; t < 20; t++) {
        final tr = track(r, 48000, onsets, p, fl);
        final res = detect(tr.x).found;
        final used = <int>{};
        for (final o in tr.trueMs) {
          final i = res.indexWhere(
            (d) => !used.contains(d) && d - o >= -15 && d - o <= 60,
          );
          tot++;
          if (i >= 0) {
            hit++;
            used.add(res[i]);
            if (fl == -60) offs.add(res[i] - o);
          }
        }
        extra += res.where((d) => !used.contains(d)).length;
      }
      cells.add('${f(100 * hit / tot, 0)}% / ${f(extra / 20, 1)}');
    }
    w('| $p | ${cells.join(' | ')} |');
  }
  double mean(List<double> l) => l.reduce((a, b) => a + b) / l.length;
  final m = mean(offs);
  final sd = math.sqrt(
    offs.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / offs.length,
  );
  w(
    '\nDetection time minus true onset at −60 dBFS floor (all levels that hit): mean ${f(m)} ms, SD ${f(sd)} ms, range ${f(offs.reduce(math.min), 0)}…${f(offs.reduce(math.max), 0)} ms. A constant lag cancels in first-clap anchoring; the SD (level-dependent lag + 5 ms hop) does not.',
  );
  // timing offset by level
  w('\nDetection lag by clap level (floor −60, level jitter 0):');
  w('| peak dBFS | mean lag ms | SD ms | hit % |');
  w('|---|---|---|---|');
  for (final p in peaks) {
    final l = <double>[];
    var hit = 0, tot = 0;
    for (var t = 0; t < 30; t++) {
      final tr = track(r, 48000, onsets, p, -60, levelJitterDb: 0);
      final res = detect(tr.x).found;
      for (final o in tr.trueMs) {
        tot++;
        final i = res.indexWhere((d) => d - o >= -15 && d - o <= 60);
        if (i >= 0) {
          hit++;
          l.add(res[i] - o);
        }
      }
    }
    if (l.isEmpty) {
      w('| $p | - | - | 0 |');
    } else {
      final mm = mean(l);
      final s = math.sqrt(
        l.map((v) => (v - mm) * (v - mm)).reduce((a, b) => a + b) / l.length,
      );
      w('| $p | ${f(mm)} | ${f(s)} | ${f(100 * hit / tot, 0)} |');
    }
  }
  // confounders
  w(
    '\nNon-clap sounds (room floor −60 dBFS, 100 events each, random phase); % of events that produce ≥1 clap detection, at event peak −18 dBFS and −30 dBFS (claps hit 100% at −18 and ~60–70% at −30 in the same room):',
  );
  final sr = 48000;
  Float64List event(String kind, double peakDb) {
    final n = (.4 * sr).round();
    final x = Float64List(n);
    switch (kind) {
      case 'plosive + vowel ("pa")':
        for (var i = 0; i < (.008 * sr); i++) {
          x[i] = (r.nextDouble() * 2 - 1) * (1 - i / (.008 * sr));
        }
        for (var i = 0; i < (.2 * sr); i++) {
          final t = i / sr;
          final env = math.min(1.0, t / .03) * math.exp(-t / .12);
          var v = 0.0;
          for (var k = 1; k <= 12; k++) {
            v += math.sin(2 * math.pi * 140 * k * t) / k;
          }
          x[i + (.008 * sr).round()] += .25 * env * v;
        }
      case 'cough':
        final src = Float64List(n);
        for (var i = 0; i < (.15 * sr); i++) {
          final t = i / sr;
          src[i] =
              (r.nextDouble() * 2 - 1) *
              math.min(1.0, t / .008) *
              math.exp(-t / .06);
        }
        x.setAll(0, bandpass(src, 1200, .6, sr));
      case 'door slam (low thump)':
        for (var i = 0; i < n; i++) {
          final t = i / sr;
          x[i] =
              math.sin(2 * math.pi * 90 * t) * math.exp(-t / .05) +
              .3 * (r.nextDouble() * 2 - 1) * math.exp(-t / .02);
        }
      default: // sibilant "s"
        final src = Float64List(n);
        for (var i = 0; i < (.15 * sr); i++) {
          final t = i / sr;
          src[i] =
              (r.nextDouble() * 2 - 1) *
              math.min(1.0, t / .015) *
              (t < .13 ? 1 : (.15 - t) / .02);
        }
        final hp = bandpass(src, 6000, .5, sr);
        x.setAll(0, hp);
    }
    var pk = 0.0;
    for (final v in x) {
      pk = math.max(pk, v.abs());
    }
    final k = dbToAmp(peakDb) / pk;
    for (var i = 0; i < n; i++) {
      x[i] *= k;
    }
    return x;
  }

  for (final kind in [
    'plosive + vowel ("pa")',
    'cough',
    'door slam (low thump)',
    'sibilant "s"',
  ]) {
    final cells = <String>[];
    for (final level in [-18.0, -30.0]) {
      var trig = 0;
      for (var t = 0; t < 100; t++) {
        final x = pinkNoise((1.3 * sr).round(), r, -60);
        final e = event(kind, level);
        final s = (.5 * sr).round() + r.nextInt(480);
        for (var i = 0; i < e.length; i++) {
          x[s + i] += e[i];
        }
        if (detect(x).found.isNotEmpty) trig++;
      }
      cells.add('$trig% at ${level.round()} dBFS');
    }
    w('- $kind: ${cells.join(', ')}');
  }
  w(
    'The warm-up (first 150 ms learn the floor) and 90 ms refractory time are fixed; the UI opens the microphone only after a go cue, so speaker bleed of the count-in is not tested here.',
  );
  ref.length;
}

Future<void> main() async {
  final ladder = easyToHard(clapLadderSource());
  ladderSection(ladder);
  await analyzerSection(ladder);
  await performerSection(ladder);
  detectorSection(ladder);
  stdout.write(out);
}
