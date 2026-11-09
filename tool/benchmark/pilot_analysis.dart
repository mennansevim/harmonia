// Pilot analysis skeleton (BENCH-01 / VAD-01 / CAL-02), pitch part only.
//
//   dart tool/benchmark/pilot_analysis.dart --root <dataset dir> \
//       [--criteria <criteria.json>] [--out report.md]
//
// The dataset dir holds `manifest.json` (AudioFixtureManifest v1), the WAV
// files it names, and `pilot_meta.json` (see docs/research/pilot/). This tool
// NEVER fabricates data: with a missing/invalid dataset it stops with an
// explicit error (exit 2). Only humanRecording + holdout rows feed the
// decision table; synthetic / instrument rows are listed apart and are not
// evidence about real singers. Verdicts need a FROZEN criteria file written
// before the data was looked at; without one the tool prints measurements
// and Wilson intervals only.
//
// Not covered here (protocol §3b–§3d): clap timing, range test–retest and
// review-card logs need their own sheets; this tool says so instead of
// guessing.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:resonia/domain/audio/audio_fixture.dart';
import 'package:resonia/domain/audio/audio_fixture_manifest.dart';
import 'package:resonia/infrastructure/audio/audio_fixture_loader.dart';

import 'detector_benchmark.dart' show Agg, algs, runAll;

/// Thrown for every "do not guess" stop; the message is reportable.
class PilotInputError implements Exception {
  PilotInputError(this.message);
  final String message;
  @override
  String toString() => message;
}

const labelClasses = [
  'correct_note',
  'octave_up',
  'octave_down',
  'wrong_note',
  'silence',
  'speech_noise',
  'unstable_vibrato',
  'short_buffer',
  'clipped',
  'accompaniment_leak',
];

/// Classes where the singer sang the asked note (or tried to): hits count.
const pitchedPositive = {
  'correct_note',
  'unstable_vibrato',
  'accompaniment_leak',
};
const octaveClasses = {'octave_up', 'octave_down'};
const unvoicedClasses = {'silence', 'speech_noise', 'short_buffer', 'clipped'};
const routes = {'builtin', 'speaker', 'wired', 'bluetooth', 'usb'};
const rooms = {'quiet', 'reverberant', 'tv_ac'};

/// Sidecar metadata of one recording (everything AudioFixture cannot hold).
class PilotMeta {
  PilotMeta({
    required this.labelClass,
    required this.device,
    required this.route,
    required this.room,
    this.labels = const {},
    this.gateResult,
  });
  final String labelClass, device, route, room;

  /// labelerId → class, for agreement; [labelClass] is the adjudicated one.
  final Map<String, String> labels;

  /// "usable" / "rejected": what the on-device quality gate said, if logged.
  final String? gateResult;

  factory PilotMeta.fromJson(String id, Object? raw) {
    Never bad(String what) => throw PilotInputError('pilot_meta[$id]: $what');
    if (raw is! Map) bad('not an object');
    String req(String k) {
      final v = raw[k];
      if (v is! String || v.trim().isEmpty) bad('missing "$k"');
      return v;
    }

    final cls = req('labelClass');
    if (!labelClasses.contains(cls)) bad('unknown labelClass "$cls"');
    final route = req('route');
    if (!routes.contains(route)) bad('unknown route "$route"');
    final room = req('room');
    if (!rooms.contains(room)) bad('unknown room "$room"');
    final labels = <String, String>{};
    final rawLabels = raw['labels'];
    if (rawLabels is Map) {
      rawLabels.forEach((k, v) {
        if (k is! String || v is! String || !labelClasses.contains(v)) {
          bad('invalid labelers entry');
        }
        labels[k] = v;
      });
    }
    final gate = raw['gateResult'];
    if (gate != null && gate != 'usable' && gate != 'rejected') {
      bad('gateResult must be usable|rejected');
    }
    return PilotMeta(
      labelClass: cls,
      device: req('device'),
      route: route,
      room: room,
      labels: labels,
      gateResult: gate as String?,
    );
  }
}

