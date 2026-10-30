import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/audio_fixture.dart';
import 'package:resonia/domain/audio/audio_fixture_manifest.dart';

AudioFixture fixture({String id = 's1', String hashChar = 'a'}) => AudioFixture(
  id: id,
  source: FixtureSource.synthetic,
  partition: FixturePartition.development,
  signal: FixtureSignal.tone,
  sampleRateHz: 48000,
  sampleCount: 4800,
  sha256: hashChar * 64,
  rightsReference: 'synthetic-generator-v1',
  expectedFrequenciesHz: [261.63],
);

void main() {
  test(
    'fixture and manifest round trip without inferring origin or permissions',
    () {
      final manifest = AudioFixtureManifest([
        AudioFixtureEntry(fixture: fixture(), relativePath: 'synthetic/c4.wav'),
      ]);
      final restored = AudioFixtureManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, Object?>,
      );
      expect(restored.toJson(), manifest.toJson());
      expect(restored.entries.single.fixture.source, FixtureSource.synthetic);
      expect(restored.entries.single.fixture.consentReference, isNull);
    },
  );
  test('unknown version and codec are rejected', () {
    final json = AudioFixtureManifest([
      AudioFixtureEntry(fixture: fixture(), relativePath: 'c4.wav'),
    ]).toJson();
    expect(
      () => AudioFixtureManifest.fromJson({...json, 'schemaVersion': 2}),
      throwsFormatException,
    );
    expect(
      () => AudioFixtureManifest.fromJson({...json, 'schemaVersion': 1.0}),
      throwsFormatException,
    );
    expect(
      () => AudioFixtureManifest.fromJson({...json, 'codec': 'aac'}),
      throwsFormatException,
    );
  });
  test(
    'paths reject traversal absolute URLs empty segments and platform aliases',
    () {
      for (final path in [
        '../c4.wav',
        '/c4.wav',
        'a/../c4.wav',
        './c4.wav',
        'a//c4.wav',
        r'C:\c4.wav',
        'https://example.com/c4.wav',
        'a/%2e%2e/c4.wav',
        'a/c4.mp3',
        '',
      ]) {
        expect(
          () => AudioFixtureEntry(fixture: fixture(), relativePath: path),
          throwsArgumentError,
          reason: path,
        );
      }
    },
  );
  test('case-insensitive duplicate paths are invalid', () {
    expect(
      () => AudioFixtureManifest([
        AudioFixtureEntry(fixture: fixture(), relativePath: 'C4.wav'),
        AudioFixtureEntry(
          fixture: fixture(id: 's2', hashChar: 'b'),
          relativePath: 'c4.wav',
        ),
      ]),
      throwsArgumentError,
    );
  });
  test('manifest snapshots entries and validates identities', () {
    final entries = [
      AudioFixtureEntry(fixture: fixture(), relativePath: 'c4.wav'),
    ];
    final manifest = AudioFixtureManifest(entries);
    entries.clear();
    expect(manifest.entries.length, 1);
    expect(() => manifest.entries.clear(), throwsUnsupportedError);
    expect(
      () => AudioFixtureManifest([
        manifest.entries.single,
        manifest.entries.single,
      ]),
      throwsArgumentError,
    );
  });
  test('malformed numeric fields and unsupported source fail closed', () {
    final json = fixture().toJson();
    for (final override in <Map<String, Object?>>[
      {'sampleRateHz': 48000.5},
      {'sampleCount': '4800'},
      {'source': 'verified'},
      {'a4Hz': double.nan},
      {
        'expectedFrequenciesHz': ['261'],
      },
    ]) {
      expect(
        () => AudioFixture.fromJson({...json, ...override}),
        throwsFormatException,
      );
    }
  });
  test(
    'empty or oversized manifest cannot silently count as valid dataset',
    () {
      expect(() => AudioFixtureManifest([]), throwsArgumentError);
      final entry = AudioFixtureEntry(
        fixture: fixture(),
        relativePath: 'c4.wav',
      );
      expect(
        () => AudioFixtureManifest(List.filled(1025, entry)),
        throwsArgumentError,
      );
    },
  );
  test(
    'deserialization still enforces real voice consent and holdout rules',
    () {
      final json = fixture().toJson();
      expect(
        () => AudioFixture.fromJson({
          ...json,
          'source': 'humanRecording',
          'signal': 'voice',
        }),
        throwsFormatException,
      );
      expect(
        () => AudioFixture.fromJson({...json, 'partition': 'holdout'}),
        throwsFormatException,
      );
    },
  );
}
