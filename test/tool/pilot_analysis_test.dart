// Schema-path tests for tool/benchmark/pilot_analysis.dart.
//
// EVERY recording below is a SYNTHETIC test tone or silence generated in the
// test. None of it is real singer data, and nothing here says anything about
// BENCH-01/VAD-01/CAL-02. One test declares such audio as a human holdout
// only to exercise the decision-table code path; the numbers are not results.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';

import '../../tool/benchmark/pilot_analysis.dart';

class _Clip {
  _Clip(this.id, this.bytes);
  final String id;
  final Uint8List bytes;
  String get sha => sha256.convert(bytes).toString();
}

_Clip _tone(String id, double hz, {double seconds = 0.6}) => _Clip(
  id,
  Pcm16Wav.tone(
    frequencyHz: hz,
    sampleRateHz: 44100,
    durationSeconds: seconds,
  ).encode(),
);

_Clip _silence(String id) => _Clip(
  id,
  Pcm16Wav(sampleRateHz: 44100, samples: List.filled(26460, 0.0)).encode(),
);

Future<Directory> _dataset(
  List<
    ({
      _Clip clip,
      String source,
      String partition,
      String signal,
      List<double> expected,
      String cls,
      String device,
      String route,
      String room,
      Map<String, String>? labels,
    })
  >
  items, {
  bool writeMeta = true,
}) async {
  final dir = await Directory.systemTemp.createTemp('resonia-pilot-test-');
  final entries = <Map<String, Object?>>[];
  final records = <String, Object?>{};
  for (final it in items) {
    await File('${dir.path}/${it.clip.id}.wav').writeAsBytes(it.clip.bytes);
    final human = it.source == 'humanRecording';
    entries.add({
      'path': '${it.clip.id}.wav',
      'fixture': {
        'id': it.clip.id,
        'source': it.source,
        'partition': it.partition,
        'signal': it.signal,
        'sampleRateHz': 44100,
        'sampleCount': (it.clip.bytes.length - 44) ~/ 2,
        'sha256': it.clip.sha,
        'rightsReference': 'test-only-synthetic',
        'consentReference': human ? 'test-only-not-real' : null,
        'subjectGroup': human ? 'g-${it.clip.id.substring(0, 1)}' : null,
        'expectedFrequenciesHz': it.expected,
        'a4Hz': 440,
      },
    });
    records[it.clip.id] = {
      'labelClass': it.cls,
      'device': it.device,
      'route': it.route,
      'room': it.room,
      if (it.labels != null) 'labels': it.labels,
    };
  }
  await File('${dir.path}/manifest.json').writeAsString(
    jsonEncode({
      'schemaVersion': 1,
      'codec': 'mono_pcm16_wav',
      'entries': entries,
    }),
  );
  if (writeMeta) {
    await File(
      '${dir.path}/pilot_meta.json',
    ).writeAsString(jsonEncode({'schemaVersion': 1, 'records': records}));
  }
  return dir;
}

({
  _Clip clip,
  String source,
  String partition,
  String signal,
  List<double> expected,
  String cls,
  String device,
  String route,
  String room,
  Map<String, String>? labels,
})
_item(
  _Clip clip, {
  String source = 'synthetic',
  String partition = 'development',
  String signal = 'tone',
  List<double> expected = const [],
  String cls = 'correct_note',
  String device = 'test-device',
  String route = 'builtin',
  String room = 'quiet',
  Map<String, String>? labels,
}) => (
  clip: clip,
  source: source,
  partition: partition,
  signal: signal,
  expected: expected,
  cls: cls,
  device: device,
  route: route,
  room: room,
  labels: labels,
);

