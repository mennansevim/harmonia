import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/single_tone_session.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../audio/synth.dart';
import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';

/// Immutable reference for the optional "Söyle" step of a pitch lesson.
///
/// This identifies the generated reference but does not certify the learner's
/// voice, pitch accuracy, mastery or readiness. Instrument transposition only
/// changes the displayed note name; it must not silently move this sounding
/// target.
class TrainerPitchSingTarget {
  TrainerPitchSingTarget._({
    required this.nodeId,
    required this.itemId,
    required this.register,
    required this.midi,
    required this.timbre,
  }) : frequencyHz = midiToHz(midi),
       contentVersion = 'trainer-synth-v1:${timbre.name}';

  factory TrainerPitchSingTarget.forNode({
    required LessonNode node,
    required String itemId,
    required Register register,
    VoicePart? voice,
    Timbre timbre = Timbre.piano,
  }) {
    if (node.trainer != TrainerKind.pitch ||
        node.kind == NodeKind.intro ||
        !node.items.contains(itemId) ||
        !node.registers.contains(register)) {
      throw ArgumentError('Target must belong to this pitch lesson');
    }
    final pitchClass = int.tryParse(itemId);
    if (pitchClass == null || pitchClass < 0 || pitchClass > 11) {
      throw ArgumentError('Pitch item must be in the 0–11 range');
    }
    final soundingRegister = voice?.fit(register) ?? register;
    return TrainerPitchSingTarget._(
      nodeId: node.id,
      itemId: itemId,
      register: soundingRegister,
      midi: soundingRegister.rootC + pitchClass,
      timbre: timbre,
    );
  }

  final String nodeId;
  final String itemId;
  final Register register;
  final int midi;
  final double frequencyHz;
  final Timbre timbre;
  final String contentVersion;
}

/// Optional, unscored pitch-production diagnostic for a trainer lesson.
///
/// It deliberately exposes the existing SESSION-01 outcome instead of an
/// accuracy/pass model. Nothing here can complete a node, mutate TrainerStore,
/// write history or unlock content. BENCH/VAD and physical-device gates remain
/// mandatory before a product score can be introduced.
class TrainerPitchSingSession extends ChangeNotifier {
  TrainerPitchSingSession({
    required this.target,
    required AudioLabBackend capture,
    required ReferenceClipPlayer referencePlayer,
    required RecordingPitchWorker worker,
    TrainerSynth synth = const TrainerSynth(),
    Duration responseDelay = const Duration(milliseconds: 500),
    Duration responseWindow = const Duration(seconds: 4),
    Duration calibrationDuration = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _session = SingleToneSessionController(
         backend: _TrainerPitchBackend(
           capture: capture,
           player: referencePlayer,
           referenceBytes: synth
               .render(
                 SoundSpec([
                   ToneEvent(0, 1.3, [target.midi]),
                 ]),
                 target.timbre,
               )
               .encode(),
         ),
         worker: worker,
         targetHz: target.frequencyHz,
         responseDelay: responseDelay,
         responseWindow: responseWindow,
         calibrationDuration: calibrationDuration,
         clock: clock,
       ) {
    _session.addListener(_changed);
  }

  static const scoringEnabled = false;

  final TrainerPitchSingTarget target;
  final SingleToneSessionController _session;
  bool _closed = false;

  SingleToneSessionPhase get phase => _session.phase;
  NoiseFloorCalibration? get calibration => _session.calibration;
  SingleToneSessionOutcome? get diagnosticOutcome => _session.outcome;
  bool get canStart => !_closed && _session.canStart;
  bool get canFinishResponse => !_closed && _session.canFinishResponse;

  void _changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> calibrate() async {
    if (!_closed) await _session.calibrate();
  }

  Future<void> startAttempt() async {
    if (!_closed) await _session.startAttempt();
  }

  void finishResponse() {
    if (!_closed) _session.finishResponse();
  }

  Future<void> cancel() async {
    if (!_closed) await _session.cancel();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _session.removeListener(_changed);
    await _session.close();
  }

  @override
  void dispose() {
    unawaited(close());
    _session.dispose();
    super.dispose();
  }
}

/// Keeps generated reference playback separate from the microphone adapter.
/// Both resources are exclusively owned and are closed exactly once.
class _TrainerPitchBackend
    implements AudioLabBackend, AudioRecordingReader, AudioRouteProbe {
  _TrainerPitchBackend({
    required this.capture,
    required this.player,
    required List<int> referenceBytes,
  }) : _referenceBytes = List.unmodifiable(referenceBytes) {
    if (capture is! AudioRecordingReader) {
      throw ArgumentError('Capture backend must expose owned recording PCM');
    }
  }

  final AudioLabBackend capture;
  final ReferenceClipPlayer player;
  final List<int> _referenceBytes;
  Future<void>? _closing;

  void _ensureOpen() {
    if (_closing != null) throw StateError('Trainer pitch session closed');
  }

  @override
  Stream<AudioLabInterruption> get interruptions => capture.interruptions;

  @override
  Future<bool> requestMicrophonePermission() {
    _ensureOpen();
    return capture.requestMicrophonePermission();
  }

  @override
  Future<void> startCapture() {
    _ensureOpen();
    return capture.startCapture();
  }

  @override
  Future<CapturedAudio> stopCapture() {
    _ensureOpen();
    return capture.stopCapture();
  }

  @override
  Future<CapturedAudioSamples> readRecording() {
    _ensureOpen();
    return (capture as AudioRecordingReader).readRecording();
  }

  @override
  Future<void> discardCapture() => capture.discardCapture();

  @override
  Future<PlaybackHandle> playReference() {
    _ensureOpen();
    return player.playWav(_referenceBytes);
  }

  @override
  Future<PlaybackHandle> playRecording() {
    _ensureOpen();
    return capture.playRecording();
  }

  @override
  Future<AudioRouteSnapshot> currentRoute() {
    _ensureOpen();
    final probe = capture;
    return probe is AudioRouteProbe
        ? (probe as AudioRouteProbe).currentRoute()
        : Future.value(const AudioRouteSnapshot.unknown());
  }

  @override
  Future<void> stopPlayback() async {
    try {
      await player.stop();
    } finally {
      await capture.stopPlayback();
    }
  }

  @override
  Future<void> close() => _closing ??= _closeBoth();

  Future<void> _closeBoth() async {
    Object? failure;
    StackTrace? failureStack;
    try {
      await player.close();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
    try {
      await capture.close();
    } catch (error, stack) {
      failure ??= error;
      failureStack ??= stack;
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }
}
