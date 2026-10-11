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
