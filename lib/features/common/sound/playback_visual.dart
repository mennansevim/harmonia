import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../domain/audio/audio_capture.dart';
import '../../../infrastructure/audio/pcm16_wav.dart';

/// The clip being played, reduced for drawing: per-column peaks of the real
/// samples plus the raw samples for the oscilloscope view. The view runs its
/// own frame clock from when the player accepted the clip (not the audio
/// device clock; output latency is not measured). Display only.
@immutable
class PlaybackVisual {
  const PlaybackVisual._({
    required this.samples,
    required this.sampleRateHz,
    required this.envelope,
  });

  /// Raw samples of the clip that was handed to the player.
  final Float32List samples;
  final int sampleRateHz;

  /// Peak |sample| per envelope bucket, 0..1 ([envelopeBuckets] values).
  final Float32List envelope;

  static const envelopeBuckets = 160;

  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRateHz);

  static PlaybackVisual? fromWav(List<int> wavBytes) {
    final Pcm16Wav wav;
    try {
      wav = Pcm16Wav.decode(Uint8List.fromList(wavBytes));
    } on FormatException {
      return null;
    }
    final samples = Float32List.fromList(wav.samples);
    final env = Float32List(envelopeBuckets);
    if (samples.isNotEmpty) {
      final per = math.max(1, samples.length ~/ envelopeBuckets);
      for (var b = 0; b < envelopeBuckets; b++) {
        var peak = 0.0;
        final end = math.min(samples.length, (b + 1) * per);
        for (var i = b * per; i < end; i++) {
          final v = samples[i].abs();
          if (v > peak) peak = v;
        }
        env[b] = peak;
      }
    }
    return PlaybackVisual._(
      samples: samples,
      sampleRateHz: wav.sampleRateHz,
      envelope: env,
    );
  }
}

/// Wraps a [ReferenceClipPlayer] and publishes what is playing so the UI can
/// draw the real waveform. Playback behaviour is unchanged.
class VisualizingClipPlayer implements ReferenceClipPlayer {
  VisualizingClipPlayer(this._inner);
  final ReferenceClipPlayer _inner;
  final ValueNotifier<PlaybackVisual?> current = ValueNotifier(null);
  int _token = 0;

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    final token = ++_token;
    final handle = await _inner.playWav(wavBytes);
    if (token == _token) current.value = PlaybackVisual.fromWav(wavBytes);
    handle.completed.then(
      (_) => _clear(token),
      onError: (Object _) => _clear(token),
    );
    return handle;
  }

  void _clear(int token) {
    if (token == _token) current.value = null;
  }

  @override
  Future<void> stop() {
    _clear(++_token);
    return _inner.stop();
  }

  @override
  Future<void> close() {
    _clear(++_token);
    return _inner.close();
  }
}
