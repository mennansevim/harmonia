import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../domain/audio/reviewed_chord_recording_manifest.dart';
import 'reviewed_chord_recording_loader.dart';

enum ChordBankLoadFailure {
  invalidRoot,
  missingManifest,
  unsafeManifest,
  unreadableManifest,
  oversizedManifest,
  invalidManifest,
  incompleteVoiceCoverage,
  invalidRecording,
}

class ChordBankLoadException implements Exception {
  const ChordBankLoadException(
    this.failure, {
    this.recordingId,
    this.recordingFailure,
  });

  final ChordBankLoadFailure failure;
  final String? recordingId;
  final ChordRecordingLoadFailure? recordingFailure;

  @override
  String toString() {
    final id = recordingId == null ? '' : ', $recordingId';
    final detail = recordingFailure == null
        ? ''
        : ', ${recordingFailure!.name}';
    return 'ChordBankLoadException(${failure.name}$id$detail)';
  }
}

/// Immutable bank published only after every manifest entry has passed its
/// hash/header/path checks. It does not imply musical, rights or educator QA.
class LoadedChordBank {
  LoadedChordBank({
    required this.manifest,
    required List<LoadedChordRecording> recordings,
  }) : recordings = List.unmodifiable(recordings) {
    if (recordings.length != manifest.recordings.length) {
      throw ArgumentError('Incomplete loaded chord bank');
    }
  }

  final ReviewedChordRecordingManifest manifest;
  final List<LoadedChordRecording> recordings;

  List<LoadedChordRecording> forVoiceCount(int voiceCount) => List.unmodifiable(
    recordings.where(
      (recording) => recording.recording.voiceCount == voiceCount,
    ),
  );
}

/// Loads one private reviewed bank from `<root>/reviewed_chords.json`.
///
/// The fixed direct-child manifest cannot redirect the loader outside [root].
/// No partial bank is observable: all 2/3/4 coverage and every WAV must pass
/// before [LoadedChordBank] is returned. This loader never starts audio IO.
class ReviewedChordBankLoader {
  ReviewedChordBankLoader({
    required this.root,
    this.maxManifestBytes = 262144,
    this.maxRecordingBytes = 4194304,
  }) {
    if (maxManifestBytes < 2 || maxManifestBytes > 1048576) {
      throw ArgumentError('Invalid chord manifest byte budget');
    }
    if (maxRecordingBytes < 44 || maxRecordingBytes > 8388608) {
      throw ArgumentError('Invalid chord recording byte budget');
    }
  }

  static const manifestFileName = 'reviewed_chords.json';

  final Directory root;
  final int maxManifestBytes;
  final int maxRecordingBytes;

  Future<LoadedChordBank> load() async {
    Never fail(
      ChordBankLoadFailure failure, {
      String? recordingId,
      ChordRecordingLoadFailure? recordingFailure,
    }) => throw ChordBankLoadException(
      failure,
      recordingId: recordingId,
      recordingFailure: recordingFailure,
    );

    String canonicalRoot;
    try {
      canonicalRoot = await root.resolveSymbolicLinks();
    } on FileSystemException {
      fail(ChordBankLoadFailure.invalidRoot);
    }
    FileSystemEntityType rootType;
    try {
      rootType = await FileSystemEntity.type(canonicalRoot, followLinks: false);
    } on FileSystemException {
      fail(ChordBankLoadFailure.invalidRoot);
    }
    if (rootType != FileSystemEntityType.directory) {
      fail(ChordBankLoadFailure.invalidRoot);
    }

    final manifestPath = p.join(canonicalRoot, manifestFileName);
    FileSystemEntityType type;
    try {
      type = await FileSystemEntity.type(manifestPath, followLinks: false);
    } on FileSystemException {
      fail(ChordBankLoadFailure.unreadableManifest);
    }
    if (type == FileSystemEntityType.notFound) {
      fail(ChordBankLoadFailure.missingManifest);
    }
    if (type != FileSystemEntityType.file) {
      fail(ChordBankLoadFailure.unsafeManifest);
    }

    final file = File(manifestPath);
    List<int> bytes;
    try {
      final resolved = await file.resolveSymbolicLinks();
      if (!p.equals(resolved, manifestPath) ||
          !p.isWithin(canonicalRoot, resolved)) {
        fail(ChordBankLoadFailure.unsafeManifest);
      }
      final handle = await file.open();
      try {
        final length = await handle.length();
        if (length < 2) fail(ChordBankLoadFailure.invalidManifest);
        if (length > maxManifestBytes) {
          fail(ChordBankLoadFailure.oversizedManifest);
        }
        bytes = await handle.read(length);
        if (bytes.length != length || await handle.length() != length) {
          fail(ChordBankLoadFailure.unreadableManifest);
        }
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      fail(ChordBankLoadFailure.unreadableManifest);
    }

    ReviewedChordRecordingManifest manifest;
    try {
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
      if (decoded is! Map) throw const FormatException('Manifest is not a map');
      manifest = ReviewedChordRecordingManifest.fromJson(
        decoded.cast<String, Object?>(),
      );
    } on Object catch (error) {
      if (error is ChordBankLoadException) rethrow;
      fail(ChordBankLoadFailure.invalidManifest);
    }

    final covered = manifest.recordings
        .map((recording) => recording.voiceCount)
        .toSet();
    if (!covered.containsAll(const {2, 3, 4})) {
      fail(ChordBankLoadFailure.incompleteVoiceCoverage);
    }

    final recordingLoader = ReviewedChordRecordingLoader(
      root: Directory(canonicalRoot),
      maxFileBytes: maxRecordingBytes,
    );
    final loaded = <LoadedChordRecording>[];
    for (final recording in manifest.recordings) {
      try {
        loaded.add(await recordingLoader.load(recording));
      } on ChordRecordingLoadException catch (error) {
        fail(
          ChordBankLoadFailure.invalidRecording,
          recordingId: error.recordingId,
          recordingFailure: error.failure,
        );
      }
    }
    return LoadedChordBank(manifest: manifest, recordings: loaded);
  }
}
