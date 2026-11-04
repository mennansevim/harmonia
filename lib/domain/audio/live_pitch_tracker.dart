import 'dart:typed_data';

import 'yin_pitch_frame_analyzer.dart';

/// Display-only live pitch from microphone chunks: averaged down to 16 kHz,
/// one experimental YIN frame every 20 ms over the last 64 ms. It draws the
/// singer's trace while a take runs; it never decides a take. Judgements stay
/// on the whole-recording analysis.
class LivePitchTracker {
  LivePitchTracker({required this.onPitch});

  /// Called once per hop with Hz, or null for silence/unpitched frames.
  final void Function(double? hz) onPitch;

  static const rateHz = 16000, frameSamples = 1024, hopSamples = 320;
  final _analyzer = YinPitchFrameAnalyzer(
    minFrequencyHz: 60,
    maxFrequencyHz: 1100,
  );
  final _ring = Float64List(frameSamples);
  final _frame = Float64List(frameSamples);
  double _sum = 0;
  int _count = 0, _sinceHop = 0, _head = 0, _filled = 0;

  void reset() {
    _head = 0;
    _filled = 0;
    _sum = 0;
    _count = 0;
    _sinceHop = 0;
  }

  /// [samples] in −1…1 at [sampleRateHz] (a whole multiple of 16 kHz is
  /// averaged exactly; other rates use the nearest whole factor).
  void add(List<double> samples, int sampleRateHz) {
    final factor = (sampleRateHz / rateHz).round().clamp(1, 6);
    for (final s in samples) {
      _sum += s;
      if (++_count < factor) continue;
      _ring[_head] = _sum / factor;
      _head = (_head + 1) % frameSamples;
      if (_filled < frameSamples) _filled++;
      _sum = 0;
      _count = 0;
      if (++_sinceHop >= hopSamples && _filled == frameSamples) {
        _sinceHop = 0;
        for (var i = 0; i < frameSamples; i++) {
          _frame[i] = _ring[(_head + i) % frameSamples];
        }
        final estimate = _analyzer.analyze(_frame, sampleRateHz: rateHz);
        onPitch(
          estimate.status == PitchFrameStatus.pitched
              ? estimate.frequencyHz
              : null,
        );
      }
    }
  }
}
