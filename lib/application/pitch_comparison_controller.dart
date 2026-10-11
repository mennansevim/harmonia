import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/perception/pitch_comparison.dart';
import 'result_history.dart';

enum PitchComparisonPhase {
  idle,
  playing,
  awaitingAnswer,
  feedback,
  finished,
  closed,
}

/// One 8-item round: play pair → answer → immediate learning feedback →
/// next. Answers are only accepted after the pair finished playing once.
class PitchComparisonController extends ChangeNotifier {
  PitchComparisonController({
    required this.player,
    required this.renderPair,
    required PitchComparisonLevel initialLevel,
    this.history,
    Random? random,
    DateTime Function()? clock,
    String Function()? newAttemptId,
  }) : _level = initialLevel,
       _random = random ?? Random(),
       _now = clock ?? DateTime.now,
       _newAttemptId = newAttemptId ?? _randomId {
    _newRound();
  }

  static String _randomId() =>
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  final ReferenceClipPlayer player;
  final List<int> Function(double firstHz, double secondHz) renderPair;
  final ResultHistoryRepository? history;
  final Random _random;
  final DateTime Function() _now;
  final String Function() _newAttemptId;

  PitchComparisonLevel _level;
  PitchComparisonLevel get level => _level;
  late PitchComparisonRound round;
  late List<PitchAnswer?> answers;
  late List<int> plays;
  int index = 0;
  PitchComparisonPhase phase = PitchComparisonPhase.idle;
  PitchComparisonOutcome? outcome;
  RecordOutcome? recordOutcome;
  bool historyFailed = false;
  bool playbackFailed = false;
  bool _heardCurrent = false;
  Completer<void>? _wake;
  int _epoch = 0;

  bool get _closed => phase == PitchComparisonPhase.closed;

  /// Retention check: each pair may be heard once (no replays).
  bool retentionCheck = false;

  bool get canPlay =>
      (phase == PitchComparisonPhase.idle ||
          phase == PitchComparisonPhase.awaitingAnswer) &&
      !(retentionCheck && plays[index] > 0);
  bool get canAnswer =>
      phase == PitchComparisonPhase.awaitingAnswer && _heardCurrent;

  void _set(PitchComparisonPhase next) {
    if (_closed) return;
    phase = next;
    notifyListeners();
  }

  void _newRound() {
    round = PitchComparisonRound.generate(_level, _random);
    answers = List.filled(round.items.length, null);
    plays = List.filled(round.items.length, 0);
    index = 0;
    outcome = null;
    recordOutcome = null;
    historyFailed = false;
    playbackFailed = false;
    _heardCurrent = false;
  }

  /// Only before the first answer or after a finished round; switching
  /// mid-round would silently discard answered items.
  bool get canChangeLevel =>
      phase == PitchComparisonPhase.finished ||
      (phase == PitchComparisonPhase.idle && answers.every((a) => a == null));

  void selectLevel(PitchComparisonLevel next) {
    if (!canChangeLevel) return;
    ++_epoch;
    _level = next;
    retentionCheck = false;
    _newRound();
    _set(PitchComparisonPhase.idle);
  }

  void newRound() => selectLevel(_level);

  Future<void> playCurrent() async {
    if (!canPlay) return;
    final epoch = ++_epoch;
    final item = round.items[index];
    plays[index]++;
    playbackFailed = false;
    _set(PitchComparisonPhase.playing);
    try {
      final handle = await player.playWav(
        renderPair(item.firstHz, item.secondHz),
      );
      if (epoch != _epoch || _closed) return;
      final wake = _wake = Completer<void>();
      await Future.any([handle.completed, wake.future]);
    } catch (_) {
      if (epoch != _epoch || _closed) return;
      playbackFailed = true;
    }
    if (epoch != _epoch || _closed) return;
    if (!playbackFailed) _heardCurrent = true;
    _set(
      _heardCurrent
          ? PitchComparisonPhase.awaitingAnswer
          : PitchComparisonPhase.idle,
    );
  }

  void answer(PitchAnswer a) {
    if (!canAnswer) return;
    answers[index] = a;
    _set(PitchComparisonPhase.feedback);
  }

  bool get lastAnswerCorrect => answers[index] == round.items[index].correct;

  Future<void> next() async {
    if (phase != PitchComparisonPhase.feedback) return;
    if (index < round.items.length - 1) {
      index++;
      _heardCurrent = false;
      _set(PitchComparisonPhase.idle);
      return;
    }
    final epoch = ++_epoch;
    final result = PitchComparisonOutcome(
      round: round,
      answers: answers,
      plays: plays,
    );
    outcome = result;
    _set(PitchComparisonPhase.finished);
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

  /// Abandons the round; nothing is recorded for an unfinished round.
  Future<void> cancel() async {
    if (_closed) return;
    ++_epoch;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    _newRound();
    _set(PitchComparisonPhase.idle);
    try {
      await player.stop();
    } catch (_) {}
  }

  Future<void> close() async {
    if (_closed) return;
    ++_epoch;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    phase = PitchComparisonPhase.closed;
    await player.close();
  }

  @override
  void dispose() {
    unawaited(close().catchError((Object _) {}));
    super.dispose();
  }
}
