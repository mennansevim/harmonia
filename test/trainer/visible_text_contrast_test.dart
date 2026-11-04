import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/tour_fonts.dart';
import '../support/visible_text_contrast.dart';

void main() {
  setUpAll(loadTourFonts);
  const faint = Color(0xFFE6E8EF);

  Widget page(List<Widget> children) => MaterialApp(
    theme: ThemeData(fontFamily: 'Manrope'),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(height: 120, child: ListView(children: children)),
          const Expanded(child: SizedBox()),
        ],
      ),
    ),
  );

  testWidgets('fully visible faint text still fails', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      page([
        const Text('Soluk metin', style: TextStyle(color: faint, fontSize: 20)),
      ]),
    );
    final e = await const VisibleTextContrastGuideline().evaluate(tester);
    expect(e.passed, isFalse);
    handle.dispose();
  });

  testWidgets('text cut by the viewport edge is skipped', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      page([
        const SizedBox(height: 90),
        const Text('Kesik metin', style: TextStyle(color: faint, fontSize: 40)),
      ]),
    );
    expect(
      (await textContrastGuideline.evaluate(tester)).passed,
      isFalse,
      reason: 'the stock guideline measures the cut line',
    );
    final e = await const VisibleTextContrastGuideline().evaluate(tester);
    expect(e.passed, isTrue);
    handle.dispose();
  });
}
