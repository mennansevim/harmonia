import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/ui/audio_reactive_orb.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('amplitude smoothing', () {
    test('level maps to 0–1 and silence stays at rest', () {
      expect(orbAmplitude(-90), 0);
      expect(orbAmplitude(double.nan), 0);
      expect(orbAmplitude(0), 1);
      expect(orbAmplitude(-30), inExclusiveRange(0, 1));
      expect(orbAmplitude(-20), greaterThan(orbAmplitude(-30)));
    });

    test('the moving average is frame-rate independent', () {
      var at60 = 0.0, at120 = 0.0;
      for (var i = 0; i < 6; i++) {
        at60 = emaStep(at60, 1, 1 / 60);
      }
      for (var i = 0; i < 12; i++) {
        at120 = emaStep(at120, 1, 1 / 120);
      }
      expect(at60, closeTo(at120, 1e-9));
      expect(at60, inExclusiveRange(0, 1));
    });

    test('it rises fast and lets go slowly', () {
      final rose = emaStep(0, 1, 0.05);
      final fell = 1 - emaStep(1, 0, 0.05);
      expect(rose, greaterThan(fell));
    });
  });

  testWidgets('the orb animates, reacts and disposes cleanly', (tester) async {
    await tester.pumpWidget(
      _host(const AudioReactiveOrb(phase: OrbPhase.idle, size: 200)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AudioReactiveOrb), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);

    for (final db in [-60.0, -30.0, -12.0]) {
      await tester.pumpWidget(
        _host(AudioReactiveOrb(phase: OrbPhase.listening, levelDb: db)),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await tester.pumpWidget(
      _host(const AudioReactiveOrb(phase: OrbPhase.completed)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check), findsNothing); // Lucide tick, not Material

    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion stops the clock but still shows the level', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AudioReactiveOrb(phase: OrbPhase.listening, levelDb: -15),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a tappable orb is a labelled button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        AudioReactiveOrb(
          phase: OrbPhase.idle,
          onTap: () => taps++,
          semanticLabel: 'Sing',
        ),
        reduced: true,
      ),
    );
    await tester.tap(find.byType(AudioReactiveOrb));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Sing'), findsOneWidget);
  });
}
