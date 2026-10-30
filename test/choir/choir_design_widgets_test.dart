import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/app/choir_scope.dart';
import 'package:resonia/trainer/ui/kit.dart';

Widget _page(Widget child, {double width = 320}) => MaterialApp(
  theme: trainerTheme(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

void main() {
  testWidgets('five part choices wrap on a narrow phone, nothing scrolls', (
    tester,
  ) async {
    var tapped = '';
    await tester.pumpWidget(
      _page(
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final name in const [
              'Tüm koro',
              'Soprano',
              'Alto',
              'Tenor',
              'Bas',
            ])
              OptionChip(
                label: name,
                selected: name == 'Alto',
                onTap: () => tapped = name,
              ),
          ],
        ),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Bas'));
    expect(tapped, 'Bas');
    expect(find.byIcon(Ic.check), findsOneWidget);
  });

  testWidgets('a chip says it is selected to assistive technology', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _page(OptionChip(label: 'Alto', selected: true, onTap: () {})),
    );
    expect(
      tester.getSemantics(find.byType(OptionChip)),
      matchesSemantics(
        label: 'Alto',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    handle.dispose();
  });

  testWidgets(
    'the wave shows one marker per noted moment and no invented one',
    (tester) async {
      Finder markers() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      final peaks = List.filled(ChoirWave.barCount, 0.3);
      await tester.pumpWidget(_page(ChoirWave(peaks: peaks)));
      expect(markers(), findsNothing);
      await tester.pumpWidget(
        _page(ChoirWave(peaks: peaks, marks: const [0.25, 0.75])),
      );
      expect(markers(), findsNWidgets(2));
      final left = tester.getCenter(markers().first).dx;
      final right = tester.getCenter(markers().last).dx;
      expect(left, lessThan(right));
    },
  );
}
