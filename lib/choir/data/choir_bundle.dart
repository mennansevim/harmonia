import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/resource.dart';
import '../domain/submission.dart';
import 'choir_store.dart';

/// `.harmonia` files: how a choir works with no server. The conductor shares
/// a choir package, singers send takes back, the conductor returns feedback.
/// Any channel the choir already uses carries them, and only a person's own
/// share action ever sends anything.
///
/// Bundles are not signed: this checks shape and consistency, not who made
/// the file. Real authorship needs accounts (CHOIR-B1).
enum BundleType { choir, submission, feedback }

enum BundleProblem {
  notABundle,
  tooLarge,
  damaged,
  newerVersion,
  ownChoir,
  unknownChoir,
  wrongChoir,
  notForYou,
}

class BundleRejected implements Exception {
  const BundleRejected(this.problem);
  final BundleProblem problem;
  @override
  String toString() => 'BundleRejected(${problem.name})';
}

enum BundleOutcome {
  /// A new choir: the person must give a name and part ([JoinPreview]).
  needsJoin,
  choirUpdated,
  takeReceived,
  feedbackReceived,

  /// Already here, or older than what is here.
  nothingNew,
}

class BundleResult {
  const BundleResult(this.outcome, {this.choir, this.preview});
  final BundleOutcome outcome;
  final Choir? choir;
  final JoinPreview? preview;
}

/// A choir package held back until the singer says who they are.
class JoinPreview {
  JoinPreview(this.choir, this._manifest, this._path);
  final Choir choir;
  final Map<String, Object?> _manifest;
  final String _path;
}

const bundleExtension = 'harmonia';
const maxBundleBytes = 512 << 20;
const _format = 'harmonia-choir';
const _schema = 1;

class ChoirBundles {
  ChoirBundles(this.store, this.workDirectory);

  final ChoirStore store;
  final Future<Directory> Function() workDirectory;

  // Writing