class Wilson {
  Wilson(this.k, this.n) {
    if (n == 0) {
      lower = upper = double.nan;
      return;
    }
    const z = 1.959964;
    final p = k / n;
    final d = 1 + z * z / n;
    final c = p + z * z / (2 * n);
    final h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n));
    lower = (c - h) / d;
    upper = (c + h) / d;
  }
  final int k, n;
  late final double lower, upper;
  double get rate => n == 0 ? double.nan : k / n;
  String get text => n == 0
      ? 'n=0'
      : '${(100 * rate).toStringAsFixed(1)}% '
            '[${(100 * lower).toStringAsFixed(1)}–${(100 * upper).toStringAsFixed(1)}] '
            '($k/$n)';
}

/// Cohen's kappa for two label lists; null when undefined.
double? cohenKappa(List<String> a, List<String> b) {
  if (a.length != b.length || a.isEmpty) return null;
  final n = a.length;
  var agree = 0;
  final ca = <String, int>{}, cb = <String, int>{};
  for (var i = 0; i < n; i++) {
    if (a[i] == b[i]) agree++;
    ca[a[i]] = (ca[a[i]] ?? 0) + 1;
    cb[b[i]] = (cb[b[i]] ?? 0) + 1;
  }
  final po = agree / n;
  var pe = 0.0;
  for (final k in ca.keys) {
    pe += (ca[k]! / n) * ((cb[k] ?? 0) / n);
  }
  if (pe >= 1) return null;
  return (po - pe) / (1 - pe);
}

enum Outcome { abstain, correct, octave, wrong }

/// Representative Hz against the asked note: correct = within [tol] cents in
/// the same octave; octave = within [tol] of a different octave; else wrong.
Outcome outcomeOf(double? repHz, double targetHz, {double tolCents = 50}) {
  if (repHz == null) return Outcome.abstain;
  final err = 1200 * math.log(repHz / targetHz) / math.ln2;
  final k = (err / 1200).round();
  final res = (err - 1200 * k).abs();
  if (res > tolCents) return Outcome.wrong;
  return k == 0 ? Outcome.correct : Outcome.octave;
}

class Row {
  Row(this.fixture, this.meta, this.aggs);
  final AudioFixture fixture;
  final PilotMeta meta;
  final Map<String, Agg> aggs;
  double? get target => fixture.expectedFrequenciesHz.isEmpty
      ? null
      : fixture.expectedFrequenciesHz.first;
}

/// (k, n) of one pre-registered metric over rows, for one algorithm.
Wilson metric(String name, List<Row> rows, String alg, Set<String> classes) {
  var k = 0, n = 0;
  for (final r in rows) {
    if (!classes.contains(r.meta.labelClass)) continue;
    final agg = r.aggs[alg]!;
    final target = r.target;
    switch (name) {
      case 'claim':
        n++;
        if (agg.rep != null) k++;
      case 'abstain':
        n++;
        if (agg.rep == null) k++;
      default:
        if (target == null) continue;
        n++;
        final o50 = outcomeOf(agg.rep, target);
        switch (name) {
          case 'hit50':
          case 'falseSuccess':
            if (o50 == Outcome.correct) k++;
          case 'hit40':
            if (outcomeOf(agg.rep, target, tolCents: 40) == Outcome.correct) {
              k++;
            }
          case 'octaveError':
            if (o50 == Outcome.octave) k++;
          default:
            throw PilotInputError('unknown metric "$name"');
        }
    }
  }
  return Wilson(k, n);
}

/// One pre-registered criterion, from a frozen criteria file.
class Criterion {
  Criterion({
    required this.id,
    required this.algorithm,
    required this.metric,
    required this.classes,
    required this.direction,
    required this.threshold,
  });
  final String id, algorithm, metric, direction;
  final Set<String> classes;
  final double threshold;

  factory Criterion.fromJson(Object? raw) {
    if (raw is! Map) throw PilotInputError('criteria: entry is not an object');
    String s(String k) {
      final v = raw[k];
      if (v is! String || v.isEmpty) {
        throw PilotInputError('criteria: missing "$k"');
      }
      return v;
    }

    final dir = s('direction');
    if (dir != 'min' && dir != 'max') {
      throw PilotInputError('criteria: direction must be min|max');
    }
    final th = raw['threshold'];
    if (th is! num || th < 0 || th > 1) {
      throw PilotInputError('criteria: threshold must be 0..1');
    }
    final classes = raw['classes'];
    if (classes is! List || classes.isEmpty) {
      throw PilotInputError('criteria: classes required');
    }
    for (final c in classes) {
      if (!labelClasses.contains(c)) {
        throw PilotInputError('criteria: unknown class "$c"');
      }
    }
    return Criterion(
      id: s('id'),
      algorithm: s('algorithm'),
      metric: s('metric'),
      classes: classes.cast<String>().toSet(),
      direction: dir,
      threshold: th.toDouble(),
    );
  }

