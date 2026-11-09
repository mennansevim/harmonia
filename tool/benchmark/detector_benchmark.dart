// Pitch-detector benchmark on SYNTHETIC voice-like signals + real piano takes.
// Run with the repo's package config:
//   dart compile exe --packages=<repo>/.dart_tool/package_config.json bench_detector.dart -o bench_detector
//
// Everything here is synthetic (or instrument) audio. It says nothing about
// real human singers; that gate (BENCH-01) stays open.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:resonia/domain/audio/recording_pitch_analyzer.dart';
import 'package:resonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';

const twoPi = 2 * math.pi;

double gauss(math.Random r) {
  final u1 = 1 - r.nextDouble();
  final u2 = r.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(twoPi * u2);
}

const vowels = <String, List<List<double>>>{
  // formants, bandwidths, gains
  'a': [
    [800, 1150, 2900, 3900],
    [80, 90, 120, 130],
    [1, .5, .25, .12],
  ],
  'i': [
    [300, 2300, 3000, 3900],
    [60, 100, 120, 130],
    [1, .4, .25, .12],
  ],
  'u': [
    [325, 700, 2530, 3500],
    [60, 80, 120, 130],
    [1, .3, .2, .1],
  ],
};

double formantGain(double f, List<List<double>> v) {
  var g = 0.0;
  for (var i = 0; i < v[0].length; i++) {
    final fc = v[0][i], bw = v[1][i], gain = v[2][i];
    final x = f / fc;
    final q = fc / bw;
    final mag = 1 / math.sqrt(math.pow(1 - x * x, 2) + math.pow(x / q, 2));
    g += gain * mag / q;
  }
  return g;
}

