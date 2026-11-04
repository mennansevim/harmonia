import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/rhythm_imitation.dart';
import 'package:resonia/features/rhythm_imitation/transient_alignment.dart';

Future<RhythmImitationOutcome> _outcome(List<int> tapsMs) =>
    RhythmImitationEvaluator.evaluateGuided(
      referenceOnsetsMs: const [0, 500, 1000, 1500],
      tapTimestamps: [for (final ms in tapsMs) Duration(milliseconds: ms)],
    );

void main() {
  test('places every timeline entry on both lanes', () async {
    final o = await _outcome([2000, 2560, 3000, 3500]);
    expect(o.referenceOnsetsMs, [0, 500, 1000, 1500]);
    expect(o.userOnsetsMs, [0, 560, 1000, 1500], reason: 'first tap anchors');
    final data = TransientAlignmentData.fromOutcome(o)!;
    expect(data.links, hasLength(4));
    expect(data.links.first.verdict, BeatVerdict.anchor);
    expect(data.largest?.referenceIndex, 1);
    expect(data.largest?.offsetMs, 60);
    expect(data.largest?.verdict, BeatVerdict.late);
  });

  test('draws nothing for an unmeasured attempt', () async {
    final o = await _outcome([100]);
    expect(o.isMeasured, isFalse);
    expect(o.userOnsetsMs, isEmpty);
    expect(TransientAlignmentData.fromOutcome(o), isNull);
  });

  testWidgets('moves taps onto the beat and back', (tester) async {
    final data = TransientAlignmentData.fromOutcome(
      await _outcome([0, 560, 1000, 1500]),
    )!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TransientAlignmentView(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rhythm_alignment_largest')), findsOneWidget);
    expect(find.byIcon(Icons.straighten_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('rhythm_alignment_snap')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('rhythm_alignment_snap')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.straighten_rounded), findsOneWidget);
  });
}
