import 'dart:io';
import 'dart:math';

import 'package:resonia/choir/data/choir_remote.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/choir_access.dart';
import 'package:resonia/choir/domain/resource.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/choir/online/choir_backend.dart';

import 'fake_choir_backend.dart';

/// Files and work of the fake server: what the SQL functions and the media
/// Edge Function hold, with the same rules (ChoirAccess).
class FakeWorkServer {
  FakeWorkServer(this.server, this.dir);
  final FakeChoirServer server;
  final Directory dir;

  final references = <ReferenceAsset>[];
  final resources = <ChoirResource>[];
  final assignments = <Assignment>[];
  final submissions = <Submission>[];

  /// media id → (choir, kind, owner).
  final media = <String, (String, RemoteMediaKind, String)>{};
  final _random = Random(7);

  String newMediaId(String ext) {
    final b = StringBuffer();
    for (var i = 0; i < 32; i++) {
      b.write(_random.nextInt(16).toRadixString(16));
    }
    return '$b.$ext';
  }
}

class FakeChoirRemote implements ChoirRemote {
  FakeChoirRemote(this.work, this.backend);
  final FakeWorkServer work;
  final FakeChoirBackend backend;

  FakeChoirServer get _server => work.server;

  /// Where each upload asked to go: (kind, work, shelf, part, label).
  final uploads = <(RemoteMediaKind, String?, String?, String?, String)>[];

  @override
  String? get userId => backend.userId;

  Never _deny([String m = 'not allowed']) =>
      throw ChoirBackendException.fromMessage(m);

  ChoirMember _me(String choirId) => _server.member(choirId, userId) ?? _deny();

  ChoirAccess _access(String choirId) => ChoirAccess([
    for (final m in _server.members)
      if (m.choirId == choirId) m,
  ]);

  void _needDrive(String choirId) {
    if (!_server.drives.containsKey(choirId)) {
      throw const ChoirBackendException(BackendProblem.driveMissing);
    }
  }

  @override
  Future<OnlineSnapshot> pull(String choirId) async {
    final me = _me(choirId);
    final access = _access(choirId);
    return OnlineSnapshot(
      choir: _server.choirs.firstWhere((c) => c.id == choirId),
      members: [
        for (final m in _server.members)
          if (m.choirId == choirId) m,
      ],
      references: [
        for (final r in work.references)
          if (r.choirId == choirId) r,
      ],
      resources: [
        for (final r in work.resources)
          if (r.choirId == choirId) r,
      ],
      assignments: [
        for (final a in work.assignments)
          if (a.choirId == choirId) a,
      ],
      submissions: [
        for (final s in work.submissions)
          if (s.choirId == choirId && access.canSeeStatus(me, s))
            access.canReadFeedback(me, s)
                ? s
                : Submission.fromJson({...s.toJson(), 'feedback': const []}),
      ],
    );
  }

  @override
  Future<String> upload(
    String choirId,
    RemoteMediaKind kind,
    File file, {
    String label = '',
    String? work,
    String? shelf,
    String? part,
  }) async {
    uploads.add((kind, work, shelf, part, label));
    final me = _me(choirId);
    final ok = switch (kind) {
      RemoteMediaKind.repertoire => me.isConductor,
      RemoteMediaKind.take => me.isSinger && me.part != null,
      RemoteMediaKind.voiceNote => me.isConductor || me.leadsPart,
    };
    if (!ok) _deny();
    _needDrive(choirId);
    final ext = file.path.split('.').last;
    final id = this.work.newMediaId(ext);
    await file.copy('${this.work.dir.path}/$id');
    this.work.media[id] = (choirId, kind, me.userId);
    return id;
  }

  @override
  Future<void> download(String mediaId, File to) async {
    final m = work.media[mediaId] ?? _deny('no such file');
    final me = _me(m.$1);
    final access = _access(m.$1);
    final ok =
        m.$3 == me.userId ||
        switch (m.$2) {
          RemoteMediaKind.repertoire => true,
          RemoteMediaKind.take => work.submissions.any(
            (s) => s.recordingId == mediaId && access.canListen(me, s),
          ),
          RemoteMediaKind.voiceNote => work.submissions.any(
            (s) =>
                s.feedback.any((f) => f.voiceNoteId == mediaId) &&
                access.canReadFeedback(me, s),
          ),
        };
    if (!ok) _deny('no such file');
    await File('${work.dir.path}/$mediaId').copy(to.path);
  }