  /// min: pass when the interval's lower bound clears the threshold, fail when
  /// even the upper bound does not; else inconclusive. max mirrors it.
  String verdict(Wilson w) {
    if (w.n == 0) return 'no data';
    if (direction == 'min') {
      if (w.lower >= threshold) return 'PASS';
      if (w.upper < threshold) return 'FAIL';
    } else {
      if (w.upper <= threshold) return 'PASS';
      if (w.lower > threshold) return 'FAIL';
    }
    return 'inconclusive';
  }
}

List<Criterion>? loadCriteria(String? path) {
  if (path == null) return null;
  final f = File(path);
  if (!f.existsSync()) throw PilotInputError('criteria file not found');
  final Object? doc;
  try {
    doc = jsonDecode(f.readAsStringSync());
  } on FormatException {
    throw PilotInputError('criteria file is not valid JSON');
  }
  if (doc is! Map) throw PilotInputError('criteria: not an object');
  if (doc['frozen'] != true) return null; // draft: no verdicts
  final list = doc['criteria'];
  if (list is! List || list.isEmpty) {
    throw PilotInputError('criteria: "criteria" list required');
  }
  final c = list.map(Criterion.fromJson).toList();
  for (final x in c) {
    if (!algs.contains(x.algorithm)) {
      throw PilotInputError('criteria: unknown algorithm "${x.algorithm}"');
    }
  }
  return c;
}

/// Reads the dataset, runs the detectors and returns the Markdown report.
/// Throws [PilotInputError] (never invents data).
Future<String> analyzePilot(Directory root, {String? criteriaPath}) async {
  final manifestFile = File('${root.path}/manifest.json');
  final metaFile = File('${root.path}/pilot_meta.json');
  if (!root.existsSync() ||
      !manifestFile.existsSync() ||
      !metaFile.existsSync()) {
    throw PilotInputError(
      'No pilot dataset: need manifest.json and pilot_meta.json in the root. '
      'Nothing was analysed and no data was generated.',
    );
  }
  final AudioFixtureManifest manifest;
  final Map<String, Object?> metaDoc;
  try {
    manifest = AudioFixtureManifest.fromJson(
      jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>,
    );
    metaDoc = jsonDecode(metaFile.readAsStringSync()) as Map<String, Object?>;
  } on FormatException catch (e) {
    throw PilotInputError('Invalid manifest/meta: ${e.message}');
  } on TypeError {
    throw PilotInputError('Invalid manifest/meta: wrong JSON shape');
  }
  if (metaDoc['schemaVersion'] != 1 || metaDoc['records'] is! Map) {
    throw PilotInputError('pilot_meta.json: schemaVersion 1 + records needed');
  }
  final records = metaDoc['records'] as Map;
  final criteria = loadCriteria(criteriaPath);

  final loader = AudioFixtureLoader(root: root);
  final rows = <Row>[];
  try {
    await for (final loaded in loader.loadManifest(manifest)) {
      final fx = loaded.entry.fixture;
      if (!records.containsKey(fx.id)) {
        throw PilotInputError('pilot_meta has no record for ${fx.id}');
      }
      final meta = PilotMeta.fromJson(fx.id, records[fx.id]);
      // Float64 copy of the decoded PCM, as the benchmark detectors expect.
      final s = Float64List.fromList(loaded.wav.samples);
      rows.add(Row(fx, meta, runAll(s, fx.sampleRateHz)));
    }
  } on FixtureLoadException catch (e) {
    throw PilotInputError('Fixture rejected: $e');
  }
  final extra = records.keys.where(
    (k) => !manifest.entries.any((e) => e.fixture.id == k),
  );
  if (extra.isNotEmpty) {
    throw PilotInputError('pilot_meta has records without a fixture');
  }
  return _report(rows, criteria);
}

