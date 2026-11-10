import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/data/choir_remote.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/choir/online/choir_backend.dart';
import 'package:resonia/choir/online/online_choir_controller.dart';

import 'support/fake_choir_backend.dart';
import 'support/fake_choir_remote.dart';

/// One phone signed in to the fake server.
class Phone {
  Phone(this.backend, this.remote, this.store);
  final FakeChoirBackend backend;
  final FakeChoirRemote remote;
  final ChoirStore store;
}

void main() {
  late Directory tmp;
  late FakeChoirServer server;
  late FakeWorkServer work;
  late String choirId;
  late Phone sef, ayse, ece, sena, aylin;

  Future<Phone> phone(String user) async {
    final backend = FakeChoirBackend(server, signedInAs: user);
    final remote = FakeChoirRemote(work, backend);
    final root = await Directory('${tmp.path}/$user').create();
    final store = ChoirStore(
      persistence: MemoryChoirPersistence(),
      mediaRoot: () async => root,
    )..remote = remote;
    await store.load();
    return Phone(backend, remote, store);
  }

  Future<String> file(String name, List<int> bytes) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('online_work');
    server = FakeChoirServer();
    work = FakeWorkServer(
      server,
      await Directory('${tmp.path}/drive').create(),
    );
    sef = await phone('sef');
    choirId = await sef.backend.createChoir('Koro', 'Şef');
    final code = await sef.backend.createInvite(choirId);
    for (final (who, part) in [
      ('ayse', ChoirPart.soprano),
      ('ece', ChoirPart.soprano),
      ('sena', ChoirPart.soprano),
      ('aylin', ChoirPart.alto),
    ]) {
      final b = FakeChoirBackend(server, signedInAs: who);
      final r = await b.requestJoin(code, who, part);
      await sef.backend.decideJoin(r, approve: true);
    }
    await sef.backend.setSectionLeader(choirId, 'ayse', true);
    ayse = await phone('ayse');
    ece = await phone('ece');
    sena = await phone('sena');
    aylin = await phone('aylin');
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<Assignment> publishWork() async {
    server.drives[choirId] = 'koro@gmail.com';
    await sef.store.syncOnline(choirId);
    final choir = sef.store.choir(choirId)!;
    final midi = await sef.store.addMidi(
      choir: choir,
      sourcePath: await file('gloria.mid', [77, 84, 104, 100]),
      fileName: 'gloria.mid',
      rights: RightsDeclaration.ownRecording,
      trackParts: const {1: ChoirPart.soprano, 2: ChoirPart.alto},
    );
    final a = Assignment(
      id: sef.store.newHex(),
      choirId: choirId,
      title: 'Gloria 1–24',
      parts: const [ChoirPart.soprano, ChoirPart.alto],
      pieces: [
        AssignmentPiece(
          id: 'p1',
          title: 'Gloria',
          mode: PieceMode.lyrics,
          midiReferenceId: midi.id,
          withAccompaniment: true,
        ),
      ],
      createdAt: server.now,
    );
    await sef.store.publish(a);
    return a;
  }

  Future<Submission> sendTake(Phone p, Assignment a, List<int> bytes) async {
    await p.store.syncOnline(choirId);
    final draft = await p.store.keepTake(
      assignment: a,
      piece: a.pieces.single,
      sourcePath: await file('take-${p.backend.userId}.wav', bytes),
      fileName: 'take.wav',
      durationMs: 30000,
      kind: TakeKind.accompaniedMix,
    );
    return p.store.markSent(draft);
  }

  test('nothing is uploaded before the conductor connects Drive', () async {
    await sef.store.syncOnline(choirId);
    await expectLater(
      sef.store.addMidi(
        choir: sef.store.choir(choirId)!,
        sourcePath: await file('x.mid', [1]),
        fileName: 'x.mid',
        rights: RightsDeclaration.ownRecording,
        trackParts: const {},
      ),
      throwsA(
        isA<ChoirBackendException>().having(
          (e) => e.problem,
          'problem',
          BackendProblem.driveMissing,
        ),
      ),
    );
    expect(work.references, isEmpty);
  });

  test(
    'repertoire and assignment reach every singer; MIDI is fetched once',
    () async {
      final a = await publishWork();
      await aylin.store.syncOnline(choirId);
      expect(aylin.store.assignmentsOf(choirId).single.title, 'Gloria 1–24');
      final ref = aylin.store.reference(a.pieces.single.midiReferenceId!)!;
      final path = await aylin.store.ensureMedia(ref.id);
      expect(await File(path).readAsBytes(), [77, 84, 104, 100]);
      expect(aylin.store.isConductor(aylin.store.choir(choirId)!), isFalse);
      expect(sef.store.isConductor(sef.store.choir(choirId)!), isTrue);
    },
  );

  test(
    'a take goes to the part first, then the conductor once forwarded',
    () async {
      final a = await publishWork();
      final sent = await sendTake(ece, a, [1, 2, 3]);
      expect(sent.status, SubmissionStatus.submitted);
      expect(work.submissions.single.recordingId, sent.recordingId);
      // The take kept its file under the server's name: no download back.
      expect(
        File(await ece.store.mediaPath(sent.recordingId!)).existsSync(),
        isTrue,
      );

      // Section leader: in the queue, can hear it.
      await ayse.store.syncOnline(choirId);
      final queued = ayse.store.reviewQueue(choirId).single;
      expect(queued.memberId, 'ece');
      expect(
        await File(
          await ayse.store.ensureMedia(queued.recordingId!),
        ).readAsBytes(),
        [1, 2, 3],
      );
      // Same part: hears it, cannot decide.
      await sena.store.syncOnline(choirId);
      expect(sena.store.partTakes(a.id, 'p1').single.memberId, 'ece');
      expect(sena.store.reviewQueue(choirId), isEmpty);
      // Another part and the conductor (not yet forwarded): nothing.
      await aylin.store.syncOnline(choirId);
      expect(aylin.store.partTakes(a.id, 'p1'), isEmpty);
      await expectLater(
        aylin.store.ensureMedia(sent.recordingId!),
        throwsA(isA<ChoirBackendException>()),
      );
      await sef.store.syncOnline(choirId);
      expect(sef.store.reviewQueue(choirId), isEmpty);
      await expectLater(
        sef.store.ensureMedia(sent.recordingId!),
        throwsA(isA<ChoirBackendException>()),
      );

      // Leader forwards with a sung note.
      final voice = await ayse.store.addMedia(
        await file('note.wav', [9, 9]),
        'voice.wav',
      );
      final forwarded = await ayse.store.leaderDecide(
        submission: queued,
        forward: true,
        text: 'Temiz, nefes 12. ölçüde',
        voiceNoteId: voice,
      );
      expect(forwarded.status, SubmissionStatus.forwarded);
      expect(ayse.store.reviewQueue(choirId), isEmpty);

      await sef.store.syncOnline(choirId);
      final mine = sef.store.reviewQueue(choirId).single;
      expect(mine.feedback.single.text, 'Temiz, nefes 12. ölçüde');
      expect(
        await File(
          await sef.store.ensureMedia(mine.recordingId!),
        ).readAsBytes(),
        [1, 2, 3],
      );
      expect(
        await File(
          await sef.store.ensureMedia(mine.feedback.single.voiceNoteId!),
        ).readAsBytes(),
        [9, 9],
      );
      await sef.store.review(
        submission: mine,
        outcome: ReviewOutcome.revisionRequested,
        text: 'Girişi bir daha',
      );

      // The singer reads both notes; another soprano reads none.
      await ece.store.syncOnline(choirId);
      final back = ece.store.mySubmission(a.id, 'p1')!;
      expect(back.status, SubmissionStatus.revisionRequested);
      expect(back.feedback.map((f) => f.text), [
        'Temiz, nefes 12. ölçüde',
        'Girişi bir daha',
      ]);
      await ece.store.ensureMedia(back.feedback.first.voiceNoteId!);
      await sena.store.syncOnline(choirId);
      expect(
        sena.store.submissions.firstWhere((s) => s.memberId == 'ece').feedback,
        isEmpty,
      );

      // Retake: the draft survives a sync, then goes as attempt 2.
      final draft = await ece.store.keepTake(
        assignment: a,
        piece: a.pieces.single,
        sourcePath: await file('retake.wav', [4, 5]),
        fileName: 'take.wav',
        durationMs: 28000,
        kind: TakeKind.accompaniedMix,
      );
      await ece.store.syncOnline(choirId);
      expect(
        ece.store.mySubmission(a.id, 'p1')!.status,
        SubmissionStatus.draft,
      );
      final again = await ece.store.markSent(draft);
      expect([again.status, again.attempt], [SubmissionStatus.submitted, 2]);
    },
  );

  test('a part with no leader goes straight to the conductor', () async {
    final a = await publishWork();
    await sendTake(aylin, a, [7]);
    await sef.store.syncOnline(choirId);
    expect(sef.store.reviewQueue(choirId).single.memberId, 'aylin');
  });

  test('the leader returns a take only with a note', () async {
    final a = await publishWork();
    await sendTake(ece, a, [1]);
    await ayse.store.syncOnline(choirId);
    final s = ayse.store.reviewQueue(choirId).single;
    expect(
      () => ayse.store.leaderDecide(submission: s, forward: false),
      throwsArgumentError,
    );
    await ayse.store.leaderDecide(
      submission: s,
      forward: false,
      text: 'Tempo kaçıyor',
    );
    await sef.store.syncOnline(choirId);
    expect(sef.store.reviewQueue(choirId), isEmpty);
  });

  test('a singer cannot publish or add repertoire', () async {
    await publishWork();
    await ece.store.syncOnline(choirId);
    await expectLater(
      ece.remote.putAssignment(ece.store.assignmentsOf(choirId).single),
      throwsA(isA<ChoirBackendException>()),
    );
    await expectLater(
      ece.remote.upload(
        choirId,
        RemoteMediaKind.repertoire,
        File(await file('y.mid', [1])),
      ),
      throwsA(isA<ChoirBackendException>()),
    );
  });

  test('leaving, removal and sign-out take the choir off the phone', () async {
    await publishWork();
    await aylin.store.syncOnline(choirId);
    final online = OnlineChoirController(aylin.backend);
    final sync = OnlineMirrorSync(aylin.store, online);
    addTearDown(() {
      sync.dispose();
      online.dispose();
    });
    await online.refresh();
    await pumpEventQueue();
    expect(aylin.store.choir(choirId), isNotNull, reason: 'still a member');

    await sef.backend.removeMember(choirId, 'aylin');
    await online.refresh();
    await pumpEventQueue();
    expect(aylin.store.choir(choirId), isNull);
    expect(aylin.store.onlineChoirIds, isEmpty);
    expect(aylin.store.assignmentsOf(choirId), isEmpty);

    await ece.store.syncOnline(choirId);
    final eceOnline = OnlineChoirController(ece.backend);
    final eceSync = OnlineMirrorSync(ece.store, eceOnline);
    addTearDown(() {
      eceSync.dispose();
      eceOnline.dispose();
    });
    await eceOnline.signOut();
    await pumpEventQueue();
    expect(ece.store.choir(choirId), isNull);
  });

  test('server media ids map to uuids and back', () {
    const uuid = '0123abcd-4567-89ab-cdef-0123456789ab';
    final id = mediaIdOf(uuid, 'wav');
    expect(id, '0123abcd456789abcdef0123456789ab.wav');
    expect(mediaIdPattern.hasMatch(id), isTrue);
    expect(uuidOfMedia(id), uuid);
    expect(() => uuidOfMedia('abc.wav'), throwsArgumentError);
  });
}
