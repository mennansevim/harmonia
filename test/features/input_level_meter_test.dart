import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/features/common/input_level_meter.dart';
import 'package:harmonia/features/single_tone_session/single_tone_session_screen.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

void main() {
  testWidgets('meter labels levels and never claims pitch', (tester) async {
    final levels = StreamController<double>.broadcast(sync: true);
    addTearDown(levels.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InputLevelMeter(levels: levels.stream)),
      ),
    );
    expect(find.text('Giriş seviyesi: bekleniyor'), findsOneWidget);
    for (final (db, label) in [
      (-20.0, 'uygun'),
      (-1.0, 'çok yüksek — telefondan uzaklaş'),
      (-70.0, 'çok düşük'),
    ]) {
      levels.add(db);
      await tester.pump();
      expect(find.text('Giriş seviyesi: $label'), findsOneWidget);
    }
    expect(find.textContaining('doğru olduğunu göstermez'), findsOneWidget);
  });

  testWidgets('session shows the meter only while the mic is open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeRoutedAudioLabBackend()
      ..nextClip(List.filled(32000, 0.0005));
    await tester.pumpWidget(
      MaterialApp(
        home: SingleToneSessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    expect(find.byKey(const Key('input_level_meter')), findsNothing);
    await tester.tap(find.byKey(const Key('session_calibrate')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('input_level_meter')), findsOneWidget);
    backend.levels.add(-30);
    await tester.pump();
    expect(find.text('Giriş seviyesi: uygun'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('input_level_meter')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
