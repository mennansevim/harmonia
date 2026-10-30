import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/features/common/ui/answer_comparison_card.dart';

Widget app({String? selected = 'mi', bool dark = false}) => MaterialApp(
  theme: dark ? ResoniaTheme.dark() : ResoniaTheme.light(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AnswerComparisonCard(
        questionNumber: 2,
        reference: 'Do bağlamı, ardından do → mi.',
        selected: selected,
        correct: 'mi',
      ),
    ),
  ),
);

void main() {
  for (final entry in <String?, String>{
    'mi': 'Doğru',
    'sol': 'Farklı seçim',
    null: 'Cevap yok',
  }.entries) {
    testWidgets('read-only comparison distinguishes ${entry.value}', (
      tester,
    ) async {
      await tester.pumpWidget(app(selected: entry.key));
      expect(find.text('Soru 2 · ${entry.value}'), findsOneWidget);
      expect(find.text('Do bağlamı, ardından do → mi.'), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('Do bağlamı, ardından do → mi.'), findsOneWidget);
      expect(find.text('mi'), findsNWidgets(entry.key == 'mi' ? 2 : 1));
      if (entry.key != null && entry.key != 'mi') {
        expect(find.text(entry.key!), findsOneWidget);
      }
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      await tester.tap(find.text('Soru 2 · ${entry.value}'));
      await tester.pumpAndSettle();
      expect(find.text('Do bağlamı, ardından do → mi.'), findsNothing);
    });
  }

  testWidgets('both themes fit 320px large text with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    for (final dark in [false, true]) {
      await tester.pumpWidget(app(selected: 'sol', dark: dark));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('sol')).dy,
        lessThan(tester.getTopLeft(find.text('mi')).dy),
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'wide layout compares answers side by side and labels semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(app(selected: 'sol'));
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('sol')).dy,
          tester.getTopLeft(find.text('mi')).dy,
        );
        expect(find.bySemanticsLabel('sol'), findsOneWidget);
        expect(find.bySemanticsLabel('mi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}
