import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/features/single_tone_session/single_tone_session_screen.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

List<double> _noise(double seconds) {
  var state = 9;
  return List.generate((seconds * 16000).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return 0.0017 * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _answer() => [
  ..._noise(0.3),
  ...List.generate(
    19200,
    (i) => 0.2 * math.sin(2 * math.pi * 261.63 * i / 16000),
  ),
];

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), 150);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

void main() {
  testWidgets('uncalibrated attempt asks to measure the room, unscored', (
    tester,
  ) async {
    final backend = FakeRoutedAudioLabBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: SingleToneSessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _tap(tester, 'session_start');
    await tester.pumpAndSettle();
    expect(find.text('Ölçüm alınamadı — puanlanmadı'), findsOneWidget);
    expect(find.textContaining('Önce ortamı ölç'), findsOneWidget);
    expect(backend.calls, isNot(contains('reference')));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('full flow fits 320px at 1.8× and never shows a verdict', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final backend = FakeRoutedAudioLabBackend()..nextClip(_noise(2));
    await tester.pumpWidget(
      MaterialApp(
        home: SingleToneSessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _tap(tester, 'session_calibrate');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ortam ölçüldü'), findsOneWidget);

    backend.nextClip(_answer());
    await _tap(tester, 'session_start');
    await tester.pump();
    expect(find.text('Referansı dinle. Mikrofon kapalı.'), findsOneWidget);
    backend.playbackEnd.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Şimdi söyle. Mikrofon açık.'), findsOneWidget);
    await _tap(tester, 'session_finish');
    await tester.pumpAndSettle();
    expect(find.text('Kaydın analiz edildi'), findsOneWidget);
    expect(find.text('Doğru!'), findsNothing);
    await _tap(tester, 'session_details');
    await tester.pumpAndSettle();
    expect(find.textContaining('Gözlenen temsilî frekans'), findsOneWidget);
    expect(find.textContaining('başarı kanıtı değildir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
