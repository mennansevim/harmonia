import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/trainer/ui/kit.dart';

// QA-DEF-001: inside a list item BigButton dissolved into its parent's
// semantics node, so VoiceOver could neither reach nor activate it.
void main() {
  Widget list(List<Widget> children) => MaterialApp(
    home: Scaffold(
      body: ListView(children: [Column(children: children)]),
    ),
  );

  testWidgets('BigButton in a list is its own node and activates', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      list([
        const Text('Başlık'),
        BigButton(
          key: const Key('cta'),
          label: 'Çalışmaya başla',
          onPressed: () => taps++,
        ),
      ]),
    );

    final node = tester.getSemantics(find.byKey(const Key('cta')));
    expect(node.label, 'Çalışmaya başla');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('Çalışmaya başla'));
    await tester.pump();
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('disabled and busy BigButton offer no tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      list([
        const BigButton(key: Key('off'), label: 'Kapalı', onPressed: null),
        BigButton(
          key: const Key('busy'),
          label: 'Bekliyor',
          busy: true,
          onPressed: () {},
        ),
      ]),
    );
    for (final key in ['off', 'busy']) {
      final data = tester.getSemantics(find.byKey(Key(key))).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse, reason: key);
    }
    handle.dispose();
  });

  testWidgets('text after a HeroCard is not read as part of it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      list([
        const HeroCard(key: Key('hero'), child: Text('Sesine alan aç.')),
        const Text('Dipnot'),
      ]),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('hero'))).label.trim(),
      'Sesine alan aç.',
    );
    handle.dispose();
  });

  testWidgets('AppCards in one list item stay separate elements', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      list([
        const AppCard(key: Key('a'), child: Text('Nefes')),
        const AppCard(key: Key('b'), child: Text('Başlarken')),
      ]),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('a'))).label.trim(),
      'Nefes',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('b'))).label.trim(),
      'Başlarken',
    );
    handle.dispose();
  });
}
