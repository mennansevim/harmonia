import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:harmonia/infrastructure/audio/reviewed_chord_recording_loader.dart';

Uint8List wav({int rate = 8000, int channels = 1, int frames = 800}) {
  final bytes = Uint8List(44 + frames * channels * 2);
  final view = ByteData.sublistView(bytes);
  void tag(int at, String value) => bytes.setRange(at, at + 4, value.codeUnits);
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  view.setUint32(4, bytes.length - 8, Endian.little);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, channels, Endian.little);
  view.setUint32(24, rate, Endian.little);
  view.setUint32(28, rate * channels * 2, Endian.little);
  view.setUint16(32, channels * 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  view.setUint32(40, frames * channels * 2, Endian.little);
  return bytes;
}

void main() {
  late Directory temporary;
  late Directory root;
  late Uint8List bytes;
  late ReviewedChordRecordingLoader loader;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'harmonia-reviewed-chord-loader-',
    );
    root = await Directory('${temporary.path}/chords').create();
    await Directory('${root.path}/2-notes').create();
    await Directory('${root.path}/3-notes').create();
    bytes = wav();
    await File('${root.path}/2-notes/c4-g4.wav').writeAsBytes(bytes);
    loader = ReviewedChordRecordingLoader(root: root);
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  ReviewedChordRecording recording({
    String id = 'c4-g4',
    String path = '2-notes/c4-g4.wav',
    String? hash,
    int rate = 8000,
    int channels = 1,
    int frames = 800,
  }) => ReviewedChordRecording(
    id: id,
    voiceCount: 2,
    relativePath: path,
    targetMidiNotes: const [60, 67],
    sha256: hash ?? sha256.convert(bytes).toString(),
    sampleRateHz: rate,
    channels: channels,
    sampleFrames: frames,
    a4Hz: 440,
    rightsReference: 'rights/self-recorded-v1',
    labelReviewReference: 'review/piano-labels-v1',
  );

  Matcher failure(ChordRecordingLoadFailure reason) => throwsA(
    isA<ChordRecordingLoadException>()
        .having((error) => error.failure, 'failure', reason)
        .having((error) => error.recordingId, 'id', 'c4-g4'),
  );

  test(
    'loads matching mono bytes and returns defensive playback copy',
    () async {
      final loaded = await loader.load(recording());
      expect(loaded.header.sampleRateHz, 8000);
      expect(loaded.header.channels, 1);
      expect(loaded.header.sampleFrames, 800);
      final copy = loaded.bytes;
      copy[0] = 0;
      expect(loaded.bytes[0], 'R'.codeUnitAt(0));
      expect(await File('${root.path}/2-notes/c4-g4.wav').readAsBytes(), bytes);
    },
  );

  test(
    'matching stereo PCM16 is supported without decoding or remixing',
    () async {
      bytes = wav(channels: 2);
      await File('${root.path}/2-notes/c4-g4.wav').writeAsBytes(bytes);
      final loaded = await loader.load(recording(channels: 2));
      expect(loaded.header.channels, 2);
      expect(loaded.header.sampleFrames, 800);
      expect(loaded.bytes, bytes);
    },
  );

  test(
    'missing root, file and file masquerading as root are explicit',
    () async {
      await expectLater(
        ReviewedChordRecordingLoader(
          root: Directory('${temporary.path}/missing'),
        ).load(recording()),
        failure(ChordRecordingLoadFailure.invalidRoot),
      );
      await expectLater(
        loader.load(recording(path: '2-notes/missing.wav')),
        failure(ChordRecordingLoadFailure.missingFile),
      );
      await expectLater(
        ReviewedChordRecordingLoader(
          root: Directory('${root.path}/2-notes/c4-g4.wav'),
        ).load(recording()),
        failure(ChordRecordingLoadFailure.invalidRoot),
      );
    },
  );

  test('hash mismatch stops before WAV acceptance', () async {
    await expectLater(
      loader.load(recording(hash: '0' * 64)),
      failure(ChordRecordingLoadFailure.hashMismatch),
    );
  });

  test('header rate channel and frame declarations must match', () async {
    await expectLater(
      loader.load(recording(rate: 16000, frames: 1600)),
      failure(ChordRecordingLoadFailure.sampleRateMismatch),
    );
    await expectLater(
      loader.load(recording(channels: 2)),
      failure(ChordRecordingLoadFailure.channelMismatch),
    );
    await expectLater(
      loader.load(recording(frames: 801)),
      failure(ChordRecordingLoadFailure.frameCountMismatch),
    );
  });

  test('matching hash cannot excuse malformed RIFF or PCM format', () async {
    for (final corrupt in <void Function(ByteData)>[
      (view) => view.setUint16(20, 3, Endian.little),
      (view) => view.setUint16(34, 24, Endian.little),
      (view) => view.setUint16(32, 4, Endian.little),
      (view) => view.setUint32(4, bytes.length, Endian.little),
    ]) {
      bytes = wav();
      corrupt(ByteData.sublistView(bytes));
      await File('${root.path}/2-notes/c4-g4.wav').writeAsBytes(bytes);
      await expectLater(
        loader.load(recording()),
        failure(ChordRecordingLoadFailure.invalidWav),
      );
    }
  });

  test('truncated data and odd frame bytes fail closed', () async {
    bytes = Uint8List.sublistView(wav(), 0, wav().length - 1);
    ByteData.sublistView(bytes).setUint32(4, bytes.length - 8, Endian.little);
    ByteData.sublistView(bytes).setUint32(40, bytes.length - 44, Endian.little);
    await File('${root.path}/2-notes/c4-g4.wav').writeAsBytes(bytes);
    await expectLater(
      loader.load(recording()),
      failure(ChordRecordingLoadFailure.invalidWav),
    );
  });

  test('byte budget is enforced before retaining playback bytes', () async {
    await expectLater(
      ReviewedChordRecordingLoader(
        root: root,
        maxFileBytes: 44,
      ).load(recording()),
      failure(ChordRecordingLoadFailure.oversizedFile),
    );
    expect(
      () => ReviewedChordRecordingLoader(root: root, maxFileBytes: 0),
      throwsArgumentError,
    );
  });

  test('final and parent symlinks are rejected', () async {
    await File('${temporary.path}/outside.wav').writeAsBytes(bytes);
    await Link(
      '${root.path}/2-notes/link.wav',
    ).create('${temporary.path}/outside.wav');
    await expectLater(
      loader.load(recording(path: '2-notes/link.wav')),
      failure(ChordRecordingLoadFailure.unsafePath),
    );
    await Directory('${root.path}/3-notes').delete();
    final outsideDirectory = await Directory(
      '${temporary.path}/outside-chords',
    ).create();
    await File('${outsideDirectory.path}/c4-e4-g4.wav').writeAsBytes(bytes);
    await Link('${root.path}/3-notes').create(outsideDirectory.path);
    final three = ReviewedChordRecording(
      id: 'c4-e4-g4',
      voiceCount: 3,
      relativePath: '3-notes/c4-e4-g4.wav',
      targetMidiNotes: const [60, 64, 67],
      sha256: sha256.convert(bytes).toString(),
      sampleRateHz: 8000,
      channels: 1,
      sampleFrames: 800,
      a4Hz: 440,
      rightsReference: 'rights/self-recorded-v1',
      labelReviewReference: 'review/piano-labels-v1',
    );
    await expectLater(
      loader.load(three),
      throwsA(
        isA<ChordRecordingLoadException>().having(
          (error) => error.failure,
          'failure',
          ChordRecordingLoadFailure.unsafePath,
        ),
      ),
    );
  });

  test('directory posing as WAV is unsafe', () async {
    await File('${root.path}/2-notes/c4-g4.wav').delete();
    await Directory('${root.path}/2-notes/c4-g4.wav').create();
    await expectLater(
      loader.load(recording()),
      failure(ChordRecordingLoadFailure.unsafePath),
    );
  });

  test(
    'manifest stream is sequential and fails before claiming completion',
    () async {
      final manifest = ReviewedChordRecordingManifest([
        recording(),
        ReviewedChordRecording(
          id: 'd4-a4',
          voiceCount: 2,
          relativePath: '2-notes/d4-a4.wav',
          targetMidiNotes: const [62, 69],
          sha256: 'b' * 64,
          sampleRateHz: 8000,
          channels: 1,
          sampleFrames: 800,
          a4Hz: 440,
          rightsReference: 'rights/self-recorded-v1',
          labelReviewReference: 'review/piano-labels-v1',
        ),
      ]);
      var delivered = 0;
      await expectLater(
        () async {
          await for (final _ in loader.loadManifest(manifest)) {
            delivered++;
          }
        },
        throwsA(
          isA<ChordRecordingLoadException>().having(
            (error) => error.failure,
            'failure',
            ChordRecordingLoadFailure.missingFile,
          ),
        ),
      );
      expect(delivered, 1);
    },
  );

  test('reportable failures never expose the private absolute root', () async {
    try {
      await loader.load(recording(path: '2-notes/missing.wav'));
      fail('Expected loader failure');
    } on ChordRecordingLoadException catch (error) {
      expect(error.toString(), isNot(contains(temporary.path)));
    }
  });
}
