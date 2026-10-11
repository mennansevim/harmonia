import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/features/audio_lab/audio_lab_screen.dart';
import '../support/fake_audio_lab_backend.dart';

void main() {
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
