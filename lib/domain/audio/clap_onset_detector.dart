import 'dart:math' as math;

/// Finds hand-clap onsets in live microphone samples: a clap is a sudden
/// jump of short-window energy well above the running room level. 5 ms hops,
/// 90 ms refractory time (a clap's own tail and room echo are not new
/// claps). Draft thresholds, not benchmarked on human claps across devices.
class ClapOnsetDetector {
  ClapOnsetDetector({
    required this.onClap,
    this.minLevelDb = -42,
    this.aboveFloorDb = 16,
    this.riseDb = 9,
    this.refractoryMs = 90,
    this.warmUpMs = 150,
  });

  /// Onset time in ms since the first sample given after [reset].
  final void Function(int ms) onClap;
  final double minLevelDb, aboveFloorDb, riseDb;
  final int refractoryMs;

  /// The first [warmUpMs] only learn the room level: a microphone's own
  /// start-up click must not count as the first clap.
  final int warmUpMs;

  static const hopMs = 5;
  int _rate = 48000, _hop = 240, _inHop = 0, _samples = 0;
  double _energy = 0, _previousDb = -120, _floorDb = -70;
  int? _last;

  void reset() {
    _inHop = 0;
    _samples = 0;
    _energy = 0;
    _previousDb = -120;
    _floorDb = -70;
    _last = null;
  }

  void add(List<double> samples, int sampleRateHz) {
    if (sampleRateHz != _rate) {
      _rate = sampleRateHz;
      _hop = (sampleRateHz * hopMs / 1000).round();
    }
    for (final s in samples) {
      _energy += s * s;
      _samples++;
      if (++_inHop < _hop) continue;
      final db = 10 * math.log(_energy / _hop + 1e-12) / math.ln10;
      final ms = ((_samples - _hop) * 1000 / _rate).round();
      _inHop = 0;
      _energy = 0;
      final last = _last;
      final ready =
          ms >= warmUpMs && (last == null || ms - last >= refractoryMs);
      if (ready &&
          db >= minLevelDb &&
          db - _floorDb >= aboveFloorDb &&
          db - _previousDb >= riseDb) {
        _last = ms;
        onClap(ms);
      }
      // The room level follows quiet stretches quickly and loud ones slowly,
      // so a run of claps does not raise it.
      final rate = db < _floorDb || ms < warmUpMs ? 0.3 : 0.01;
      _floorDb += (db - _floorDb) * rate;
      _previousDb = db;
    }
  }
}
