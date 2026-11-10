import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/audio/audio_capture.dart';
import '../domain/audio/rhythm_imitation.dart';
import '../domain/audio/rhythm_reference_clock.dart';
import '../domain/content/rhythm_patterns.dart';
import '../domain/learning/rhythm_next_step.dart';
import 'result_history.dart';

enum RhythmImitationPhase {
  idle,
  listening,
  awaitingTaps,
  tapping,
  evaluating,
  finished,
  closed,
}

/// Listen → repeat by tapping. Taps carry the pointer event's monotonic
/// engine timestamp (not wall clock, not handler time). Taps while the
/// reference plays are never evaluated; they are only counted.
class RhythmImitationController extends ChangeNotifier {
  RhythmImitationController({
    required this.player,
    required this.renderReference,
    required RhythmPattern initialPattern,
    this.idleTimeout = const Duration(milliseconds: 2500),
    this.history,
    List<RhythmPattern>? catalog,
    DateTime Function()? clock,
    String Function()? newAttemptId,
  }) : _pattern = initialPattern,
       catalog = catalog ?? [initialPattern],
       _now = clock ?? DateTime.now,
       _newAttemptId = newAttemptId ?? _randomAttemptId;

  static String _randomAttemptId() =>
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  /// Optional local history; a finished attempt is recorded exactly once.
  final ResultHistoryRepository? history;
  final DateTime Function() _now;
  final String Function() _newAttemptId;
  String? _attemptId;

  /// Ordered patterns the next-step rule may recommend.
  final List<RhythmPattern> catalog;

  /// Null until a record was attempted for the current outcome.
  RecordOutcome? recordOutcome;
  bool historyFailed = false;

  /// One concrete next action computed from local history after a record.
  NextStep? nextStep;

  /// Retention check: one listen only, flagged in the stored result.
  bool retentionCheck = false;

  final ReferenceClipPlayer player;

  /// Onsets (ms) → encoded WAV; injected so application stays codec-free.
  final List<int> Function(List<int> onsetsMs) renderReference;
  final Duration idleTimeout;
  RhythmPattern _pattern;
  RhythmPattern get pattern => _pattern;

  RhythmImitationPhase phase = RhythmImitationPhase.idle;
  RhythmImitationOutcome? outcome;
  RhythmGuidedSegment? guidedSegment;
  bool get isGuided => guidedSegment != null;
  RhythmGuidedSegment? get suggestedGuidedSegment {
    final result = outcome;
    if (result == null) return null;
    return RhythmGuidedSegment.fromOutcome(
      outcome: result,
      protocol: _pattern.exercise.protocol,
    );
  }

  int referencePlays = 0;
  int tapsDuringReference = 0;
  bool playbackFailed = false;
  final List<Duration> _taps = [];
  int get tapCount => _taps.length;
  Timer? _idle;
  Completer<void>? _wake;
  int _epoch = 0;

  bool get _closed => phase == RhythmImitationPhase.closed;
  int get maxReferencePlays =>
      retentionCheck ? 1 : _pattern.exercise.protocol.maxReferencePlays;

  /// Replays are allowed only before the answer starts, within the quota.
  bool get canListen =>
      referencePlays < maxReferencePlays &&
      (phase == RhythmImitationPhase.idle ||
          phase == RhythmImitationPhase.awaitingTaps ||
          phase == RhythmImitationPhase.finished);
  bool get acceptsTaps =>
      phase == RhythmImitationPhase.awaitingTaps ||
      phase == RhythmImitationPhase.tapping;

  void _set(RhythmImitationPhase next) {
    if (_closed) return;
    phase = next;
    notifyListeners();
  }

  void _resetAttempt({bool clearGuided = false}) {
    _idle?.cancel();
    _attemptId = null;
    recordOutcome = null;
    historyFailed = false;
    nextStep = null;
    _taps.clear();
    outcome = null;
    referencePlays = 0;
    tapsDuringReference = 0;
    playbackFailed = false;
    if (clearGuided) guidedSegment = null;
  }

