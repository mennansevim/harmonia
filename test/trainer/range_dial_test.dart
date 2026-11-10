import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/ui/range_dial.dart';

void main() {
  test('dial span is C2–C6 and widens to whole octaves', () {
    const inside = RangeDial(low: 56, high: 75, notation: NoteNotation.letter);
    expect((inside.min, inside.max), (36, 84));
    const wide = RangeDial(low: 33, high: 86, notation: NoteNotation.letter);
    expect((wide.min, wide.max), (24, 96));
  });

  testWidgets('renders the centre content over the dial', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: RangeDial(
            low: 56,
            high: 75,
            notation: NoteNotation.letter,
            center: Text('G#3 – D#5'),
          ),
        ),
      ),
    );
    expect(find.text('G#3 – D#5'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
