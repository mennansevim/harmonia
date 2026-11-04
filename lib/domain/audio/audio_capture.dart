import '../models/measurement_provenance.dart';
import 'capture_quality.dart';

enum AudioLabInterruption { routeChanged, audioFocusLost }

class CapturedAudio {
  CapturedAudio({required this.sampleRateHz, required this.sampleCount}) {
    if (sampleRateHz < 8000 ||
        sampleRateHz > 192000 ||
        sampleCount < 0 ||
        sampleCount > sampleRateHz * 120) {
      throw ArgumentError('Invalid captured metadata');
    }
  }
  final int sampleRateHz, sampleCount;
  double get durationSeconds => sampleCount / sampleRateHz;
}

class PlaybackHandle {
  const PlaybackHandle(this.completed);
  final Future<void> completed;
}

abstract interface class AudioCapture {
  Future<bool> requestMicrophonePermission();
  Future<void> startCapture();
  Future<CapturedAudio> stopCapture();
  Future<void> discardCapture();
}

abstract interface class ReferencePlayback {
  Future<PlaybackHandle> playReference();
  Future<PlaybackHandle> playRecording();
  Future<void> stopPlayback();
}

abstract interface class AudioLabBackend
    implements AudioCapture, ReferencePlayback {
  Stream<AudioLabInterruption> get interruptions;
  Future<void> close();
}

/// Immutable local snapshot. Origin does not certify voice or accuracy.
class CapturedAudioSamples {
  CapturedAudioSamples({
    required this.sampleRateHz,
    required List<double> samples,
    required this.source,
  }) : samples = List.unmodifiable(samples);
  final int sampleRateHz;
  final List<double> samples;
  final MeasurementSource source;
}

/// Optional capability: reads only the backend's current owned recording.
abstract interface class AudioRecordingReader {
  Future<CapturedAudioSamples> readRecording();
}

/// Optional capability: current audio route. Implementations must report
/// `RouteCertainty.inferred` when the platform only lists available devices.
abstract interface class AudioRouteProbe {
  Future<AudioRouteSnapshot> currentRoute();
}

/// Plays a generated/bundled reference clip (e.g. rhythm clicks). Encoded
/// WAV bytes stay local; implementations own and delete their temp files.
abstract interface class ReferenceClipPlayer {
  Future<PlaybackHandle> playWav(List<int> wavBytes);
  Future<void> stop();
  Future<void> close();
}

/// Optional: live input level (dBFS, ≤ 0) while capturing. Display only:
/// never scored, never a voice/pitch claim, not calibrated across devices.
/// Raw mono samples (−1…1) while a capture runs, for display-only live
/// views. Nothing here is measured or retained beyond the capture.
abstract interface class LiveSampleSource {
  Stream<List<double>> get liveSamples;
  int get liveSampleRateHz;
}

abstract interface class InputLevelSource {
  Stream<double> get inputLevelDb;

  /// Origin of the level stream. This labels UI evidence only; it does not
  /// certify calibration, pitch, voice activity or analyzer accuracy.
  MeasurementProvenance get inputLevelProvenance;
}
