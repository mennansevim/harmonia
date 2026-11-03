import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/features/single_tone_session/single_tone_session_screen.dart';
import 'package:resonia/features/common/ui/resonia_ui.dart';
import 'package:resonia/app/theme/resonia_theme.dart';

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
  testWidgets(
    'diagnostic shell exposes help without automatic capture or progress',
    (tester) async {
      final backend = FakeRoutedAudioLabBackend();
      await tester.pumpWidget(
        MaterialApp(
          home: SingleToneSessionScreen(
            backend: backend,
            worker: FakeRecordingPitchWorker(),
          ),
        ),
      );
      expect(find.byType(LessonScaffold), findsOneWidget);
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(find.text('Puansız'), findsOneWidget);
      expect(find.textContaining('Referans sentetik'), findsOneWidget);
      expect(find.textContaining('cihazdan gönderilmez'), findsNothing);
      await _tap(tester, 'session_help');
      await tester.pumpAndSettle();
      expect(find.textContaining('4 saniye'), findsOneWidget);
      expect(find.textContaining('cihazdan gönderilmez'), findsOneWidget);
      expect(backend.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'contextual controls keep finish and cancel available while recording',
    (tester) async {
      final backend = FakeRoutedAudioLabBackend()..nextClip(_noise(2));
      await tester.pumpWidget(
        MaterialApp(
          home: SingleToneSessionScreen(
            backend: backend,
            worker: FakeRecordingPitchWorker(),
          ),
        ),
      );
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('session_calibrate')))
            .tone,
        ChunkyTone.primary,
      );
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('session_start')))
            .tone,
        ChunkyTone.neutral,
      );
      await _tap(tester, 'session_calibrate');
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('session_start')))
            .tone,
        ChunkyTone.primary,
      );
      backend.nextClip(_answer());
      await _tap(tester, 'session_start');
      expect(find.byKey(const Key('session_start')), findsNothing);
      expect(find.byKey(const Key('session_finish')), findsNothing);
      backend.playbackEnd.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('session_finish')))
            .tone,
        ChunkyTone.record,
      );
      expect(find.byKey(const Key('session_cancel')), findsOneWidget);
      expect(
        find.byKey(const Key('live_visual_feedback_field')),
        findsOneWidget,
      );
      backend.levels.add(-24);
      await tester.pump();
      expect(find.text('Canlı giriş seviyesi'), findsOneWidget);
      expect(find.textContaining('Test kaynağı'), findsOneWidget);
      expect(find.textContaining('perde ölçülmüyor'), findsOneWidget);
      await _tap(tester, 'session_cancel');
      await tester.pumpAndSettle();
      expect(backend.capturing, isFalse);
      expect(find.byKey(const Key('session_start')), findsOneWidget);
      expect(find.byKey(const Key('live_visual_feedback_field')), findsNothing);
      expect(find.byType(LessonProgressBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dark reduced-motion large-text permission denial remains neutral',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final backend = FakeRoutedAudioLabBackend()..permission = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ResoniaTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: SingleToneSessionScreen(
            backend: backend,
            worker: FakeRecordingPitchWorker(),
          ),
        ),
      );
      await _tap(tester, 'session_help');
      await tester.pumpAndSettle();
      await _tap(tester, 'session_calibrate');
      await tester.pumpAndSettle();
      expect(find.text('Ölçüm alınamadı — puanlanmadı'), findsOneWidget);
      expect(find.textContaining('Telefon ayarlarından'), findsOneWidget);
      expect(find.byKey(const Key('microphone_open_settings')), findsOneWidget);
      expect(backend.calls, isNot(contains('start')));
      expect(backend.calls, isNot(contains('reference')));
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'lesson close during pending permission cannot start late capture',
    (tester) async {
      final backend = FakeRoutedAudioLabBackend()..permissionGate = Completer();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SingleToneSessionScreen(
                      backend: backend,
                      worker: FakeRecordingPitchWorker(),
                    ),
                  ),
                ),
                child: const Text('Tek ses aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tek ses aç'));
      await tester.pumpAndSettle();
      await _tap(tester, 'session_calibrate');
      await tester.tap(find.byKey(const Key('lesson_close')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        backend.permissionGate!.complete(true);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('Tek ses aç'), findsOneWidget);
      expect(backend.calls, contains('close'));
      expect(backend.calls, isNot(contains('start')));
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.byKey(const Key('pitch_feedback_field')), findsOneWidget);
    expect(
      find.textContaining('güven ve kararlılık ölçülmedi'),
      findsOneWidget,
    );
    expect(find.textContaining('Test kaynağı'), findsOneWidget);
    await _tap(tester, 'session_details');
    await tester.pumpAndSettle();
    expect(find.textContaining('Gözlenen temsilî frekans'), findsOneWidget);
    expect(find.textContaining('başarı kanıtı değildir'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
