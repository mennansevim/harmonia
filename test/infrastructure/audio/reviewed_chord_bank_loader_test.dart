import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/reviewed_chord_recording_manifest.dart';
import 'package:resonia/infrastructure/audio/reviewed_chord_bank_loader.dart';
import 'package:resonia/infrastructure/audio/reviewed_chord_recording_loader.dart';

Uint8List _wav(int marker) {
  const rate = 8000;
  const frames = 800;
  final bytes = Uint8List(44 + frames * 2);
  final view = ByteData.sublistView(bytes);
  void tag(int at, String value) => bytes.setRange(at, at + 4, value.codeUnits);
  tag(0, 'RIFF');
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  tag(36, 'data');
  view.setUint32(4, bytes.length - 8, Endian.little);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, rate, Endian.little);
  view.setUint32(28, rate * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  view.setUint32(40, frames * 2, Endian.little);
  view.setInt16(44, marker, Endian.little);
  return bytes;
}

void main() {
  late Directory temporary;
  late Directory root;
  late List<ReviewedChordRecording> recordings;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('resonia-chord-bank-');
    root = await Directory('${temporary.path}/bank').create();
    recordings = [];
    for (final voiceCount in const [2, 3, 4]) {
      final directory = await Directory(
        '${root.path}/$voiceCount-notes',
      ).create();
      final bytes = _wav(voiceCount);
      final id = 'reviewed-$voiceCount';
      await File('${directory.path}/$id.wav').writeAsBytes(bytes);
      recordings.add(
        ReviewedChordRecording(
          id: id,
          voiceCount: voiceCount,
          relativePath: '$voiceCount-notes/$id.wav',
          targetMidiNotes: const {
            2: [60, 67],
            3: [60, 64, 67],
            4: [60, 64, 67, 71],
          }[voiceCount]!,
          sha256: sha256.convert(bytes).toString(),
          sampleRateHz: 8000,
          channels: 1,
          sampleFrames: 800,
          a4Hz: 440,
          rightsReference: 'rights/self-recorded-v1',
          labelReviewReference: 'review/piano-labels-v1',
        ),
      );
    }
    await _writeManifest(root, recordings);
  });

  tearDown(() => temporary.delete(recursive: true));

  test('publishes complete 2/3/4 bank only after every WAV passes', () async {
    final bank = await ReviewedChordBankLoader(root: root).load();

    expect(bank.recordings.map((entry) => entry.recording.voiceCount), [
      2,
      3,
      4,
    ]);
    expect(bank.forVoiceCount(3).single.recording.targetMidiNotes, [
      60,
      64,
      67,
    ]);
    final copy = bank.recordings.first.bytes;
    copy[0] = 0;
    expect(bank.recordings.first.bytes[0], 'R'.codeUnitAt(0));
  });

  test('incomplete voice coverage cannot become an available bank', () async {
    await _writeManifest(root, recordings.take(2).toList());

    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.incompleteVoiceCoverage),
    );
  });

  test('one missing WAV rejects the whole bank with bounded detail', () async {
    await File('${root.path}/3-notes/reviewed-3.wav').delete();

    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      throwsA(
        isA<ChordBankLoadException>()
            .having(
              (error) => error.failure,
              'failure',
              ChordBankLoadFailure.invalidRecording,
            )
            .having((error) => error.recordingId, 'recording', 'reviewed-3')
            .having(
              (error) => error.recordingFailure,
              'recording failure',
              ChordRecordingLoadFailure.missingFile,
            ),
      ),
    );
  });

  test('malformed, oversized and missing manifests fail closed', () async {
    final manifest = File(
      '${root.path}/${ReviewedChordBankLoader.manifestFileName}',
    );
    await manifest.writeAsString('{broken');
    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.invalidManifest),
    );

    await manifest.writeAsString('x' * 40);
    await expectLater(
      ReviewedChordBankLoader(root: root, maxManifestBytes: 32).load(),
      _bankFailure(ChordBankLoadFailure.oversizedManifest),
    );

    await manifest.delete();
    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.missingManifest),
    );
  });

  test('invalid UTF-8 and unsupported schema are bounded failures', () async {
    final manifest = File(
      '${root.path}/${ReviewedChordBankLoader.manifestFileName}',
    );
    await manifest.writeAsBytes(const [0xC3, 0x28]);
    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.invalidManifest),
    );

    final unsupported = ReviewedChordRecordingManifest(recordings).toJson();
    unsupported['schemaVersion'] = 2;
    await manifest.writeAsString(jsonEncode(unsupported));
    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.invalidManifest),
    );
  });

  test('missing and file-shaped roots are explicit', () async {
    await expectLater(
      ReviewedChordBankLoader(
        root: Directory('${temporary.path}/missing'),
      ).load(),
      _bankFailure(ChordBankLoadFailure.invalidRoot),
    );
    final fileRoot = File('${temporary.path}/not-a-directory');
    await fileRoot.writeAsString('private');
    await expectLater(
      ReviewedChordBankLoader(root: Directory(fileRoot.path)).load(),
      _bankFailure(ChordBankLoadFailure.invalidRoot),
    );
  });

  test('manifest symlink and directory are never followed', () async {
    final manifestPath =
        '${root.path}/${ReviewedChordBankLoader.manifestFileName}';
    await File(manifestPath).delete();
    final outside = File('${temporary.path}/outside.json');
    await outside.writeAsString(
      jsonEncode(ReviewedChordRecordingManifest(recordings).toJson()),
    );
    await Link(manifestPath).create(outside.path);
    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.unsafeManifest),
    );

    await Link(manifestPath).delete();
    await Directory(manifestPath).create();
    await expectLater(
      ReviewedChordBankLoader(root: root).load(),
      _bankFailure(ChordBankLoadFailure.unsafeManifest),
    );
  });

  test('reportable errors never disclose the private root', () async {
    await File('${root.path}/4-notes/reviewed-4.wav').delete();
    try {
      await ReviewedChordBankLoader(root: root).load();
      fail('Expected a bank failure');
    } on ChordBankLoadException catch (error) {
      expect(error.toString(), isNot(contains(temporary.path)));
    }
  });
}

Future<void> _writeManifest(
  Directory root,
  List<ReviewedChordRecording> recordings,
) => File('${root.path}/${ReviewedChordBankLoader.manifestFileName}')
    .writeAsString(
      jsonEncode(ReviewedChordRecordingManifest(recordings).toJson()),
      flush: true,
    );

Matcher _bankFailure(ChordBankLoadFailure failure) => throwsA(
  isA<ChordBankLoadException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);
