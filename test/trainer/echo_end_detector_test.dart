import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/koro/echo_end_detector.dart';

/// Feeds [hops] copies of [midi]; returns the hop index that ended, or null.
int? _feed(EchoEndDetector d, double? midi, int hops) {
  for (var i = 0; i < hops; i++) {
    if (d.add(midi)) return i;
  }
  return null;
}

void main() {
  test('silence before any singing never ends the answer', () {
    final d = EchoEndDetector(expectedNotes: 3);
    expect(_feed(d, null, 300), isNull);
    expect(d.done, isFalse);
  });

  test('ends 700 ms after every expected note was heard', () {
    final d = EchoEndDetector(expectedNotes: 3);
    expect(_feed(d, 46, 20), isNull);
    expect(_feed(d, 48, 20), isNull);
    expect(_feed(d, 46, 20), isNull);
    expect(d.segments, 3);
    expect(_feed(d, null, 100), EchoEndDetector.shortSilenceHops - 1);
    expect(d.done, isTrue);
    expect(d.add(null), isFalse, reason: 'fires once');
  });

  test('a breath between notes does not cut the take', () {
    final d = EchoEndDetector(expectedNotes: 3);
    _feed(d, 46, 20);
    // 1 s pause after only one note: shorter than the long silence.
    expect(_feed(d, null, 50), isNull);
    expect(_feed(d, 48, 20), isNull);
    expect(d.segments, 2);
    expect(_feed(d, null, 100), EchoEndDetector.longSilenceHops - 1);
  });

  test('slides between notes without a gap still count as separate notes', () {
    final d = EchoEndDetector(expectedNotes: 3);
    _feed(d, 46, 15);
    _feed(d, 48, 15);
    _feed(d, 46, 15);
    expect(d.segments, 3);
  });

  test('a short blip is not singing', () {
    final d = EchoEndDetector(expectedNotes: 1);
    _feed(d, 60, 4);
    expect(_feed(d, null, 200), isNull);
  });
}
