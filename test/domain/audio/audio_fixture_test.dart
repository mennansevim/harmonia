import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/audio_fixture.dart';

void main() {
  AudioFixture human({
    String id = 'h1',
    String hashChar = 'a',
    String? consent = 'consent-1',
    String? group = 'subject-opaque-1',
    FixturePartition partition = FixturePartition.development,
  }) => AudioFixture(
    id: id,
    source: FixtureSource.humanRecording,
    partition: partition,
    signal: FixtureSignal.voice,
    sampleRateHz: 48000,
    sampleCount: 48000,
    sha256: hashChar * 64,
    rightsReference: 'private-benchmark-permission-1',
    consentReference: consent,
    subjectGroup: group,
    expectedFrequenciesHz: [261.63],
  );
  test('real voice metadata requires explicit consent and subject group', () {
    expect(() => human(consent: null), throwsArgumentError);
    expect(() => human(group: null), throwsArgumentError);
    expect(human().source, FixtureSource.humanRecording);
  });
  test('same subject cannot appear in development and holdout', () {
    expect(
      () => AudioFixture.validateManifest([
        human(),
        human(id: 'h2', hashChar: 'b', partition: FixturePartition.holdout),
      ]),
      throwsArgumentError,
    );
    AudioFixture.validateManifest([
      human(),
      human(
        id: 'h2',
        hashChar: 'b',
        group: 'another-subject',
        partition: FixturePartition.holdout,
      ),
    ]);
  });
  test('duplicate identifiers or audio contents rejected', () {
    expect(
      () => AudioFixture.validateManifest([human(), human(id: 'h2')]),
      throwsArgumentError,
    );
    expect(
      () => AudioFixture.validateManifest([human(), human(hashChar: 'b')]),
      throwsArgumentError,
    );
  });
  test(
    'synthetic fixtures cannot satisfy real holdout or voice benchmarks',
    () {
      for (final signal in [FixtureSignal.voice, FixtureSignal.tone]) {
        expect(
          () => AudioFixture(
            id: 's',
            source: FixtureSource.synthetic,
            partition: FixturePartition.holdout,
            signal: signal,
            sampleRateHz: 48000,
            sampleCount: 0,
            sha256: 'c' * 64,
            rightsReference: 'generated',
          ),
          throwsArgumentError,
        );
      }
    },
  );
  test('unvoiced fixture cannot assert expected pitch', () {
    expect(
      () => AudioFixture(
        id: 's',
        source: FixtureSource.synthetic,
        partition: FixturePartition.development,
        signal: FixtureSignal.silence,
        sampleRateHz: 48000,
        sampleCount: 0,
        sha256: 'c' * 64,
        rightsReference: 'generated',
        expectedFrequenciesHz: [440],
      ),
      throwsArgumentError,
    );
  });
}
