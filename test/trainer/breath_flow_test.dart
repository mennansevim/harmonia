import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/ui/breath_flow.dart';

void main() {
  const steps = <BreathStep>[
    (kind: BreathKind.inhale, seconds: 4),
    (kind: BreathKind.hold, seconds: 2),
    (kind: BreathKind.exhale, seconds: 6),
  ];

  group('breathAt', () {
    test('fills while breathing in, stays full on hold, empties out', () {
      expect(breathAt(steps, 0).fullness, 0);
      expect(breathAt(steps, 2).fullness, closeTo(0.5, 1e-9));
      expect(breathAt(steps, 3.999).fullness, closeTo(1, 1e-3));
      for (var t = 4.0; t < 6; t += 0.25) {
        final at = breathAt(steps, t);
        expect(at.index, 1, reason: '$t');
        expect(at.fullness, 1, reason: '$t');
      }
      expect(breathAt(steps, 9).fullness, closeTo(0.5, 1e-9));
      expect(breathAt(steps, 11.999).fullness, closeTo(0, 1e-3));
    });

    test('moves without jumps, and loops back to the start', () {
      var prev = breathAt(steps, 0).fullness;
      for (var t = 0.02; t < 24; t += 0.02) {
        final f = breathAt(steps, t).fullness;
        expect((f - prev).abs(), lessThan(0.02), reason: '$t');
        prev = f;
      }
      expect(breathAt(steps, 12).index, 0);
      expect(breathAt(steps, 12.5).progress, closeTo(0.125, 1e-9));
    });

    test('a hold after breathing out stays empty', () {
      const box = <BreathStep>[
        (kind: BreathKind.inhale, seconds: 4),
        (kind: BreathKind.exhale, seconds: 4),
        (kind: BreathKind.hold, seconds: 4),
      ];
      expect(breathAt(box, 10).fullness, 0);
    });
  });

  // One frame per pump: step through [seconds] at about 60 fps.
  Future<void> frames(WidgetTester tester, double seconds) async {
    for (var i = 0; i < seconds * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Widget host({
    int ms = 0,
    bool running = true,
    bool done = false,
    bool reduced = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: Center(
          child: BreathFlow(
            steps: steps,
            elapsedMs: ms,
            running: running,
            done: done,
            child: const Text('4'),
          ),
        ),
      ),
    ),
  );

  testWidgets('animates while running and shows its centre', (tester) async {
    await tester.pumpWidget(host());
    for (var ms = 100; ms <= 3000; ms += 100) {
      await tester.pumpWidget(host(ms: ms));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('breath_flow')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('paused, the rings glide to a stop and rest', (tester) async {
    await tester.pumpWidget(host(ms: 1500));
    await frames(tester, 1);
    await tester.pumpWidget(host(ms: 1500, running: false));
    await frames(tester, 4);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('done and reduced motion settle quickly', (tester) async {
    await tester.pumpWidget(host(ms: 60000, running: false, done: true));
    await frames(tester, 4);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(host(ms: 2000, running: false, reduced: true));
    await frames(tester, 4);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
