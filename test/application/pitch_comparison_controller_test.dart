import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/pitch_comparison_controller.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/perception/pitch_comparison.dart';

import '../support/fake_clip_player.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeClipPlayer player;
  late InMemoryResultHistory history;
  late PitchComparisonController c;
  setUp(() {
    player = FakeClipPlayer();
    history = InMemoryResultHistory();
    var n = 0;
    c = PitchComparisonController(
      player: player,
      renderPair: (a, b) => [1, 2, 3],
      initialLevel: draftPitchLevels.first,
      history: history,
      random: Random(5),
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

  test('no answer before the pair has been heard once', () async {
    c.answer(PitchAnswer.first);
    expect(c.answers.first, isNull);
    final run = c.playCurrent();
    await _flush();
    expect(c.canAnswer, isFalse, reason: 'still playing');
    player.end.complete();
    await run;
    expect(c.canAnswer, isTrue);
  });

  test('full round records once, counts replays, gives feedback', () async {
    for (var i = 0; i < 8; i++) {
      await play();
      if (i == 0) await play(); // one replay
      c.answer(c.round.items[i].correct);
      expect(c.lastAnswerCorrect, isTrue);
      await c.next();
    }
    expect(c.phase, PitchComparisonPhase.finished);
    expect(c.outcome!.correctCount, 8);
    expect(c.outcome!.referencePlays, 2);
    final saved = await history.load();
    expect(saved.single.result.measurements['correct'], 8);
    expect(c.recordOutcome, RecordOutcome.recorded);
  });

  test('wrong answer shows the correct tone; level locked mid-round', () async {
    await play();
    final wrong = c.round.items[0].correct == PitchAnswer.first
        ? PitchAnswer.second
        : PitchAnswer.first;
    c.answer(wrong);
    expect(c.lastAnswerCorrect, isFalse);
    await c.next();
    c.selectLevel(draftPitchLevels[1]);
    expect(c.level, draftPitchLevels.first);
  });

  test('cancel abandons the round without recording', () async {
    await play();
    c.answer(PitchAnswer.first);
    await c.cancel();
    expect(c.index, 0);
    expect(await history.load(), isEmpty);
    expect(player.calls, contains('stop'));
  });

  test('playback failure keeps answers locked', () async {
    player.playFailure = StateError('x');
    await c.playCurrent();
    expect(c.playbackFailed, isTrue);
    expect(c.canAnswer, isFalse);
  });

  test(
    'retention check allows one listen per pair and flags the result',
    () async {
      c.retentionCheck = true;
      for (var i = 0; i < 8; i++) {
        await play();
        expect(c.canPlay, isFalse, reason: 'no replay in retention check');
        c.answer(c.round.items[i].correct);
        await c.next();
      }
      final saved = await history.load();
      expect(saved.single.result.measurements['retentionCheck'], isTrue);
    },
  );
}