  void _conductor(String choirId) {
    if (!_me(choirId).isConductor) _deny('only the conductor edits');
  }

  @override
  Future<void> putReference(ReferenceAsset asset) async {
    _conductor(asset.choirId);
    work.references
      ..removeWhere((r) => r.id == asset.id)
      ..add(asset);
  }

  @override
  Future<void> putResource(ChoirResource resource) async {
    _conductor(resource.choirId);
    work.resources
      ..removeWhere((r) => r.id == resource.id)
      ..add(resource);
  }

  @override
  Future<void> deleteResource(ChoirResource resource) async {
    _conductor(resource.choirId);
    work.resources.removeWhere((r) => r.id == resource.id);
  }

  @override
  Future<void> putAssignment(Assignment assignment) async {
    _conductor(assignment.choirId);
    for (final p in assignment.pieces) {
      final ref = p.midiReferenceId;
      if (ref != null && !work.references.any((r) => r.id == ref)) {
        _deny('unknown reference');
      }
    }
    work.assignments
      ..removeWhere((a) => a.id == assignment.id)
      ..add(assignment);
  }

  @override
  Future<void> submitTake(Submission take) async {
    final me = _me(take.choirId);
    final file = work.media[take.recordingId];
    if (!me.isSinger ||
        file == null ||
        file.$3 != me.userId ||
        file.$2 != RemoteMediaKind.take) {
      _deny('take needs a recording');
    }
    final assignment = work.assignments.firstWhere(
      (a) => a.id == take.assignmentId,
    );
    final at = work.submissions.indexWhere(
      (s) =>
          s.assignmentId == take.assignmentId &&
          s.pieceId == take.pieceId &&
          s.memberId == me.userId,
    );
    var base = at < 0
        ? Submission.start(
            id: 'sub-${work.submissions.length + 1}',
            assignment: assignment,
            pieceId: take.pieceId,
            member: me,
          )
        : work.submissions[at];
    if (base.status == SubmissionStatus.revisionRequested) {
      base = base.retake();
    } else if (base.status != SubmissionStatus.draft) {
      _deny('take already sent');
    }
    final sent = base
        .attachRecording(
          assignment: assignment,
          recordingId: take.recordingId!,
          durationMs: take.durationMs!,
          kind: take.takeKind!,
        )
        .submit(_server.now);
    if (at < 0) {
      work.submissions.add(sent);
    } else {
      work.submissions[at] = sent;
    }
  }

  int _index(Submission s) {
    final i = work.submissions.indexWhere((x) => x.id == s.id);
    if (i < 0) _deny('no such take');
    return i;
  }

  @override
  Future<void> markListened(Submission s) async {
    final i = _index(s);
    work.submissions[i] = work.submissions[i].markListened(
      _me(s.choirId),
      _server.now,
    );
  }

  @override
  Future<void> leaderDecide(
    Submission s, {
    required bool forward,
    Feedback? note,
  }) async {
    final i = _index(s);
    final me = _me(s.choirId);
    final current = work.submissions[i];
    work.submissions[i] = forward
        ? current.forward(
            leader: me,
            now: _server.now,
            text: note?.text ?? '',
            tags: note?.tags ?? const [],
            marks: note?.marks ?? const [],
            voiceNoteId: note?.voiceNoteId,
          )
        : current.requestRetake(
            leader: me,
            now: _server.now,
            text: note?.text ?? '',
            tags: note?.tags ?? const [],
            marks: note?.marks ?? const [],
            voiceNoteId: note?.voiceNoteId,
          );
  }

  @override
  Future<void> conductorReview(
    Submission s, {
    required bool accept,
    required Feedback note,
  }) async {
    final i = _index(s);
    final me = _me(s.choirId);
    final current = work.submissions[i];
    if (!_access(s.choirId).canConductorReview(me, current)) _deny();
    work.submissions[i] = current.review(
      conductor: me,
      outcome: accept
          ? ReviewOutcome.accepted
          : ReviewOutcome.revisionRequested,
      now: _server.now,
      text: note.text,
      tags: note.tags,
      marks: note.marks,
      voiceNoteId: note.voiceNoteId,
    );
  }
}
