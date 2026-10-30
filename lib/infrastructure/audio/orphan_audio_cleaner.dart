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

/// Removes temp directories left by a crash/kill of earlier audio sessions.
/// Only `resonia-audio-lab-*` / `resonia-clip-*` directories directly in
/// the temp root are considered, only known file names inside them are
/// deleted, and a directory is removed only once empty. Never recursive.
/// Run at app start, before any audio screen creates its own directory.
class OrphanAudioCleaner {
  OrphanAudioCleaner(this._tempRoot);

  final Future<Directory> Function() _tempRoot;
  static const prefixes = ['resonia-audio-lab-', 'resonia-clip-'];
  static const knownFiles = {'recording.wav', 'reference.wav', 'clip.wav'};

  Future<OrphanCleanupReport> run() async {
    var removed = 0, kept = 0, failures = 0;
    final Directory root;
    try {
      root = await _tempRoot();
    } catch (_) {
      return const OrphanCleanupReport(failures: 1);
    }
    final List<FileSystemEntity> children;
    try {
      children = await root.list(followLinks: false).toList();
    } catch (_) {
      return const OrphanCleanupReport(failures: 1);
    }
    for (final entity in children) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is! Directory || !prefixes.any(name.startsWith)) continue;
      try {
        var unexpected = false;
        await for (final child in entity.list(followLinks: false)) {
          final childName = child.uri.pathSegments.last;
          if (child is File && knownFiles.contains(childName)) {
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
