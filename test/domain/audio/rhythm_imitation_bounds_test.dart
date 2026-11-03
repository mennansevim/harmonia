import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/rhythm_imitation_controller.dart';
import 'package:resonia/domain/audio/rhythm_imitation.dart';
import 'package:resonia/domain/audio/rhythm_reference_clock.dart';
import 'package:resonia/domain/content/rhythm_patterns.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';
import 'package:resonia/domain/models/attempt_assistance_evidence.dart';
import 'package:resonia/domain/models/exercise_protocol_fingerprint.dart';

import '../../support/fake_clip_player.dart';

ExerciseProtocol protocol({
  double tempo = 60,
  List<double> beats = const [0, 1],
}) => ExerciseProtocol(
  mode: ExerciseMode.learning,
  notes: const [],
  rhythmOnsetsBeats: beats,
  tempoBpm: tempo,
);

Future<RhythmImitationOutcome> evaluate(
  ExerciseProtocol p, {
  List<Duration> taps = const [Duration.zero, Duration(seconds: 1)],
  int plays = 1,
}) => RhythmImitationEvaluator.evaluate(
  protocol: p,
  tapTimestamps: taps,
  referencePlays: plays,
);

void expectNeutral(RhythmImitationOutcome outcome) {
  expect(outcome.status, RhythmImitationStatus.invalidInput);
  expect(outcome.analysis, isNull);
  expect(outcome.timeline, isEmpty);
  expect(outcome.spanRatio, isNull);
}

void main() {
  test(
    'stored rhythm result carries protocol-bound assistance evidence',
    () async {
      final p = protocol();
      final outcome = await evaluate(p);
      final configured = ConfiguredExercise(
        exercise: const Exercise(
          id: 'rhythm-evidence',
          title: 'Rhythm evidence',
          skill: Skill.rhythm,
          difficulty: 1,
        ),
        protocol: p,
      );
      final result = outcome.toResult(
        exercise: configured,
        sessionId: 'session',
        createdAt: DateTime.utc(2026, 11),
      );
      final evidence = AttemptAssistanceEvidence.fromJson(
        result.measurements[AttemptAssistanceEvidence.measurementKey]!
            as Map<String, Object?>,
      );

      expect(evidence.referencePlaysCompleted, 1);
      expect(evidence.pitchHintsUsed, 0);
      expect(evidence.isIndependent, isTrue);
      expect(
        result.measurements[ExerciseProtocolFingerprint.measurementKey],
        ExerciseProtocolFingerprint.compute(p),
      );
      expect(
        evidence.configuredRecallDelayMs,
        p.recallDelayMs,
        reason:
            'Configured policy is retained; measured latency is not claimed',
      );
    },
  );

  test('tiny tempo and huge finite beats fail before round', () async {
    expectNeutral(await evaluate(protocol(tempo: 1e-300)));
    expectNeutral(await evaluate(protocol(beats: [0, 1e300])));
  });

  test('millisecond collisions are not merged or scored', () async {
    expectNeutral(await evaluate(protocol(tempo: 1e300)));
    expectNeutral(await evaluate(protocol(beats: [0, 0.0001])));
  });

  test(
    '30 second rendering boundary is inclusive, never rounded down',
    () async {
      final p = protocol(beats: [0, 30]);
      expect(RhythmReferenceClock.onsetsMs(p), [0, 30000]);
      final valid = await evaluate(
        p,
        taps: [Duration.zero, Duration(seconds: 30)],
      );
      expect(valid.analysis!.timingAccuracy.value, 100);
      expectNeutral(await evaluate(protocol(beats: [0, 30.0001])));
    },
  );

  test('single reference onset cannot be an imitation assessment', () async {
    expectNeutral(await evaluate(protocol(beats: [0])));
  });

  test(
    'negative timestamps are invalid even before too-few handling',
    () async {
      expectNeutral(
        await evaluate(protocol(), taps: [Duration(microseconds: -1)]),
      );
      expectNeutral(
        await evaluate(
          protocol(),
          taps: [Duration(seconds: -1), Duration.zero],
        ),
      );
    },
  );

  test('safe large absolute epoch preserves first-tap alignment', () async {
    const end = RhythmImitationEvaluator.maxTimestampUs;
    final valid = await evaluate(
      protocol(),
      taps: [
        Duration(microseconds: end - 1000000),
        Duration(microseconds: end),
      ],
    );
    expect(valid.analysis!.timingAccuracy.value, 100);
    expect(valid.spanRatio, 1);
    expectNeutral(
      await evaluate(protocol(), taps: [Duration(microseconds: end + 1)]),
    );
  });

  test(
    'backwards timestamps reject; duplicate taps remain scored extras',
    () async {
      expectNeutral(
        await evaluate(
          protocol(),
          taps: [Duration(seconds: 2), Duration(seconds: 1)],
        ),
      );
      final extra = await evaluate(
        protocol(),
        taps: [Duration.zero, Duration(seconds: 1), Duration(seconds: 1)],
      );
      expect(extra.isMeasured, isTrue);
      expect(extra.analysis!.extraCount, 1);
      expect(extra.analysis!.timingAccuracy.value, lessThan(100));
    },
  );

  test(
    'reference play quota invalidates evidence, not with a zero score',
    () async {
      for (final plays in [-1, 0, 2]) {
        expectNeutral(await evaluate(protocol(), plays: plays));
      }
    },
  );

  test('valid empty answer remains too few taps', () async {
    final outcome = await evaluate(protocol(), taps: []);
    expect(outcome.status, RhythmImitationStatus.tooFewTaps);
    expect(outcome.analysis, isNull);
  });

  test('invalid reference never reaches renderer or player', () async {
    var renders = 0;
    final c = RhythmImitationController(
      player: FakeClipPlayer(),
      renderReference: (_) {
        renders++;
        return [1];
      },
      initialPattern: RhythmPattern(
        title: 'Invalid clock test',
        description: 'Test only',
        exercise: ConfiguredExercise(
          exercise: draftRhythmPatterns.first.exercise.exercise,
          protocol: protocol(tempo: 1e-300),
        ),
      ),
    );
    await c.listen();
    expect(renders, 0);
    expect(c.playbackFailed, isTrue);
    expect(c.phase, RhythmImitationPhase.idle);
    expect(c.outcome, isNull);
    await c.close();
    c.dispose();
  });
}