void main() {
  group('statistics helpers', () {
    test('Wilson interval brackets the rate and handles n=0', () {
      final w = Wilson(9, 10);
      expect(w.rate, 0.9);
      expect(w.lower, lessThan(0.9));
      expect(w.upper, greaterThan(0.9));
      expect(w.lower, closeTo(0.5958, 1e-3));
      expect(Wilson(0, 0).text, 'n=0');
      expect(Wilson(10, 10).upper, closeTo(1, 1e-9));
    });

    test('outcome: correct, octave, wrong, abstain', () {
      expect(outcomeOf(440, 440), Outcome.correct);
      expect(outcomeOf(440 * 1.02, 440), Outcome.correct); // ≈34 c
      expect(outcomeOf(440 * 1.04, 440), Outcome.wrong); // ≈68 c
      expect(outcomeOf(880, 440), Outcome.octave);
      expect(outcomeOf(220, 440), Outcome.octave);
      expect(outcomeOf(660, 440), Outcome.wrong);
      expect(outcomeOf(null, 440), Outcome.abstain);
      expect(outcomeOf(440 * 1.02, 440, tolCents: 40), Outcome.correct); // 34 c
      expect(outcomeOf(440 * 1.025, 440, tolCents: 40), Outcome.wrong); // 43 c
    });

    test('Cohen kappa: perfect, chance-level and undefined', () {
      expect(cohenKappa(['a', 'b', 'a', 'b'], ['a', 'b', 'a', 'b']), 1);
      expect(cohenKappa(['a', 'a', 'b', 'b'], ['a', 'b', 'a', 'b']), 0);
      expect(cohenKappa(['a', 'a'], ['a', 'a']), isNull);
      expect(cohenKappa([], []), isNull);
    });

    test('criteria verdicts follow the interval, not the point estimate', () {
      final min = Criterion(
        id: 'c',
        algorithm: 'app-yin',
        metric: 'hit50',
        classes: {'correct_note'},
        direction: 'min',
        threshold: 0.8,
      );
      expect(min.verdict(Wilson(95, 100)), 'PASS'); // lower ≈ .89
      expect(min.verdict(Wilson(8, 10)), 'inconclusive');
      expect(min.verdict(Wilson(10, 100)), 'FAIL');
      expect(min.verdict(Wilson(0, 0)), 'no data');
      final max = Criterion(
        id: 'c',
        algorithm: 'app-yin',
        metric: 'octaveError',
        classes: {'correct_note'},
        direction: 'max',
        threshold: 0.1,
      );
      expect(max.verdict(Wilson(0, 100)), 'PASS');
      expect(max.verdict(Wilson(50, 100)), 'FAIL');
    });
  });

  group('inputs are never invented', () {
    test('a missing dataset stops with an explicit error', () async {
      final dir = await Directory.systemTemp.createTemp('resonia-empty-');
      addTearDown(() => dir.delete(recursive: true));
      expect(
        () => analyzePilot(dir),
        throwsA(
          isA<PilotInputError>().having(
            (e) => e.message,
            'message',
            contains('No pilot dataset'),
          ),
        ),
      );
      expect(
        () => analyzePilot(Directory('${dir.path}/nope')),
        throwsA(isA<PilotInputError>()),
      );
    });

    test('the shipped templates are refused, not analysed', () async {
      final dir = await Directory.systemTemp.createTemp('resonia-tpl-');
      addTearDown(() => dir.delete(recursive: true));
      File(
        'docs/research/pilot/manifest_template.json',
      ).copySync('${dir.path}/manifest.json');
      File(
        'docs/research/pilot/pilot_meta_template.json',
      ).copySync('${dir.path}/pilot_meta.json');
      await expectLater(analyzePilot(dir), throwsA(isA<PilotInputError>()));
    });

    test('a recording without a meta record is rejected', () async {
      final dir = await _dataset([
        _item(_tone('a', 440), expected: [440]),
      ]);
      addTearDown(() => dir.delete(recursive: true));
      final metaPath = '${dir.path}/pilot_meta.json';
      File(
        metaPath,
      ).writeAsStringSync(jsonEncode({'schemaVersion': 1, 'records': {}}));
      await expectLater(
        analyzePilot(dir),
        throwsA(
          isA<PilotInputError>().having(
            (e) => e.message,
            'message',
            contains('no record'),
          ),
        ),
      );
    });

    test('an unknown label class or route is rejected', () {
      expect(
        () => PilotMeta.fromJson('x', {
          'labelClass': 'great_note',
          'device': 'd',
          'route': 'builtin',
          'room': 'quiet',
        }),
        throwsA(isA<PilotInputError>()),
      );
      expect(
        () => PilotMeta.fromJson('x', {
          'labelClass': 'correct_note',
          'device': 'd',
          'route': 'carrier-pigeon',
          'room': 'quiet',
        }),
        throwsA(isA<PilotInputError>()),
      );
    });

    test('a tampered file is rejected by the fixture loader', () async {
      final clip = _tone('a', 440);
      final dir = await _dataset([
        _item(clip, expected: [440]),
      ]);
      addTearDown(() => dir.delete(recursive: true));
      final tampered = Uint8List.fromList(clip.bytes)..[100] ^= 0x40;
      File('${dir.path}/a.wav').writeAsBytesSync(tampered);
      await expectLater(
        analyzePilot(dir),
        throwsA(
          isA<PilotInputError>().having(
            (e) => e.message,
            'message',
            contains('hashMismatch'),
          ),
        ),
      );
    });
  });

  group('schema path (synthetic test tones, not real data)', () {
    test('synthetic rows never reach the decision set', () async {
      final dir = await _dataset([
        _item(_tone('a', 440), expected: [440]),
        _item(_tone('b', 880), expected: [440], cls: 'octave_up'),
        _item(_silence('c'), signal: 'silence', cls: 'silence'),
      ]);
      addTearDown(() => dir.delete(recursive: true));
      final report = await analyzePilot(dir);
      expect(report, contains('| human, holdout (decision set) | 0 |'));
      expect(
        report,
        contains('| synthetic / instrument (not for decisions) | 3 |'),
      );
      expect(report, contains('No human holdout recordings'));
      expect(report, contains('No FROZEN criteria file'));
      expect(report, contains('### yin+fallback'));
      expect(report, contains('### mpm'));
      expect(report, contains('| correct_note | 1 |'));
      expect(report, contains('| octave_up | 1 |'));
      expect(report, contains('No row has two labelers'));
      expect(report, contains('Not analysed here'));
    });

    test(
      'draft criteria give no verdicts; frozen ones need human holdout',
      () async {
        final dir = await _dataset([
          _item(_tone('a', 440), expected: [440]),
        ]);
        addTearDown(() => dir.delete(recursive: true));
        final criteria = {
          'frozen': false,
          'criteria': [
            {
              'id': 'x',
              'algorithm': 'app-yin',
              'metric': 'hit50',
              'classes': ['correct_note'],
              'direction': 'min',
              'threshold': 0.5,
            },
          ],
        };
        final draft = File('${dir.path}/draft.json')
          ..writeAsStringSync(jsonEncode(criteria));
        expect(
          await analyzePilot(dir, criteriaPath: draft.path),
          contains('No FROZEN criteria file'),
        );
        criteria['frozen'] = true;
        final frozen = File('${dir.path}/frozen.json')
          ..writeAsStringSync(jsonEncode(criteria));
        expect(
          await analyzePilot(dir, criteriaPath: frozen.path),
          contains('there is no human holdout: no verdicts'),
        );
      },
    );

    test('TEST ONLY: decision table, kappa and verdict rows render', () async {
      // Synthetic tones declared as a human holdout purely to exercise the
      // code path. The audio is not a human voice and the numbers mean
      // nothing.
      final items = [
        for (var i = 0; i < 4; i++)
          _item(
            _tone(
              '${String.fromCharCode(97 + i)}$i',
              440,
              seconds:
                  0.6 + 0.05 * i, // distinct bytes: duplicates are rejected
            ),
            source: 'humanRecording',
            partition: 'holdout',
            signal: 'voice',
            expected: [440],
            labels: {'A': 'correct_note', 'B': 'correct_note'},
          ),
      ];
      final dir = await _dataset(items);
      addTearDown(() => dir.delete(recursive: true));
      final frozen = File('${dir.path}/frozen.json')
        ..writeAsStringSync(
          jsonEncode({
            'frozen': true,
            'criteria': [
              {
                'id': 'hit50-app',
                'algorithm': 'app-yin',
                'metric': 'hit50',
                'classes': ['correct_note'],
                'direction': 'min',
                'threshold': 0.9,
              },
            ],
          }),
        );
      final report = await analyzePilot(dir, criteriaPath: frozen.path);
      expect(report, contains('| human, holdout (decision set) | 4 |'));
      expect(report, contains('UNDERPOWERED'));
      expect(report, contains('| hit50-app | app-yin | hit50 |'));
      // 4/4 gives a lower bound below 0.9: must be inconclusive, not PASS.
      expect(report, contains('inconclusive'));
      expect(report, contains('kappa=undefined'));
    });
  });

  test('the criteria template is a draft and parses as criteria', () {
    final doc =
        jsonDecode(
              File(
                'docs/research/pilot/criteria_template.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(doc['frozen'], false, reason: 'a template must not be frozen');
    final list = (doc['criteria'] as List).map(Criterion.fromJson).toList();
    expect(list, isNotEmpty);
  });
}