String _report(List<Row> rows, List<Criterion>? criteria) {
  final b = StringBuffer();
  void w(String s) => b.writeln(s);
  bool human(Row r) => r.fixture.source == FixtureSource.humanRecording;
  final decision = [
    for (final r in rows)
      if (human(r) && r.fixture.partition == FixturePartition.holdout) r,
  ];
  final humanDev = [
    for (final r in rows)
      if (human(r) && r.fixture.partition == FixturePartition.development) r,
  ];
  final nonHuman = [
    for (final r in rows)
      if (!human(r)) r,
  ];

  w('# Pilot analysis (pitch)');
  w('');
  w(
    'Generated from the supplied dataset only. Synthetic and instrument rows '
    'are not evidence about real singers and never enter the decision table.',
  );
  w('');
  w('| set | rows |');
  w('|---|---|');
  w('| human, holdout (decision set) | ${decision.length} |');
  w('| human, development (tuning only) | ${humanDev.length} |');
  w('| synthetic / instrument (not for decisions) | ${nonHuman.length} |');
  w('');
  if (decision.isEmpty) {
    w(
      '**No human holdout recordings: there is nothing to decide.** '
      'The tables below are for development/schema checks only.',
    );
    w('');
  } else if (decision.length < 100) {
    w(
      '**UNDERPOWERED:** the protocol asks for ≥100 labelled recordings; '
      'this holdout has ${decision.length}. Intervals are wide.',
    );
    w('');
  }

  void section(String title, List<Row> set) {
    w('## $title');
    if (set.isEmpty) {
      w('(no rows)\n');
      return;
    }
    for (final alg in algs) {
      w('### $alg');
      w('| label class | n | correct (≤50 c) | octave | wrong | abstain |');
      w('|---|---|---|---|---|---|');
      for (final cls in labelClasses) {
        final of = [
          for (final r in set)
            if (r.meta.labelClass == cls) r,
        ];
        if (of.isEmpty) continue;
        final counts = {for (final o in Outcome.values) o: 0};
        for (final r in of) {
          final t = r.target;
          final agg = r.aggs[alg]!;
          // Unvoiced rows have no target: only "claimed a pitch" vs not.
          final o = t == null
              ? (agg.rep == null ? Outcome.abstain : Outcome.wrong)
              : outcomeOf(agg.rep, t);
          counts[o] = counts[o]! + 1;
        }
        w(
          '| $cls | ${of.length} | ${counts[Outcome.correct]} | '
          '${counts[Outcome.octave]} | ${counts[Outcome.wrong]} | '
          '${counts[Outcome.abstain]} |',
        );
      }
      w('');
      w('| metric (95% Wilson interval) | value |');
      w('|---|---|');
      w(
        '| hit ≤50 c, sung-note classes | '
        '${metric('hit50', set, alg, pitchedPositive).text} |',
      );
      w(
        '| hit ≤40 c, sung-note classes | '
        '${metric('hit40', set, alg, pitchedPositive).text} |',
      );
      w(
        '| octave error, sung-note classes | '
        '${metric('octaveError', set, alg, pitchedPositive).text} |',
      );
      w(
        '| abstain, sung-note classes | '
        '${metric('abstain', set, alg, pitchedPositive).text} |',
      );
      w(
        '| false success, wrong note + octave-off | '
        '${metric('falseSuccess', set, alg, {'wrong_note', ...octaveClasses}).text} |',
      );
      w(
        '| pitch claimed on unvoiced | '
        '${metric('claim', set, alg, unvoicedClasses).text} |',
      );
      final disp = [
        for (final r in set)
          if (r.meta.labelClass == 'correct_note' && r.aggs[alg]!.disp != null)
            r.aggs[alg]!.disp!,
      ]..sort();
      w(
        '| pitch dispersion SD, correct_note (cents; median / n) | '
        '${disp.isEmpty ? 'n=0' : '${disp[(disp.length - 1) ~/ 2].toStringAsFixed(1)} / ${disp.length}'} |',
      );
      w('');
    }
    w('### By device / route / room (hit ≤50 c, sung-note classes)');
    for (final alg in algs) {
      w('**$alg**');
      for (final (label, key) in <(String, String Function(Row))>[
        ('device', (r) => r.meta.device),
        ('route', (r) => r.meta.route),
        ('room', (r) => r.meta.room),
      ]) {
        final groups = {for (final r in set) key(r)}.toList()..sort();
        for (final g in groups) {
          final sub = [
            for (final r in set)
              if (key(r) == g) r,
          ];
          w(
            '- $label `$g`: ${metric('hit50', sub, alg, pitchedPositive).text}',
          );
        }
      }
      w('');
    }
  }

  section('Decision set: human holdout', decision);
  section('Human development (not for decisions)', humanDev);
  section('Synthetic / instrument (schema path, not real singers)', nonHuman);

  // Labeler agreement over every row with ≥2 labelers (human only).
  final pairs = <String, (List<String>, List<String>)>{};
  for (final r in rows.where(human)) {
    final ids = r.meta.labels.keys.toList()..sort();
    if (ids.length < 2) continue;
    final key = '${ids[0]}/${ids[1]}';
    final p = pairs.putIfAbsent(key, () => (<String>[], <String>[]));
    p.$1.add(r.meta.labels[ids[0]]!);
    p.$2.add(r.meta.labels[ids[1]]!);
  }
  w('## Labeler agreement');
  if (pairs.isEmpty) {
    w('No row has two labelers; agreement is not measured.\n');
  } else {
    for (final e in pairs.entries) {
      final k = cohenKappa(e.value.$1, e.value.$2);
      w(
        '- ${e.key}: n=${e.value.$1.length}, kappa='
        '${k == null ? 'undefined' : k.toStringAsFixed(2)}',
      );
    }
    w('');
  }

  // Quality gate usable-recording ratio, only when the app logged it.
  final gated = rows.where((r) => human(r) && r.meta.gateResult != null);
  w('## Quality gate (logged on device)');
  if (gated.isEmpty) {
    w(
      'No gate results logged: the usable-recording ratio is not computed '
      '(it needs the on-device session log, CAL-02).\n',
    );
  } else {
    final usable = gated.where((r) => r.meta.gateResult == 'usable').length;
    w('usable: ${Wilson(usable, gated.length).text}\n');
  }

  w('## Pre-registered criteria');
  if (criteria == null) {
    w(
      'No FROZEN criteria file supplied: measurements only, no verdicts. '
      'Criteria must be frozen before the data are looked at '
      '(docs/research/PILOT_PROTOCOL_2026-11.md).\n',
    );
  } else if (decision.isEmpty) {
    w('Criteria supplied but there is no human holdout: no verdicts.\n');
  } else {
    w('| id | algorithm | metric | rule | measured | verdict |');
    w('|---|---|---|---|---|---|');
    for (final c in criteria) {
      final m = metric(c.metric, decision, c.algorithm, c.classes);
      w(
        '| ${c.id} | ${c.algorithm} | ${c.metric} | '
        '${c.direction == 'min' ? '≥' : '≤'} ${(100 * c.threshold).toStringAsFixed(1)}% | '
        '${m.text} | ${c.verdict(m)} |',
      );
    }
    w('');
  }

  w('## Not analysed here');
  w(
    '- Clap timing / false triggers, range test–retest and review-card logs '
    '(protocol §3b–§3d) need their own sheets; no numbers are produced for '
    'them by this tool.',
  );
  return b.toString();
}

Future<void> main(List<String> args) async {
  String? root, criteria, out;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--root':
        root = i + 1 < args.length ? args[++i] : null;
      case '--criteria':
        criteria = i + 1 < args.length ? args[++i] : null;
      case '--out':
        out = i + 1 < args.length ? args[++i] : null;
      default:
        stderr.writeln('Unknown argument ${args[i]}');
        exit(64);
    }
  }
  if (root == null) {
    stderr.writeln(
      'Usage: dart tool/benchmark/pilot_analysis.dart --root <dataset dir> '
      '[--criteria criteria.json] [--out report.md]',
    );
    exit(64);
  }
  try {
    final report = await analyzePilot(Directory(root), criteriaPath: criteria);
    if (out != null) {
      File(out).writeAsStringSync(report);
    } else {
      stdout.write(report);
    }
  } on PilotInputError catch (e) {
    stderr.writeln('pilot_analysis: ${e.message}');
    exit(2);
  }
}
