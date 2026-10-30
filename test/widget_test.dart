import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/domain/audio/pitch_analyzer.dart';
import 'package:resonia/features/common/ui/resonia_ui.dart';
import 'package:resonia/features/single_tone_exercise/single_tone_exercise_screen.dart';
import 'package:resonia/infrastructure/audio/mock/mock_pitch_analyzer.dart';

class _Analyzer extends PitchAnalyzer {
  int calls = 0;
  Future<PitchAnalysisResult>? next;
  @override
  Future<PitchAnalysisResult> analyze(PitchAnalysisRequest request) {
    calls++;
    return next ??
        MockPitchAnalyzer(simulatedLatency: Duration.zero).analyze(request);
  }
}

Widget _demo() => MaterialApp(home: SingleToneExerciseScreen());

void main() {
  Future<void> choose(WidgetTester tester, String scenario) async {
    final finder = find.byKey(Key('scenario_$scenario'));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('simulation shell/help makes no automatic analysis or progress', (
    tester,
  ) async {
    final analyzer = _Analyzer();
    await tester.pumpWidget(
      MaterialApp(home: SingleToneExerciseScreen(pitchAnalyzer: analyzer)),
    );
    expect(find.byType(LessonScaffold), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    expect(find.text('Simülasyon'), findsOneWidget);
    expect(find.text('Mikrofon kapalı'), findsOneWidget);
    expect(find.textContaining('senin başarını ölçmez'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('demo_help')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu örnekler neyi gösterir?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('referans ses çalınmaz'), findsOneWidget);
    expect(analyzer.calls, 0);
  });

  testWidgets('single-flight clears stale success and failure retries safely', (
    tester,
  ) async {
    final analyzer = _Analyzer();
    await tester.pumpWidget(
      MaterialApp(home: SingleToneExerciseScreen(pitchAnalyzer: analyzer)),
    );
    await choose(tester, 'correct');
    expect(find.byKey(const Key('feedback_success')), findsOneWidget);
    final gate = Completer<PitchAnalysisResult>();
    analyzer.next = gate.future;
    final action = tester
        .widget<ChunkyButton>(find.byKey(const Key('scenario_correct')))
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(analyzer.calls, 2);
    expect(find.byKey(const Key('feedback_success')), findsNothing);
    expect(find.byKey(const Key('demo_pending')), findsOneWidget);
    for (final button in tester.widgetList<ChunkyButton>(
      find.byType(ChunkyButton),
    )) {
      expect(button.onPressed, isNull);
    }
    gate.completeError(StateError('secret/path'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo_error')), findsOneWidget);
    expect(find.textContaining('secret/path'), findsNothing);
    expect(find.textContaining('Genel:'), findsNothing);
    analyzer.next = null;
    await choose(tester, 'correct');
    expect(analyzer.calls, 3);
    expect(find.byKey(const Key('demo_error')), findsNothing);
    expect(find.text('Örnek puanlar • kişisel sonuç değildir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'close during pending demo consumes late error without UI update',
    (tester) async {
      final gate = Completer<PitchAnalysisResult>();
      final analyzer = _Analyzer()..next = gate.future;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SingleToneExerciseScreen(pitchAnalyzer: analyzer),
                  ),
                ),
                child: const Text('Örnekleri aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Örnekleri aç'));
      await tester.pumpAndSettle();
      await choose(tester, 'correct');
      await tester.tap(find.byKey(const Key('lesson_close')));
      await tester.pumpAndSettle();
      gate.completeError(StateError('late private failure'));
      await tester.pumpAndSettle();
      expect(find.text('Örnekleri aç'), findsOneWidget);
      expect(find.byKey(const Key('demo_error')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all mock outcomes fit dark reduced-motion 320px large text', (
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
    await tester.pumpWidget(
      MaterialApp(theme: ResoniaTheme.dark(), home: SingleToneExerciseScreen()),
    );
    for (final scenario in MockPitchScenario.values) {
      await choose(tester, scenario.name);
      expect(find.text('Simülasyon sonucu'), findsOneWidget);
      if (scenario == MockPitchScenario.silence ||
          scenario == MockPitchScenario.noisy) {
        final title = tester.widget<Text>(find.text('Ölçüm Alınamadı'));
        expect(title.style!.color, ResoniaResultColors.dark.notMeasured);
        expect(find.textContaining('Genel:'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'mock success octave and invalid cards meet a11y in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: dark ? ResoniaTheme.dark() : ResoniaTheme.light(),
            home: SingleToneExerciseScreen(),
          ),
        );
        for (final scenario in ['correct', 'wrongOctaveDown', 'silence']) {
          await choose(tester, scenario);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      }
      semantics.dispose();
    },
  );

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
      await choose(tester, scenario);
      expect(find.text('Ölçüm Alınamadı'), findsOneWidget);
      expect(find.byKey(const Key('measurement_not_scored')), findsOneWidget);
      expect(find.text('Genel: 0'), findsNothing);
      expect(find.text('Doğru!'), findsNothing);
    });
  }
}
