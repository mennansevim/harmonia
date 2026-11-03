import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/models/exercise.dart';
import 'package:resonia/domain/models/exercise_protocol.dart';
import 'package:resonia/domain/models/exercise_protocol_fingerprint.dart';

ExerciseProtocol _protocol({
  List<double> rhythm = const [0, 1, 2],
  double tempo = 72,
  int recallDelayMs = 0,
  int maxReferencePlays = 2,
  bool allowPitchHint = false,
}) => ExerciseProtocol(
  mode: ExerciseMode.learning,
  notes: const [],
  rhythmOnsetsBeats: rhythm,
  tempoBpm: tempo,
  recallDelayMs: recallDelayMs,
  maxReferencePlays: maxReferencePlays,
  allowPitchHint: allowPitchHint,
);

void main() {
  test('fingerprint is stable across strict JSON round trip', () {
    final protocol = _protocol();
    final fingerprint = ExerciseProtocolFingerprint.compute(protocol);
    final restored = ExerciseProtocol.fromJson(protocol.toJson());

    expect(ExerciseProtocolFingerprint.isValid(fingerprint), isTrue);
    expect(ExerciseProtocolFingerprint.compute(restored), fingerprint);
  });

  test('stimulus and aid policy changes produce different identities', () {
    final base = ExerciseProtocolFingerprint.compute(_protocol());
    final variants = [
      _protocol(rhythm: const [0, 1, 2.5]),
      _protocol(tempo: 73),
      _protocol(recallDelayMs: 500),
      _protocol(maxReferencePlays: 3),
      _protocol(allowPitchHint: true),
    ];

    expect(
      variants.map(ExerciseProtocolFingerprint.compute).toSet(),
      hasLength(variants.length),
    );
    expect(
      variants.map(ExerciseProtocolFingerprint.compute),
      everyElement(isNot(base)),
    );
  });

  test('validator rejects unversioned, truncated and non-hex values', () {
    expect(ExerciseProtocolFingerprint.isValid('a' * 64), isFalse);
    expect(
      ExerciseProtocolFingerprint.isValid(
        '${ExerciseProtocolFingerprint.algorithm}:${'a' * 63}',
      ),
      isFalse,
    );
    expect(
      ExerciseProtocolFingerprint.isValid(
        '${ExerciseProtocolFingerprint.algorithm}:${'g' * 64}',
      ),
      isFalse,
    );
  });
}
