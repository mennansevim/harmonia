import 'dart:math' as math;

/// Where the live echo trace is drawn. Display only: the take is judged on
/// the whole recording, never on this layout.
///
/// Only note order and pitch are compared, so the trace is laid out by the
/// notes the singer actually produced: the k-th held note is drawn inside the
/// k-th reference slot, however fast or slow it was sung. Gaps between notes
/// are squeezed into the slot borders.

/// One held note in the trace, in ms of captured audio.
typedef EchoSegment = ({int startMs, int endMs});

/// Splits a 20 ms-hop trace (ms, MIDI or null) into held notes. Same rules as
/// the end detector: a note holds at least 100 ms; 60 ms of silence or 60 ms
/// more than 0.8 semitone away from the held pitch starts a new one.
/// [open] is true when the last note may still be growing.
({List<EchoSegment> segments, bool open}) echoSegments(
  List<(int, double?)> trace,
) {
  const hopMs = 20, minHops = 5, breakHops = 3, moveHops = 3;
  final segments = <EchoSegment>[];
  double? anchor;
  var start = 0, lastOn = 0, hops = 0, silent = 0, off = 0;
  var offStart = 0;
  double? offPitch;

  void close() {
    if (anchor != null && hops >= minHops) {
      segments.add((startMs: start, endMs: lastOn + hopMs));
    }
    anchor = null;
    hops = off = 0;
  }

  void begin(int t, double m) {
    anchor = m;
    start = lastOn = t;
    hops = 1;
    off = 0;
  }

  for (final (t, midi) in trace) {
    if (midi == null) {
      if (++silent >= breakHops) close();
      continue;
    }
    silent = 0;
    final a = anchor;
    if (a == null) {
      begin(t, midi);
    } else if ((midi - a).abs() > 0.8) {
      if (off == 0) {
        offStart = t;
        offPitch = midi;
      }
      if (++off >= moveHops) {
        final from = offStart, pitch = offPitch!;
        close();
        begin(from, pitch);
        lastOn = t;
        hops = moveHops;
      }
    } else {
      off = 0;
      hops++;
      lastOn = t;
      anchor = a + (midi - a) * 0.1;
    }
  }
  final open = anchor != null && hops >= minHops;
  if (open) segments.add((startMs: start, endMs: lastOn + hopMs));
  return (segments: segments, open: open);
}

/// Maps trace time to x on a graph [width] wide with [notes] equal slots.
/// While [live], a still-growing last note fills its slot at [noteMs] per
/// slot so the head moves forward as the singer holds it. When the trace
/// has more notes than the melody (extra notes), it falls back to a plain
/// time scale so the extras stay visible.
double Function(int ms) echoTraceX(
  List<(int, double?)> trace, {
  required int notes,
  required double width,
  required bool live,
  int noteMs = 600,
  int slotMs = 800,
}) {
  final voiced = [
    for (final p in trace)
      if (p.$2 != null) p.$1,
  ];
  if (voiced.isEmpty || notes <= 0) return (_) => 0;
  final (:segments, :open) = echoSegments(trace);
  if (segments.isEmpty || segments.length > notes) {
    final t0 = voiced.first, span = voiced.last - t0;
    final shown = live ? math.max(notes * slotMs, span) : math.max(1, span);
    return (t) => ((t - t0) / shown * width).clamp(0.0, width);
  }
  final slot = width / notes, pad = slot * 0.08, inner = slot - 2 * pad;
  final anchors = <(int, double)>[];
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    final left = slot * i + pad;
    final growing = live && open && i == segments.length - 1;
    final fill = growing ? math.min(1.0, (s.endMs - s.startMs) / noteMs) : 1.0;
    anchors
      ..add((s.startMs, left))
      ..add((math.max(s.endMs, s.startMs + 1), left + inner * fill));
  }
  return (t) {
    if (t <= anchors.first.$1) return anchors.first.$2;
    for (var i = 1; i < anchors.length; i++) {
      final (t1, x1) = anchors[i];
      if (t <= t1) {
        final (t0, x0) = anchors[i - 1];
        return t1 == t0 ? x1 : x0 + (x1 - x0) * (t - t0) / (t1 - t0);
      }
    }
    return anchors.last.$2;
  };
}
