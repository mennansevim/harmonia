import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/choir_access.dart';
import 'package:resonia/choir/domain/submission.dart';

final t0 = DateTime.utc(2026, 11, 10, 18);
DateTime at(int h) => t0.add(Duration(hours: h));

ChoirMember singer(
  String id,
  ChoirPart part, {
  String choir = 'c1',
  bool leads = false,
}) => ChoirMember(
  userId: id,
  choirId: choir,
  displayName: id,
  role: ChoirRole.singer,
  part: part,
  joinedAt: t0,
  leadsPart: leads,
);

ChoirMember conductorOf(String choir) => ChoirMember(
  userId: 'sef-$choir',
  choirId: choir,
  displayName: 'Şef',
  role: ChoirRole.conductor,
  joinedAt: t0,
);

final a1 = Assignment(
  id: 'a1',
  choirId: 'c1',
  title: 'Gloria',
  parts: const [ChoirPart.soprano, ChoirPart.alto],
  pieces: [AssignmentPiece(id: 'p1', title: 'Gloria', mode: PieceMode.lyrics)],
  createdAt: t0,
);

Submission sent(ChoirMember who) =>
    Submission.start(
          id: 's-${who.userId}',
          assignment: a1,
          pieceId: 'p1',
          member: who,
        )
        .attachRecording(
          assignment: a1,
          recordingId: 'rec-${who.userId}',
          durationMs: 60000,
          kind: TakeKind.unaccompanied,
        )
        .submit(at(1));

