import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/single_tone_session.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/domain/models/measurement_provenance.dart';
import 'package:harmonia/trainer/audio/synth.dart';
import 'package:harmonia/trainer/domain/curriculum.dart';
import 'package:harmonia/trainer/domain/music.dart';
import 'package:harmonia/trainer/domain/trainers.dart';
import 'package:harmonia/trainer/sing/trainer_pitch_sing_session.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';

const _rate = 16000;

List<double> _noise(double seconds, {double rms = 0.001}) {
  var state = 17;
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

LessonNode _pitchNode({List<Register> registers = const [Register.medium]}) =>
    LessonNode(
      id: 'pitch-test',
      trainer: TrainerKind.pitch,
      kind: NodeKind.lesson,
      title: 'Test',
      subtitle: 'Test',
      items: const ['0', '4'],
      newItems: const ['4'],
      registers: registers,
    );

class _Player implements ReferenceClipPlayer {
  final calls = <String>[];
  List<int>? bytes;
  Completer<void> completion = Completer<void>();

  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    calls.add('play');
    bytes = List.of(wavBytes);
    return PlaybackHandle(completion.future);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> close() async => calls.add('close');
}

Future<void> _settle([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  test('target binds pitch item, register and timbre without a score', () {
    final target = TrainerPitchSingTarget.forNode(
      node: _pitchNode(),
      itemId: '4',
      register: Register.medium,
      timbre: Timbre.clarinet,
    );
    expect(target.midi, 64);
    expect(target.frequencyHz, closeTo(midiToHz(64), 1e-9));
    expect(target.contentVersion, 'trainer-synth-v1:clarinet');
    expect(TrainerPitchSingSession.scoringEnabled, isFalse);
  });

  test('lower choir voice moves the sounding register down', () {
    final target = TrainerPitchSingTarget.forNode(
      node: _pitchNode(registers: const [Register.high]),
      itemId: '0',
      register: Register.high,
      voice: VoicePart.tenor,
    );
    expect(target.register, Register.medium);
    expect(target.midi, 60);
  });

  test(
    'target rejects non-pitch, intro, foreign item and foreign register',
    () {
      final interval = LessonNode(
        id: 'interval-test',
        trainer: TrainerKind.interval,
        kind: NodeKind.lesson,
        title: 'Test',
        subtitle: 'Test',
        items: const ['P5'],
      );
      expect(
        () => TrainerPitchSingTarget.forNode(
          node: interval,
          itemId: 'P5',
          register: Register.medium,
        ),
        throwsArgumentError,
      );
      expect(
        () => TrainerPitchSingTarget.forNode(
          node: _pitchNode(),
          itemId: '7',
          register: Register.medium,
        ),
        throwsArgumentError,
      );
      expect(
        () => TrainerPitchSingTarget.forNode(
          node: _pitchNode(),
          itemId: '0',
          register: Register.high,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'generated reference uses dedicated player and preserves evidence source',
    () async {
      final backend = FakeRoutedAudioLabBackend();
      final player = _Player();
      final worker = FakeRecordingPitchWorker();
      final target = TrainerPitchSingTarget.forNode(
        node: _pitchNode(),
        itemId: '4',
        register: Register.medium,
      );
      final session = TrainerPitchSingSession(
        target: target,
        capture: backend,
        referencePlayer: player,
        worker: worker,
        calibrationDuration: const Duration(milliseconds: 1),
        responseDelay: const Duration(milliseconds: 1),
        responseWindow: const Duration(milliseconds: 5),
      );
      backend.nextClip(_noise(2));
      await session.calibrate();
      backend.nextClip(_answer(target.frequencyHz));
      final run = session.startAttempt();
      await _settle(5);
      expect(player.calls, contains('play'));
      expect(player.bytes, isNotEmpty);
      expect(backend.calls, isNot(contains('reference')));
      player.completion.complete();
      await run;
      expect(session.diagnosticOutcome!.needsRetry, isFalse);
      expect(
        session.diagnosticOutcome!.evidence!.provenance.source,
        MeasurementSource.mock,
      );
      expect(
        session.diagnosticOutcome!.deviation!.absoluteCents.abs(),
        lessThan(20),
      );
      await session.close();
      session.dispose();
    },
  );

  test('silent response is neutral and never invokes analyzer', () async {
    final backend = FakeRoutedAudioLabBackend();
    final player = _Player();
    final worker = FakeRecordingPitchWorker();
    final target = TrainerPitchSingTarget.forNode(
      node: _pitchNode(),
      itemId: '0',
      register: Register.medium,
    );
    final session = TrainerPitchSingSession(
      target: target,
      capture: backend,
      referencePlayer: player,
      worker: worker,
      calibrationDuration: const Duration(milliseconds: 1),
      responseDelay: const Duration(milliseconds: 1),
      responseWindow: const Duration(milliseconds: 5),
    );
    backend.nextClip(_noise(2));
    await session.calibrate();
    backend.nextClip(_noise(1.5));
    final run = session.startAttempt();
    await _settle(5);
    player.completion.complete();
    await run;
    expect(session.diagnosticOutcome!.retryReason, SessionRetryReason.quality);
    expect(worker.calls, 0);
    await session.close();
    session.dispose();
  });

  test('cancel during playback cannot publish a late diagnostic', () async {
    final backend = FakeRoutedAudioLabBackend();
    final player = _Player();
    final target = TrainerPitchSingTarget.forNode(
      node: _pitchNode(),
      itemId: '0',
      register: Register.medium,
    );
    final session = TrainerPitchSingSession(
      target: target,
      capture: backend,
      referencePlayer: player,
      worker: FakeRecordingPitchWorker(),
      calibrationDuration: const Duration(milliseconds: 1),
    );
    backend.nextClip(_noise(2));
    await session.calibrate();
    backend.calls.clear();
    final run = session.startAttempt();
    await _settle(5);
    await session.cancel();
    player.completion.complete();
    await run;
    expect(session.phase, SingleToneSessionPhase.idle);
    expect(session.diagnosticOutcome, isNull);
    expect(backend.calls, isNot(contains('start')));
    await session.close();
    session.dispose();
  });

  test('close owns both resources and is idempotent', () async {
    final backend = FakeRoutedAudioLabBackend();
    final player = _Player();
    final session = TrainerPitchSingSession(
      target: TrainerPitchSingTarget.forNode(
        node: _pitchNode(),
        itemId: '0',
        register: Register.medium,
      ),
      capture: backend,
      referencePlayer: player,
      worker: FakeRecordingPitchWorker(),
    );
    await session.close();
    await session.close();
    expect(player.calls.where((call) => call == 'close'), hasLength(1));
    expect(backend.calls.where((call) => call == 'close'), hasLength(1));
    expect(session.phase, SingleToneSessionPhase.closed);
    session.dispose();
  });
}
