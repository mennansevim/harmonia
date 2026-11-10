import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/koro/echo_trace_layout.dart';

/// Builds a 20 ms trace from (MIDI or null, hops) runs.
List<(int, double?)> _trace(List<(double?, int)> runs) {
  final out = <(int, double?)>[];
  for (final (m, hops) in runs) {
    for (var i = 0; i < hops; i++) {
      out.add((out.length * 20, m));
    }
  }
  return out;
}

void main() {
  test('three quick notes are three segments', () {
    final t = _trace([(46, 10), (48, 10), (null, 4), (46, 10)]);
    final r = echoSegments(t);
    expect(r.segments.length, 3);
    expect(r.open, isTrue);
  });

  test('blips are not notes', () {
    final r = echoSegments(_trace([(46, 10), (null, 3), (60, 2), (null, 5)]));
    expect(r.segments.length, 1);
    expect(r.open, isFalse);
  });

  test('each sung note lands in its own slot, however fast', () {
    // The screenshot case: three notes sung in about 200 ms each.
    final t = _trace([(46, 10), (48, 10), (null, 4), (46, 10), (null, 5)]);
    final x = echoTraceX(t, notes: 3, width: 300, live: false);
    final segs = echoSegments(t).segments;
    for (var i = 0; i < 3; i++) {
      final mid = (segs[i].startMs + segs[i].endMs) ~/ 2;
      expect(x(mid) ~/ 100, i, reason: 'note $i in slot $i');
    }
  });

  test('a note still being held grows inside its slot while live', () {
    final t = _trace([(46, 15)]);
    final x = echoTraceX(t, notes: 3, width: 300, live: true);
    final end = x(t.last.$1 + 20);
    expect(end, greaterThan(8));
    expect(end, lessThan(100), reason: 'stays in the first slot');
  });

  test('extra notes fall back to a time scale so they stay visible', () {
    final t = _trace([
      (46, 8),
      (null, 4),
      (48, 8),
      (null, 4),
      (50, 8),
      (null, 4),
      (52, 8),
    ]);
    final x = echoTraceX(t, notes: 3, width: 300, live: false);
    expect(x(0), 0);
    expect(x(t.last.$1), closeTo(300, 0.01));
  });
}
