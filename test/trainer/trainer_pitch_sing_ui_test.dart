import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/trainer/app/scope.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/domain/curriculum.dart';
import 'package:resonia/trainer/domain/trainers.dart';
import 'package:resonia/trainer/learn/lesson_flow.dart';
import 'package:resonia/trainer/sing/trainer_pitch_sing_session.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;

List<double> _noise(double seconds, {double rms = 0.001}) {
  var state = 29;
  final amp = rms * math.sqrt(3);
  return List.generate((seconds * _rate).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return amp * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _answer(double hz) => [
  ..._noise(0.3),
  ...List.generate(
    (_rate * 1.2).round(),
    (i) => 0.2 * math.sin(2 * math.pi * hz * i / _rate),
  ),
];

class _Player implements ReferenceClipPlayer {
  final calls = <String>[];
  Completer<void> completion = Completer<void>();

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    calls.add('play');
    return PlaybackHandle(completion.future);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> close() async => calls.add('close');
}

TrainerStore _store() => TrainerStore(MemoryTrainerPersistence());

Widget _app({
  required TrainerStore store,
  required LessonNode node,
  required bool liveAudio,
  TrainerPitchSingSession Function(TrainerPitchSingTarget)? factory,
}) => TrainerScope(
  store: store,
  audio: TrainerAudio.silent(),
  liveAudio: liveAudio,
  child: MaterialApp(
    home: LessonFlow(
      node: node,
      random: math.Random(3),
      pitchSingSessionFactory: factory,
    ),
  ),
);

Future<void> _toSing(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('lesson_next')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('lesson_next')));
  await tester.pumpAndSettle();
  expect(find.text('SÖYLE'), findsOneWidget);
}

