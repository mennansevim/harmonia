import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/application/rhythm_imitation_controller.dart';
import 'package:harmonia/domain/learning/rhythm_next_step.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/domain/audio/rhythm_imitation.dart';
import 'package:harmonia/domain/content/rhythm_patterns.dart';

import '../support/fake_clip_player.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeClipPlayer player;
  late RhythmImitationController c;
  setUp(() {
    player = FakeClipPlayer();
    c = RhythmImitationController(
      player: player,
      renderReference: (ms) => List.filled(ms.length, 1),
      initialPattern: draftRhythmPatterns.first,
      idleTimeout: const Duration(milliseconds: 20),
    );
  });
  tearDown(() async {
    await c.close();
    c.dispose();
  });

  Future<void> listen() async {
    final run = c.listen();
    await _flush();
    expect(c.phase, RhythmImitationPhase.listening);
    player.end.complete();
    await run;
    player.end = Completer();
  }

  test('taps before listening or during reference are not evaluated', () async {
    c.registerTap(const Duration(milliseconds: 1));
    expect(c.tapCount, 0);
    final run = c.listen();
    await _flush();
    c.registerTap(const Duration(milliseconds: 2));
    c.registerTap(const Duration(milliseconds: 3));
    expect(c.tapsDuringReference, 2);
    expect(c.tapCount, 0);
    player.end.complete();
    await run;
    expect(c.phase, RhythmImitationPhase.awaitingTaps);
  });

  test('taps then inactivity produce a measured timeline', () async {
    await listen();
    for (final ms in [0, 750, 1500, 2250]) {
      c.registerTap(Duration(milliseconds: 5000 + ms));
    }
    expect(c.phase, RhythmImitationPhase.tapping);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.phase, RhythmImitationPhase.finished);
    expect(c.outcome!.isMeasured, isTrue);
    expect(c.outcome!.referencePlays, 1);
  });

  test('replays respect the quota and stop once answering starts', () async {
    await listen();
    await listen();
    await listen();
    expect(c.referencePlays, 3);
    expect(c.canListen, isFalse);
    final fresh = RhythmImitationController(
      player: FakeClipPlayer(),
      renderReference: (ms) => [1],
      initialPattern: draftRhythmPatterns.first,
    );
    expect(fresh.canListen, isTrue);
    fresh.dispose();
  });

  test('no replay after the first tap', () async {
    await listen();
    c.registerTap(const Duration(seconds: 1));
    expect(c.canListen, isFalse);
  });

  test('a backwards timestamp is dropped, not reordered', () async {
    await listen();
    c.registerTap(const Duration(milliseconds: 100));
    c.registerTap(const Duration(milliseconds: 50));
    expect(c.tapCount, 1);
  });

  test('finish with one tap is a neutral too-few-taps outcome', () async {
    await listen();
    c.registerTap(const Duration(seconds: 1));
    await c.finish();
    expect(c.outcome!.status, RhythmImitationStatus.tooFewTaps);
  });

  test('cancel during reference resets the attempt and stops audio', () async {
    final run = c.listen();
    await _flush();
    await c.cancel();
    await run;
    expect(c.phase, RhythmImitationPhase.idle);
    expect(c.referencePlays, 0);
    expect(player.calls, contains('stop'));
  });

  test('playback failure returns to idle with a visible flag', () async {
    player.playFailure = StateError('no audio');
    await c.listen();
    expect(c.phase, RhythmImitationPhase.idle);
    expect(c.playbackFailed, isTrue);
  });

  test('pattern change only before tapping and resets evidence', () async {
    final run = c.listen();
    await _flush();
    c.selectPattern(draftRhythmPatterns[1]);
    expect(c.pattern, draftRhythmPatterns.first);
    player.end.complete();
    await run;
    c.registerTap(const Duration(seconds: 1));
    c.selectPattern(draftRhythmPatterns[2]);
    expect(c.pattern, draftRhythmPatterns.first, reason: 'tapping started');
    c.registerTap(const Duration(seconds: 2));
    await c.finish();
    c.selectPattern(draftRhythmPatterns[1]);
    expect(c.pattern, draftRhythmPatterns[1]);
    expect(c.outcome, isNull);
    expect(c.referencePlays, 0);
  });

  test('finished attempt is recorded once with touch provenance', () async {
    final history = InMemoryResultHistory();
    var ids = 0;
    final h = RhythmImitationController(
      player: player,
      renderReference: (ms) => [1],
      initialPattern: draftRhythmPatterns.first,
      history: history,
      newAttemptId: () => 'attempt-${++ids}000',
      clock: () => DateTime.utc(2026, 10, 11, 9),
    );
    final run = h.listen();
    await _flush();
    player.end.complete();
    await run;
    player.end = Completer();
    // A replay belongs to the same attempt id.
    final replay = h.listen();
    await _flush();
    player.end.complete();
    await replay;
    for (final ms in [0, 750, 1500, 2250]) {
      h.registerTap(Duration(milliseconds: 9000 + ms));
    }
    await h.finish();
    expect(h.recordOutcome, RecordOutcome.recorded);
    final saved = await history.load();
    expect(saved.single.attemptId, 'attempt-1000');
    expect(saved.single.result.provenance.source, MeasurementSource.touch);
    expect(saved.single.result.measurements['referencePlays'], 2);
    // Next attempt gets a new id.
    player.end = Completer();
    final next = h.listen();
    await _flush();
    player.end.complete();
    await next;
    h.registerTap(const Duration(seconds: 20));
    await h.finish();
    expect((await history.load()).map((e) => e.attemptId), [
      'attempt-1000',
      'attempt-2000',
    ]);
    expect((await history.load()).last.result.isValid, isFalse);
    await h.close();
    h.dispose();
  });

  test('history failure is flagged without losing the outcome', () async {
    final h = RhythmImitationController(
      player: player,
      renderReference: (ms) => [1],
      initialPattern: draftRhythmPatterns.first,
      history: _BrokenHistory(),
    );
    final run = h.listen();
    await _flush();
    player.end.complete();
    await run;
    h.registerTap(const Duration(seconds: 1));
    h.registerTap(const Duration(milliseconds: 1750));
    await h.finish();
    expect(h.outcome!.isMeasured, isTrue);
    expect(h.historyFailed, isTrue);
    await h.close();
    h.dispose();
  });

  test(
    'error segment is replayed locally and never added to history',
    () async {
      final history = InMemoryResultHistory();
      final guidedPlayer = FakeClipPlayer();
      List<int>? renderedOnsets;
      final h = RhythmImitationController(
        player: guidedPlayer,
        renderReference: (ms) {
          renderedOnsets = List.of(ms);
          return [1];
        },
        initialPattern: draftRhythmPatterns.first,
        history: history,
        newAttemptId: () => 'rhythm-guided-source',
      );

      var run = h.listen();
      await _flush();
      guidedPlayer.end.complete();
      await run;
      for (final ms in [0, 750, 2250]) {
        h.registerTap(Duration(milliseconds: 10000 + ms));
      }
      await h.finish();
      expect(await history.load(), hasLength(1));
      expect(h.suggestedGuidedSegment!.onsetsMs, [0, 750, 1500]);

      h.startGuidedSegment();
      expect(h.isGuided, isTrue);
      expect(h.phase, RhythmImitationPhase.idle);
      guidedPlayer.end = Completer();
      run = h.listen();
      await _flush();
      expect(renderedOnsets, [0, 750, 1500]);
      guidedPlayer.end.complete();
      await run;
      for (final ms in [0, 750, 1500]) {
        h.registerTap(Duration(milliseconds: 20000 + ms));
      }
      await h.finish();
      expect(h.outcome!.guided, isTrue);
      expect(h.recordOutcome, isNull);
      expect(h.nextStep, isNull);
      expect(await history.load(), hasLength(1));

      h.exitGuidedSegment();
      expect(h.isGuided, isFalse);
      expect(h.phase, RhythmImitationPhase.idle);
      await h.close();
      h.dispose();
    },
  );

  test(
    'next step after two clean attempts moves on; retention is strict',
    () async {
      final history = InMemoryResultHistory();
      var ids = 0;
      final h = RhythmImitationController(
        player: player,
        renderReference: (ms) => [1],
        initialPattern: draftRhythmPatterns.first,
        catalog: draftRhythmPatterns,
        history: history,
        newAttemptId: () => 'attempt-${++ids}000',
      );
      Future<void> cleanAttempt() async {
        player.end = Completer();
        final run = h.listen();
        await _flush();
        player.end.complete();
        await run;
        for (final ms in [0, 750, 1500, 2250]) {
          h.registerTap(Duration(milliseconds: 40000 * ids + ms));
        }
        await h.finish();
      }

      await cleanAttempt();
      expect(h.nextStep!.kind, NextStepKind.repeat);
      await cleanAttempt();
      expect(h.nextStep!.kind, NextStepKind.nextPattern);
      h.applyNextStep();
      expect(h.pattern, draftRhythmPatterns[1]);
      expect(h.phase, RhythmImitationPhase.idle);
      expect(h.retentionCheck, isFalse);
      h.retentionCheck = true;
      expect(h.maxReferencePlays, 1);
      await h.close();
      h.dispose();
    },
  );
}

class _BrokenHistory extends InMemoryResultHistory {
  @override
  Future<RecordOutcome> record(ResultHistoryEntry entry) async =>
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
}