Float64List pink(int n, math.Random r) {
  final out = Float64List(n);
  double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  for (var i = 0; i < n; i++) {
    final w = r.nextDouble() * 2 - 1;
    b0 = .99886 * b0 + w * .0555179;
    b1 = .99332 * b1 + w * .0750759;
    b2 = .969 * b2 + w * .153852;
    b3 = .8665 * b3 + w * .3104856;
    b4 = .55 * b4 + w * .5329522;
    b5 = -.7616 * b5 - w * .016898;
    out[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * .5362;
    b6 = w * .115926;
  }
  return out;
}

double rms(Float64List x) {
  var s = 0.0;
  for (final v in x) {
    s += v * v;
  }
  return math.sqrt(s / x.length);
}

/// Voice-like harmonic source with formant shaping, jitter, shimmer, optional
/// vibrato and onset scoop, aspiration noise and pink ambient noise.
Float64List synthVoice({
  required double f0,
  required int sr,
  required double seconds,
  required String vowel,
  required double hnrDb,
  required double vibCents,
  required bool scoop,
  required double? snrDb,
  required math.Random rnd,
}) {
  final n = (seconds * sr).round();
  final v = vowels[vowel]!;
  final maxK = math.min(60, (math.min(sr * .45, 5000.0) / f0).floor());
  final amps = [
    for (var k = 1; k <= maxK; k++) (1 / k) * (.15 + formantGain(k * f0, v)),
  ];
  final out = Float64List(n);
  var phase = rnd.nextDouble() * twoPi;
  final vibPhase = rnd.nextDouble() * twoPi;
  var jitter = 0.0, shimmer = 1.0;
  for (var i = 0; i < n; i++) {
    final t = i / sr;
    var cents = 0.0;
    if (vibCents > 0) {
      cents +=
          vibCents *
          math.min(1.0, t / .4) *
          math.sin(twoPi * 5.5 * t + vibPhase);
    }
    if (scoop) cents += -200 * math.exp(-t / .06);
    final f = f0 * math.pow(2, cents / 1200) * (1 + jitter);
    phase += twoPi * f / sr;
    if (phase >= twoPi) {
      phase -= twoPi;
      jitter = gauss(rnd) * .005;
      shimmer = 1 + gauss(rnd) * .03;
    }
    final c = math.cos(phase), s1 = math.sin(phase);
    var sPrev = 0.0, sCur = s1; // sin(0*phi)=0, sin(1*phi)
    var acc = amps[0] * sCur;
    for (var k = 1; k < maxK; k++) {
      final sNext = 2 * c * sCur - sPrev;
      acc += amps[k] * sNext;
      sPrev = sCur;
      sCur = sNext;
    }
    out[i] = acc * shimmer;
  }
  // level, fades
  final scale = .12 / rms(out);
  for (var i = 0; i < n; i++) {
    out[i] *= scale;
  }
  final fade = (.02 * sr).round();
  for (var i = 0; i < fade; i++) {
    final g = i / fade;
    out[i] *= g;
    out[n - 1 - i] *= g;
  }
  final voiceRms = rms(out);
  if (hnrDb < 60) {
    final nz = voiceRms / math.pow(10, hnrDb / 20);
    var prev = 0.0;
    final raw = Float64List(n);
    for (var i = 0; i < n; i++) {
      final w = gauss(rnd);
      raw[i] = w - prev;
      prev = w;
    }
    final k = nz / rms(raw);
    for (var i = 0; i < n; i++) {
      out[i] += raw[i] * k;
    }
  }
  if (snrDb != null) {
    final p = pink(n, rnd);
    final k = voiceRms / math.pow(10, snrDb / 20) / rms(p);
    for (var i = 0; i < n; i++) {
      out[i] += p[i] * k;
    }
  }
  var peak = 0.0;
  for (final x in out) {
    peak = math.max(peak, x.abs());
  }
  if (peak > .98) {
    for (var i = 0; i < n; i++) {
      out[i] *= .98 / peak;
    }
  }
  return out;
}

// ---------------------------------------------------------------- detectors

class Prep {
  Prep(this.x, this.rmsDb, this.clipped);
  final Float64List x;
  final double rmsDb;
  final bool clipped;
}

Prep prep(Float64List frame) {
  var sum = 0.0;
  var clip = 0;
  for (final s in frame) {
    sum += s;
    if (s.abs() >= .999) clip++;
  }
  final mean = sum / frame.length;
  final x = Float64List(frame.length);
  var e = 0.0;
  for (var i = 0; i < frame.length; i++) {
    x[i] = frame[i] - mean;
    e += x[i] * x[i];
  }
  final r = math.sqrt(e / frame.length);
  final db = r <= 1e-6
      ? -120.0
      : math.max(-120.0, 20 * math.log(r) / math.ln10);
  return Prep(x, db, clip / frame.length > .01);
}

class Curves {
  Curves(this.cmndf, this.nsdf);
  final Float64List cmndf, nsdf;
}

Curves curves(Float64List x, int maxLag) {
  final len = x.length;
  final w = len - maxLag - 1;
  final ps = Float64List(len + 1);
  for (var i = 0; i < len; i++) {
    ps[i + 1] = ps[i] + x[i] * x[i];
  }
  final cm = Float64List(maxLag + 2)..[0] = 1;
  final ns = Float64List(maxLag + 2)..[0] = 1;
  var cum = 0.0;
  for (var tau = 1; tau <= maxLag + 1; tau++) {
    var r = 0.0;
    for (var j = 0; j < w; j++) {
      r += x[j] * x[j + tau];
    }
    final m = ps[w] + (ps[w + tau] - ps[tau]);
    final d = m - 2 * r;
    cum += d;
    cm[tau] = cum > 0 ? d * tau / cum : 1;
    ns[tau] = m > 0 ? 2 * r / m : 0;
  }
  return Curves(cm, ns);
}

double parabolic(Float64List a, int i, {required bool max}) {
  final l = a[i - 1], m = a[i], r = a[i + 1];
  final den = max ? (l - 2 * m + r) : (l - 2 * m + r);
  if (max ? den >= 0 : den <= 0) return 0;
  return ((l - r) / (2 * den)).clamp(-.5, .5);
}

double? yinFallback(
  Float64List cm,
  int sr, {
  double minHz = 50,
  double maxHz = 2000,
  double thr = .15,
  double fbMax = .30,
}) {
  final minLag = math.max(2, (sr / maxHz).floor());
  final maxLag = (sr / minHz).ceil();
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (cm[lag] >= thr) continue;
    while (lag < maxLag && cm[lag + 1] < cm[lag]) {
      lag++;
    }
    final adj = _yinAdj(cm, lag);
    final f = sr / (lag + adj);
    if (f < minHz || f > maxHz) break;
    return f;
  }
  // global-minimum fallback with a periodicity gate
  var best = minLag;
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (cm[lag] < cm[best]) best = lag;
  }
  if (cm[best] < fbMax) {
    final f = sr / (best + _yinAdj(cm, best));
    if (f >= minHz && f <= maxHz) return f;
  }
  return null;
}

double _yinAdj(Float64List cm, int lag) {
  final l = cm[lag - 1], m = cm[lag], r = cm[lag + 1];
  final den = l - 2 * m + r;
  return den > 0 ? ((l - r) / (2 * den)).clamp(-.5, .5) : 0.0;
}

