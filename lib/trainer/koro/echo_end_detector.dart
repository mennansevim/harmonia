/// Decides when a sung answer is over, from the live display pitch (one
/// estimate per 20 ms hop, MIDI or null). It only ends the listening window
/// early; the take is still judged on the whole recording afterwards.
///
/// The answer ends after a stretch of silence that follows real singing:
/// a short pause once every expected note has been heard as its own
/// segment, a longer one otherwise (so a breath between notes does not cut
/// the take). Noise that never goes quiet falls back to the session's
/// fixed window.
class EchoEndDetector {
  EchoEndDetector({required this.expectedNotes});

  final int expectedNotes;

  // All counts are 20 ms hops.
  /// 200 ms of singing before anything can end the answer.
  static const minVoicedHops = 10;

  /// A note must hold 100 ms to count as heard.
  static const segmentHops = 5;

  /// 700 ms of silence once every expected note was heard.
  static const shortSilenceHops = 35;

  /// 1.5 s of silence otherwise.
  static const longSilenceHops = 75;

  /// 60 ms of silence splits two notes.
  static const breakHops = 3;

  /// 60 ms away from the held pitch starts a new note.
  static const moveHops = 3;

  int _voiced = 0, _silent = 0, _segments = 0;
  int _segmentLength = 0, _offAnchor = 0;
  double? _anchor;
  bool _done = false;

  int get segments => _segments + (_segmentLength >= segmentHops ? 1 : 0);
  bool get done => _done;

  void reset() {
    _voiced = _silent = _segments = _segmentLength = _offAnchor = 0;
    _anchor = null;
    _done = false;
  }

  /// Feeds one hop; returns true once, on the hop that ends the answer.
  bool add(double? midi) {
    if (_done) return false;
    if (midi == null) {
      _silent++;
      if (_silent >= breakHops) _closeSegment();
      if (_voiced < minVoicedHops) return false;
      final needed = segments >= expectedNotes
          ? shortSilenceHops
          : longSilenceHops;
      if (_silent >= needed) return _done = true;
      return false;
    }
    _voiced++;
    _silent = 0;
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = midi;
      _segmentLength = 1;
      return false;
    }
    if ((midi - anchor).abs() > 0.8) {
      if (++_offAnchor >= moveHops) {
        _closeSegment();
        _anchor = midi;
        _segmentLength = 1;
      }
      return false;
    }
    _offAnchor = 0;
    _segmentLength++;
    // Let the anchor follow slow drift inside one note.
    _anchor = anchor + (midi - anchor) * 0.1;
    return false;
  }

  void _closeSegment() {
    if (_segmentLength >= segmentHops) _segments++;
    _segmentLength = 0;
    _offAnchor = 0;
    _anchor = null;
  }
}
