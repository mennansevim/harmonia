import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/application/chord_reference_session.dart';
import 'package:resonia/application/chord_response_attempt_coordinator.dart';
import 'package:resonia/application/chord_response_capture_session.dart';
import 'package:resonia/application/chord_response_diagnostic_analyzer.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';
import 'package:resonia/features/chord_exercise/chord_diagnostic_screen.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;

double _hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();

List<double> _tone(int midi, double seconds) => List.generate(
  (_rate * seconds).round(),
  (i) => 0.2 * math.sin(2 * math.pi * _hz(midi) * i / _rate),
);

List<double> _response(List<int> notes) => [
  ...List<double>.filled((_rate * 0.2).round(), 0),
  for (final note in notes) ...[
    ..._tone(note, 0.55),
    ...List<double>.filled((_rate * 0.16).round(), 0),
  ],
];

class _Player implements ReferenceClipPlayer {
  Completer<void> completed = Completer<void>();
  int plays = 0;

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    plays++;
    return PlaybackHandle(completed.future);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> close() async {}
}

class _Harness {
  _Harness({
    this.mode = ExerciseMode.learning,
    this.order = ResponseOrder.exact,
  }) {
    final recording = ReviewedChordRecording(
      id: 'dyad-c-g',
      voiceCount: 2,
      relativePath: '2-notes/dyad-c-g.wav',
      targetMidiNotes: const [60, 67],
      sha256: 'a' * 64,
      sampleRateHz: 48000,
      channels: 1,
      sampleFrames: 96000,
      a4Hz: 440,
      rightsReference: 'rights/user-recorded',
      labelReviewReference: 'reviews/dyad-c-g',
    );
    final reference = ChordReferenceSession(
      recording: recording,
      wavBytes: const [1, 2, 3],
      player: player,
      mode: mode,
      maxReferencePlays: mode == ExerciseMode.recallExam ? 1 : 3,
      wait: (_) async {},
    );
    session = ChordResponseCaptureSession(
      reference: reference,
      backend: backend,
      wait: (_) async {},
      clock: () => DateTime.utc(2026, 10, 30, 18),
    );
    coordinator = ChordResponseAttemptCoordinator(
      session: session,
      responseOrder: order,
      analyzer: ChordResponseDiagnosticAnalyzer(
        worker: worker,
        clock: () => DateTime.utc(2026, 10, 30, 18, 1),
      ),
    );
  }

  final ExerciseMode mode;
  final ResponseOrder order;
  final player = _Player();
  final backend = FakeRoutedAudioLabBackend();
  final worker = FakeRecordingPitchWorker();
  late final ChordResponseCaptureSession session;
  late final ChordResponseAttemptCoordinator coordinator;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.scrollUntilVisible(finder, 160);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Widget _app(_Harness harness) => MaterialApp(
  theme: ResoniaTheme.light(),
  home: ChordDiagnosticScreen(coordinator: harness.coordinator),
);

void main() {
  testWidgets(
    'reviewed dyad runs explicit flow and explains candidate comparison',
    (tester) async {
      final harness = _Harness();
      harness.backend.nextClip(List<double>.filled(_rate * 2, 0.0001));
      await tester.pumpWidget(_app(harness));

      expect(find.text('2 sesli piyano'), findsOneWidget);
      expect(find.text('Do4'), findsOneWidget);
      expect(find.text('Sol4'), findsOneWidget);
      expect(find.text('Puansız'), findsOneWidget);
      expect(harness.backend.calls, isEmpty);
      expect(find.byKey(const Key('chord_respond')), findsNothing);

      await _tap(tester, 'chord_calibrate');
      await tester.pumpAndSettle();
      expect(find.textContaining('Ortam ölçüldü'), findsOneWidget);

      harness.backend.nextClip(_response(const [60, 67]));
      await _tap(tester, 'chord_listen');
      expect(harness.player.plays, 1);
      expect(find.textContaining('Mikrofon kapalı'), findsOneWidget);
      harness.player.completed.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chord_respond')), findsOneWidget);

      await _tap(tester, 'chord_respond');
      expect(
        find.byKey(const Key('live_visual_feedback_field')),
        findsOneWidget,
      );
      harness.backend.levels.add(-24);
      await tester.pump();
      expect(find.text('Canlı giriş seviyesi'), findsOneWidget);
      expect(find.textContaining('Test kaynağı'), findsOneWidget);
      expect(find.textContaining('perde ölçülmüyor'), findsOneWidget);

      await _tap(tester, 'chord_finish');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chord_diagnostic_result')), findsOneWidget);
      expect(find.text('Aday karşılaştırma — puan değil'), findsOneWidget);
      expect(find.text('1. ses: aynı mutlak perde adayı'), findsOneWidget);
      expect(find.text('2. ses: aynı mutlak perde adayı'), findsOneWidget);
      expect(
        find.textContaining('Hiçbir ilerleme kaydı yazılmadı'),
        findsOneWidget,
      );
      expect(find.textContaining('%'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('silent response is a neutral retry and worker never runs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = _Harness();
    harness.backend.nextClip(List<double>.filled(_rate * 2, 0.0001));
    await tester.pumpWidget(
      MaterialApp(
        theme: ResoniaTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ChordDiagnosticScreen(coordinator: harness.coordinator),
      ),
    );
    await _tap(tester, 'chord_calibrate');
    await tester.pumpAndSettle();
    harness.backend.nextClip(List<double>.filled(_rate, 0));
    await _tap(tester, 'chord_listen');
    harness.player.completed.complete();
    await tester.pumpAndSettle();
    await _tap(tester, 'chord_respond');
    await _tap(tester, 'chord_finish');
    await tester.pumpAndSettle();

    expect(
      find.text('Kayıt kalitesi yeterli değil — puanlanmadı'),
      findsOneWidget,
    );
    expect(harness.worker.calls, 0);
    expect(find.textContaining('başarısız'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('recall mode hides reviewed target labels before response', (
    tester,
  ) async {
    final harness = _Harness(
      mode: ExerciseMode.recallExam,
      order: ResponseOrder.anyOrder,
    );
    await tester.pumpWidget(_app(harness));

    expect(find.text('Do4'), findsNothing);
    expect(find.text('Sol4'), findsNothing);
    expect(find.text('Ses'), findsNWidgets(2));
    expect(
      find.text('Birlikte dinle · sesleri istediğin sırada söyle'),
      findsOneWidget,
    );
    expect(harness.backend.calls, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
