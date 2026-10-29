import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_result.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/models/score_metric.dart';
import 'package:harmonia/infrastructure/storage/file_result_history.dart';

ResultHistoryEntry entry(String id, {double score = 80}) => ResultHistoryEntry(
  attemptId: id,
  result: ExerciseResult(
    sessionId: id,
    exerciseId: 'draft-rhythm-quarters',
    skill: Skill.rhythm,
    target: const {},
    measurements: const {'matched': 3, 'missed': 0, 'extra': 0},
    scores: ExerciseScores(
      overall: ScoreMetric.measured(score),
      timing: ScoreMetric.measured(score),
    ),
    createdAt: DateTime.utc(2026, 10, 11),
    provenance: const MeasurementProvenance(
      source: MeasurementSource.touch,
      analyzerVersion: 'rhythm-imitation-1',
    ),
  ),
);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('hist-'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  for (final make in <String, ResultHistoryRepository Function(int)>{
    'memory': (c) => InMemoryResultHistory(capacity: c),
    'file': (c) => FileResultHistory(directory: () async => dir, capacity: c),
  }.entries) {
    group(make.key, () {
      test(
        'same attempt is never counted twice; conflicts not overwritten',
        () async {
          final h = make.value(10);
          expect(await h.record(entry('attempt-0001')), RecordOutcome.recorded);
          expect(
            await h.record(entry('attempt-0001')),
            RecordOutcome.duplicate,
          );
          expect(
            await h.record(entry('attempt-0001', score: 10)),
            RecordOutcome.conflict,
          );
          final all = await h.load();
          expect(all, hasLength(1));
          expect(all.single.result.scores.overall.value, 80);
        },
      );

      test('capacity is explicit, never silent pruning', () async {
        final h = make.value(2);
        await h.record(entry('attempt-0001'));
        await h.record(entry('attempt-0002'));
        expect(
          await h.record(entry('attempt-0003')),
          RecordOutcome.storageFull,
        );
        expect((await h.load()).map((e) => e.attemptId), [
          'attempt-0001',
          'attempt-0002',
        ]);
      });

      test('batch uses the same dedup conflict and capacity rules', () async {
        final h = make.value(3);
        await h.record(entry('attempt-0001'));
        await h.record(entry('attempt-0002', score: 10));
        final report = await h.recordAll([
          entry('attempt-0001'),
          entry('attempt-0002', score: 99),
          entry('attempt-0003'),
          entry('attempt-0004'),
        ]);
        expect(report.count(RecordOutcome.duplicate), 1);
        expect(report.count(RecordOutcome.conflict), 1);
        expect(report.count(RecordOutcome.recorded), 1);
        expect(report.count(RecordOutcome.storageFull), 1);
        final stored = await h.load();
        expect(stored.map((item) => item.attemptId), [
          'attempt-0001',
          'attempt-0002',
          'attempt-0003',
        ]);
        expect(stored[1].result.scores.overall.value, 10);
      });

      test('delete one and clear all', () async {
        final h = make.value(10);
        await h.record(entry('attempt-0001'));
        await h.record(entry('attempt-0002'));
        expect(await h.delete('attempt-0001'), isTrue);
        expect(await h.delete('attempt-9999'), isFalse);
        expect((await h.load()).single.attemptId, 'attempt-0002');
        await h.clear();
        expect(await h.load(), isEmpty);
      });
    });
  }

  test(
    'file history persists across instances and serializes writes',
    () async {
      final a = FileResultHistory(directory: () async => dir);
      await Future.wait([
        a.record(entry('attempt-0001')),
        a.record(entry('attempt-0002')),
        a.record(entry('attempt-0003')),
      ]);
      final b = FileResultHistory(directory: () async => dir);
      expect((await b.load()).map((e) => e.attemptId), [
        'attempt-0001',
        'attempt-0002',
        'attempt-0003',
      ]);
    },
  );

  test('corrupt history is reported and the file is kept', () async {
    final file = File('${dir.path}/result_history.json')
      ..writeAsStringSync('{"schemaVersion":1,"entries":[{"attemptId":"x"}]}');
    final h = FileResultHistory(directory: () async => dir);
    await expectLater(
      h.load(),
      throwsA(
        isA<HistoryStorageException>().having(
          (e) => e.failure,
          'failure',
          HistoryStorageFailure.corrupt,
        ),
      ),
    );
    await expectLater(
      h.record(entry('attempt-0001')),
      throwsA(isA<HistoryStorageException>()),
    );
    expect(file.readAsStringSync(), contains('"attemptId":"x"'));
    await h.clear();
    expect(await h.load(), isEmpty);
  });

  test('failed file batch exposes no imported prefix', () async {
    var available = true;
    final h = FileResultHistory(
      directory: () async {
        if (!available) throw StateError('storage unavailable');
        return dir;
      },
    );
    await h.record(entry('attempt-0001'));
    available = false;
    await expectLater(
      h.recordAll([entry('attempt-0002'), entry('attempt-0003')]),
      throwsA(isA<HistoryStorageException>()),
    );
    available = true;
    expect((await h.load()).map((item) => item.attemptId), ['attempt-0001']);
  });

  test('attempt ids are validated', () {
    for (final id in ['short', 'has space here', '../../etc/passwd', '']) {
      expect(() => entry(id), throwsArgumentError);
    }
  });
}
