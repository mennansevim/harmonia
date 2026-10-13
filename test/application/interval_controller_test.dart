import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/interval_controller.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/perception/interval_identification.dart';

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
}
