import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/melody_session.dart';
import 'package:harmonia/application/melody_practice.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/home/home_screen.dart';
import 'package:harmonia/features/melody/melody_session_screen.dart';
import 'package:harmonia/features/melody/melody_practice_screen.dart';
import 'package:harmonia/features/common/ui/harmonia_ui.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

class _Backend extends FakeRoutedAudioLabBackend
    implements MelodyReferenceBackend {
  @override
  final reference = DiagnosticMelodyReference(
    id: 'fake-melody',
    contentVersion: 'test-1',
    frequenciesHz: [440, 550, 660],
  );
}

class _PracticePlayer implements DiagnosticMelodyPracticePlayer {
  final calls = <String>[];

  @override
  Future<PlaybackHandle> play(DiagnosticMelodyPractice practice) async {
    calls.add('play');
    return PlaybackHandle(Future<void>.value());
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> close() async => calls.add('close');
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), 200);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
}

Future<void> _remove(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

Future<void> _calibrate(WidgetTester tester, _Backend backend) async {
  backend.nextClip(List.filled(32000, 0.0));
  await _tap(tester, 'melody_calibrate');
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> _answerPhase(WidgetTester tester, _Backend backend) async {
  await _tap(tester, 'melody_start');
  backend.playbackEnd.complete();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('diagnostic lesson has no percentage and contextual actions', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    expect(find.byType(LessonScaffold), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    expect(find.text('Puansız'), findsOneWidget);
    expect(
      tester
          .widget<ChunkyButton>(find.byKey(const Key('melody_calibrate')))
          .tone,
      ChunkyTone.primary,
    );
    expect(
      tester.widget<ChunkyButton>(find.byKey(const Key('melody_start'))).tone,
      ChunkyTone.neutral,
    );
    expect(backend.calls, isEmpty);
    await _calibrate(tester, backend);
    expect(
      tester.widget<ChunkyButton>(find.byKey(const Key('melody_start'))).tone,
      ChunkyTone.primary,
    );
    await _answerPhase(tester, backend);
    expect(find.byKey(const Key('melody_start')), findsNothing);
    expect(
      tester.widget<ChunkyButton>(find.byKey(const Key('melody_finish'))).tone,
      ChunkyTone.record,
    );
    expect(find.byKey(const Key('melody_cancel')), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    await _remove(tester);
  });

  testWidgets('help exposes recording policy without starting resources', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    expect(find.textContaining('cihazdan gönderilmez'), findsNothing);
    await _tap(tester, 'melody_help');
    await tester.pumpAndSettle();
    expect(find.textContaining('cihazdan gönderilmez'), findsOneWidget);
    expect(find.textContaining('8 saniye'), findsOneWidget);
    expect(backend.calls, isEmpty);
    await _remove(tester);
  });

  testWidgets('lesson close returns to source and releases the session', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MelodySessionScreen(
                    backend: backend,
                    worker: FakeRecordingPitchWorker(),
                  ),
                ),
              ),
              child: const Text('Ezgi aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ezgi aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lesson_close')));
    await tester.pumpAndSettle();
    // Route disposal detaches immediately; stream/native cleanup settles
    // asynchronously outside the widget's fake frame clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Ezgi aç'), findsOneWidget);
    expect(backend.calls, contains('close'));
    expect(backend.calls, isNot(contains('permission')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark large-text help remains usable with reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        theme: HarmoniaTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _tap(tester, 'melody_help');
    await tester.pumpAndSettle();
    await _tap(tester, 'melody_start');
    await tester.pumpAndSettle();
    expect(find.text('Ölçüm alınamadı — puanlanmadı'), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    expect(backend.calls, isNot(contains('permission')));
    expect(tester.takeException(), isNull);
    await _remove(tester);
  });

  testWidgets('entry never asks permission; uncalibrated start is neutral', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    expect(backend.calls, isEmpty);
    await _tap(tester, 'melody_start');
    await tester.pumpAndSettle();
    expect(find.text('Ölçüm alınamadı — puanlanmadı'), findsOneWidget);
    expect(find.textContaining('Önce ortamı ölç'), findsWidgets);
    expect(backend.calls, isNot(contains('permission')));
    await _remove(tester);
  });
  testWidgets('permission denial offers settings explanation without score', (
    tester,
  ) async {
    final backend = _Backend()..permission = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _tap(tester, 'melody_calibrate');
    await tester.pumpAndSettle();
    expect(find.textContaining('Telefon ayarlarından'), findsOneWidget);
    expect(find.byKey(const Key('microphone_open_settings')), findsOneWidget);
    expect(backend.calls, isNot(contains('reference')));
    await _remove(tester);
  });
  testWidgets('320px large text flow shows diagnostic origin not success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _calibrate(tester, backend);
    backend.nextClip([
      ...List.filled(4800, 0.0),
      ...List.generate(
        24000,
        (i) => 0.2 * math.sin(2 * math.pi * 440 * i / 16000),
      ),
    ]);
    await _answerPhase(tester, backend);
    expect(find.text('Şimdi söyle. Mikrofon açık.'), findsOneWidget);
    await _tap(tester, 'melody_finish');
    await tester.pumpAndSettle();
    expect(find.text('Yerel analiz tamamlandı — puanlanmadı'), findsOneWidget);
    await _tap(tester, 'melody_details');
    await tester.pumpAndSettle();
    expect(find.text('Kayıt kaynağı: mock'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Sonuç geçmişe'), 200);
    expect(find.textContaining('Sonuç geçmişe'), findsOneWidget);
    expect(find.text('Doğru!'), findsNothing);
    expect(tester.takeException(), isNull);
    await _remove(tester);
  });
  testWidgets('silent quality retry remains unscored', (tester) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _calibrate(tester, backend);
    backend.nextClip(List.filled(16000, 0.0));
    await _answerPhase(tester, backend);
    await _tap(tester, 'melody_finish');
    await tester.pumpAndSettle();
    expect(find.textContaining('öğrenci hatası değildir'), findsOneWidget);
    expect(find.byKey(const Key('melody_details')), findsNothing);
    await _remove(tester);
  });
  testWidgets(
    'candidate mismatch offers explicit unscored review and no autoplay',
    (tester) async {
      final backend = _Backend();
      final player = _PracticePlayer();
      await tester.pumpWidget(
        MaterialApp(
          home: MelodySessionScreen(
            backend: backend,
            worker: FakeRecordingPitchWorker(),
            practicePlayerFactory: () => player,
          ),
        ),
      );
      await _calibrate(tester, backend);
      backend.nextClip([
        ...List.filled(4000, 0.0),
        ...List.generate(
          12000,
          (i) => 0.2 * math.sin(2 * math.pi * 440 * i / 16000),
        ),
      ]);
      await _answerPhase(tester, backend);
      await _tap(tester, 'melody_finish');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('melody_candidate_practice')),
        findsOneWidget,
      );
      expect(find.textContaining('doğrulanmış hata'), findsOneWidget);
      expect(find.textContaining('puan değildir'), findsOneWidget);
      await _tap(tester, 'melody_open_candidate_practice');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(MelodyPracticeScreen), findsOneWidget);
      expect(find.text('Seçim: 1–2. ses • 2 tekrar'), findsOneWidget);
      expect(player.calls, isEmpty);
      expect(find.byType(LessonProgressBar), findsNothing);
      await _remove(tester);
    },
  );
  testWidgets('cancel stuck playback and background do not resume capture', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _calibrate(tester, backend);
    backend.calls.clear();
    await _tap(tester, 'melody_start');
    await _tap(tester, 'melody_cancel');
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('start')));
    await _tap(tester, 'melody_start');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    backend.playbackEnd.complete();
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('start')));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _remove(tester);
  });
  testWidgets('dispose during permission wait suppresses late UI work', (
    tester,
  ) async {
    final backend = _Backend()..permissionGate = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    await _tap(tester, 'melody_calibrate');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      backend.permissionGate!.complete(true);
      // Permission/stream cancellation futures can belong to the real zone.
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('start')));
    expect(backend.calls, contains('close'));
    expect(tester.takeException(), isNull);
  });
  testWidgets('home opens melody without auto capture or placeholder changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          profile: LearnerProfile(
            goal: PracticeGoal.conservatory,
            createdAt: DateTime.utc(2026),
          ),
          onOpenSettings: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_practice')));
    await tester.pumpAndSettle();
    await _tap(tester, 'open_melody_session');
    await tester.pumpAndSettle();
    expect(find.byType(MelodySessionScreen), findsOneWidget);
    expect(find.textContaining('piyano kaydı değildir'), findsOneWidget);
    await _remove(tester);
  });
  testWidgets('melody initial screen meets tap label and contrast guidelines', (
    tester,
  ) async {
    final backend = _Backend();
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: backend,
          worker: FakeRecordingPitchWorker(),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    await _remove(tester);
  });
}
