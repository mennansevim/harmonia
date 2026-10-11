import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/features/audio_lab/audio_lab_screen.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

List<double> _clip(double seconds, double Function(int) f) =>
    List.generate((seconds * 16000).round(), f);

void main() {
  testWidgets('calibration then quality report fit narrow enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var state = 3;
    final backend = FakeRoutedAudioLabBackend()
      ..nextClip(
        _clip(2, (_) {
          state = (state * 1103515245 + 12345) & 0x7fffffff;
          return 0.0017 * (state / 0x7fffffff * 2 - 1);
        }),
      );
    await tester.pumpWidget(
      MaterialApp(
        home: AudioLabScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    expect(find.textContaining('Ortam ölçümü yok'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('audio_lab_calibrate')));
    await tester.tap(find.byKey(const Key('audio_lab_calibrate')));
    await tester.pump();
    expect(find.textContaining('2 saniye sessiz kal'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ortam ölçüldü'), findsOneWidget);

    backend.nextClip(
      _clip(1.5, (i) => 0.2 * math.sin(2 * math.pi * 261.63 * i / 16000)),
    );
    for (final key in [
      'audio_lab_record',
      'audio_lab_stop',
      'audio_lab_analyze',
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Kayıt kalitesi: analiz için yeterli görünüyor.'),
      findsOneWidget,
    );
    expect(find.textContaining('insan sesi tespiti değildir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