  /// Starts an unscored excerpt around the first measured timing error.
  void startGuidedSegment() {
    if (phase != RhythmImitationPhase.finished || isGuided) return;
    final segment = suggestedGuidedSegment;
    if (segment == null) return;
    ++_epoch;
    _resetAttempt();
    guidedSegment = segment;
    retentionCheck = false;
    _set(RhythmImitationPhase.idle);
  }

  /// Leaves the excerpt without turning it into a scored attempt.
  void exitGuidedSegment() {
    if (!isGuided) return;
    ++_epoch;
    _resetAttempt(clearGuided: true);
    retentionCheck = false;
    _set(RhythmImitationPhase.idle);
  }

  /// From a finished result: a fresh attempt on the same pattern (or the
  /// same excerpt), with a fresh listen quota.
  Future<void> retry() async {
    if (phase != RhythmImitationPhase.finished) return;
    ++_epoch;
    _resetAttempt();
    retentionCheck = false;
    _set(RhythmImitationPhase.idle);
    await listen();
  }

  /// Starts the recommended action as a fresh attempt on its pattern.
  void applyNextStep() {
    final step = nextStep;
    if (step == null || step.pattern == null) return;
    selectPattern(step.pattern!);
    retentionCheck = step.kind == NextStepKind.delayedCheck;
    notifyListeners();
  }

  /// The next pattern in catalog (easy→hard) order, or null at the end.
  RhythmPattern? get followingPattern {
    final i = catalog.indexOf(_pattern);
    return i < 0 || i + 1 >= catalog.length ? null : catalog[i + 1];
  }

  /// Moves on to [followingPattern] as a fresh attempt. Navigation only:
  /// it records nothing and does not count as mastery.
  void advancePattern() {
    final next = followingPattern;
    if (next != null) selectPattern(next);
  }

  /// Allowed before the first tap; switching resets the attempt evidence.
  void selectPattern(RhythmPattern next) {
    if (phase != RhythmImitationPhase.idle &&
        phase != RhythmImitationPhase.awaitingTaps &&
        phase != RhythmImitationPhase.finished) {
      return;
    }
    ++_epoch;
    _pattern = next;
    retentionCheck = false;
    _resetAttempt(clearGuided: true);
    _set(RhythmImitationPhase.idle);
  }

  List<int> get _referenceMs {
    final segment = guidedSegment;
    if (segment != null) return segment.onsetsMs;
    final onsets = RhythmReferenceClock.onsetsMs(_pattern.exercise.protocol);
    if (onsets == null) throw ArgumentError('Invalid rhythm reference clock');
    return onsets;
  }

  Future<void> listen() async {
    if (!canListen) return;
    if (phase == RhythmImitationPhase.finished) {
      _resetAttempt();
      retentionCheck = false;
    }
    final epoch = ++_epoch;
    _attemptId ??= _newAttemptId();
    referencePlays++;
    playbackFailed = false;
    _set(RhythmImitationPhase.listening);
    try {
      final handle = await player.playWav(renderReference(_referenceMs));
      if (epoch != _epoch || _closed) return;
      final wake = _wake = Completer<void>();
      await Future.any([handle.completed, wake.future]);
    } catch (_) {
      if (epoch != _epoch || _closed) return;
      playbackFailed = true;
      _set(RhythmImitationPhase.idle);
      return;
    }
    if (epoch != _epoch || _closed) return;
    _set(RhythmImitationPhase.awaitingTaps);
  }

  /// [timestamp] must be the pointer event's monotonic time stamp.
  void registerTap(Duration timestamp) {
    if (phase == RhythmImitationPhase.listening) {
      tapsDuringReference++;
      notifyListeners();
      return;
    }
    if (!acceptsTaps || _taps.length >= RhythmImitationEvaluator.maxTaps) {
      return;
    }
    if (_taps.isNotEmpty && timestamp < _taps.last) return;
    _taps.add(timestamp);
    if (phase == RhythmImitationPhase.awaitingTaps) {
      _set(RhythmImitationPhase.tapping);
    } else {
      notifyListeners();
    }
    _idle?.cancel();
    _idle = Timer(finishWait, () => unawaited(finish()));
  }

