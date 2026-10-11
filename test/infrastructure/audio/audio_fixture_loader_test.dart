import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/audio_fixture.dart';
import 'package:harmonia/domain/audio/audio_fixture_manifest.dart';
import 'package:harmonia/infrastructure/audio/audio_fixture_loader.dart';
import 'package:harmonia/infrastructure/audio/pcm16_wav.dart';

void main() {
  late Directory temporary;
  late Directory root;
  late Uint8List bytes;
  late AudioFixtureLoader loader;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'harmonia-fixture-loader-test-',
    );
    root = await Directory('${temporary.path}/dataset').create();
    bytes = Pcm16Wav.tone(
      frequencyHz: 261.63,
      sampleRateHz: 44100,
      durationSeconds: .1,
    ).encode();
    await File('${root.path}/c4.wav').writeAsBytes(bytes);
    loader = AudioFixtureLoader(root: root);
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });
  AudioFixtureEntry entry({
    String id = 's1',
    String path = 'c4.wav',
    String? hash,
    int rate = 44100,
    int count = 4410,
  }) => AudioFixtureEntry(
    relativePath: path,
    fixture: AudioFixture(
      id: id,
      source: FixtureSource.synthetic,
      partition: FixturePartition.development,
      signal: FixtureSignal.tone,
      sampleRateHz: rate,
      sampleCount: count,
      sha256: hash ?? sha256.convert(bytes).toString(),
      rightsReference: 'synthetic-generator-v1',
      expectedFrequenciesHz: [261.63],
    ),
  );
  Matcher failure(FixtureLoadFailure reason) => throwsA(
    isA<FixtureLoadException>()
        .having((e) => e.failure, 'failure', reason)
        .having((e) => e.fixtureId, 'id', 's1'),
  );

  test(
    'reads matching file hash and real header without changing dataset',
    () async {
      final loaded = await loader.load(entry());
      expect(loaded.wav.sampleRateHz, 44100);
      expect(loaded.wav.samples.length, 4410);
      expect(loaded.entry.fixture.source, FixtureSource.synthetic);
      expect(await File('${root.path}/c4.wav').readAsBytes(), bytes);
    },
  );
  test('missing file is explicit instead of silently skipped', () async {
    await expectLater(
      loader.load(entry(path: 'missing.wav')),
      failure(FixtureLoadFailure.missingFile),
    );
  });
  test('missing root and file masquerading as root rejected', () async {
    await expectLater(
      AudioFixtureLoader(
        root: Directory('${temporary.path}/missing'),
      ).load(entry()),
      failure(FixtureLoadFailure.invalidRoot),
    );
    await expectLater(
      AudioFixtureLoader(root: Directory('${root.path}/c4.wav')).load(entry()),
      failure(FixtureLoadFailure.invalidRoot),
    );
  });
  test('tampered hash fails before decoding or scoring', () async {
    await expectLater(
      loader.load(entry(hash: '0' * 64)),
      failure(FixtureLoadFailure.hashMismatch),
    );
  });
  test('header sample rate cannot be overwritten by manifest', () async {
    await expectLater(
      loader.load(entry(rate: 48000)),
      failure(FixtureLoadFailure.sampleRateMismatch),
    );
  });
  test('sample count and duration evidence must match actual PCM', () async {
    await expectLater(
      loader.load(entry(count: 4409)),
      failure(FixtureLoadFailure.sampleCountMismatch),
    );
  });
  test('matching hash does not excuse truncated WAV', () async {
    bytes = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    await File('${root.path}/c4.wav').writeAsBytes(bytes);
    await expectLater(
      loader.load(entry()),
      failure(FixtureLoadFailure.invalidWav),
    );
  });
  test('matching hash does not excuse stereo unsupported codec', () async {
    ByteData.sublistView(bytes).setUint16(22, 2, Endian.little);
    await File('${root.path}/c4.wav').writeAsBytes(bytes);
    await expectLater(
      loader.load(entry()),
      failure(FixtureLoadFailure.invalidWav),
    );
  });
  test('byte budget enforced before reading PCM', () async {
    await expectLater(
      AudioFixtureLoader(root: root, maxFileBytes: 44).load(entry()),
      failure(FixtureLoadFailure.oversizedFile),
    );
    expect(
      () => AudioFixtureLoader(root: root, maxFileBytes: 0),
      throwsArgumentError,
    );
  });
  test('final symlink outside root rejected', () async {
    await File('${temporary.path}/outside.wav').writeAsBytes(bytes);
    await Link('${root.path}/link.wav').create('${temporary.path}/outside.wav');
    await expectLater(
      loader.load(entry(path: 'link.wav')),
      failure(FixtureLoadFailure.unsafePath),
    );
  });
  test('parent symlink and internal aliases rejected', () async {
    await Link('${root.path}/parent').create(temporary.path);
    await expectLater(
      loader.load(entry(path: 'parent/anything.wav')),
      failure(FixtureLoadFailure.unsafePath),
    );
    await Link('${root.path}/alias.wav').create('${root.path}/c4.wav');
    await expectLater(
      loader.load(entry(path: 'alias.wav')),
      failure(FixtureLoadFailure.unsafePath),
    );
  });
  test(
    'directories posing as WAV and file parent components rejected',
    () async {
      await Directory('${root.path}/folder.wav').create();
      await expectLater(
        loader.load(entry(path: 'folder.wav')),
        failure(FixtureLoadFailure.unsafePath),
      );
      await expectLater(
        loader.load(entry(path: 'c4.wav/child.wav')),
        failure(FixtureLoadFailure.unsafePath),
      );
    },
  );
  test('nested files are supported inside selected root', () async {
    await Directory('${root.path}/synthetic').create();
    await File('${root.path}/synthetic/c4.wav').writeAsBytes(bytes);
    expect(
      (await loader.load(entry(path: 'synthetic/c4.wav'))).wav.samples.length,
      4410,
    );
  });
  test(
    'manifest stream stops on bad entry rather than claiming whole dataset valid',
    () async {
      final manifest = AudioFixtureManifest([
        entry(),
        entry(id: 's2', path: 'missing.wav', hash: 'b' * 64),
      ]);
      var delivered = 0;
      await expectLater(
        () async {
          await for (final _ in loader.loadManifest(manifest)) {
            delivered++;
          }
        },
        throwsA(
          isA<FixtureLoadException>().having(
            (e) => e.failure,
            'failure',
            FixtureLoadFailure.missingFile,
          ),
        ),
      );
      expect(delivered, 1);
    },
  );
  test('reportable errors do not include absolute private paths', () async {
    try {
      await loader.load(entry(path: 'missing.wav'));
      fail('Expected fixture error');
    } on FixtureLoadException catch (error) {
      expect(error.toString(), isNot(contains(temporary.path)));
    }
  });
}