  Future<String> _write(
    BundleType type,
    Map<String, Object?> body,
    Iterable<String> mediaIds,
    String name,
  ) async {
    final ids = mediaIds.toSet();
    final files = <String, String>{};
    for (final id in ids) {
      final file = File(await store.mediaPath(id));
      files[id] = (await sha256.bind(file.openRead()).first).toString();
    }
    final manifest = {
      'format': _format,
      'schema': _schema,
      'type': type.name,
      'files': files,
      ...body,
    };
    final dir = await (await workDirectory()).createTemp('choir-bundle-');
    final path = '${dir.path}/$name.$bundleExtension';
    final encoder = ZipFileEncoder()..create(path, level: 0);
    encoder.addArchiveFile(
      ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))),
    );
    for (final id in ids) {
      await encoder.addFile(File(await store.mediaPath(id)), 'files/$id');
    }
    await encoder.close();
    return path;
  }

  static String _safeName(String text) {
    final clean = text
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    return clean.isEmpty
        ? 'koro'
        : clean.substring(0, clean.length > 40 ? 40 : clean.length);
  }

  /// What a singer needs: the assignments, their MIDI files, the library.
  Future<String> exportChoir(Choir choir) async {
    final refs = store.references.where((r) => r.choirId == choir.id).toList();
    final assignments = store.assignments.where((a) => a.choirId == choir.id);
    final resources = store.resources.where((r) => r.choirId == choir.id);
    final used = {for (final a in assignments) ...a.referenceIds};
    final shared = refs.where((r) => used.contains(r.id) && r.shareable);
    return _write(
      BundleType.choir,
      {
        'choir': choir.toJson(),
        'conductorName': store.meIn(choir.id)?.displayName,
        'references': [for (final r in shared) r.toJson()],
        'assignments': [for (final a in assignments) a.toJson()],
        'resources': [for (final r in resources) r.toJson()],
      },
      [
        ...shared.map((r) => r.id),
        for (final r in resources)
          if (r.fileId != null) r.fileId!,
      ],
      _safeName(choir.name),
    );
  }

  Future<String> exportSubmission(Submission s) => _write(
    BundleType.submission,
    {'submission': s.toJson(), 'member': store.meIn(s.choirId)!.toJson()},
    [s.recordingId!],
    _safeName('${store.myName ?? 'kayit'}-${s.part.name}'),
  );

  Future<String> exportFeedback(Submission s) => _write(
    BundleType.feedback,
    {'submission': s.toJson()},
    [
      for (final f in s.feedback)
        if (f.voiceNoteId != null) f.voiceNoteId!,
    ],
    _safeName('geri-bildirim-${s.part.name}'),
  );

  // Reading

  /// Validates and applies [path]. Nothing is stored unless the whole file
  /// checks out.
  Future<BundleResult> open(String path) async {
    final file = File(path);
    if (await file.length() > maxBundleBytes) {
      throw const BundleRejected(BundleProblem.tooLarge);
    }
    final manifest = await _readManifest(path);
    return switch (_type(manifest)) {
      BundleType.choir => _openChoir(manifest, path),
      BundleType.submission => _openSubmission(manifest, path),
      BundleType.feedback => _openFeedback(manifest, path),
    };
  }

  BundleType _type(Map<String, Object?> manifest) {
    if (manifest['format'] != _format) {
      throw const BundleRejected(BundleProblem.notABundle);
    }
    final schema = manifest['schema'];
    if (schema is! int || schema > _schema) {
      throw const BundleRejected(BundleProblem.newerVersion);
    }
    if (schema < 1) throw const BundleRejected(BundleProblem.damaged);
    final type = BundleType.values
        .where((t) => t.name == manifest['type'])
        .firstOrNull;
    if (type == null) throw const BundleRejected(BundleProblem.damaged);
    return type;
  }

  /// Runs a decoding step; bad JSON or broken rules mean a damaged file.
  T _decode<T>(T Function() read) {
    try {
      return read();
    } on FormatException {
      throw const BundleRejected(BundleProblem.damaged);
    } on ArgumentError {
      throw const BundleRejected(BundleProblem.damaged);
    } on TypeError {
      throw const BundleRejected(BundleProblem.damaged);
    } on StateError {
      throw const BundleRejected(BundleProblem.damaged);
    }
  }

  Future<Map<String, Object?>> _readManifest(String path) async {
    final input = InputFileStream(path);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const BundleRejected(BundleProblem.notABundle);
      }
      final entry = archive.findFile('manifest.json');
      if (entry == null || entry.size > 16 << 20) {
        throw const BundleRejected(BundleProblem.notABundle);
      }
      return _decode(
        () =>
            jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, Object?>,
      );
    } finally {
      await input.close();
    }
  }

  /// Copies only the media the manifest lists, each by verified hash, then
  /// moves them in together. Entry names are never used as paths.
  Future<void> _installFiles(
    String path,
    Map<String, Object?> manifest,
    Set<String> wanted,
  ) async {
    final listed = _decode(
      () => (manifest['files'] as Map<String, Object?>).cast<String, String>(),
    );
    if (!listed.keys.toSet().containsAll(wanted)) {
      throw const BundleRejected(BundleProblem.damaged);
    }
    final input = InputFileStream(path);
    final staged = <String, File>{};
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const BundleRejected(BundleProblem.damaged);
      }
      for (final id in wanted) {
        if (!mediaIdPattern.hasMatch(id)) {
          throw const BundleRejected(BundleProblem.damaged);
        }
        if (await File(await store.mediaPath(id)).exists()) continue;
        final entry = archive.findFile('files/$id');
        if (entry == null) throw const BundleRejected(BundleProblem.damaged);
        final bytes = entry.readBytes();
        if (bytes == null || sha256.convert(bytes).toString() != listed[id]) {
          throw const BundleRejected(BundleProblem.damaged);
        }
        final temp = File('${await store.mediaPath(id)}.part');
        await temp.writeAsBytes(bytes, flush: true);
        staged[id] = temp;
      }
      for (final e in staged.entries) {
        await e.value.rename(await store.mediaPath(e.key));
      }
    } catch (_) {
      for (final temp in staged.values) {
        if (await temp.exists()) await temp.delete();
      }
      rethrow;
    } finally {
      await input.close();
    }
  }

  List<T> _rows<T>(
    Map<String, Object?> manifest,
    String key,
    T Function(Map<String, Object?>) read,
  ) => _decode(
    () => [
      for (final row in manifest[key] as List<Object?>)
        read(row as Map<String, Object?>),
    ],
  );

  Future<BundleResult> _openChoir(
    Map<String, Object?> manifest,
    String path,
  ) async {
    final choir = _decode(
      () => Choir.fromJson(manifest['choir'] as Map<String, Object?>),
    );
    if (choir.conductorId == store.myId) {
      throw const BundleRejected(BundleProblem.ownChoir);
    }
    final known = store.choir(choir.id);
    if (known != null && known.conductorId != choir.conductorId) {
      throw const BundleRejected(BundleProblem.wrongChoir);
    }
    if (known == null || store.meIn(choir.id) == null) {
      return BundleResult(
        BundleOutcome.needsJoin,
        choir: choir,
        preview: JoinPreview(choir, manifest, path),
      );
    }
    await _mergeChoir(choir, manifest, path);
    return BundleResult(BundleOutcome.choirUpdated, choir: choir);
  }

  Future<void> _mergeChoir(
    Choir choir,
    Map<String, Object?> manifest,
    String path,
  ) async {
    final references = _rows(manifest, 'references', ReferenceAsset.fromJson);
    final assignments = _rows(manifest, 'assignments', Assignment.fromJson);
    final resources = _rows(manifest, 'resources', ChoirResource.fromJson);
    final sameChoir =
        references.every((r) => r.choirId == choir.id) &&
        assignments.every((a) => a.choirId == choir.id) &&
        resources.every((r) => r.choirId == choir.id);
    final refIds = references.map((r) => r.id).toSet();
    final complete = assignments.every(
      (a) => a.referenceIds.every(refIds.contains),
    );
    if (!sameChoir || !complete) {
      throw const BundleRejected(BundleProblem.damaged);
    }
    await _installFiles(path, manifest, {
      ...refIds,
      for (final r in resources)
        if (r.fileId != null) r.fileId!,
    });
    void upsert<T>(List<T> list, Iterable<T> fresh, Object? Function(T) id) {
      final ids = fresh.map(id).toSet();
      list
        ..removeWhere((e) => ids.contains(id(e)))
        ..addAll(fresh);
    }

    upsert(store.references, references, (r) => r.id);
    upsert(store.assignments, assignments, (a) => a.id);
    upsert(store.resources, resources, (r) => r.id);
    await store.save();
  }

  /// Finishes a [BundleOutcome.needsJoin]: the singer named themself.
  Future<void> join(
    JoinPreview preview, {
    required String displayName,
    required ChoirPart part,
  }) async {
    final choir = preview.choir;
    store.myName = displayName.trim();
    await _mergeChoir(choir, preview._manifest, preview._path);
    if (store.choir(choir.id) == null) store.choirs.add(choir);
    store.members
      ..removeWhere((m) => m.choirId == choir.id && m.userId == store.myId)
      ..add(
        ChoirMember(
          userId: store.myId,
          choirId: choir.id,
          displayName: store.myName!,
          role: ChoirRole.singer,
          part: part,
          joinedAt: store.now.toUtc(),
        ),
      );
    await store.save();
  }

  Future<BundleResult> _openSubmission(
    Map<String, Object?> manifest,
    String path,
  ) async {
    final incoming = _decode(
      () => Submission.fromJson(manifest['submission'] as Map<String, Object?>),
    );
    final member = _decode(
      () => ChoirMember.fromJson(manifest['member'] as Map<String, Object?>),
    );
    final choir = store.choir(incoming.choirId);
    if (choir == null) throw const BundleRejected(BundleProblem.unknownChoir);
    if (!store.isConductor(choir)) {
      throw const BundleRejected(BundleProblem.notForYou);
    }
    final assignment = store.assignments
        .where((a) => a.id == incoming.assignmentId)
        .firstOrNull;
    if (assignment?.choirId != choir.id ||
        assignment!.piece(incoming.pieceId) == null ||
        member.choirId != choir.id ||
        member.userId != incoming.memberId ||
        !member.isSinger ||
        incoming.status != SubmissionStatus.submitted ||
        incoming.recordingId == null) {
      throw const BundleRejected(BundleProblem.damaged);
    }
    final existing = store.submissions
        .where((s) => s.id == incoming.id)
        .firstOrNull;
    if (existing != null && existing.attempt >= incoming.attempt) {
      return BundleResult(BundleOutcome.nothingNew, choir: choir);
    }
    await _installFiles(path, manifest, {incoming.recordingId!});
    store.submissions
      ..removeWhere((s) => s.id == incoming.id)
      ..add(incoming);
    store.members
      ..removeWhere((m) => m.choirId == choir.id && m.userId == member.userId)
      ..add(member);
    await store.save();
    await store.deleteMedia(existing?.recordingId);
    return BundleResult(BundleOutcome.takeReceived, choir: choir);
  }

  Future<BundleResult> _openFeedback(
    Map<String, Object?> manifest,
    String path,
  ) async {
    final incoming = _decode(
      () => Submission.fromJson(manifest['submission'] as Map<String, Object?>),
    );
    final choir = store.choir(incoming.choirId);
    if (choir == null) throw const BundleRejected(BundleProblem.unknownChoir);
    if (incoming.memberId != store.myId) {
      throw const BundleRejected(BundleProblem.notForYou);
    }
    if (incoming.feedback.isEmpty ||
        incoming.feedback.any((f) => f.authorId != choir.conductorId)) {
      throw const BundleRejected(BundleProblem.damaged);
    }
    final existing = store.submissions
        .where((s) => s.id == incoming.id)
        .firstOrNull;
    if (existing != null &&
        (existing.attempt > incoming.attempt ||
            existing.feedback.length >= incoming.feedback.length)) {
      return BundleResult(BundleOutcome.nothingNew, choir: choir);
    }
    await _installFiles(path, manifest, {
      for (final f in incoming.feedback)
        if (f.voiceNoteId != null) f.voiceNoteId!,
    });
    // The singer's own copy of the take stays; the bundle has no audio of it.
    store.submissions
      ..removeWhere((s) => s.id == incoming.id)
      ..add(incoming);
    await store.save();
    return BundleResult(BundleOutcome.feedbackReceived, choir: choir);
  }
}
