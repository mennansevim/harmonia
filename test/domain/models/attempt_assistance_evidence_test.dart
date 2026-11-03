import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/models/attempt_assistance_evidence.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';

ExerciseProtocol _protocol({
  bool hint = false,
  bool transposition = false,
  int maxPlays = 2,
}) => ExerciseProtocol(
  mode: ExerciseMode.learning,
  notes: const [],
  rhythmOnsetsBeats: const [0, 1],
  maxReferencePlays: maxPlays,
  allowPitchHint: hint,
  allowTransposition: transposition,
  recallDelayMs: 750,
);

void main() {
  test('protocol-bound evidence round-trips and names independence', () {
    final evidence = AttemptAssistanceEvidence.forProtocol(
      _protocol(),
      referencePlaysCompleted: 1,
    );
    final restored = AttemptAssistanceEvidence.fromJson(evidence.toJson());

    expect(restored.referencePlaysCompleted, 1);
    expect(restored.configuredRecallDelayMs, 750);
    expect(restored.isIndependent, isTrue);
    expect(
      AttemptAssistanceEvidence.claimsIndependent({
        'referencePlays': 1,
        AttemptAssistanceEvidence.measurementKey: restored.toJson(),
      }),
      isTrue,
    );
  });

  test('unavailable aids and replay quota are rejected', () {
    expect(
      () => AttemptAssistanceEvidence.forProtocol(
        _protocol(),
        referencePlaysCompleted: 3,
      ),
      throwsArgumentError,
    );
    expect(
      () => AttemptAssistanceEvidence.forProtocol(
        _protocol(),
        referencePlaysCompleted: 1,
        pitchHintsUsed: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => AttemptAssistanceEvidence.forProtocol(
        _protocol(),
        referencePlaysCompleted: 1,
        transpositionUsed: true,
      ),
      throwsArgumentError,
    );
  });

  test('allowed aid use stays valid but cannot claim independence', () {
    final evidence = AttemptAssistanceEvidence.forProtocol(
      _protocol(hint: true, transposition: true),
      referencePlaysCompleted: 1,
      pitchHintsUsed: 1,
      transpositionUsed: true,
    );

    expect(evidence.isIndependent, isFalse);
    expect(
      AttemptAssistanceEvidence.claimsIndependent({
        'referencePlays': 1,
        AttemptAssistanceEvidence.measurementKey: evidence.toJson(),
      }),
      isFalse,
    );
  });

  test('strict reader and conflicting legacy field fail closed', () {
    final valid = AttemptAssistanceEvidence.forProtocol(
      _protocol(),
      referencePlaysCompleted: 1,
    ).toJson();
    expect(
      () => AttemptAssistanceEvidence.fromJson({...valid, 'extra': true}),
      throwsFormatException,
    );
    expect(
      () =>
          AttemptAssistanceEvidence.fromJson({...valid, 'pitchHintsUsed': 1.0}),
      throwsFormatException,
    );
    expect(
      AttemptAssistanceEvidence.claimsIndependent({
        'referencePlays': 2,
        AttemptAssistanceEvidence.measurementKey: valid,
      }),
      isFalse,
    );
    expect(
      AttemptAssistanceEvidence.claimsIndependent({
        'referencePlays': 1,
        AttemptAssistanceEvidence.measurementKey: {'schemaVersion': 1},
      }),
      isFalse,
    );
  });

  test(
    'legacy results remain compatible but missing evidence is not unaided',
    () {
      expect(
        AttemptAssistanceEvidence.claimsIndependent({'referencePlays': 1}),
        isTrue,
      );
      expect(
        AttemptAssistanceEvidence.claimsIndependent({'referencePlays': 2}),
        isFalse,
      );
      expect(AttemptAssistanceEvidence.claimsIndependent(const {}), isFalse);
    },
  );
}
