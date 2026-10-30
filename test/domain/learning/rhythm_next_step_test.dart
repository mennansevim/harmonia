import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/rhythm_imitation.dart';
import 'package:resonia/domain/content/rhythm_patterns.dart';
import 'package:resonia/domain/learning/rhythm_next_step.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_result.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/domain/models/score_metric.dart';

final _p = draftRhythmPatterns;
final _day1 = DateTime(2026, 10, 11, 10);

ExerciseResult _r(
  RhythmPattern p,
  DateTime at, {
  int missed = 0,
  int extra = 0,
  int late = 0,
  double meanAbs = 20,
  bool valid = true,
  String version = RhythmImitationOutcome.version,
  MeasurementSource source = MeasurementSource.touch,
  String? content,
}) => ExerciseResult(
  sessionId: 's',
  exerciseId: p.exercise.exercise.id,
  skill: Skill.rhythm,
  difficulty: p.exercise.exercise.difficulty,
  exerciseMode: p.exercise.exercise.mode,
  target: const {},
  measurements: valid
      ? {
          'missed': missed,
          'extra': extra,
          'late': late,
          'early': 0,
          'meanAbsoluteOffsetMs': meanAbs,
        }
      : const {},
  scores: valid
      ? ExerciseScores(timing: ScoreMetric.measured(80))
      : const ExerciseScores(),
  measurementStatus: valid
      ? MeasurementStatus.valid
      : MeasurementStatus.invalid,
  createdAt: at,
  contentVersion: content ?? p.exercise.exercise.contentVersion,
  provenance: MeasurementProvenance(source: source, analyzerVersion: version),
);

NextStep _rec(List<ExerciseResult> r, {DateTime? now}) =>
    RhythmNextStepPolicy.recommend(
      results: r,
      patterns: _p,
      now: now ?? _day1.add(const Duration(hours: 1)),
    );

void main() {
  test('no history → start with the first pattern', () {
    final s = _rec(const []);
    expect(s.kind, NextStepKind.start);
    expect(s.pattern, _p.first);
  });

  test('unmeasured last attempt → retry, not an error focus', () {
    final s = _rec([_r(_p[0], _day1, valid: false)]);
    expect(s.kind, NextStepKind.retryUnmeasured);
  });

  test('repeat cites the dominant error of the last attempt', () {
    var s = _rec([_r(_p[0], _day1, missed: 2, late: 1)]);
    expect(s.kind, NextStepKind.repeat);
    expect(s.focus, RhythmErrorFocus.missed);
    expect(s.focusCount, 2);
    s = _rec([_r(_p[0], _day1, late: 3)]);
    expect(s.focus, RhythmErrorFocus.late);
  });

  test('one clean attempt is not mastery; sloppy timing is not clean', () {
    expect(_rec([_r(_p[0], _day1)]).kind, NextStepKind.repeat);
    expect(
      _rec([
        _r(_p[0], _day1),
        _r(_p[0], _day1.add(const Duration(minutes: 1)), meanAbs: 90),
      ]).kind,
      NextStepKind.repeat,
    );
  });

  test('two clean attempts → next pattern', () {
    final s = _rec([
      _r(_p[0], _day1),
      _r(_p[0], _day1.add(const Duration(minutes: 1))),
    ]);
    expect(s.kind, NextStepKind.nextPattern);
    expect(s.pattern, _p[1]);
  });

  test('next day: retention check outranks in-progress work', () {
    final history = [
      _r(_p[0], _day1),
      _r(_p[0], _day1.add(const Duration(minutes: 1))),
      _r(_p[1], _day1.add(const Duration(minutes: 5)), missed: 1),
    ];
    expect(_rec(history).kind, NextStepKind.repeat);
    final s = _rec(history, now: _day1.add(const Duration(days: 1)));
    expect(s.kind, NextStepKind.delayedCheck);
    expect(s.pattern, _p[0]);
  });

  test('clean attempt on a later day counts as retained', () {
    final s = _rec([
      _r(_p[0], _day1),
      _r(_p[0], _day1.add(const Duration(minutes: 1))),
      _r(_p[0], _day1.add(const Duration(days: 1))),
    ], now: _day1.add(const Duration(days: 2)));
    expect(s.kind, NextStepKind.nextPattern);
    expect(s.pattern, _p[1]);
  });

  test('failed retention check returns to targeted repetition', () {
    final s = _rec([
      _r(_p[0], _day1),
      _r(_p[0], _day1.add(const Duration(minutes: 1))),
      _r(_p[0], _day1.add(const Duration(days: 1)), extra: 1),
    ], now: _day1.add(const Duration(days: 1, hours: 1)));
    expect(s.kind, NextStepKind.repeat);
    expect(s.focus, RhythmErrorFocus.extra);
  });

  test('other analyzer/content versions and sources are not comparable', () {
    final s = _rec([
      _r(_p[0], _day1, version: 'old-1'),
      _r(_p[0], _day1, content: 'draft-0'),
      _r(_p[0], _day1, source: MeasurementSource.mock),
    ]);
    expect(s.kind, NextStepKind.start);
  });

  test('all mastered and retained → done', () {
    final history = <ExerciseResult>[
      for (final p in _p) ...[
        _r(p, _day1),
        _r(p, _day1.add(const Duration(minutes: 1))),
        _r(p, _day1.add(const Duration(days: 1))),
      ],
    ];
    expect(
      _rec(history, now: _day1.add(const Duration(days: 3))).kind,
      NextStepKind.allDone,
    );
  });

  test('current unmastered pattern wins over earlier unstarted ones', () {
    final history = [_r(_p[1], _day1, missed: 1)];
    expect(_rec(history).kind, NextStepKind.start);
    final s = RhythmNextStepPolicy.recommend(
      results: history,
      patterns: _p,
      now: _day1,
      current: _p[1],
    );
    expect(s.kind, NextStepKind.repeat);
    expect(s.pattern, _p[1]);
  });
}
