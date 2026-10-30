import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../domain/submission.dart';
import '../midi/part_renderer.dart';
import 'take_engine.dart';
import 'wav_io.dart';

enum TakePhase {
  idle,
  preparing,
  recording,
  mixing,
  review,
  interrupted,
  failed,
}

/// One recording attempt: prepare the accompaniment, sing, hear the result,
/// correct the alignment. Unscored; nothing here judges the singing.
class TakeController extends ChangeNotifier {
  TakeController({
    required this.capture,
    required this.workDirectory,
    required this.maxSeconds,
    this.render,
    Timer Function(Duration, void Function())? timer,
  }) : _timer = timer ?? Timer.new;

  final TakeCapture capture;
  final Directory workDirectory;
  final int maxSeconds;

  /// Null records with no accompaniment.
  final Future<RenderedPart> Function()? render;
  final Timer Function(Duration, void Function()) _timer;

  TakePhase phase = TakePhase.idle;
  TakeInterruption? interruption;

  /// Why the last attempt failed, for logs and tests; never shown as is.
  Object? failure;

  /// How the correction slider reads: ms the voice is moved earlier.
  int alignmentMs = 0;
  int? resultDurationMs;
  double levelDb = -60;

  static const alignmentRangeMs = 500;

  RenderedPart? _part;
  int _lagMs = 0;
  Timer? _limit;
  StreamSubscription<TakeInterruption>? _interruptions;
  StreamSubscription<double>? _levels;
  var _epoch = 0;

  bool get accompanied => render != null;
  String get _vocalPath => '${workDirectory.path}/vocal.wav';
  String get _accompanimentPath => '${workDirectory.path}/accompaniment.wav';
  String get resultPath => '${workDirectory.path}/take.wav';
  TakeKind get kind =>
      accompanied ? TakeKind.accompaniedMix : TakeKind.unaccompanied;

  /// Count-in the singer hears before the first note, for the UI.
  Duration get countIn {
    final part = _part;
    if (part == null) return Duration.zero;
    return Duration(
      microseconds:
          part.countInSamples *
          Duration.microsecondsPerSecond ~/
          part.sampleRateHz,
    );
  }

  void _set(TakePhase next) {
    phase = next;
    notifyListeners();
  }

  /// Renders first so singing starts on time, then opens the mic.
  Future<void> begin() async {
    if (phase != TakePhase.idle &&
        phase != TakePhase.review &&
        phase != TakePhase.interrupted &&
        phase != TakePhase.failed) {
      return;
    }
    final epoch = ++_epoch;
    interruption = null;
    alignmentMs = 0;
    resultDurationMs = null;
    _set(TakePhase.preparing);
    try {
      final make = render;
      if (make != null) {
        final part = _part ??= await make();
        if (epoch != _epoch) return;
        await File(
          _accompanimentPath,
        ).writeAsBytes(await _encodeOff(part), flush: true);
      }
      if (epoch != _epoch) return;
      _interruptions = capture.interruptions.listen(_onInterrupted);
      _levels = capture.levelsDb.listen((db) {
        levelDb = db;
        notifyListeners();
      });
      _lagMs = await capture.start(
        vocalPath: _vocalPath,
        accompanimentPath: make == null ? null : _accompanimentPath,
      );
      if (epoch != _epoch) return;
      final part = _part;
      final limit = part != null
          ? part.duration
          : Duration(seconds: maxSeconds);
      _limit = _timer(limit, finish);
      _set(TakePhase.recording);
    } catch (e) {
      if (epoch != _epoch) return;
      failure = e;
      await _stopWatching();
      _set(TakePhase.failed);
    }
  }

  Future<void> _stopWatching() async {
    _limit?.cancel();
    _limit = null;
    await _interruptions?.cancel();
    await _levels?.cancel();
    _interruptions = null;
    _levels = null;
  }

  Future<void> _onInterrupted(TakeInterruption reason) async {
    if (phase != TakePhase.recording) return;
    _epoch++;
    interruption = reason;
    await _stopWatching();
    await capture.cancel();
    _set(TakePhase.interrupted);
  }

  /// The singer stopped, or the piece ended.
  Future<void> finish() async {
    if (phase != TakePhase.recording) return;
    final epoch = ++_epoch;
    await _stopWatching();
    _set(TakePhase.mixing);
    try {
      await capture.stop();
      await _produce(epoch);
      if (epoch != _epoch) return;
      _set(TakePhase.review);
    } catch (e) {
      if (epoch != _epoch) return;
      failure = e;
      _set(TakePhase.failed);
    }
  }

  Future<void> _produce(int epoch) async {
    final vocalFile = File(_vocalPath);
    final part = _part;
    if (part == null) {
      final durationMs = await _durationOff(await vocalFile.readAsBytes());
      if (durationMs <= 0) throw const FormatException('Empty take');
      await vocalFile.copy(resultPath);
      resultDurationMs = durationMs;
      return;
    }
    final bytes = await vocalFile.readAsBytes();
    final out = await _mixOff(bytes, part, _lagMs - alignmentMs);
    if (epoch != _epoch) return;
    await File(resultPath).writeAsBytes(out, flush: true);
    resultDurationMs = (out.length - 44) ~/ 2 * 1000 ~/ part.sampleRateHz;
  }

  /// Moves the voice against the accompaniment and mixes again.
  Future<void> setAlignment(int ms) async {
    if (phase != TakePhase.review || _part == null) return;
    final epoch = ++_epoch;
    alignmentMs = ms.clamp(-alignmentRangeMs, alignmentRangeMs);
    _set(TakePhase.mixing);
    try {
      await _produce(epoch);
      if (epoch != _epoch) return;
      _set(TakePhase.review);
    } catch (e) {
      if (epoch != _epoch) return;
      failure = e;
      _set(TakePhase.failed);
    }
  }

  @override
  void dispose() {
    _epoch++;
    final recording = phase == TakePhase.recording;
    unawaited(_stopWatching());
    if (recording) unawaited(capture.cancel().catchError((Object _) {}));
    super.dispose();
  }
}

// Top level on purpose: a closure made inside the controller would drag it,
// listeners and all, into the isolate message.

Future<Uint8List> _encodeOff(RenderedPart part) =>
    Isolate.run(() => encodeWav(part.samples, part.sampleRateHz));

Future<int> _durationOff(Uint8List bytes) =>
    Isolate.run(() => readWav(bytes).durationMs);

Future<Uint8List> _mixOff(Uint8List vocal, RenderedPart part, int offsetMs) =>
    Isolate.run(() {
      final mixed = mixTake(
        vocal: readWav(vocal),
        accompaniment: part.samples,
        sampleRateHz: part.sampleRateHz,
        countInSamples: part.countInSamples,
        offsetMs: offsetMs,
      );
      if (mixed.isEmpty) throw const FormatException('Empty take');
      return encodeWav(mixed, part.sampleRateHz);
    });