double? mpm(
  Float64List ns,
  int sr, {
  double minHz = 50,
  double maxHz = 2000,
  double k = .9,
  double clarity = .6,
}) {
  final minLag = math.max(2, (sr / maxHz).floor());
  final maxLag = (sr / minHz).ceil();
  var i = 1;
  while (i < maxLag && ns[i] > 0) {
    i++; // skip the first positive lobe
  }
  final peaks = <int>[];
  var gmax = 0.0;
  while (i < maxLag) {
    while (i < maxLag && ns[i] <= 0) {
      i++;
    }
    var best = -1;
    while (i < maxLag && ns[i] > 0) {
      if (i > 0 &&
          i + 1 < ns.length &&
          ns[i] >= ns[i - 1] &&
          ns[i] >= ns[i + 1]) {
        if (best < 0 || ns[i] > ns[best]) best = i;
      }
      i++;
    }
    if (best >= minLag && best < maxLag) {
      peaks.add(best);
      gmax = math.max(gmax, ns[best]);
    }
  }
  if (peaks.isEmpty || gmax < clarity) return null;
  for (final p in peaks) {
    if (ns[p] >= k * gmax) {
      final l = ns[p - 1], m = ns[p], r = ns[p + 1];
      final den = l - 2 * m + r;
      final adj = den < 0 ? ((l - r) / (2 * den)).clamp(-.5, .5) : 0.0;
      final f = sr / (p + adj);
      return (f >= minHz && f <= maxHz) ? f : null;
    }
  }
  return null;
}

class Agg {
  Agg(this.rep, this.disp, this.ratio, this.accepted);
  final double? rep, disp;
  final double ratio;
  final int accepted;
}

Agg aggregate(List<double> hz, int frames) {
  if (hz.isEmpty) return Agg(null, null, 0, 0);
  final s = [...hz]..sort();
  final rep = s[(s.length - 1) ~/ 2];
  double? disp;
  if (hz.length >= 2) {
    var mean = 0.0, m2 = 0.0, c = 0;
    for (final f in hz) {
      final cents = 1200 * math.log(f) / math.ln2;
      c++;
      final d = cents - mean;
      mean += d / c;
      m2 += d * (cents - mean);
    }
    disp = math.sqrt(math.max(0, m2 / c));
  }
  return Agg(rep, disp, hz.length / frames, hz.length);
}

List<int> frameStarts(int n, int size) {
  final hop = size ~/ 2;
  final last = n - size;
  final starts = [for (var s = 0; s <= last; s += hop) s];
  if (last % hop != 0) starts.add(last);
  return starts;
}

const algs = ['app-yin', 'yin+fallback', 'mpm'];

Map<String, Agg> runAll(Float64List samples, int sr) {
  final det = YinPitchFrameAnalyzer();
  final size = det.recommendedFrameSamples(sr);
  final starts = frameStarts(samples.length, size);
  final app = <double>[], yf = <double>[], mp = <double>[];
  final maxLag = (sr / 50).ceil();
  for (final s in starts) {
    final frame = Float64List.sublistView(samples, s, s + size);
    final est = det.analyze(frame, sampleRateHz: sr);
    if (est.status == PitchFrameStatus.pitched) app.add(est.frequencyHz!);
    final p = prep(Float64List.fromList(frame));
    if (p.clipped || p.rmsDb <= -50) continue;
    final c = curves(p.x, maxLag);
    final a = yinFallback(c.cmndf, sr);
    if (a != null) yf.add(a);
    final m = mpm(c.nsdf, sr);
    if (m != null) mp.add(m);
  }
  return {
    'app-yin': aggregate(app, starts.length),
    'yin+fallback': aggregate(yf, starts.length),
    'mpm': aggregate(mp, starts.length),
  };
}

class Cond {
  const Cond(
    this.name, {
    this.sr = 48000,
    this.snr,
    this.vib = 0,
    this.hnr = 30,
    this.scoop = false,
  });
  final String name;
  final int sr;
  final double? snr;
  final double vib, hnr;
  final bool scoop;
}

const conds = <Cond>[
  Cond('baseline (clean, 48k)'),
  Cond('SNR 30 dB (pink)', snr: 30),
  Cond('SNR 20 dB (pink)', snr: 20),
  Cond('SNR 10 dB (pink)', snr: 10),
  Cond('SNR 5 dB (pink)', snr: 5),
  Cond('SNR 0 dB (pink)', snr: 0),
  Cond('vibrato ±30c @5.5Hz', vib: 30),
  Cond('vibrato ±60c', vib: 60),
  Cond('vibrato ±100c', vib: 100),
  Cond('breathy HNR 15 dB', hnr: 15),
  Cond('very breathy HNR 8 dB', hnr: 8),
  Cond('onset scoop −200c', scoop: true),
  Cond('44.1 kHz', sr: 44100),
  Cond('16 kHz', sr: 16000),
];

