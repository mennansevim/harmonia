import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:harmonia/features/single_tone_exercise/single_tone_exercise_screen.dart';

Widget _demo() => MaterialApp(home: SingleToneExerciseScreen());

void main() {
  testWidgets('invalid feedback fits a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_demo());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('scenario_silence')));
    await tester.tap(find.byKey(const Key('scenario_silence')));
    await tester.pumpAndSettle();
    expect(find.text('Ölçüm Alınamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single-tone demo screen shows its C4 target', (tester) async {
    await tester.pumpWidget(_demo());
    await tester.pumpAndSettle();

    expect(find.text('Tek Ses: Do (C4)'), findsWidgets);
    expect(find.text('C4'), findsOneWidget);
  });

  testWidgets('picking the correct scenario shows success feedback', (
    tester,
  ) async {
    await tester.pumpWidget(_demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scenario_correct')));
    await tester.pump(); // start analyzing
    await tester.pumpAndSettle(); // simulated analyzer latency

    expect(find.text('Doğru!'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('picking a wrong-octave scenario shows the octave warning', (
    tester,
  ) async {
    await tester.pumpWidget(_demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scenario_wrongOctaveDown')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Yanlış Oktav'), findsOneWidget);
  });

  for (final scenario in ['silence', 'noisy']) {
    testWidgets('$scenario is an unscored measurement, not a zero grade', (
      tester,
    ) async {
      await tester.pumpWidget(_demo());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('scenario_$scenario')));
      await tester.pumpAndSettle();
      expect(find.text('Ölçüm Alınamadı'), findsOneWidget);
      expect(find.byKey(const Key('measurement_not_scored')), findsOneWidget);
      expect(find.text('Genel: 0'), findsNothing);
      expect(find.text('Doğru!'), findsNothing);
    });
  }
}
