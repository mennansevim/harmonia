import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../domain/audio/reviewed_chord_recording_manifest.dart';

enum ChordRecordingLoadFailure {
  invalidRoot,
  missingFile,
  unsafePath,
  unreadableFile,
  oversizedFile,
  hashMismatch,
  invalidWav,
  sampleRateMismatch,
  channelMismatch,
  frameCountMismatch,
}

class ChordRecordingLoadException implements Exception {
  const ChordRecordingLoadException(this.failure, this.recordingId);

  final ChordRecordingLoadFailure failure;
  final String recordingId;

  @override
  String toString() =>
      'ChordRecordingLoadException(${failure.name}, $recordingId)';
}

class ChordWavHeader {
  const ChordWavHeader({
    required this.sampleRateHz,
    required this.channels,
    required this.sampleFrames,
  });

  final int sampleRateHz;
  final int channels;
  final int sampleFrames;
}

class LoadedChordRecording {
  LoadedChordRecording({
    required this.recording,
    required this.header,
    required Uint8List bytes,
  }) : _bytes = Uint8List.fromList(bytes);

  final ReviewedChordRecording recording;
  final ChordWavHeader header;
  final Uint8List _bytes;

  /// Defensive copy for a later player adapter; this loader never starts one.
  Uint8List get bytes => Uint8List.fromList(_bytes);
}

/// Read-only loader for an explicitly selected reviewed piano-recording root.
/// Hash/header matching does not verify note labels, rights or teaching value.
class ReviewedChordRecordingLoader {
  ReviewedChordRecordingLoader({
    required this.root,
    this.maxFileBytes = 4194304,
  }) {
    if (maxFileBytes < 44 || maxFileBytes > 8388608) {
      throw ArgumentError('Invalid chord recording byte budget');
    }
  }

  final Directory root;
  final int maxFileBytes;

  Future<LoadedChordRecording> load(ReviewedChordRecording recording) async {
    Never fail(ChordRecordingLoadFailure reason) =>
        throw ChordRecordingLoadException(reason, recording.id);

    String canonicalRoot;
    try {
      canonicalRoot = await root.resolveSymbolicLinks();
    } on FileSystemException {
      fail(ChordRecordingLoadFailure.invalidRoot);
    }
    if (await FileSystemEntity.type(canonicalRoot, followLinks: false) !=
        FileSystemEntityType.directory) {
      fail(ChordRecordingLoadFailure.invalidRoot);
    }

    var current = canonicalRoot;
    final parts = recording.relativePath.split('/');
    for (var i = 0; i < parts.length; i++) {
      current = p.join(current, parts[i]);
      if (!p.isWithin(canonicalRoot, current)) {
        fail(ChordRecordingLoadFailure.unsafePath);
      }
      FileSystemEntityType type;
      try {
        type = await FileSystemEntity.type(current, followLinks: false);
      } on FileSystemException {
        fail(ChordRecordingLoadFailure.unreadableFile);
      }
      if (type == FileSystemEntityType.link) {
        fail(ChordRecordingLoadFailure.unsafePath);
      }
      if (type == FileSystemEntityType.notFound) {
        fail(ChordRecordingLoadFailure.missingFile);
      }
      final expected = i == parts.length - 1
          ? FileSystemEntityType.file
          : FileSystemEntityType.directory;
      if (type != expected) fail(ChordRecordingLoadFailure.unsafePath);
    }

    final file = File(current);
    late Uint8List bytes;
    try {
      final resolved = await file.resolveSymbolicLinks();
      if (!p.isWithin(canonicalRoot, resolved) ||
          !p.equals(resolved, current)) {
        fail(ChordRecordingLoadFailure.unsafePath);
      }
      final handle = await file.open();
      try {
        final length = await handle.length();
        if (length > maxFileBytes) {
          fail(ChordRecordingLoadFailure.oversizedFile);
        }
        bytes = await handle.read(length);
        if (bytes.length != length || await handle.length() != length) {
          fail(ChordRecordingLoadFailure.unreadableFile);
        }
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      fail(ChordRecordingLoadFailure.unreadableFile);
    }

    if (sha256.convert(bytes).toString() != recording.sha256) {
      fail(ChordRecordingLoadFailure.hashMismatch);
    }
    late ChordWavHeader header;
    try {
      header = _decodeHeader(bytes);
    } on FormatException {
      fail(ChordRecordingLoadFailure.invalidWav);
    }
    if (header.sampleRateHz != recording.sampleRateHz) {
      fail(ChordRecordingLoadFailure.sampleRateMismatch);
    }
    if (header.channels != recording.channels) {
      fail(ChordRecordingLoadFailure.channelMismatch);
    }
    if (header.sampleFrames != recording.sampleFrames) {
      fail(ChordRecordingLoadFailure.frameCountMismatch);
    }
    return LoadedChordRecording(
      recording: recording,
      header: header,
      bytes: bytes,
    );
  }

  Stream<LoadedChordRecording> loadManifest(
    ReviewedChordRecordingManifest manifest,
  ) async* {
    for (final recording in manifest.recordings) {
      yield await load(recording);
    }
  }
}

ChordWavHeader _decodeHeader(Uint8List bytes) {
  if (bytes.length < 44 || bytes.length > 8388608) {
    throw const FormatException('Invalid chord WAV size');
  }
  final view = ByteData.sublistView(bytes);
  String tag(int at) => String.fromCharCodes(bytes.sublist(at, at + 4));
  if (tag(0) != 'RIFF' ||
      tag(8) != 'WAVE' ||
      view.getUint32(4, Endian.little) + 8 != bytes.length) {
    throw const FormatException('Invalid RIFF/WAVE header');
  }

  int? rate;
  int? channels;
  int? blockAlign;
  int? dataBytes;
  for (var at = 12; at < bytes.length;) {
    if (at + 8 > bytes.length) throw const FormatException('Truncated chunk');
    final length = view.getUint32(at + 4, Endian.little);
    final start = at + 8;
    final end = start + length;
    if (end + (length & 1) > bytes.length) {
      throw const FormatException('Truncated chunk data');
    }
    final chunk = tag(at);
    if (chunk == 'fmt ') {
      if (rate != null || length < 16) {
        throw const FormatException('Invalid format chunk');
      }
      final format = view.getUint16(start, Endian.little);
      channels = view.getUint16(start + 2, Endian.little);
      rate = view.getUint32(start + 4, Endian.little);
      final byteRate = view.getUint32(start + 8, Endian.little);
      blockAlign = view.getUint16(start + 12, Endian.little);
      final bits = view.getUint16(start + 14, Endian.little);
      if (format != 1 ||
          (channels != 1 && channels != 2) ||
          rate < 8000 ||
          rate > 48000 ||
          bits != 16 ||
          blockAlign != channels * 2 ||
          byteRate != rate * blockAlign) {
        throw const FormatException('Only mono/stereo PCM16 is supported');
      }
    } else if (chunk == 'data') {
      if (dataBytes != null) throw const FormatException('Duplicate data');
      dataBytes = length;
    }
    at = end + (length & 1);
  }
  if (rate == null ||
      channels == null ||
      blockAlign == null ||
      dataBytes == null ||
      dataBytes == 0 ||
      dataBytes % blockAlign != 0) {
    throw const FormatException('Missing or invalid PCM data');
  }
  return ChordWavHeader(
    sampleRateHz: rate,
    channels: channels,
    sampleFrames: dataBytes ~/ blockAlign,
  );
}
