import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../infrastructure/storage/json_file_store.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/choir_access.dart';
import '../domain/resource.dart';
import '../domain/submission.dart';
import 'choir_remote.dart';

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

/// Choir data for the screens. Choirs made here or joined by package live on
/// the device (ADR-036). Online choirs (ADR-041, [onlineChoirIds]) are a
/// cached mirror of the server: changes go to [remote] first, then the
/// mirror is pulled again; files are fetched on first use ([ensureMedia]).
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

  /// The choir server, once the person signed in (ADR-041).
  ChoirRemote? remote;

  /// Choirs whose rows mirror the server.
  final onlineChoirIds = <String>{};

  bool isOnline(String choirId) =>
      remote != null && onlineChoirIds.contains(choirId);

  /// Who "I" am in [choirId]: the account on the server, this device's id
  /// elsewhere.
  String meId(String choirId) =>
      isOnline(choirId) ? (remote!.userId ?? myId) : myId;

  bool _mine(String memberId) =>
      memberId == myId ||
      (remote?.userId != null && memberId == remote!.userId);

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
    onlineChoirIds.addAll(
      ((doc['online'] as List<Object?>?) ?? const []).cast<String>(),
    );
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
    'online': onlineChoirIds.toList(),
  };

  Future<void> save() async {
    if (loadError != null) return;
    await persistence.write(_toJson());
    notifyListeners();
  }

  // Queries

  Choir? choir(String id) => choirs.where((c) => c.id == id).firstOrNull;
  bool isConductor(Choir c) => c.conductorId == meId(c.id);

  ChoirMember? meIn(String choirId) => members
      .where((m) => m.choirId == choirId && m.userId == meId(choirId))
      .firstOrNull;

  /// The rules of who hears and decides what (CHOIR-B).
  ChoirAccess accessIn(String choirId) => ChoirAccess([
    for (final m in members)
      if (m.choirId == choirId) m,
  ]);

  /// [s]'s recording may be played by me.
  bool canListen(Submission s) {
    final me = meIn(s.choirId);
    return me != null && accessIn(s.choirId).canListen(me, s);
  }

  /// I lead [s]'s part and it waits for me.
  bool leadsReview(Submission s) {
    final me = meIn(s.choirId);
    return me != null && accessIn(s.choirId).canLeaderAct(me, s);
  }

  /// I may close [s] now, as conductor or as its part's leader.
  bool canDecide(Submission s) {
    final me = meIn(s.choirId);
    if (me == null) return false;
    final access = accessIn(s.choirId);
    return access.canConductorReview(me, s) || access.canLeaderAct(me, s);
  }

  /// Sent takes of my part by others, newest first: what I may hear.
  List<Submission> partTakes(String assignmentId, String pieceId) =>
      submissions
          .where(
            (s) =>
                s.assignmentId == assignmentId &&
                s.pieceId == pieceId &&
                !_mine(s.memberId) &&
                s.status != SubmissionStatus.draft &&
                canListen(s),
          )
          .toList()
        ..sort((a, b) => b.submittedAt!.compareTo(a.submittedAt!));

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
            _mine(s.memberId),
      )
      .firstOrNull;

  List<Submission> submissionsOf(String assignmentId) => submissions
      .where(
        (s) =>
            s.assignmentId == assignmentId &&
            s.status != SubmissionStatus.draft,
      )
      .toList();

  /// Takes waiting for my decision, oldest first: the conductor's (only
  /// those that reached them), or a section leader's part.
  List<Submission> reviewQueue(String choirId) =>
      submissions.where((s) => s.choirId == choirId && canDecide(s)).toList()
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

  /// The local path of [id], fetched from the server first when this is an
  /// online choir's file not yet on the device.
  Future<String> ensureMedia(String id) async {
    final path = await mediaPath(id);
    final file = File(path);
    if (!await file.exists() && remote != null) {
      final part = File('$path.part');
      await remote!.download(id, part);
      await part.rename(path);
    }
    return path;
  }

  /// Gives a local file the server's media id, so it is never fetched back.
  Future<String> _adopt(String localId, String serverId) async {
    if (localId == serverId) return serverId;
    final from = File(await mediaPath(localId));
    final to = await mediaPath(serverId);
    if (await from.exists()) await from.rename(to);
    return serverId;
  }

  Future<String> _uploadLocal(
    String choirId,
    RemoteMediaKind kind,
    String localId, {
    String label = '',
    String? work,
    String? shelf,
    String? part,
  }) async {
    final id = await remote!.upload(
      choirId,
      kind,
      File(await mediaPath(localId)),
      label: label,
      work: work,
      shelf: shelf,
      part: part,
    );
    return _adopt(localId, id);
  }

  // Online mirror

  /// Replaces this device's copy of an online choir with the server's.
  /// My unsent drafts stay; personal library items a singer added stay.
  Future<void> applyOnline(OnlineSnapshot snap) async {
    final id = snap.choir.id;
    onlineChoirIds.add(id);
    final drafts = [
      for (final s in submissions)
        if (s.choirId == id &&
            s.status == SubmissionStatus.draft &&
            _mine(s.memberId))
          s,
    ];
    final me = remote?.userId ?? myId;
    final personal = snap.choir.conductorId == me
        ? const <ChoirResource>[]
        : [
            for (final r in resources)
              if (r.choirId == id && r.authorId == me) r,
          ];
    choirs
      ..removeWhere((c) => c.id == id)
      ..add(snap.choir);
    members
      ..removeWhere((m) => m.choirId == id)
      ..addAll(snap.members);
    references
      ..removeWhere((r) => r.choirId == id)
      ..addAll(snap.references);
    assignments
      ..removeWhere((a) => a.choirId == id)
      ..addAll(snap.assignments);
    resources
      ..removeWhere((r) => r.choirId == id)
      ..addAll(snap.resources)
      ..addAll(personal.where((p) => !snap.resources.any((r) => r.id == p.id)));
    submissions
      ..removeWhere((s) => s.choirId == id)
      ..addAll(snap.submissions);
    // A draft survives unless the server already has a newer sent take for
    // that piece (sent from another phone); a retake draft replaces the
    // returned one it came from.
    for (final d in drafts) {
      final server = submissions
          .where(
            (s) =>
                s.choirId == id &&
                s.assignmentId == d.assignmentId &&
                s.pieceId == d.pieceId &&
                _mine(s.memberId),
          )
          .firstOrNull;
      if (server == null) {
        submissions.add(d);
      } else if (server.status == SubmissionStatus.revisionRequested) {
        submissions
          ..remove(server)
          ..add(d);
      }
    }
    await save();
  }

  Future<void> syncOnline(String choirId) async {
    if (remote == null) return;
    await applyOnline(await remote!.pull(choirId));
  }

  /// Drops an online choir I no longer belong to (left, removed, deleted).
  Future<void> forgetOnline(String choirId) async {
    final choir = this.choir(choirId);
    onlineChoirIds.remove(choirId);
    if (choir != null) {
      await forgetChoir(choir);
    } else {
      await save();
    }
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
    String? work,
  }) async {
    var id = await addMedia(sourcePath, fileName);
    if (isOnline(choir.id)) {
      id = await _uploadLocal(
        choir.id,
        RemoteMediaKind.repertoire,
        id,
        label: fileName,
        work: work,
      );
    }
    final asset = ReferenceAsset(
      id: id,
      choirId: choir.id,
      kind: ReferenceKind.midi,
      fileName: fileName,
      rights: rights,
      uploadedAt: now.toUtc(),
      trackParts: trackParts,
    );
    if (isOnline(choir.id)) await remote!.putReference(asset);
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
    if (isOnline(assignment.choirId)) {
      await remote!.putAssignment(assignment);
    }
    assignments
      ..removeWhere((a) => a.id == assignment.id)
      ..add(assignment);
    await save();
  }

  Future<void> addResource(ChoirResource resource) async {
    var item = resource;
    final choir = this.choir(resource.choirId);
    // The conductor's library goes to the choir; a singer's stays personal.
    if (choir != null && isOnline(choir.id) && isConductor(choir)) {
      if (item.fileId != null) {
        item = ChoirResource(
          id: item.id,
          choirId: item.choirId,
          kind: item.kind,
          title: item.title,
          authorId: item.authorId,
          createdAt: item.createdAt,
          text: item.text,
          fileId: await _uploadLocal(
            choir.id,
            RemoteMediaKind.repertoire,
            item.fileId!,
            label: item.title,
            shelf: switch (item.kind) {
              ResourceKind.score => 'score',
              ResourceKind.rehearsalRecording => 'rehearsal',
              ResourceKind.note => 'other',
            },
          ),
          fileName: item.fileName,
          rehearsalOn: item.rehearsalOn,
        );
      }
      await remote!.putResource(item);
    }
    resources.add(item);
    await save();
  }

  Future<void> removeResource(ChoirResource resource) async {
    final choir = this.choir(resource.choirId);
    if (choir != null && isOnline(choir.id) && isConductor(choir)) {
      await remote!.deleteResource(resource);
    }
    resources.removeWhere((r) => r.id == resource.id);
    await deleteMedia(resource.fileId);
    await save();
  }

  Future<void> markListened(Submission s) async {
    final me = meIn(s.choirId);
    if (me == null || s.status != SubmissionStatus.submitted || !canDecide(s)) {
      return;
    }
    if (isOnline(s.choirId)) {
      // Best effort: listening is a hint, not a decision.
      try {
        await remote!.markListened(s);
      } catch (_) {}
    }
    _replace(s.markListened(me, now.toUtc()));
    await save();
  }

  /// A section leader forwards [submission] to the conductor or returns it
  /// for a retake (that needs a note).
  Future<Submission> leaderDecide({
    required Submission submission,
    required bool forward,
    String text = '',
    List<FeedbackTag> tags = const [],
    List<FeedbackMark> marks = const [],
    String? voiceNoteId,
  }) async {
    final me = meIn(submission.choirId)!;
    var voice = voiceNoteId;
    if (voice != null && isOnline(submission.choirId)) {
      voice = await _uploadVoice(submission, voice);
    }
    final next = forward
        ? submission.forward(
            leader: me,
            now: now.toUtc(),
            text: text,
            tags: tags,
            marks: marks,
            voiceNoteId: voice,
          )
        : submission.requestRetake(
            leader: me,
            now: now.toUtc(),
            text: text,
            tags: tags,
            marks: marks,
            voiceNoteId: voice,
          );
    if (isOnline(submission.choirId)) {
      await remote!.leaderDecide(
        submission,
        forward: forward,
        note: next.feedback.length > submission.feedback.length
            ? next.feedback.last
            : null,
      );
      await syncOnline(submission.choirId);
      return submissions.firstWhere((s) => s.id == submission.id);
    }
    _replace(next);
    await save();
    return next;
  }

  Future<Submission> review({
    required Submission submission,
    required ReviewOutcome outcome,
    String text = '',
    List<FeedbackTag> tags = const [],
    List<FeedbackMark> marks = const [],
    String? voiceNoteId,
  }) async {
    var voice = voiceNoteId;
    if (voice != null && isOnline(submission.choirId)) {
      voice = await _uploadVoice(submission, voice);
    }
    final next = submission.review(
      conductor: meIn(submission.choirId)!,
      outcome: outcome,
      now: now.toUtc(),
      text: text,
      tags: tags,
      marks: marks,
      voiceNoteId: voice,
    );
    if (isOnline(submission.choirId)) {
      await remote!.conductorReview(
        submission,
        accept: outcome == ReviewOutcome.accepted,
        note: next.feedback.last,
      );
      await syncOnline(submission.choirId);
      return submissions.firstWhere((s) => s.id == submission.id);
    }
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
  /// conductor received it. In an online choir it means uploaded and
  /// accepted by the server.
  Future<Submission> markSent(Submission draft) async {
    if (isOnline(draft.choirId)) return _sendOnline(draft);
    final next = draft.submit(now.toUtc());
    _replace(next);
    await save();
    return next;
  }

  /// The work a take belongs to, for its Drive folder.
  String? _workOf(Submission s) => assignments
      .where((a) => a.id == s.assignmentId)
      .firstOrNull
      ?.piece(s.pieceId)
      ?.title;

  /// A voice note goes beside the take it answers, named for its singer.
  Future<String> _uploadVoice(Submission s, String localId) => _uploadLocal(
    s.choirId,
    RemoteMediaKind.voiceNote,
    localId,
    work: _workOf(s),
    part: s.part.name,
    label:
        members
            .where((m) => m.choirId == s.choirId && m.userId == s.memberId)
            .firstOrNull
            ?.displayName ??
        '',
  );

  Future<Submission> _sendOnline(Submission draft) async {
    final assignment = assignments.firstWhere(
      (a) => a.id == draft.assignmentId,
    );
    final id = await _uploadLocal(
      draft.choirId,
      RemoteMediaKind.take,
      draft.recordingId!,
      work: _workOf(draft),
      label: '${assignment.title} · deneme ${draft.attempt}',
    );
    final withUpload = draft.clearRecording().attachRecording(
      assignment: assignment,
      recordingId: id,
      durationMs: draft.durationMs!,
      kind: draft.takeKind!,
    );
    // Keep the uploaded name locally until the server has it.
    _replace(withUpload);
    await save();
    await remote!.submitTake(withUpload.submit(now.toUtc()));
    await syncOnline(draft.choirId);
    return mySubmission(draft.assignmentId, draft.pieceId)!;
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
    onlineChoirIds.remove(choir.id);
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
    onlineChoirIds.clear();
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