const midis = [36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80, 84];
const seeds = 2;

double hzOf(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

/// One condition → rows [alg, midi, vowel, errCents|null, ratio, disp|null].
List<List<Object?>> runCond(Cond c) {
  final rows = <List<Object?>>[];
  var seed = 1000;
  for (final midi in midis) {
    for (final v in vowels.keys) {
      for (var s = 0; s < seeds; s++) {
        seed++;
        final rnd = math.Random(seed);
        final f0 = hzOf(midi);
        final x = synthVoice(
          f0: f0,
          sr: c.sr,
          seconds: 1.5,
          vowel: v,
          hnrDb: c.hnr,
          vibCents: c.vib,
          scoop: c.scoop,
          snrDb: c.snr,
          rnd: rnd,
        );
        final res = runAll(x, c.sr);
        for (final a in algs) {
          final g = res[a]!;
          final err = g.rep == null
              ? null
              : 1200 * math.log(g.rep! / f0) / math.ln2;
          rows.add([a, midi, v, err, g.ratio, g.disp]);
        }
      }
    }
  }
  return rows;
}

class Stat {
  int n = 0, detected = 0, ok10 = 0, ok25 = 0, ok50 = 0, octave = 0, gross = 0;
  final abs = <double>[];
  double ratioSum = 0, dispSum = 0;
  int dispN = 0;
  void add(double? err, double ratio, double? disp) {
    n++;
    ratioSum += ratio;
    if (disp != null) {
      dispSum += disp;
      dispN++;
    }
    if (err == null) return;
    detected++;
    final a = err.abs();
    abs.add(a);
    if (a <= 10) ok10++;
    if (a <= 25) ok25++;
    if (a <= 50) {
      ok50++;
      return;
    }
    var isOct = false;
    for (final k in const [-2, -1, 1, 2]) {
      if ((err - 1200 * k).abs() <= 100) isOct = true;
    }
    if (isOct) {
      octave++;
    } else {
      gross++;
    }
  }

  double pct(int v) => n == 0 ? 0 : 100 * v / n;
  double med() {
    if (abs.isEmpty) return double.nan;
    final s = [...abs]..sort();
    return s[s.length ~/ 2];
  }

  double p95() {
    if (abs.isEmpty) return double.nan;
    final s = [...abs]..sort();
    return s[(s.length * .95).floor().clamp(0, s.length - 1)];
  }
}

String f(double v, [int d = 1]) => v.isNaN ? '  -  ' : v.toStringAsFixed(d);

Future<void> main(List<String> args) async {
  // sanity: framework analyzer vs RecordingPitchAnalyzer path equality
  {
    final x = synthVoice(
      f0: 220,
      sr: 48000,
      seconds: 1.5,
      vowel: 'a',
      hnrDb: 30,
      vibCents: 0,
      scoop: false,
      snrDb: null,
      rnd: math.Random(1),
    );
    final ev = RecordingPitchAnalyzer().analyze(
      samples: x,
      sampleRateHz: 48000,
    );
    final mine = runAll(x, 48000)['app-yin']!;
    stdout.writeln(
      'sanity: RecordingPitchAnalyzer rep=${ev.representativeFrequencyHz?.toStringAsFixed(3)} '
      'mine(app-yin)=${mine.rep?.toStringAsFixed(3)} '
      'ratio=${ev.periodicFrameRatio?.toStringAsFixed(3)}/${mine.ratio.toStringAsFixed(3)}',
    );
  }

  final all = await Future.wait([
    for (final c in conds) Isolate.run(() => runCond(c)),
  ]);
  final byCond = <String, Map<String, Stat>>{};
  final byPitch = <String, Map<int, Stat>>{};
  final json = <String, Object?>{};
  for (var i = 0; i < conds.length; i++) {
    final name = conds[i].name;
    byCond[name] = {for (final a in algs) a: Stat()};
    for (final row in all[i]) {
      final a = row[0] as String;
      byCond[name]![a]!.add(
        row[3] as double?,
        row[4] as double,
        row[5] as double?,
      );
      if (i == 0) {
        byPitch
            .putIfAbsent(a, () => {})
            .putIfAbsent(row[1] as int, Stat.new)
            .add(row[3] as double?, row[4] as double, row[5] as double?);
      }
    }
  }

  final b = StringBuffer();
  b.writeln(
    '## Condition sweep (each cell: n=${midis.length * vowels.length * seeds} synthetic takes of 1.5 s, 13 pitches C2..C6, 3 vowels)',
  );
  b.writeln(
    '| condition | algorithm | detected % | ±10c % | ±25c % | ±50c % | octave-err % | other gross % | median abs c | p95 abs c | mean periodic ratio |',
  );
  b.writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  for (final c in conds) {
    for (final a in algs) {
      final s = byCond[c.name]![a]!;
      b.writeln(
        '| ${c.name} | $a | ${f(s.pct(s.detected))} | ${f(s.pct(s.ok10))} | ${f(s.pct(s.ok25))} | ${f(s.pct(s.ok50))} | ${f(s.pct(s.octave))} | ${f(s.pct(s.gross))} | ${f(s.med())} | ${f(s.p95())} | ${f(s.ratioSum / s.n, 2)} |',
      );
    }
  }
  b.writeln(
    '\n## Baseline by pitch (clean, 48 kHz) — detected / ±50c / median abs cents',
  );
  b.write('| midi (note) |');
  for (final a in algs) {
    b.write(' $a |');
  }
  b.writeln();
  b.writeln('|---|---|---|---|');
  for (final m in midis) {
    b.write('| $m (${hzOf(m).toStringAsFixed(0)} Hz) |');
    for (final a in algs) {
      final s = byPitch[a]![m]!;
      b.write(
        ' ${f(s.pct(s.detected), 0)} / ${f(s.pct(s.ok50), 0)} / ${f(s.med())} |',
      );
    }
    b.writeln();
  }
  b.writeln(
    '\n## Measured pitch dispersion (app "stability" input) vs true vibrato SD',
  );
  b.writeln(
    '| condition | app-yin mean dispersion (cents) | true vibrato SD (A/√2) |',
  );
  b.writeln('|---|---|---|');
  for (final c in conds.where(
    (c) => c.vib > 0 || c.name.startsWith('baseline'),
  )) {
    final s = byCond[c.name]!['app-yin']!;
    b.writeln(
      '| ${c.name} | ${f(s.dispN == 0 ? double.nan : s.dispSum / s.dispN)} | ${f(c.vib / math.sqrt2)} |',
    );
  }

  // Real piano takes (instrument, not voice).
  final dir = Directory(
    '${args.isNotEmpty ? args[0] : '.'}/assets/audio/piano/notes',
  );
  if (dir.existsSync()) {
    b.writeln(
      '\n## Real piano recordings (assets/audio/piano/notes; instrument, NOT voice; ET A4=440 truth)',
    );
    b.writeln(
      '| note | true Hz | app-yin err c | yin+fallback err c | mpm err c |',
    );
    b.writeln('|---|---|---|---|---|');
    const names = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.wav'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final errs = <String, List<double>>{for (final a in algs) a: []};
    final rows = <(int, String)>[];
    for (final file in files) {
      final base = file.uri.pathSegments.last.replaceAll('.wav', '');
      final midi = (int.parse(base.substring(1)) + 1) * 12 + names[base[0]]!;
      final wav = Pcm16Wav.decode(file.readAsBytesSync());
      final start = (wav.sampleRateHz * .3).round();
      final end = math.min(wav.samples.length, start + wav.sampleRateHz * 3);
      final x = Float64List.fromList(wav.samples.sublist(start, end));
      final res = runAll(x, wav.sampleRateHz);
      final f0 = hzOf(midi);
      String cell(String a) {
        final r = res[a]!.rep;
        if (r == null) return 'none';
        final e = 1200 * math.log(r / f0) / math.ln2;
        errs[a]!.add(e);
        return e.toStringAsFixed(1);
      }

      rows.add((
        midi,
        '| $base | ${f0.toStringAsFixed(1)} | ${cell('app-yin')} | ${cell('yin+fallback')} | ${cell('mpm')} |',
      ));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    for (final r in rows) {
      b.writeln(r.$2);
    }
    final summary = algs
        .map((a) {
          final e = errs[a]!;
          final ok = e.where((v) => v.abs() <= 50).length;
          final oct = e.where((v) => v.abs() > 50).length;
          return '$a: detected ${e.length}, ≤50c $ok, >50c $oct';
        })
        .join(' · ');
    b.writeln('\nPiano summary: ${files.length} notes. $summary');
  }

  stdout.write(b);
  // Optional second argument: directory that receives the markdown + meta.
  if (args.length > 1) {
    File('${args[1]}/detector_results.md').writeAsStringSync(b.toString());
    json['conds'] = [for (final c in conds) c.name];
    File('${args[1]}/detector_meta.json').writeAsStringSync(jsonEncode(json));
  }
}
