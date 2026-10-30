import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/application/melody_practice.dart';
import 'package:resonia/application/melody_session.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/features/common/ui/resonia_ui.dart';
import 'package:resonia/features/melody/melody_practice_screen.dart';
import 'package:resonia/features/melody/melody_session_screen.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

class _Player implements DiagnosticMelodyPracticePlayer {
  final calls = <String>[];
  final end = Completer<void>();
  Completer<PlaybackHandle>? startGate;
  Completer<void>? closeGate;
  Object? playError, closeError;
  DiagnosticMelodyPractice? selection;
  @override
  Future<PlaybackHandle> play(DiagnosticMelodyPractice practice) async {
    calls.add('play');
    selection = practice;
    if (playError case final error?) throw error;
    return startGate == null
        ? PlaybackHandle(end.future)
        : await startGate!.future;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> close() async {
    calls.add('close');
    await closeGate?.future;
    if (closeError case final error?) throw error;
  }
}

class _Capture extends FakeRoutedAudioLabBackend
    implements MelodyReferenceBackend {
  @override
  final reference = DiagnosticMelodyReference(
    id: 'test',
    contentVersion: '1',
    frequenciesHz: [440, 550, 660],
  );
  final closeGate = Completer<void>();
  bool fail = false;
  @override
  Future<void> close() async {
    calls.add('closing');
    await closeGate.future;
    if (fail) throw StateError('private native failure');
    await super.close();
  }
}

void main() {
  final reference = DiagnosticMelodyReference(
    id: 'five',
    contentVersion: 'synthetic-test',
    frequenciesHz: [220, 330, 440, 550, 660],
  );
  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    _Player player, {
    Stream<void>? events,
    bool dark = false,
    DiagnosticMelodyPractice? initialPractice,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ResoniaTheme.dark() : ResoniaTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Önceki sayfa'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MelodyPracticeScreen(
                    reference: reference,
                    player: player,
                    interruptions: events,
                    initialPractice: initialPractice,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Önceki sayfa'));
    await tester.pumpAndSettle();
  }

  DropdownButton<int> dropdown(WidgetTester tester, String key) =>
      tester.widget<DropdownButton<int>>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(DropdownButton<int>),
        ),
      );

  testWidgets(
    'manual range/repeats preserve original Hz, no autoplay or score',
    (tester) async {
      final player = _Player();
      await pump(tester, player);
      expect(player.calls, isEmpty);
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(find.text('Puansız'), findsOneWidget);
      dropdown(tester, 'practice_start').onChanged!(2);
      await tester.pump();
      dropdown(tester, 'practice_end_2').onChanged!(5);
      dropdown(tester, 'practice_repetitions').onChanged!(3);
      await tester.pump();
      await tap(tester, 'practice_play');
      expect(player.selection!.frequenciesHz, [440, 550, 660]);
      expect(player.selection!.repetitions, 3);
      expect(dropdown(tester, 'practice_start').onChanged, isNull);
      await tap(tester, 'practice_stop');
      expect(dropdown(tester, 'practice_start').onChanged, isNotNull);
      expect(find.textContaining('Tamamlanan referans:'), findsNothing);
      expect(find.textContaining('Genel:'), findsNothing);
      await tap(tester, 'lesson_close');
      expect(player.calls, ['play', 'stop', 'close']);
      expect(find.text('Önceki sayfa'), findsOneWidget);
    },
  );

  testWidgets('candidate suggestion preselects range but never autoplays', (
    tester,
  ) async {
    final player = _Player();
    final initial = DiagnosticMelodyPractice(
      reference: reference,
      startIndex: 1,
      endIndexExclusive: 3,
      repetitions: 2,
    );
    await pump(tester, player, initialPractice: initial);
    expect(player.calls, isEmpty);
    expect(find.text('Sentetik · deneysel aday bölüm'), findsOneWidget);
    expect(find.text('Seçim: 2–3. ses • 2 tekrar'), findsOneWidget);
    expect(find.textContaining('doğrulanmış hata'), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    await tap(tester, 'lesson_close');
  });

  testWidgets('background and focus stop, never auto resume', (tester) async {
    final events = StreamController<void>.broadcast(sync: true);
    addTearDown(events.close);
    final player = _Player();
    await pump(tester, player, events: events.stream);
    await tap(tester, 'practice_play');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(player.calls, ['play', 'stop']);
    expect(
      tester
          .widget<ChunkyButton>(find.byKey(const Key('practice_play')))
          .onPressed,
      isNull,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(player.calls, ['play', 'stop']);
    await tap(tester, 'practice_play');
    events.add(null);
    await tester.pumpAndSettle();
    expect(player.calls, ['play', 'stop', 'play', 'stop']);
    await tap(tester, 'lesson_close');
  });

  testWidgets('monitor failure stops and disables further playback', (
    tester,
  ) async {
    final events = StreamController<void>.broadcast(sync: true);
    addTearDown(events.close);
    final player = _Player();
    await pump(tester, player, events: events.stream);
    await tap(tester, 'practice_play');
    events.addError(StateError('private/path'));
    await tester.pumpAndSettle();
    expect(player.calls, ['play', 'stop']);
    expect(find.textContaining('izlemesi hazırlanamadı'), findsOneWidget);
    expect(
      tester
          .widget<ChunkyButton>(find.byKey(const Key('practice_play')))
          .onPressed,
      isNull,
    );
    expect(find.textContaining('private/path'), findsNothing);
    await tap(tester, 'lesson_close');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'close during pending start holds route until cleanup, consumes late error',
    (tester) async {
      final player = _Player()..startGate = Completer<PlaybackHandle>();
      await pump(tester, player);
      await tap(tester, 'practice_play');
      await tap(tester, 'lesson_close');
      expect(find.byType(MelodyPracticeScreen), findsOneWidget);
      expect(player.calls, ['play']);
      player.startGate!.complete(PlaybackHandle(player.end.future));
      await tester.pumpAndSettle();
      player.end.completeError(StateError('late completion'));
      await tester.pumpAndSettle();
      expect(player.calls, ['play', 'close']);
      expect(find.byType(MelodyPracticeScreen), findsNothing);
      expect(find.text('Önceki sayfa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system back also awaits close; failure blocks unsafe route release',
    (tester) async {
      final player = _Player()..closeGate = Completer<void>();
      await pump(tester, player);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MelodyPracticeScreen), findsOneWidget);
      player.closeError = StateError('private close');
      player.closeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('kapandığı doğrulanamadı'), findsOneWidget);
      await tap(tester, 'lesson_close');
      expect(player.calls, ['close']);
      expect(find.byType(MelodyPracticeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('load failure has explicit safe retry', (tester) async {
    final player = _Player()..playError = StateError('secret/path');
    await pump(tester, player);
    await tap(tester, 'practice_play');
    expect(find.textContaining('Yeniden deneyebilirsin'), findsOneWidget);
    expect(find.textContaining('secret/path'), findsNothing);
    player.playError = null;
    await tap(tester, 'practice_play');
    expect(find.textContaining('Seçili bölüm çalıyor'), findsOneWidget);
    await tap(tester, 'lesson_close');
  });

  testWidgets(
    'dark reduced-motion large text supports selectors help and stop',
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
      final player = _Player();
      await pump(tester, player, dark: true);
      await tap(tester, 'practice_help');
      expect(
        find.textContaining('uygulama hatalı bölümü belirlemez'),
        findsOneWidget,
      );
      await tap(tester, 'practice_play');
      await tap(tester, 'practice_stop');
      await tap(tester, 'lesson_close');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'handoff closes parent before player creation and replaces capture route',
    (tester) async {
      final capture = _Capture();
      addTearDown(capture.levels.close);
      final player = _Player();
      int created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Ana sayfa'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MelodySessionScreen(
                      backend: capture,
                      worker: FakeRecordingPitchWorker(),
                      practicePlayerFactory: () {
                        created++;
                        expect(capture.calls.last, 'close');
                        return player;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ana sayfa'));
      await tester.pumpAndSettle();
      await tap(tester, 'melody_open_practice');
      expect(created, 0);
      expect(find.byKey(const Key('melody_start')), findsNothing);
      await tap(tester, 'lesson_close');
      expect(find.byType(MelodySessionScreen), findsOneWidget);
      capture.closeGate.complete();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(created, 1);
      expect(find.byType(MelodySessionScreen), findsNothing);
      expect(player.calls, isEmpty);
      expect(capture.calls, isNot(contains('permission')));
      await tap(tester, 'lesson_close');
      expect(find.text('Ana sayfa'), findsOneWidget);
    },
  );

  testWidgets('failed parent close never creates rehearsal player', (
    tester,
  ) async {
    final capture = _Capture()..fail = true;
    addTearDown(capture.levels.close);
    addTearDown(capture.events.close);
    int created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MelodySessionScreen(
          backend: capture,
          worker: FakeRecordingPitchWorker(),
          practicePlayerFactory: () {
            created++;
            return _Player();
          },
        ),
      ),
    );
    await tap(tester, 'melody_open_practice');
    capture.closeGate.complete();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    expect(created, 0);
    expect(find.textContaining('güvenle devredilemedi'), findsOneWidget);
    expect(find.byKey(const Key('melody_start')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'disposing during parent close cannot create a late player or route',
    (tester) async {
      final capture = _Capture();
      addTearDown(capture.levels.close);
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MelodySessionScreen(
            backend: capture,
            worker: FakeRecordingPitchWorker(),
            practicePlayerFactory: () {
              created++;
              return _Player();
            },
          ),
        ),
      );
      await tap(tester, 'melody_open_practice');
      await tester.pumpWidget(const SizedBox());
      capture.closeGate.complete();
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(created, 0);
      expect(capture.calls.where((call) => call == 'close'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'practice controls meet tap label and contrast guidelines in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        for (final dark in [false, true]) {
          await pump(tester, _Player(), dark: dark);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await tap(tester, 'lesson_close');
        }
      } finally {
        handle.dispose();
      }
    },
  );
}
