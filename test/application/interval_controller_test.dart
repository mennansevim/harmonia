import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/interval_controller.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/domain/perception/interval_identification.dart';

import '../support/fake_clip_player.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeClipPlayer player;
  late InMemoryResultHistory history;
  late IntervalController c;
  setUp(() {
    player = FakeClipPlayer();
    history = InMemoryResultHistory();
    var n = 0;
    c = IntervalController(
      player: player,
      renderItem: (_) => [1],
      initialLevel: draftIntervalLevels.first,
      history: history,
      random: Random(1),
      newAttemptId: () => 'attempt-${++n}000',
    );
  });
  tearDown(() async {
    await c.close();
    c.dispose();
  });

  Future<void> play() async {
    player.end = Completer();
    final run = c.playCurrent();
    await _flush();
    player.end.complete();
    await run;
  }

  test(
    'answers outside the level options and before listening are ignored',
    () async {
      c.answer(SolfegeDegree.re);
      expect(c.answers.first, isNull);
      await play();
      c.answer(SolfegeDegree.ti);
      expect(c.answers.first, isNull);
      c.answer(c.round.items.first.degree);
      expect(c.lastAnswerCorrect, isTrue);
    },
  );

  test('full round records once; retention allows one listen', () async {
    c.retentionCheck = true;
    for (var i = 0; i < 8; i++) {
      await play();
      expect(c.canPlay, isFalse);
      c.answer(c.round.items[i].degree);
      await c.next();
    }
    final saved = await history.load();
    expect(saved.single.result.measurements['correct'], 8);
    expect(saved.single.result.measurements['retentionCheck'], isTrue);
  });

  test('level cannot change mid-round; cancel records nothing', () async {
    await play();
    c.answer(c.round.items.first.degree);
    await c.next();
    c.selectLevel(draftIntervalLevels[1]);
    expect(c.level, draftIntervalLevels.first);
    await c.cancel();
    expect(await history.load(), isEmpty);
    c.selectLevel(draftIntervalLevels[1]);
    expect(c.level, draftIntervalLevels[1]);
  });

  test(
    'reference and selected review preserve result and retention evidence',
    () async {
      c.retentionCheck = true;
      for (var i = 0; i < 8; i++) {
        await play();
        c.answer(i == 0 ? SolfegeDegree.sol : c.round.items[i].degree);
        await c.next();
      }
      final result = c.outcome!;
      final plays = List<int>.of(result.plays);
      final saved = await history.load();
      Future<void> finishReview(Future<void> Function() startReview) async {
        player.end = Completer();
        final start = startReview();
        await _flush();
        player.end.complete();
        await start;
      }

      await finishReview(() => c.reviewReference(0));
      await finishReview(() => c.reviewSelected(0));
      player.end = Completer();
      final interrupted = c.reviewReference(0);
      await _flush();
      await c.pause();
      await interrupted;
      expect(c.phase, IntervalPhase.finished);
      expect(c.outcome, same(result));
      expect(c.outcome!.plays, plays);
      expect((await history.load()).single, same(saved.single));
      expect(saved.single.result.measurements['retentionCheck'], isTrue);
    },
  );

  test(
    'guided retry keeps exact missed degrees and is not persisted',
    () async {
      final missed = <IntervalItem>[];
      for (var i = 0; i < 8; i++) {
        await play();
        final correct = c.round.items[i].degree;
        if (i < 2) {
          missed.add(c.round.items[i]);
          c.answer(c.level.options.firstWhere((option) => option != correct));
        } else {
          c.answer(correct);
        }
        await c.next();
      }
      expect((await history.load()), hasLength(1));
      expect(c.mistakeCount, 2);

      expect(await c.startGuidedRetry(), isTrue);
      expect(c.guidedRetry, isTrue);
      expect(c.round.items, orderedEquals(missed));
      for (var i = 0; i < c.round.items.length; i++) {
        await play();
        c.answer(c.round.items[i].degree);
        await c.next();
      }
      expect(c.outcome!.correctCount, 2);
      expect(c.recordOutcome, isNull);
      expect(
        () => c.outcome!.toResult(
          sessionId: 'forbidden',
          createdAt: DateTime.utc(2026),
        ),
        throwsStateError,
      );
      expect((await history.load()), hasLength(1));
    },
  );
}
