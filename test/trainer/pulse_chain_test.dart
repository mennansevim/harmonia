import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/koro/pulse_chain.dart';
import 'package:resonia/trainer/koro/range_ladder.dart';

RangeAttempt _a(int midi, RangeMatch match) => RangeAttempt(
  targetMidi: midi,
  direction: RangeDirection.up,
  attempt: 1,
  judgement: RangeJudgement(match),
);

void main() {
  test('a reached note stays reached; misses keep their kind', () {
    final marks = chainMarks([
      _a(50, RangeMatch.missed),
      _a(50, RangeMatch.matched),
      _a(51, RangeMatch.matched),
      _a(51, RangeMatch.missed),
      _a(52, RangeMatch.missed),
      _a(52, RangeMatch.octaveOff),
      _a(41, RangeMatch.unmeasured),
    ]);
    expect(marks[50], ChainMark.matched);
    expect(marks[51], ChainMark.matched);
    expect(marks[52], ChainMark.octave);
    expect(marks[41], ChainMark.missed);
    expect(marks.containsKey(45), isFalse);
  });

  testWidgets('the chain runs every phase and disposes cleanly', (
    tester,
  ) async {
    Widget host(ChainPhase phase, int attempts, {ChainMark? result}) =>
        MaterialApp(
          home: Scaffold(
            body: PulseChain(
              low: 38,
              high: 52,
              start: 45,
              marks: {
                for (var m = 45; m < 45 + attempts; m++) m: ChainMark.matched,
              },
              attempts: attempts,
              notation: NoteNotation.letter,
              target: 45 + attempts,
              phase: phase,
              result: result,
            ),
          ),
        );
    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(host(ChainPhase.piano, i));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(host(ChainPhase.listening, i));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(
        host(ChainPhase.feedback, i + 1, result: ChainMark.matched),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpWidget(host(ChainPhase.turn, 3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('pulse_chain')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
