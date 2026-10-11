import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../domain/audio/audio_fixture_manifest.dart';
import 'pcm16_wav.dart';

enum FixtureLoadFailure {
  invalidRoot,
  missingFile,
  unsafePath,
  unreadableFile,
  oversizedFile,
  hashMismatch,
  invalidWav,
  sampleRateMismatch,
  sampleCountMismatch,
}

/// No absolute path/recording content is exposed in a reportable error.
class FixtureLoadException implements Exception {
  const FixtureLoadException(this.failure, this.fixtureId);
  final FixtureLoadFailure failure;
  final String fixtureId;
  @override
  String toString() => 'FixtureLoadException(${failure.name}, $fixtureId)';
}

class LoadedAudioFixture {
  const LoadedAudioFixture({required this.entry, required this.wav});
  final AudioFixtureEntry entry;
  final Pcm16Wav wav;
  // Hash/header validation is NOT validation of labels, consent or licenses.
}

/// Read-only, IO fixture loader for an explicitly selected private dataset root.
/// Rejects symlink components and escaping paths; not a hostile-process sandbox.
class AudioFixtureLoader {
  AudioFixtureLoader({required this.root, this.maxFileBytes = 4224044}) {
    if (maxFileBytes < 44 || maxFileBytes > 46080044) {
      throw ArgumentError('Invalid fixture byte budget');
    }
  }
  final Directory root;
  final int maxFileBytes;

  Future<LoadedAudioFixture> load(AudioFixtureEntry entry) async {
    final id = entry.fixture.id;
    Never fail(FixtureLoadFailure reason) =>
        throw FixtureLoadException(reason, id);
    String canonicalRoot;
    try {
      canonicalRoot = await root.resolveSymbolicLinks();
    } on FileSystemException {
      fail(FixtureLoadFailure.invalidRoot);
    }
    if (await FileSystemEntity.type(canonicalRoot, followLinks: false) !=
        FileSystemEntityType.directory) {
      fail(FixtureLoadFailure.invalidRoot);
    }
    var current = canonicalRoot;
    final parts = entry.relativePath.split('/');
    for (var i = 0; i < parts.length; i++) {
      current = p.join(current, parts[i]);
      if (!p.isWithin(canonicalRoot, current)) {
        fail(FixtureLoadFailure.unsafePath);
      }
      FileSystemEntityType type;
      try {
        type = await FileSystemEntity.type(current, followLinks: false);
      } on FileSystemException {
        fail(FixtureLoadFailure.unreadableFile);
      }
      if (type == FileSystemEntityType.link) {
        fail(FixtureLoadFailure.unsafePath);
      }
      if (type == FileSystemEntityType.notFound) {
        fail(FixtureLoadFailure.missingFile);
      }
      if (type !=
          (i == parts.length - 1
              ? FileSystemEntityType.file
              : FileSystemEntityType.directory)) {
        fail(FixtureLoadFailure.unsafePath);
      }
    }
    final file = File(current);
    Uint8List bytes;
    try {
      final resolved = await file.resolveSymbolicLinks();
      if (!p.isWithin(canonicalRoot, resolved) ||
          !p.equals(resolved, current)) {
        fail(FixtureLoadFailure.unsafePath);
      }
      final handle = await file.open();
      try {
        final length = await handle.length();
        if (length > maxFileBytes) fail(FixtureLoadFailure.oversizedFile);
        bytes = await handle.read(length);
        if (bytes.length != length || await handle.length() != length) {
          fail(FixtureLoadFailure.unreadableFile);
        }
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      fail(FixtureLoadFailure.unreadableFile);
    }
    if (sha256.convert(bytes).toString() != entry.fixture.sha256) {
      fail(FixtureLoadFailure.hashMismatch);
    }
    Pcm16Wav wav;
    try {
      wav = Pcm16Wav.decode(bytes);
    } on FormatException {
      fail(FixtureLoadFailure.invalidWav);
    }
    if (wav.sampleRateHz != entry.fixture.sampleRateHz) {
      fail(FixtureLoadFailure.sampleRateMismatch);
    }
    if (wav.samples.length != entry.fixture.sampleCount) {
      fail(FixtureLoadFailure.sampleCountMismatch);
    }
    return LoadedAudioFixture(entry: entry, wav: wav);
  }

  /// Sequential and fail-fast; callers must finish the stream before declaring
  /// the whole dataset valid. Avoid retaining every decoded PCM in memory.
  Stream<LoadedAudioFixture> loadManifest(
    AudioFixtureManifest manifest,
  ) async* {
    for (final entry in manifest.entries) {
      yield await load(entry);
    }
  }
}
