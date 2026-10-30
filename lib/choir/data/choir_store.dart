import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../infrastructure/storage/json_file_store.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/resource.dart';
import '../domain/submission.dart';

abstract interface class ChoirPersistence {
  Future<Map<String, Object?>?> read();
  Future<void> write(Map<String, Object?> document);
  Future<void> delete();
}

class FileChoirPersistence implements ChoirPersistence {
  final _store = JsonFileStore(
    getApplicationSupportDirectory,
    'choir',
    maxBytes: 8 << 20,
  );
  @override
  Future<Map<String, Object?>?> read() => _store.read();
  @override
  Future<void> write(Map<String, Object?> document) => _store.write(document);
  @override
  Future<void> delete() => _store.delete();
}

class MemoryChoirPersistence implements ChoirPersistence {
  Map<String, Object?>? document;
  @override
  Future<Map<String, Object?>?> read() async => document;
  @override
  Future<void> write(Map<String, Object?> document) async =>
      this.document = document;
  @override
  Future<void> delete() async => document = null;
}

/// Media ids are the file names, so a bundle's id is checked against this
/// before it ever touches a path.
final mediaIdPattern = RegExp(r'^[a-f0-9]{16,64}\.[a-z0-9]{1,5}$');

/// On-device choir data (ADR-036 local-first). No server: every screen goes
/// through this class, and a future sync adapter replaces [ChoirPersistence]
/// and the bundle transport, not the screens.
class ChoirStore extends ChangeNotifier {
  ChoirStore({
    required this.persistence,
    required this.mediaRoot,
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  static const schema = 1;

  final ChoirPersistence persistence;
  final Future<Directory> Function() mediaRoot;
  final DateTime Function() _clock;
  final Random _random;

  DateTime get now => _clock();

  bool loaded = false;
  String? loadError;
  late String myId;
  String? myName;

  /// The singer agreed to their voice being recorded and shared with the
  /// conductor (asked once, before the first recording).
  bool recordingConsent = false;

  final choirs = <Choir>[];
  final members = <ChoirMember>[];
  final references = <ReferenceAsset>[];
  final assignments = <Assignment>[];
  final submissions = <Submission>[];
  final resources = <ChoirResource>[];

  String newHex() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> load() async {
    try {
      final doc = await persistence.read();
      if (doc == null) {
        myId = newHex();
      } else {
        _restore(doc);
      }
    } on FormatException catch (e) {
      // Never wipe unreadable data: the screen says so and writes nothing.
      myId = newHex();
      loadError = e.message;
    }
    loaded = true;
    notifyListeners();
  }

  void _restore(Map<String, Object?> doc) {
    if (doc['schema'] != schema) {
      throw const FormatException('Unknown choir schema');
    }
    myId = doc['myId'] as String;
    myName = doc['myName'] as String?;
    recordingConsent = doc['recordingConsent'] == true;
    Iterable<Map<String, Object?>> rows(String key) =>
        (doc[key] as List<Object?>).cast<Map<String, Object?>>();
    choirs.addAll(rows('choirs').map(Choir.fromJson));
    members.addAll(rows('members').map(ChoirMember.fromJson));
    references.addAll(rows('references').map(ReferenceAsset.fromJson));
    assignments.addAll(rows('assignments').map(Assignment.fromJson));
    submissions.addAll(rows('submissions').map(Submission.fromJson));
    resources.addAll(rows('resources').map(ChoirResource.fromJson));
  }

  Map<String, Object?> _toJson() => {
    'schema': schema,
    'myId': myId,
    'myName': myName,
    'recordingConsent': recordingConsent,
    'choirs': [for (final c in choirs) c.toJson()],
    'members': [for (final m in members) m.toJson()],
    'references': [for (final r in references) r.toJson()],
    'assignments': [for (final a in assignments) a.toJson()],
    'submissions': [for (final s in submissions) s.toJson()],
    'resources': [for (final r in resources) r.toJson()],
  };

  Future<void> save() async {
    if (loadError != null) return;
    await persistence.write(_toJson());
    notifyListeners();
  }

  // Queries

  Choir? choir(String id) => choirs.where((c) => c.id == id).firstOrNull;
  bool isConductor(Choir c) => c.conductorId == myId;

  ChoirMember? meIn(String choirId) => members
      .where((m) => m.choirId == choirId && m.userId == myId)
      .firstOrNull;

  List<ChoirMember> singersOf(String choirId) =>
      members.where((m) => m.choirId == choirId && m.isSinger).toList()
        ..sort((a, b) {
          final byPart = (a.part?.index ?? 9) - (b.part?.index ?? 9);
          return byPart != 0 ? byPart : a.displayName.compareTo(b.displayName);
        });

  ReferenceAsset? reference(String id) =>
      references.where((r) => r.id == id).firstOrNull;

  /// Soonest due first; those with no due date last.
  List<Assignment> assignmentsOf(String choirId) =>
      assignments.where((a) => a.choirId == choirId).toList()..sort((a, b) {
        if (a.dueAt == null || b.dueAt == null) {
          return a.dueAt == b.dueAt
              ? b.createdAt.compareTo(a.createdAt)
              : a.dueAt == null
              ? 1
              : -1;
        }
        return a.dueAt!.compareTo(b.dueAt!);
      });

  List<ChoirResource> resourcesOf(String choirId) =>
      resources.where((r) => r.choirId == choirId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Submission? mySubmission(String assignmentId, String pieceId) => submissions
      .where(
        (s) =>
            s.assignmentId == assignmentId &&
            s.pieceId == pieceId &&
            s.memberId == myId,
      )
      .firstOrNull;

  List<Submission> submissionsOf(String assignmentId) => submissions
      .where(
        (s) =>
            s.assignmentId == assignmentId &&
            s.status != SubmissionStatus.draft,
      )
      .toList();

  /// Takes still waiting for the conductor, oldest first.
  List<Submission> reviewQueue(String choirId) =>
      submissions
          .where((s) => s.choirId == choirId && s.awaitsConductor)
          .toList()
        ..sort((a, b) => a.submittedAt!.compareTo(b.submittedAt!));

  /// A singer's work still to send, soonest due first, for the Today card.
  (Choir, Assignment)? nextDue() {
    (Choir, Assignment)? best;
    for (final choir in choirs) {
      final me = meIn(choir.id);
      if (me == null || !me.isSinger || me.part == null) continue;
      for (final a in assignmentsOf(choir.id)) {
        if (a.dueAt == null || !a.includes(me.part!) || a.isLate(now)) continue;
        final open = a.pieces.any((p) {
          final s = mySubmission(a.id, p.id);
          return s == null ||
              s.status == SubmissionStatus.draft ||
              s.status == SubmissionStatus.revisionRequested;
        });
        if (!open) continue;
        if (best == null || a.dueAt!.isBefore(best.$2.dueAt!)) {
          best = (choir, a);
        }
      }
    }
    return best;
  }

  // Media

  Future<Directory> _mediaDir() async {
    final dir = Directory('${(await mediaRoot()).path}/choir_media');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> mediaPath(String id) async {
    if (!mediaIdPattern.hasMatch(id)) throw ArgumentError('Bad media id');
    return '${(await _mediaDir()).path}/$id';
  }

  /// Copies a picked or recorded file in; the source is left alone.
  Future<String> addMedia(String sourcePath, String fileName) async {
    final dot = fileName.lastIndexOf('.');
    final raw = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    final ext = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(raw) ? raw : 'bin';
    final id = '${newHex()}.$ext';
    await File(sourcePath).copy(await mediaPath(id));
    return id;
  }

  Future<void> deleteMedia(String? id) async {
    if (id == null) return;
    final file = File(await mediaPath(id));
    if (await file.exists()) await file.delete();
  }

  // Conductor

  Future<Choir> createChoir(String name, String conductorName) async {
    myName = conductorName.trim();
    final choir = Choir(
      id: newHex(),
      name: name.trim(),
      conductorId: myId,
      createdAt: now.toUtc(),
    );
    choirs.add(choir);
    members.add(
      ChoirMember(
        userId: myId,
        choirId: choir.id,
        displayName: myName!,
        role: ChoirRole.conductor,
        joinedAt: now.toUtc(),
      ),
    );
    await save();
    return choir;
  }

  Future<ReferenceAsset> addMidi({
    required Choir choir,
    required String sourcePath,
    required String fileName,
    required RightsDeclaration rights,
    required Map<int, ChoirPart> trackParts,
  }) async {
    final asset = ReferenceAsset(
      id: await addMedia(sourcePath, fileName),
      choirId: choir.id,
      kind: ReferenceKind.midi,
      fileName: fileName,
      rights: rights,
      uploadedAt: now.toUtc(),
      trackParts: trackParts,
    );
    references.add(asset);
    await save();
    return asset;
  }

  /// Throws [ArgumentError] when a file is missing or has no declared right
  /// to be shared.
  Future<void> publish(Assignment assignment) async {
    final problems = assignment.publishProblems({
      for (final r in references) r.id: r,
    });
    if (problems.isNotEmpty) throw ArgumentError(problems.join('; '));
    assignments
      ..removeWhere((a) => a.id == assignment.id)
      ..add(assignment);
    await save();
  }

  Future<void> addResource(ChoirResource resource) async {
    resources.add(resource);
    await save();
  }

  Future<void> removeResource(ChoirResource resource) async {
    resources.removeWhere((r) => r.id == resource.id);
    await deleteMedia(resource.fileId);
    await save();
  }

  Future<void> markListened(Submission s) async {
    final me = meIn(s.choirId);
    if (me == null || s.status != SubmissionStatus.submitted) return;
    _replace(s.markListened(me, now.toUtc()));
    await save();
  }

  Future<Submission> review({
    required Submission submission,
    required ReviewOutcome outcome,
    String text = '',
    List<FeedbackTag> tags = const [],
    List<FeedbackMark> marks = const [],
    String? voiceNoteId,
  }) async {
    final next = submission.review(
      conductor: meIn(submission.choirId)!,
      outcome: outcome,
      now: now.toUtc(),
      text: text,
      tags: tags,
      marks: marks,
      voiceNoteId: voiceNoteId,
    );
    _replace(next);
    await save();
    return next;
  }

  void _replace(Submission next) {
    final at = submissions.indexWhere((s) => s.id == next.id);
    if (at < 0) {
      submissions.add(next);
    } else {
      submissions[at] = next;
    }
  }

  // Singer

  Future<void> setConsent() async {
    recordingConsent = true;
    await save();
  }

  /// Keeps a take as the draft of this piece, replacing any earlier one.
  /// After a revision request this opens the next attempt.
  Future<Submission> keepTake({
    required Assignment assignment,
    required AssignmentPiece piece,
    required String sourcePath,
    required String fileName,
    required int durationMs,
    required TakeKind kind,
  }) async {
    var draft = mySubmission(assignment.id, piece.id);
    final previous = draft?.recordingId;
    if (draft?.status == SubmissionStatus.revisionRequested) {
      draft = draft!.retake();
    }
    draft ??= Submission.start(
      id: newHex(),
      assignment: assignment,
      pieceId: piece.id,
      member: meIn(assignment.choirId)!,
    );
    final id = await addMedia(sourcePath, fileName);
    final next = draft.clearRecording().attachRecording(
      assignment: assignment,
      recordingId: id,
      durationMs: durationMs,
      kind: kind,
    );
    _replace(next);
    await save();
    await deleteMedia(previous);
    return next;
  }

  /// The singer deletes an unsent take.
  Future<void> discardTake(Submission draft) async {
    await deleteMedia(draft.recordingId);
    _replace(draft.clearRecording());
    await save();
  }

  /// Sent means handed to the OS share sheet; the app cannot know that the
  /// conductor received it.
  Future<Submission> markSent(Submission draft) async {
    final next = draft.submit(now.toUtc());
    _replace(next);
    await save();
    return next;
  }

  /// Leaves a choir and removes everything of it from this device.
  Future<void> forgetChoir(Choir choir) async {
    final ids = <String?>[
      ...references.where((r) => r.choirId == choir.id).map((r) => r.id),
      ...resources.where((r) => r.choirId == choir.id).map((r) => r.fileId),
      for (final s in submissions.where((s) => s.choirId == choir.id)) ...[
        s.recordingId,
        ...s.feedback.map((f) => f.voiceNoteId),
      ],
    ];
    choirs.removeWhere((c) => c.id == choir.id);
    members.removeWhere((m) => m.choirId == choir.id);
    references.removeWhere((r) => r.choirId == choir.id);
    assignments.removeWhere((a) => a.choirId == choir.id);
    submissions.removeWhere((s) => s.choirId == choir.id);
    resources.removeWhere((r) => r.choirId == choir.id);
    await Future.wait(ids.map(deleteMedia));
    await save();
  }

  /// "Delete my data": everything, including the media folder.
  Future<void> clearAll() async {
    choirs.clear();
    members.clear();
    references.clear();
    assignments.clear();
    submissions.clear();
    resources.clear();
    myName = null;
    recordingConsent = false;
    myId = newHex();
    loadError = null;
    final dir = await _mediaDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    await persistence.delete();
    notifyListeners();
  }
}
