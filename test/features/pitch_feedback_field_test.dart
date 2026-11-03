import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/domain/audio/visual_feedback_frame.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/features/common/pitch_feedback_field.dart';

void main() {
  testWidgets('reduced-motion diagnostic stays explicit and unscored', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final frame = VisualFeedbackFrame(
      sessionId: 'local-widget-1',
      phase: VisualFeedbackPhase.diagnostic,
      level01: 0.35,
      signedCents: -37,
      confidence01: null,
      stability01: null,
      completedNotes: 0,
      provenance: const MeasurementProvenance(
        source: MeasurementSource.mock,
        analyzerVersion: 'fake-test',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ResoniaTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: PitchFeedbackField(frame: frame)),
        ),
      ),
    );

    expect(find.text('Tanısal sapma: 37 sent pes'), findsOneWidget);
    expect(find.textContaining('Test kaynağı'), findsOneWidget);
    expect(find.textContaining('puan değildir'), findsOneWidget);
    expect(find.textContaining('doğru'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('responding frame shows energy without a tuning verdict', (
    tester,
  ) async {
    final frame = VisualFeedbackFrame(
      sessionId: 'live-local-1',
      phase: VisualFeedbackPhase.responding,
      level01: 0.7,
      completedNotes: 0,
      provenance: const MeasurementProvenance(
        source: MeasurementSource.microphone,
        analyzerVersion: 'level-only',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ResoniaTheme.light(),
        home: Scaffold(body: PitchFeedbackField(frame: frame)),
      ),
    );

    expect(find.text('Canlı giriş seviyesi'), findsOneWidget);
    expect(find.textContaining('perde ölçülmüyor'), findsOneWidget);
    expect(find.textContaining('kalibre değil'), findsOneWidget);
    expect(find.textContaining('merkeze yakın'), findsNothing);
    expect(find.textContaining('puan değildir'), findsOneWidget);
  });
}
