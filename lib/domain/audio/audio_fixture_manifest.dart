import 'audio_fixture.dart';

class AudioFixtureEntry {
  AudioFixtureEntry({required this.fixture, required this.relativePath}) {
    final parts = relativePath.split('/');
    if (!relativePath.endsWith('.wav') ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(part),
        )) {
      throw ArgumentError('Fixtures require a portable relative WAV path');
    }
  }
  final AudioFixture fixture;
  final String relativePath;
  Map<String, Object?> toJson() => {
    'path': relativePath,
    'fixture': fixture.toJson(),
  };
}

/// Explicit file mapping: metadata alone does not locate or validate audio.
class AudioFixtureManifest {
  AudioFixtureManifest(List<AudioFixtureEntry> entries)
    : entries = List.unmodifiable(entries) {
    if (entries.isEmpty || entries.length > 1024) {
      throw ArgumentError('Manifest requires 1–1024 entries');
    }
    AudioFixture.validateManifest(entries.map((e) => e.fixture).toList());
    final paths = <String>{};
    for (final entry in entries) {
      // Portable policy: also reject aliases on case-insensitive file systems.
      if (!paths.add(entry.relativePath.toLowerCase())) {
        throw ArgumentError('Duplicate fixture path');
      }
    }
  }
  final List<AudioFixtureEntry> entries;
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'codec': 'mono_pcm16_wav',
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  factory AudioFixtureManifest.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] is! int ||
        json['schemaVersion'] != 1 ||
        json['codec'] != 'mono_pcm16_wav') {
      throw const FormatException('Unsupported fixture manifest version/codec');
    }
    try {
      final rawEntries = json['entries'] as List;
      if (rawEntries.isEmpty || rawEntries.length > 1024) {
        throw const FormatException('Manifest requires 1–1024 entries');
      }
      return AudioFixtureManifest(
        rawEntries.map((raw) {
          final entry = raw as Map<String, Object?>;
          return AudioFixtureEntry(
            relativePath: entry['path'] as String,
            fixture: AudioFixture.fromJson(
              entry['fixture'] as Map<String, Object?>,
            ),
          );
        }).toList(),
      );
    } on TypeError {
      throw const FormatException('Malformed manifest fields');
    } on ArgumentError {
      throw const FormatException('Invalid manifest entries');
    }
  }
}
