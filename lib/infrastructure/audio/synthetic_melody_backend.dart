import '../../application/melody_session.dart';
import '../../application/melody_practice.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/capture_quality.dart';
import '../../domain/models/measurement_provenance.dart';
import 'just_audio_clip_player.dart';
import 'pcm16_wav.dart';
import 'plugin_audio_lab_backend.dart';

/// Dedicated rehearsal adapter. Supply a fresh player, never the capture
/// session's player; this adapter has no capture/permission dependency.
class SyntheticMelodyPracticePlayer implements DiagnosticMelodyPracticePlayer {
  SyntheticMelodyPracticePlayer(this._player);
  final ReferenceClipPlayer _player;
  Future<void>? _closing;

  @override
  Future<PlaybackHandle> play(DiagnosticMelodyPractice practice) {
    if (_closing != null) throw StateError('Rehearsal player closed');
    final bytes = List<int>.unmodifiable(
      renderDiagnosticMelodyPractice(practice).encode(),
    );
    return _player.playWav(bytes);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> close() => _closing ??= _player.close();
}

/// Local sine reference, explicitly not a piano recording or approved lesson.
/// Fixed 600 ms tones + 200 ms gaps, last gap 400 ms. No hidden transpose/mix.
Pcm16Wav renderDiagnosticMelody(
  DiagnosticMelodyReference reference, {
  int sampleRateHz = 48000,
}) {
  return renderDiagnosticMelodyPractice(
    DiagnosticMelodyPractice(
      reference: reference,
      startIndex: 0,
      endIndexExclusive: reference.frequenciesHz.length,
    ),
    sampleRateHz: sampleRateHz,
  );
}

/// Bounded local rehearsal WAV; caller must explicitly own playback/cancel.
/// No playback, file I/O, permission request or microphone use occurs here.
/// Original frequency/octave/order/tempo are preserved; no scoring or hints
/// are attributed to an assessment attempt by preparing this audio.
Pcm16Wav renderDiagnosticMelodyPractice(
  DiagnosticMelodyPractice practice, {
  int sampleRateHz = 48000,
}) {
  if (sampleRateHz < 8000 || sampleRateHz > 48000) {
    throw ArgumentError('Diagnostic melody supports 8–48 kHz');
  }
  final frequencies = practice.frequenciesHz;
  final samples = <double>[];
  for (var repeat = 0; repeat < practice.repetitions; repeat++) {
    for (var i = 0; i < frequencies.length; i++) {
      samples.addAll(
        Pcm16Wav.tone(
          frequencyHz: frequencies[i],
          sampleRateHz: sampleRateHz,
          durationSeconds: DiagnosticMelodyPractice.toneMs / 1000,
        ).samples,
      );
      final lastNote = i == frequencies.length - 1;
      final lastRepeat = repeat == practice.repetitions - 1;
      final gapMs = !lastNote
          ? DiagnosticMelodyPractice.noteGapMs
          : lastRepeat
          ? DiagnosticMelodyPractice.tailMs
          : DiagnosticMelodyPractice.repeatGapMs;
      samples.addAll(List.filled(sampleRateHz * gapMs ~/ 1000, 0.0));
    }
  }
  return Pcm16Wav(sampleRateHz: sampleRateHz, samples: samples);
}

/// Owns capture + clip player exclusively. Use via MelodySessionController,
/// whose native queue serializes resource calls and rejects stale callbacks.
/// Capture interruptions are forwarded; device focus/route QA is still open.
class SyntheticMelodyBackend
    implements MelodyReferenceBackend, AudioRecordingReader, AudioRouteProbe {
  SyntheticMelodyBackend({
    required this.reference,
    required AudioLabBackend capture,
    required this.player,
    int sampleRateHz = 48000,
  }) : _capture = capture,
       _bytes = List.unmodifiable(
         renderDiagnosticMelody(reference, sampleRateHz: sampleRateHz).encode(),
       ) {
    if (capture is! AudioRecordingReader) {
      throw ArgumentError('Capture backend must expose owned recording PCM');
    }
  }

  factory SyntheticMelodyBackend.mobile(DiagnosticMelodyReference reference) =>
      SyntheticMelodyBackend(
        reference: reference,
        capture: PluginAudioLabBackend(),
        player: JustAudioClipPlayer(),
      );

  @override
  final DiagnosticMelodyReference reference;
  static const referenceSource = MeasurementSource.synthetic;
  final AudioLabBackend _capture;
  final ReferenceClipPlayer player;
  final List<int> _bytes;
  Future<void>? _closing;

  void _ensureOpen() {
    if (_closing != null) throw StateError('Melody backend closed');
  }

  @override
  Stream<AudioLabInterruption> get interruptions => _capture.interruptions;
  @override
  Future<bool> requestMicrophonePermission() async {
    _ensureOpen();
    return _capture.requestMicrophonePermission();
  }

  @override
  Future<void> startCapture() async {
    _ensureOpen();
    await _capture.startCapture();
  }

  @override
  Future<CapturedAudio> stopCapture() async {
    _ensureOpen();
    return _capture.stopCapture();
  }

  @override
  Future<CapturedAudioSamples> readRecording() async {
    _ensureOpen();
    return (_capture as AudioRecordingReader).readRecording();
  }

  @override
  Future<void> discardCapture() => _capture.discardCapture();
  @override
  Future<PlaybackHandle> playReference() async {
    _ensureOpen();
    return player.playWav(_bytes);
  }

  @override
  Future<PlaybackHandle> playRecording() async {
    _ensureOpen();
    return _capture.playRecording();
  }

  @override
  Future<AudioRouteSnapshot> currentRoute() async {
    _ensureOpen();
    final probe = _capture;
    return probe is AudioRouteProbe
        ? (probe as AudioRouteProbe).currentRoute()
        : const AudioRouteSnapshot.unknown();
  }

  @override
  Future<void> stopPlayback() async {
    // One failure cannot skip stopping the other owned player.
    try {
      await player.stop();
    } finally {
      await _capture.stopPlayback();
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
      await _capture.close();
    } catch (error, stack) {
      failure ??= error;
      failureStack ??= stack;
    }
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }
}
