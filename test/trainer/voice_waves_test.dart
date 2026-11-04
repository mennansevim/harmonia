import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/koro/range_ladder.dart';
import 'package:resonia/trainer/koro/voice_waves.dart';
import 'package:resonia/trainer/ui/kit.dart';

void main() {
  group('1€ filter', () {
    test('a held note stops trembling', () {
      final f = OneEuroFilter();
      final rnd = math.Random(3);
      var maxDev = 0.0;
      for (var i = 0; i < 300; i++) {
        final y = f.filter(20 + (rnd.nextDouble() - 0.5) * 12, 1 / 60);
        if (i > 120) maxDev = math.max(maxDev, (y - 20).abs());
      }
      expect(maxDev, lessThan(3)); // raw jitter is ±6 cents
    });

    test('a slide is followed without long lag', () {
      final f = OneEuroFilter()..filter(-200, 1 / 60);
      double y = -200;
      for (var i = 0; i < 30; i++) {
        y = f.filter(0, 1 / 60); // half a second after a 2-semitone jump
      }
      expect(y.abs(), lessThan(15));
    });

    test('reset starts a new phrase from its first value', () {
      final f = OneEuroFilter()..filter(-300, 1 / 60);
      f.reset();
      expect(f.filter(40, 1 / 60), 40);
    });
  });

  group('fixed-rate history', () {
    test('samples at the same rate whatever the frame rate', () {
      final a = WaveTrack(), b = WaveTrack();
      const s = WaveSample(cents: 0, amp: 0.5, voiced: true);
      for (var i = 0; i < 60; i++) {
        a.add(1 / 60, s);
      }
      for (var i = 0; i < 24; i++) {
        b.add(1 / 24, s);
      }
      expect(a.length, closeTo(120, 1));
      expect(b.length, closeTo(120, 1));
    });

    test('interpolates between frames and keeps a bounded window', () {
      final t = WaveTrack(seconds: 1);
      t.add(0.5, const WaveSample(cents: 0, amp: 0, voiced: true));
      t.add(0.5, const WaveSample(cents: 100, amp: 1, voiced: true));
      expect(t.length, lessThanOrEqualTo(120));
      final mid = t.at(0.25)!;
      expect(mid.cents, inExclusiveRange(0, 100));
      expect(t.at(5), isNull);
    });
  });

  test('"on the note" follows the ladder pass rule', () {
    // A take this close is matched by the real judgement.
    final edge = judgeRangeTake(
      midiToHz(57) * math.pow(2, (voiceWavesOnNoteCents - 1) / 1200),
      57,
    );
    expect(edge.match, RangeMatch.matched);
    expect(waveLock(0), 1);
    expect(waveLock(voiceWavesOnNoteCents + 1), 0);
    expect(waveColor(0), TC.limeShadow);
    expect(waveColor(-150), isNot(waveColor(150)));
  });

  testWidgets('the waves draw, follow the voice and dispose cleanly', (
    tester,
  ) async {
    Widget host({
      double? midi,
      bool listening = false,
      bool reference = false,
    }) => MaterialApp(
      home: Scaffold(
        body: VoiceWaves(
          target: 57,
          notation: NoteNotation.letter,
          pitchMidi: midi,
          levelDb: -18,
          listening: listening,
          reference: reference,
        ),
      ),
    );
    await tester.pumpWidget(host(reference: true));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 40; i++) {
      await tester.pumpWidget(host(midi: 56.4 + i * 0.015, listening: true));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('voice_waves')), findsOneWidget);
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
