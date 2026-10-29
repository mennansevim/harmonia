import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/features/common/ui/harmonia_ui.dart';
import 'package:harmonia/features/audio_lab/audio_lab_screen.dart';
import 'package:harmonia/domain/audio/recording_pitch_analyzer.dart';
import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

void main() {
  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'diagnostic lesson and help never start audio or imply progress',
    (tester) async {
      final backend = FakeAudioLabBackend();
      await tester.pumpWidget(
        MaterialApp(
          home: AudioLabScreen(
            backend: backend,
            worker: FakeRecordingPitchWorker(),
          ),
        ),
      );
      expect(find.byType(LessonScaffold), findsOneWidget);
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(find.text('Puansız'), findsOneWidget);
      expect(
        find.textContaining('doğru/yanlış kararı veya başarı puanı verilmez'),
        findsOneWidget,
      );
      await tap(tester, 'audio_lab_help');
      expect(
        find.textContaining('Sunucuya veya AI’ye gönderilmez'),
        findsOneWidget,
      );
      expect(backend.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('recording controls and live meter follow capture and discard', (
    tester,
  ) async {
    final backend = FakeRoutedAudioLabBackend();
    addTearDown(backend.levels.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AudioLabScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    expect(find.byKey(const Key('input_level_meter')), findsNothing);
    await tap(tester, 'audio_lab_record');
    expect(find.byKey(const Key('audio_lab_record')), findsNothing);
    expect(find.byKey(const Key('audio_lab_reference')), findsNothing);
    expect(find.byKey(const Key('audio_lab_calibrate')), findsNothing);
    expect(find.byKey(const Key('input_level_meter')), findsOneWidget);
    backend.levels.add(-30);
    await tester.pump();
    expect(find.text('Giriş seviyesi: uygun'), findsOneWidget);
    await tap(tester, 'audio_lab_stop');
    expect(find.byKey(const Key('input_level_meter')), findsNothing);
    expect(
      find.textContaining('Ortam ölçümü mevcut kaydı siler'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('audio_lab_analyze')), findsOneWidget);
    await tap(tester, 'audio_lab_cancel');
    expect(find.byKey(const Key('audio_lab_metadata')), findsNothing);
    expect(find.text('Hazır. Mikrofon kapalı.'), findsOneWidget);
    expect(backend.calls, contains('discard'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'lesson close invalidates pending permission without late capture',
    (tester) async {
      final backend = FakeAudioLabBackend()..permissionGate = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AudioLabScreen(
                      backend: backend,
                      worker: FakeRecordingPitchWorker(),
                    ),
                  ),
                ),
                child: const Text('Laboratuvarı aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Laboratuvarı aç'));
      await tester.pumpAndSettle();
      await tap(tester, 'audio_lab_record');
      expect(find.text('Mikrofon izni bekleniyor…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lesson_close')));
      await tester.pumpAndSettle();
      backend.permissionGate!.complete(true);
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('Laboratuvarı aç'), findsOneWidget);
      expect(backend.calls, isNot(contains('start')));
      expect(backend.calls, contains('close'));
      expect(backend.capturing, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dark reduced-motion large text denial still allows reference without mic',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final backend = FakeAudioLabBackend()..permission = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmoniaTheme.dark(),
          home: AudioLabScreen(
            backend: backend,
            worker: FakeRecordingPitchWorker(),
          ),
        ),
      );
      await tap(tester, 'audio_lab_record');
      expect(find.textContaining('Mikrofon izni verilmedi'), findsOneWidget);
      expect(find.byKey(const Key('microphone_open_settings')), findsOneWidget);
      await tap(tester, 'audio_lab_reference');
      expect(find.text('Referansı dinle. Mikrofon kapalı.'), findsOneWidget);
      expect(backend.calls.where((c) => c == 'permission'), hasLength(1));
      expect(backend.calls, isNot(contains('start')));
      backend.playbackEnd.complete();
      await tester.pumpAndSettle();
      await tap(tester, 'audio_lab_help');
      expect(
        find.textContaining('İzin tekrar otomatik istenmez'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('explicit delete during analysis rejects a late worker result', (
    tester,
  ) async {
    final backend = FakeAudioLabBackend();
    final worker = FakeRecordingPitchWorker()
      ..gate = Completer<RecordingPitchEvidence>();
    await tester.pumpWidget(
      MaterialApp(
        home: AudioLabScreen(backend: backend, worker: worker),
      ),
    );
    for (final key in [
      'audio_lab_record',
      'audio_lab_stop',
      'audio_lab_analyze',
    ]) {
      await tap(tester, key);
    }
    expect(
      tester
          .widget<ChunkyButton>(find.byKey(const Key('audio_lab_analyze')))
          .onPressed,
      isNull,
    );
    await tap(tester, 'audio_lab_cancel');
    worker.gate!.completeError(StateError('late private worker error'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audio_lab_metadata')), findsNothing);
    expect(find.byKey(const Key('audio_lab_diagnostics')), findsNothing);
    expect(find.byKey(const Key('audio_lab_analysis_error')), findsNothing);
    expect(backend.calls, contains('discard'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('diagnostics stay unscored and fit narrow enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final backend = FakeAudioLabBackend();
    final worker = FakeRecordingPitchWorker();
    await tester.pumpWidget(
      MaterialApp(
        home: AudioLabScreen(backend: backend, worker: worker),
      ),
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
    expect(find.text('Yerel analiz • Başarı skoru değildir'), findsOneWidget);
    expect(find.text('Temsilî frekans: Ölçülmedi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'background clears pending diagnostics and consumes late worker error',
    (tester) async {
      final backend = FakeAudioLabBackend();
      final worker = FakeRecordingPitchWorker()
        ..gate = Completer<RecordingPitchEvidence>();
      await tester.pumpWidget(
        MaterialApp(
          home: AudioLabScreen(backend: backend, worker: worker),
        ),
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
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(backend.calls, contains('discard'));
      worker.gate!.completeError(StateError('late worker failure'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audio_lab_diagnostics')), findsNothing);
      expect(find.byKey(const Key('audio_lab_analysis_error')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'inactive permission dialog does not cancel intentional recording',
    (tester) async {
      final backend = FakeAudioLabBackend()..permissionGate = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(home: AudioLabScreen(backend: backend)),
      );
      await tester.tap(find.byKey(const Key('audio_lab_record')));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      backend.permissionGate!.complete(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(backend.capturing, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(backend.calls, contains('close'));
      expect(backend.capturing, isFalse);
    },
  );
  testWidgets('entry is private and starts no microphone', (tester) async {
    final backend = FakeAudioLabBackend();
    await tester.pumpWidget(
      MaterialApp(home: AudioLabScreen(backend: backend)),
    );
    expect(find.text('Gerçek kayıt • Deneysel'), findsOneWidget);
    expect(backend.calls, isEmpty);
    await tester.tap(find.byKey(const Key('audio_lab_record')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('audio_lab_stop')), findsOneWidget);
    await tester.tap(find.byKey(const Key('audio_lab_stop')));
    await tester.pumpAndSettle();
    expect(find.text('1.00 sn • 44100 Hz • mono PCM16'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('close'));
    expect(backend.capturing, isFalse);
  });
  testWidgets(
    'permission denial fits narrow enlarged text and stays unrecorded',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final backend = FakeAudioLabBackend()..permission = false;
      await tester.pumpWidget(
        MaterialApp(home: AudioLabScreen(backend: backend)),
      );
      await tester.ensureVisible(find.byKey(const Key('audio_lab_record')));
      await tester.tap(find.byKey(const Key('audio_lab_record')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audio_lab_error')), findsOneWidget);
      expect(find.byKey(const Key('microphone_open_settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(backend.calls, isNot(contains('start')));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('background transition discards active recording', (
    tester,
  ) async {
    final backend = FakeAudioLabBackend();
    await tester.pumpWidget(
      MaterialApp(home: AudioLabScreen(backend: backend)),
    );
    await tester.tap(find.byKey(const Key('audio_lab_record')));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(backend.capturing, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Hazır. Mikrofon kapalı.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
