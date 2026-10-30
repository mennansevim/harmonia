import '../../domain/audio/capture_quality.dart';

/// Stops the take: nothing resumes on its own, the singer starts over.
enum TakeInterruption { routeChanged, focusLost }

/// Practice and review playback.
abstract interface class ChoirPlayer {
  Stream<Duration> get positions;
  Stream<bool> get playingChanges;
  Future<Duration?> open(String path, {bool loop = false});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration to);
  Future<void> setSpeed(double speed);
  Future<void> close();
}

/// Records the singer while the accompaniment plays on the same device. This
/// is what replaces the second phone.
abstract interface class TakeCapture {
  Stream<TakeInterruption> get interruptions;
  Stream<double> get levelsDb;
  Future<bool> requestPermission();
  Future<AudioRouteSnapshot> route();

  /// Starts capture to [vocalPath] and, when given, playback of
  /// [accompanimentPath]. Returns how much later playback started than
  /// capture, in ms: a software estimate, not a measured output latency.
  Future<int> start({required String vocalPath, String? accompanimentPath});
  Future<void> stop();
  Future<void> cancel();
  Future<void> close();
}

/// How a singer may record, given the audio route. On the speaker the MIDI
/// would leak into the microphone, so accompanied takes stay off there
/// (ARCHITECTURE `choir_practice`).
enum RouteAdvice {
  /// Wired or USB headphones: the intended case.
  ready,

  /// Bluetooth works but adds a delay the app has not measured; the singer
  /// will likely need the alignment slider.
  bluetoothDelay,

  /// Nothing reports headphones; the singer must confirm them.
  unknown,

  /// The built-in speaker is in use.
  speaker,
}

RouteAdvice adviseRoute(AudioRouteSnapshot route) => switch (route.output) {
  AudioRouteKind.wired || AudioRouteKind.usb => RouteAdvice.ready,
  AudioRouteKind.bluetooth ||
  AudioRouteKind.airPlay => RouteAdvice.bluetoothDelay,
  AudioRouteKind.builtIn => RouteAdvice.speaker,
  AudioRouteKind.unknown => RouteAdvice.unknown,
};
