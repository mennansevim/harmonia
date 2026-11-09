import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/koro/particle_flow.dart';
import 'package:resonia/trainer/koro/particle_flow_demo.dart';
import 'package:resonia/trainer/koro/voice_waves.dart';
import 'package:resonia/trainer/ui/kit.dart';

void main() {
  group('spike gate', () {
    test('a one-off jump is held back, a real change gets through', () {
      final g = PitchSpikeGate();
      expect(g.accept(-20), -20);
      expect(g.accept(-10), -10, reason: 'small moves pass at once');
      expect(g.accept(1190), -10, reason: 'a stray octave is ignored');
      expect(g.accept(-5), -5);
      expect(g.accept(300), -5);
      expect(g.accept(305), -5);
      expect(g.accept(298), 298, reason: 'confirmed by three estimates');
    });

    test('reset forgets the held pitch', () {
      final g = PitchSpikeGate()..accept(0);
      g.reset();
      expect(g.value, isNull);
      expect(g.accept(500), 500);
    });
  });

  test('purple off the note, soft green on it, blended between', () {
    expect(flowColor(0), TC.primaryFill);
    expect(flowColor(1), TC.teal);
    expect(flowColor(0.5), isNot(anyOf(TC.primaryFill, TC.teal)));
  });

  group('demo script', () {
    const s = ParticleFlowDemoScript();
    test('starts below A3, reaches it and holds it for three seconds', () {
      expect(s.at(0).midi, isNull);
      expect(s.at(ParticleFlowDemoScript.lead + 0.01).midi!, lessThan(55));
      const from = ParticleFlowDemoScript.lead + ParticleFlowDemoScript.rise;
      for (var t = from; t < ParticleFlowDemoScript.heldUntil; t += 0.05) {
        final cents = (s.at(t).midi! - 57) * 100;
        expect(cents.abs(), lessThan(voiceWavesOnNoteCents), reason: '$t');
      }
      expect(ParticleFlowDemoScript.hold, 3);
    });

    test('the success mark waits for the hold to finish', () {
      for (var t = 0.0; t < ParticleFlowDemoScript.heldUntil; t += 0.05) {
        expect(s.flash(t), 0, reason: '$t');
      }
      expect(s.flash(ParticleFlowDemoScript.heldUntil + 0.2), greaterThan(0));
      expect(s.at(ParticleFlowDemoScript.heldUntil + 0.1).midi, isNull);
    });
  });

  Widget host({
    double? midi,
    int? serial,
    bool listening = false,
    bool reference = false,
    double flash = 0,
    bool reduced = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(
        body: ParticleFlow(
          target: 57,
          notation: NoteNotation.letter,
          pitchMidi: midi,
          pitchSerial: serial,
          levelDb: -18,
          listening: listening,
          reference: reference,
          flash: flash,
        ),
      ),
    ),
  );

  testWidgets('the flow draws, follows the voice and rests when silent', (
    tester,
  ) async {
    await tester.pumpWidget(host(reference: true));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 60; i++) {
      await tester.pumpWidget(
        host(midi: 55.4 + i * 0.03, serial: i, listening: true),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('particle_flow')), findsOneWidget);
    await tester.pumpWidget(host(flash: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(host());
    // Every particle has faded; the ticker stops instead of idling.
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion still shows the plain marker', (tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pumpWidget(
        host(midi: 57, serial: i, listening: true, reduced: true),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('particle_flow')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the demo preview runs on its own data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ParticleFlowDemo())),
    );
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 70));
    }
    expect(find.byKey(const Key('particle_flow')), findsOneWidget);
    expect(find.textContaining('DEMO'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
