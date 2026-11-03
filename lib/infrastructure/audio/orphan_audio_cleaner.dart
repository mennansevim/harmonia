import 'dart:io';

/// Result of a startup sweep; surfaced in Settings when anything failed.
class OrphanCleanupReport {
  const OrphanCleanupReport({
    this.removedDirectories = 0,
    this.keptDirectories = 0,
    this.failures = 0,
  });
  final int removedDirectories;

  /// Directories left alone because they held unexpected entries.
  final int keptDirectories;
  final int failures;
  bool get clean => keptDirectories == 0 && failures == 0;
}

/// Removes temp directories left by a crash/kill of earlier audio sessions,
/// and choir bundles left after sharing. Only directories with an app prefix
/// directly in the temp root are considered, only known file names inside
/// them are deleted, and a directory is removed only once empty. Never
/// recursive. Run at app start, before any audio screen creates its own
/// directory.
class OrphanAudioCleaner {
  OrphanAudioCleaner(this._tempRoot);

  final Future<Directory> Function() _tempRoot;
  static const prefixes = ['resonia-clip-', ...userDataPrefixes];

  /// Directories that can hold the user's voice or choir work. The clip
  /// directory is left out: it only holds synthesized sound and the trainer's
  /// long-lived player keeps writing to it.
  static const userDataPrefixes = [
    'resonia-audio-lab-',
    'choir-take-',
    'choir-practice-',
    'choir-voice-',
    'choir-bundle-',
  ];
  static const knownFiles = {
    'recording.wav',
    'reference.wav',
    'clip.wav',
    'vocal.wav',
    'accompaniment.wav',
    'take.wav',
    'voice.wav',
  };

  /// Same suffix as `bundleExtension`; storage stays free of the choir layer.
  static const bundleSuffix = '.resonia';
  static final _mixFile = RegExp(r'^mix-\d+\.wav$');

  static bool _isKnown(String name) =>
      knownFiles.contains(name) ||
      _mixFile.hasMatch(name) ||
      name.endsWith(bundleSuffix);

  /// Directories with one of [wanted] prefixes; null when the root is
  /// unreadable. Links are skipped, so nothing outside the root is touched.
  Future<List<Directory>?> _own(List<String> wanted) async {
    try {
      final root = await _tempRoot();
      final children = await root.list(followLinks: false).toList();
      return [
        for (final entity in children)
          if (entity is Directory &&
              wanted.any(
                entity.uri.pathSegments
                    .where((s) => s.isNotEmpty)
                    .last
                    .startsWith,
              ))
            entity,
      ];
    } catch (_) {
      return null;
    }
  }

  /// "Delete my data": removes [userDataPrefixes] directories whatever they
  /// hold. Unlike [run] this is recursive, so call it only while no audio
  /// screen is open.
  Future<OrphanCleanupReport> purge() async {
    final own = await _own(userDataPrefixes);
    if (own == null) return const OrphanCleanupReport(failures: 1);
    var removed = 0, failures = 0;
    for (final entity in own) {
      try {
        await entity.delete(recursive: true);
        removed++;
      } catch (_) {
        failures++;
      }
    }
    return OrphanCleanupReport(removedDirectories: removed, failures: failures);
  }

  Future<OrphanCleanupReport> run() async {
    var removed = 0, kept = 0, failures = 0;
    final own = await _own(prefixes);
    if (own == null) return const OrphanCleanupReport(failures: 1);
    for (final entity in own) {
      try {
        var unexpected = false;
        await for (final child in entity.list(followLinks: false)) {
          final childName = child.uri.pathSegments.last;
          if (child is File && _isKnown(childName)) {
            await child.delete();
          } else {
            unexpected = true;
          }
        }
        if (unexpected) {
          kept++;
        } else {
          await entity.delete();
          removed++;
        }
      } catch (_) {
        failures++;
      }
    }
    return OrphanCleanupReport(
      removedDirectories: removed,
      keptDirectories: kept,
      failures: failures,
    );
  }
}