void main() {
  final sef = conductorOf('c1');
  final leader = singer('ayse', ChoirPart.soprano, leads: true);
  final ece = singer('ece', ChoirPart.soprano);
  final sena = singer('sena', ChoirPart.soprano);
  final alto = singer('aylin', ChoirPart.alto);
  final stranger = conductorOf('c2');
  final strangerSoprano = singer('x', ChoirPart.soprano, choir: 'c2');
  final members = [sef, leader, ece, sena, alto, stranger, strangerSoprano];
  final access = ChoirAccess(members);

  group('section leader', () {
    test('needs a part and is a singer', () {
      expect(
        () => ChoirMember(
          userId: 'u',
          choirId: 'c1',
          displayName: 'u',
          role: ChoirRole.singer,
          joinedAt: t0,
          leadsPart: true,
        ),
        throwsArgumentError,
      );
      expect(leader.leads(ChoirPart.soprano), isTrue);
      expect(leader.leads(ChoirPart.alto), isFalse);
    });

    test('moving part ends leading; JSON keeps the flag', () {
      expect(leader.withPart(ChoirPart.alto).leadsPart, isFalse);
      expect(leader.withPart(ChoirPart.soprano).leadsPart, isTrue);
      final back = ChoirMember.fromJson(
        jsonDecode(jsonEncode(leader.toJson())) as Map<String, Object?>,
      );
      expect(back.leadsPart, isTrue);
      expect(ece.toJson().containsKey('leadsPart'), isFalse);
    });
  });

  group('who hears a take', () {
    final take = sent(ece);

    test('singer, same-part singers and leader hear it', () {
      expect(access.canListen(ece, take), isTrue);
      expect(access.canListen(sena, take), isTrue);
      expect(access.canListen(leader, take), isTrue);
    });

    test('another part and other choirs do not', () {
      expect(access.canListen(alto, take), isFalse);
      expect(access.canListen(strangerSoprano, take), isFalse);
      expect(access.canListen(stranger, take), isFalse);
      expect(access.canSeeStatus(strangerSoprano, take), isFalse);
      expect(access.canSeeStatus(alto, take), isTrue);
    });

    test('conductor waits for the leader to forward it', () {
      expect(access.conductorSees(take), isFalse);
      expect(access.canListen(sef, take), isFalse);
      expect(access.canConductorReview(sef, take), isFalse);
      final fwd = take.forward(leader: leader, now: at(2), text: 'Güzel');
      expect(fwd.status, SubmissionStatus.forwarded);
      expect(access.canListen(sef, fwd), isTrue);
      expect(access.canReadFeedback(sef, fwd), isTrue);
      expect(access.canConductorReview(sef, fwd), isTrue);
      final done = fwd.review(
        conductor: sef,
        outcome: ReviewOutcome.accepted,
        now: at(3),
        text: 'Tamam',
      );
      expect(done.status, SubmissionStatus.accepted);
      expect(access.canListen(sef, done), isTrue);
    });

    test('a retake asked by the leader never reaches the conductor', () {
      final back = take.requestRetake(
        leader: leader,
        now: at(2),
        text: '12. ölçü pes',
      );
      expect(back.status, SubmissionStatus.revisionRequested);
      expect(access.canListen(sef, back), isFalse);
      expect(access.canReadFeedback(ece, back), isTrue);
      expect(access.canReadFeedback(sena, back), isFalse);
      final again = back.retake();
      expect(again.forwardedAt, isNull);
      expect(again.attempt, 2);
    });

    test('a part without a leader goes straight to the conductor', () {
      final altoTake = sent(alto);
      expect(access.conductorSees(altoTake), isTrue);
      expect(access.canConductorReview(sef, altoTake), isTrue);
    });

    test("the leader's own take goes straight to the conductor", () {
      final own = sent(leader);
      expect(access.conductorSees(own), isTrue);
      expect(access.canLeaderAct(leader, own), isFalse);
      expect(
        () => own.forward(leader: leader, now: at(2)),
        throwsArgumentError,
      );
    });

    test('drafts stay with their singer', () {
      final draft = Submission.start(
        id: 'd',
        assignment: a1,
        pieceId: 'p1',
        member: sena,
      );
      expect(access.canListen(sena, draft), isTrue);
      expect(access.canListen(leader, draft), isFalse);
      expect(access.canListen(sef, draft), isFalse);
    });
  });

  group('leader actions', () {
    final take = sent(ece);

    test('only a leader of the part forwards or returns', () {
      expect(access.canLeaderAct(leader, take), isTrue);
      expect(access.canLeaderAct(sena, take), isFalse);
      expect(() => take.forward(leader: sena, now: at(2)), throwsArgumentError);
      expect(() => take.forward(leader: sef, now: at(2)), throwsArgumentError);
    });

    test('a retake request needs a reason', () {
      expect(
        () => take.requestRetake(leader: leader, now: at(2)),
        throwsArgumentError,
      );
    });

    test('listening is idempotent and forwarding keeps it', () {
      final heard = take.markListened(leader, at(2));
      expect(heard.status, SubmissionStatus.listened);
      final fwd = heard.forward(leader: leader, now: at(3));
      expect(fwd.listenedAt, at(2));
      expect(fwd.feedback, isEmpty);
      expect(fwd.markListened(sef, at(4)).status, SubmissionStatus.forwarded);
      expect(() => fwd.forward(leader: leader, now: at(4)), throwsStateError);
    });

    test('forwarded state survives JSON', () {
      final fwd = take.forward(leader: leader, now: at(2), text: 'ok');
      final back = Submission.fromJson(
        jsonDecode(jsonEncode(fwd.toJson())) as Map<String, Object?>,
      );
      expect(back.status, SubmissionStatus.forwarded);
      expect(back.forwardedAt, at(2));
      expect(back.feedback.single.authorId, leader.userId);
    });

    test('progress counts forwarded takes as waiting', () {
      final rows = assignmentProgress(
        assignment: a1,
        pieceId: 'p1',
        members: members,
        submissions: [
          take.forward(leader: leader, now: at(2)),
          sent(sena),
        ],
      );
      final soprano = rows.firstWhere((r) => r.part == ChoirPart.soprano);
      expect(
        [soprano.singers, soprano.toReview, soprano.forwarded, soprano.notSent],
        [3, 2, 1, 1],
      );
    });
  });
}
