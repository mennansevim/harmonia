import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/perception/interval_identification.dart';
import 'result_history.dart';
import 'review_playback.dart';

enum IntervalPhase { idle, playing, awaitingAnswer, feedback, finished, closed }

/// 8-item movable-do round: play context + do + degree → name the degree →
/// immediate learning feedback → next. Same safety rules as PERC-01.
class IntervalController extends ChangeNotifier {
  IntervalController({
    required this.player,
    required this.renderItem,
    required IntervalLevel initialLevel,
    this.history,
    Random? random,
    DateTime Function()? clock,
    String Function()? newAttemptId,
  }) : _level = initialLevel,
       _random = random ?? Random(),
       _now = clock ?? DateTime.now,
       _newAttemptId = newAttemptId ?? _randomId {
    review = ReviewPlaybackCoordinator(
      player: player,
      onChanged: notifyListeners,
    );
    _newRound();
  }

  static String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  final ReferenceClipPlayer player;
  final List<int> Function(IntervalItem item) renderItem;
  final ResultHistoryRepository? history;
  final Random _random;
  final DateTime Function() _now;
  final String Function() _newAttemptId;
  late final ReviewPlaybackCoordinator review;

  IntervalLevel _level;
  IntervalLevel get level => _level;
  late IntervalRound round;
  late List<SolfegeDegree?> answers;
  late List<int> plays;
  int index = 0;
  IntervalPhase phase = IntervalPhase.idle;
  IntervalOutcome? outcome;
  RecordOutcome? recordOutcome;
  bool historyFailed = false;
  bool playbackFailed = false;
  bool retentionCheck = false;
  bool guidedRetry = false;
  bool _heard = false;
  Completer<void>? _wake;
  int _epoch = 0;

  bool get _closed => phase == IntervalPhase.closed;
  bool get canPlay =>
      (phase == IntervalPhase.idle || phase == IntervalPhase.awaitingAnswer) &&
      !(retentionCheck && plays[index] > 0);
  bool get canAnswer => phase == IntervalPhase.awaitingAnswer && _heard;
  bool get canChangeLevel =>
      phase == IntervalPhase.finished ||
      (phase == IntervalPhase.idle && answers.every((a) => a == null));
  bool get lastAnswerCorrect => answers[index] == round.items[index].degree;

  void _set(IntervalPhase next) {
    if (_closed) return;
    phase = next;
    notifyListeners();
  }

  void _newRound() {
    round = IntervalRound.generate(_level, _random);
    answers = List.filled(round.items.length, null);
    plays = List.filled(round.items.length, 0);
    index = 0;
    outcome = null;
    recordOutcome = null;
    historyFailed = false;
    playbackFailed = false;
    guidedRetry = false;
    _heard = false;
  }

  int get mistakeCount {
    final result = outcome;
    if (result == null) return 0;
    return [
      for (var i = 0; i < result.answers.length; i++)
        if (result.answers[i] != result.round.items[i].degree) i,
    ].length;
  }

  /// Starts a short practice-only round with the exact missed degrees.
  /// It is deliberately excluded from history/mastery evidence.
  Future<bool> startGuidedRetry() async {
    final result = outcome;
    if (_closed || phase != IntervalPhase.finished || result == null) {
      return false;
    }
    final missed = [
      for (var i = 0; i < result.answers.length; i++)
        if (result.answers[i] != result.round.items[i].degree)
          result.round.items[i],
    ];
    if (missed.isEmpty) return false;
    ++_epoch;
    await review.cancel();
    if (_closed) return false;
    round = IntervalRound.guided(_level, missed);
    answers = List.filled(round.items.length, null);
    plays = List.filled(round.items.length, 0);
    index = 0;
    outcome = null;
    recordOutcome = null;
    historyFailed = false;
    playbackFailed = false;
    retentionCheck = false;
    guidedRetry = true;
    _heard = false;
    _set(IntervalPhase.idle);
    return true;
  }

  void selectLevel(IntervalLevel next) {
    if (!canChangeLevel) return;
    ++_epoch;
    unawaited(review.cancel());
    _level = next;
    retentionCheck = false;
    _newRound();
    _set(IntervalPhase.idle);
  }

  void newRound() => selectLevel(_level);

  Future<void> reviewReference(int itemIndex) {
    final result = outcome;
    if (phase != IntervalPhase.finished ||
        result == null ||
        itemIndex < 0 ||
        itemIndex >= result.round.items.length) {
      return Future<void>.value();
    }
    return review.play(
      itemIndex: itemIndex,
      clipId: 'reference',
      wavBytes: renderItem(result.round.items[itemIndex]),
    );
  }

  Future<void> reviewSelected(int itemIndex) {
    final result = outcome;
    if (phase != IntervalPhase.finished ||
        result == null ||
        itemIndex < 0 ||
        itemIndex >= result.round.items.length) {
      return Future<void>.value();
    }
    final answer = result.answers[itemIndex];
    if (answer == null) return Future<void>.value();
    final original = result.round.items[itemIndex];
    return review.play(
      itemIndex: itemIndex,
      clipId: 'selected',
      wavBytes: renderItem(
        IntervalItem(tonicHz: original.tonicHz, degree: answer),
      ),
    );
  }

  Future<void> playCurrent() async {
    if (!canPlay) return;
    final epoch = ++_epoch;
    plays[index]++;
    playbackFailed = false;
    _set(IntervalPhase.playing);
    try {
      final handle = await player.playWav(renderItem(round.items[index]));
      if (epoch != _epoch || _closed) return;
      final wake = _wake = Completer<void>();
      await Future.any([handle.completed, wake.future]);
    } catch (_) {
      if (epoch != _epoch || _closed) return;
      playbackFailed = true;
    }
    if (epoch != _epoch || _closed) return;
    if (!playbackFailed) _heard = true;
    _set(_heard ? IntervalPhase.awaitingAnswer : IntervalPhase.idle);
  }

  void answer(SolfegeDegree d) {
    if (!canAnswer || !_level.options.contains(d)) return;
    answers[index] = d;
    _set(IntervalPhase.feedback);
  }

  Future<void> next() async {
    if (phase != IntervalPhase.feedback) return;
    if (index < round.items.length - 1) {
      index++;
      _heard = false;
      _set(IntervalPhase.idle);
      return;
    }
    final epoch = ++_epoch;
    final result = IntervalOutcome(
      round: round,
      answers: answers,
      plays: plays,
    );
    outcome = result;
    _set(IntervalPhase.finished);
    if (guidedRetry) return;
    final store = history;
    if (store == null) return;
    try {
      final id = _newAttemptId();
      final saved = await store.record(
        ResultHistoryEntry(
          attemptId: id,
          result: result.toResult(
            sessionId: id,
            createdAt: _now().toUtc(),
            retentionCheck: retentionCheck,
          ),
        ),
      );
      if (epoch != _epoch || _closed) return;
      recordOutcome = saved;
    } catch (_) {
      if (epoch != _epoch || _closed) return;
      historyFailed = true;
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    if (_closed) return;
    ++_epoch;
    await review.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    _newRound();
    _set(IntervalPhase.idle);
    try {
      await player.stop();
    } catch (_) {}
  }

  /// Stops audio when the app is backgrounded without discarding a completed
  /// result that the learner is reviewing.
  Future<void> pause() async {
    if (_closed) return;
    if (phase == IntervalPhase.finished) {
      await review.cancel();
      return;
    }
    await cancel();
  }

  Future<void> close() async {
    if (_closed) return;
    ++_epoch;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    phase = IntervalPhase.closed;
    await review.close();
    await player.close();
  }

  @override
  void dispose() {
    review.detach();
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