  /// Silence that ends the answer. Once every expected beat has a tap, the
  /// student need not wait the full [idleTimeout]: the answer ends after the
  /// pattern's longest gap plus the unchanged match window (at least
  /// [minFinishWait]). A later tap could only have been an extra beat.
  Duration get finishWait {
    final reference = _referenceMs;
    if (_taps.length < reference.length) return idleTimeout;
    var gap = 0;
    for (var i = 1; i < reference.length; i++) {
      gap = max(gap, reference[i] - reference[i - 1]);
    }
    final wait = Duration(
      milliseconds: max(
        minFinishWait.inMilliseconds,
        gap + RhythmImitationOutcome.matchToleranceMs,
      ),
    );
    return wait < idleTimeout ? wait : idleTimeout;
  }

  static const minFinishWait = Duration(milliseconds: 600);

  /// Number of beats the current reference (pattern or excerpt) has.
  int get expectedTaps => _referenceMs.length;

  /// The current reference onsets (pattern or excerpt), ms from 0. For
  /// drawing the beat track only.
  List<int> get referenceOnsetsMs => List.unmodifiable(_referenceMs);

  /// Taps of the attempt so far, ms after the first tap (so the first tap
  /// sits on the first beat). For live feedback only: the scored values are
  /// the outcome's.
  List<int> get liveTapsMs => [
    for (final t in _taps) (t - _taps.first).inMicroseconds ~/ 1000,
  ];

  Future<void> finish() async {
    if (phase != RhythmImitationPhase.tapping &&
        phase != RhythmImitationPhase.awaitingTaps) {
      return;
    }
    _idle?.cancel();
    final epoch = ++_epoch;
    _set(RhythmImitationPhase.evaluating);
    final taps = List<Duration>.unmodifiable(_taps);
    final segment = guidedSegment;
    final result = segment == null
        ? await RhythmImitationEvaluator.evaluate(
            protocol: _pattern.exercise.protocol,
            tapTimestamps: taps,
            referencePlays: referencePlays,
          )
        : await RhythmImitationEvaluator.evaluateGuided(
            referenceOnsetsMs: segment.onsetsMs,
            tapTimestamps: taps,
            referencePlays: referencePlays,
            maxReferencePlays: maxReferencePlays,
          );
    if (epoch != _epoch || _closed) return;
    outcome = result;
    _set(RhythmImitationPhase.finished);
    if (!isGuided) await _record(epoch, result);
  }

  Future<void> _record(int epoch, RhythmImitationOutcome result) async {
    final store = history;
    final id = _attemptId;
    if (store == null || id == null) return;
    try {
      final saved = await store.record(
        ResultHistoryEntry(
          attemptId: id,
          result: result.toResult(
            exercise: _pattern.exercise,
            sessionId: id,
            createdAt: _now().toUtc(),
            retentionCheck: retentionCheck,
          ),
        ),
      );
      if (epoch != _epoch || _closed) return;
      recordOutcome = saved;
      final entries = await store.load();
      if (epoch != _epoch || _closed) return;
      nextStep = RhythmNextStepPolicy.recommend(
        results: [for (final e in entries) e.result],
        patterns: catalog,
        now: _now(),
        current: _pattern,
      );
    } catch (_) {
      if (epoch != _epoch || _closed) return;
      historyFailed = recordOutcome == null;
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    if (_closed) return;
    ++_epoch;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    _resetAttempt(clearGuided: true);
    _set(RhythmImitationPhase.idle);
    try {
      await player.stop();
    } catch (_) {
      // Nothing else is held; the next play call stops/reloads again.
    }
  }

  Future<void> close() async {
    if (_closed) return;
    ++_epoch;
    _idle?.cancel();
    final wake = _wake;
    if (wake != null && !wake.isCompleted) wake.complete();
    phase = RhythmImitationPhase.closed;
    await player.close();
  }

  @override
  void dispose() {
    unawaited(
      close().catchError((Object _) {
        debugPrint('Rhythm clip cleanup failed.');
      }),
    );
    super.dispose();
  }
}