void main() {
  testWidgets('pitch diagnostic is opt-in, unscored and source-labelled', (
    tester,
  ) async {
    final store = _store();
    await store.load();
    final node = trainerPaths[TrainerKind.pitch]!.nodes.firstWhere(
      (candidate) =>
          candidate.kind == NodeKind.lesson && candidate.newItems.length == 1,
    );
    final backend = FakeRoutedAudioLabBackend();
    final player = _Player();
    final worker = FakeRecordingPitchWorker();
    TrainerPitchSingTarget? target;
    TrainerPitchSingSession factory(TrainerPitchSingTarget value) {
      target = value;
      return TrainerPitchSingSession(
        target: value,
        capture: backend,
        referencePlayer: player,
        worker: worker,
        calibrationDuration: const Duration(milliseconds: 1),
        responseDelay: const Duration(milliseconds: 1),
        responseWindow: const Duration(milliseconds: 5),
      );
    }

    await tester.pumpWidget(
      _app(store: store, node: node, liveAudio: true, factory: factory),
    );
    await _toSing(tester);
    expect(find.byKey(const Key('sing_calibrate')), findsOneWidget);
    expect(backend.calls, isNot(contains('permission')));
    expect(store.isComplete(node.id), isFalse);

    backend.nextClip(_noise(2));
    await tester.tap(find.byKey(const Key('sing_calibrate')));
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    expect(target, isNotNull);
    expect(find.byKey(const Key('sing_start')), findsOneWidget);

    backend.nextClip(_answer(target!.frequencyHz));
    await tester.tap(find.byKey(const Key('sing_start')));
    await tester.pump(const Duration(milliseconds: 5));
    expect(player.calls, contains('play'));
    player.completion.complete();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tanısal fark:'), findsOneWidget);
    expect(find.byKey(const Key('sing_scale')), findsOneWidget);
    expect(find.text('— Hedef perde'), findsOneWidget);
    expect(find.text('Kaynak: Test kaynağı'), findsOneWidget);
    expect(store.isComplete(node.id), isFalse);
    expect(store.trainerReps(TrainerKind.pitch), 0);

    await tester.tap(find.byKey(const Key('lesson_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice')), findsOneWidget);
    expect(store.isComplete(node.id), isFalse);
  });

  testWidgets('diagnostic stays hidden when live audio is disabled', (
    tester,
  ) async {
    final store = _store();
    await store.load();
    final node = trainerPaths[TrainerKind.pitch]!.nodes.firstWhere(
      (candidate) =>
          candidate.kind == NodeKind.lesson && candidate.newItems.length == 1,
    );
    await tester.pumpWidget(_app(store: store, node: node, liveAudio: false));
    await _toSing(tester);
    expect(find.byKey(const Key('sing_calibrate')), findsNothing);
    expect(find.textContaining('ilerlemeye yazılmaz'), findsOneWidget);
  });

  testWidgets('session construction failure stays neutral and skippable', (
    tester,
  ) async {
    final store = _store();
    await store.load();
    final node = trainerPaths[TrainerKind.pitch]!.nodes.firstWhere(
      (candidate) =>
          candidate.kind == NodeKind.lesson && candidate.newItems.length == 1,
    );
    await tester.pumpWidget(
      _app(
        store: store,
        node: node,
        liveAudio: true,
        factory: (_) => throw UnsupportedError('test-only unavailable'),
      ),
    );
    await _toSing(tester);
    await tester.tap(find.byKey(const Key('sing_calibrate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('bu cihazda başlatılamadı'), findsOneWidget);
    expect(find.byKey(const Key('lesson_next')), findsOneWidget);
    expect(store.isComplete(node.id), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backgrounding cancels playback and never auto-resumes', (
    tester,
  ) async {
    final store = _store();
    await store.load();
    final node = trainerPaths[TrainerKind.pitch]!.nodes.firstWhere(
      (candidate) =>
          candidate.kind == NodeKind.lesson && candidate.newItems.length == 1,
    );
    final backend = FakeRoutedAudioLabBackend();
    final player = _Player();
    TrainerPitchSingSession factory(TrainerPitchSingTarget value) =>
        TrainerPitchSingSession(
          target: value,
          capture: backend,
          referencePlayer: player,
          worker: FakeRecordingPitchWorker(),
          calibrationDuration: const Duration(milliseconds: 1),
        );
    await tester.pumpWidget(
      _app(store: store, node: node, liveAudio: true, factory: factory),
    );
    await _toSing(tester);
    backend.nextClip(_noise(2));
    await tester.tap(find.byKey(const Key('sing_calibrate')));
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sing_start')));
    await tester.pump(const Duration(milliseconds: 5));
    expect(player.calls, contains('play'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    player.completion.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Tanısal fark:'), findsNothing);
    expect(
      find.text('Hazır · referansı dinleyip söyleyebilirsin'),
      findsOneWidget,
    );
    expect(backend.calls, containsAll(['stopPlayback', 'discard']));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(player.calls.where((call) => call == 'play'), hasLength(1));
  });

  /// Runs one calibrated attempt whose answer is [clip] for the target Hz.
  Future<void> attempt(
    WidgetTester tester,
    List<double> Function(double targetHz) clip,
  ) async {
    final store = _store();
    await store.load();
    final node = trainerPaths[TrainerKind.pitch]!.nodes.firstWhere(
      (candidate) =>
          candidate.kind == NodeKind.lesson && candidate.newItems.length == 1,
    );
    final backend = FakeRoutedAudioLabBackend();
    final player = _Player();
    TrainerPitchSingTarget? target;
    TrainerPitchSingSession factory(TrainerPitchSingTarget value) {
      target = value;
      return TrainerPitchSingSession(
        target: value,
        capture: backend,
        referencePlayer: player,
        worker: FakeRecordingPitchWorker(),
        calibrationDuration: const Duration(milliseconds: 1),
        responseDelay: const Duration(milliseconds: 1),
        responseWindow: const Duration(milliseconds: 5),
      );
    }

    await tester.pumpWidget(
      _app(store: store, node: node, liveAudio: true, factory: factory),
    );
    await _toSing(tester);
    expect(find.byKey(const Key('sing_target')), findsOneWidget);
    backend.nextClip(_noise(2));
    await tester.tap(find.byKey(const Key('sing_calibrate')));
    await tester.pump(const Duration(milliseconds: 5));
    await tester.pumpAndSettle();
    backend.nextClip(clip(target!.frequencyHz));
    await tester.tap(find.byKey(const Key('sing_start')));
    await tester.pump(const Duration(milliseconds: 5));
    player.completion.complete();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(store.trainerReps(TrainerKind.pitch), 0);
  }

  testWidgets('a wrong octave is named and never marked near the target', (
    tester,
  ) async {
    await attempt(tester, (hz) => _answer(hz * 2));
    expect(find.textContaining('oktav tiz, hedef perde değil'), findsOneWidget);
    expect(find.text('Bir oktav tiz söylendi'), findsOneWidget);
    expect(find.text('— Hedef perde'), findsNothing);
  });

  testWidgets('silence is not counted and shows no scale', (tester) async {
    await attempt(tester, (_) => _noise(1.5));
    expect(find.byKey(const Key('sing_not_counted')), findsOneWidget);
    expect(find.byKey(const Key('sing_scale')), findsNothing);
    expect(find.textContaining('Tanısal fark:'), findsNothing);
  });
}
