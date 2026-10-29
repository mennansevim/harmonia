import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/choir/domain/assignment.dart';
import 'package:harmonia/choir/domain/choir.dart';
import 'package:harmonia/choir/domain/submission.dart';

final t0 = DateTime.utc(2026, 11, 2, 18);
DateTime at(int hours) => t0.add(Duration(hours: hours));

ChoirMember singer(String id, ChoirPart? part, {String choir = 'c1'}) =>
    ChoirMember(
      userId: id,
      choirId: choir,
      displayName: id,
      role: ChoirRole.singer,
      part: part,
      joinedAt: t0,
    );

final conductor = ChoirMember(
  userId: 'sef',
  choirId: 'c1',
  displayName: 'Şef',
  role: ChoirRole.conductor,
  joinedAt: t0,
);

Assignment assignment({
  List<ChoirPart> parts = const [ChoirPart.alto, ChoirPart.bass],
  List<String> refs = const ['r1'],
}) => Assignment(
  id: 'a1',
  choirId: 'c1',
  title: 'Gloria · ölçü 1–24',
  parts: parts,
  referenceIds: refs,
  createdAt: t0,
  dueAt: at(72),
);

/// JSON through a real encode/decode, as a server or file would.
Map<String, Object?> wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  group('Choir and members', () {
    test('a conductor cannot carry a voice part', () {
      expect(
        () => ChoirMember(
          userId: 'x',
          choirId: 'c1',
          displayName: 'X',
          role: ChoirRole.conductor,
          part: ChoirPart.alto,
          joinedAt: t0,
        ),
        throwsArgumentError,
      );
    });

    test('part assignment and JSON round-trip', () {
      final m = singer('ayse', null).withPart(ChoirPart.soprano);
      final back = ChoirMember.fromJson(wire(m.toJson()));
      expect(back.part, ChoirPart.soprano);
      expect(back.withPart(null).part, isNull);
      final choir = Choir(
        id: 'c1',
        name: 'Oda Korosu',
        conductorId: 'sef',
        createdAt: t0,
      );
      expect(Choir.fromJson(wire(choir.toJson())).name, 'Oda Korosu');
    });

    test('times must be UTC and enums known', () {
      final json = wire(singer('a', ChoirPart.alto).toJson());
      expect(
        () => ChoirMember.fromJson({...json, 'joinedAt': '2026-11-02T18:00'}),
        throwsFormatException,
      );
      expect(
        () => ChoirMember.fromJson({...json, 'part': 'mezzo'}),
        throwsFormatException,
      );
      expect(
        () => ChoirMember.fromJson({...json, 'userId': ' '}),
        throwsFormatException,
      );
    });
  });

  group('Invite', () {
    Invite invite({int? maxUses}) => Invite(
      code: 'KORO-7Q2X',
      choirId: 'c1',
      createdAt: t0,
      expiresAt: at(24 * 7),
      maxUses: maxUses,
    );

    test('a personal link works once', () {
      final used = invite(maxUses: 1).redeem(at(1));
      expect(used.check(at(2)), InviteCheck.exhausted);
      expect(() => used.redeem(at(2)), throwsStateError);
    });

    test('a shared code works until it expires or is revoked', () {
      var code = invite();
      for (var i = 0; i < 40; i++) {
        code = code.redeem(at(1));
      }
      expect(code.uses, 40);
      expect(code.check(at(24 * 7)), InviteCheck.expired);
      expect(code.revoke().check(at(1)), InviteCheck.revoked);
      // Revocation is the reason shown even after expiry.
      expect(code.revoke().check(at(24 * 8)), InviteCheck.revoked);
    });

    test('rejects short codes and invites that never expire', () {
      expect(
        () =>
            Invite(code: 'abc', choirId: 'c1', createdAt: t0, expiresAt: at(1)),
        throwsArgumentError,
      );
      expect(
        () => Invite(
          code: 'KORO-7Q2X',
          choirId: 'c1',
          createdAt: t0,
          expiresAt: t0,
        ),
        throwsArgumentError,
      );
    });

    test('JSON round-trip keeps the use count', () {
      final i = invite(maxUses: 3).redeem(at(1));
      final back = Invite.fromJson(wire(i.toJson()));
      expect(back.uses, 1);
      expect(back.maxUses, 3);
      expect(back.check(at(2)), InviteCheck.ok);
    });
  });

  group('Assignment', () {
    test('parts are deduplicated and kept in SATB order', () {
      final a = assignment(
        parts: [ChoirPart.bass, ChoirPart.soprano, ChoirPart.bass],
      );
      expect(a.parts, [ChoirPart.soprano, ChoirPart.bass]);
      expect(() => assignment(parts: const []), throwsArgumentError);
    });

    test('files without a rights declaration cannot be published', () {
      ReferenceAsset ref(String id, RightsDeclaration rights, {String? c}) =>
          ReferenceAsset(
            id: id,
            choirId: c ?? 'c1',
            kind: ReferenceKind.audio,
            fileName: '$id.mp3',
            rights: rights,
            uploadedAt: t0,
            part: ChoirPart.alto,
          );
      final a = assignment(refs: const ['ok', 'unknown', 'other', 'gone']);
      final problems = a.publishProblems({
        'ok': ref('ok', RightsDeclaration.ownRecording),
        'unknown': ref('unknown', RightsDeclaration.unknown),
        'other': ref('other', RightsDeclaration.licensed, c: 'c2'),
      });
      expect(problems, [
        'unknown: paylaşım hakkı belirtilmedi',
        'other: başka koronun dosyası',
        'gone: dosya bulunamadı',
      ]);
      expect(
        assignment(
          refs: const ['ok'],
        ).publishProblems({'ok': ref('ok', RightsDeclaration.publicDomain)}),
        isEmpty,
      );
    });

    test('recording cap is bounded and JSON round-trips', () {
      expect(
        () => Assignment(
          id: 'a',
          choirId: 'c1',
          title: 'x',
          parts: const [ChoirPart.alto],
          referenceIds: const [],
          createdAt: t0,
          maxRecordingSeconds: 5,
        ),
        throwsArgumentError,
      );
      final back = Assignment.fromJson(wire(assignment().toJson()));
      expect(back.parts, [ChoirPart.alto, ChoirPart.bass]);
      expect(back.dueAt, at(72));
      expect(back.isLate(at(73)), isTrue);
      expect(back.maxRecordingSeconds, 120);
    });
  });

  group('Submission lifecycle', () {
    Submission draft([ChoirMember? m]) => Submission.start(
      id: 's1',
      assignment: assignment(),
      member: m ?? singer('ali', ChoirPart.bass),
    );

    test('only a singer of an assigned part may start one', () {
      expect(() => draft(singer('x', ChoirPart.soprano)), throwsArgumentError);
      expect(() => draft(singer('x', null)), throwsArgumentError);
      expect(() => draft(conductor), throwsArgumentError);
      expect(
        () => draft(singer('x', ChoirPart.bass, choir: 'c2')),
        throwsArgumentError,
      );
    });

    test('record → submit → listen → revision → retake → accept', () {
      final a = assignment();
      var s = draft();
      expect(() => s.submit(at(1)), throwsStateError);
      s = s.attachRecording(
        assignment: a,
        recordingId: 'rec-1',
        durationMs: 95000,
      );
      s = s.submit(at(1));
      expect(s.status, SubmissionStatus.submitted);
      expect(s.awaitsConductor, isTrue);
      expect(
        () => s.attachRecording(
          assignment: a,
          recordingId: 'rec-x',
          durationMs: 1000,
        ),
        throwsStateError,
      );

      s = s.markListened(conductor, at(2));
      expect(s.markListened(conductor, at(3)).listenedAt, at(2));
      s = s.review(
        conductor: conductor,
        outcome: ReviewOutcome.revisionRequested,
        now: at(3),
        text: '12. ölçüde girişi erken.',
        tags: const [FeedbackTag.entry],
      );
      expect(s.status, SubmissionStatus.revisionRequested);
      expect(s.latestFeedback!.attempt, 1);
      expect(s.latestFeedback!.tags.single.personalArea, 'rhythm');

      s = s.retake();
      expect(s.status, SubmissionStatus.draft);
      expect(s.attempt, 2);
      expect(s.recordingId, isNull);
      expect(s.feedback, hasLength(1));

      s = s
          .attachRecording(
            assignment: a,
            recordingId: 'rec-2',
            durationMs: 90000,
          )
          .submit(at(30));
      // Reviewing a submitted take implies it was listened to.
      s = s.review(
        conductor: conductor,
        outcome: ReviewOutcome.accepted,
        now: at(31),
        tags: const [FeedbackTag.wellDone],
      );
      expect(s.status, SubmissionStatus.accepted);
      expect(s.feedback.map((f) => f.attempt), [1, 2]);
      expect(() => s.retake(), throwsStateError);
      expect(
        () => s.review(
          conductor: conductor,
          outcome: ReviewOutcome.accepted,
          now: at(32),
          text: 'again',
        ),
        throwsStateError,
      );
    });

    test('recordings over the cap are refused; a draft can be cleared', () {
      final a = assignment();
      expect(
        () => draft().attachRecording(
          assignment: a,
          recordingId: 'r',
          durationMs: 120001,
        ),
        throwsArgumentError,
      );
      final cleared = draft()
          .attachRecording(assignment: a, recordingId: 'r', durationMs: 1000)
          .clearRecording();
      expect(cleared.recordingId, isNull);
      expect(cleared.durationMs, isNull);
    });

    test('only this choir\'s conductor reviews, with text or a tag', () {
      final s = draft()
          .attachRecording(
            assignment: assignment(),
            recordingId: 'r',
            durationMs: 1000,
          )
          .submit(at(1));
      final otherConductor = ChoirMember(
        userId: 'sef2',
        choirId: 'c2',
        displayName: 'Diğer',
        role: ChoirRole.conductor,
        joinedAt: t0,
      );
      expect(() => s.markListened(otherConductor, at(2)), throwsArgumentError);
      expect(
        () => s.review(
          conductor: singer('ali', ChoirPart.bass),
          outcome: ReviewOutcome.accepted,
          now: at(2),
          text: 'ok',
        ),
        throwsArgumentError,
      );
      expect(
        () => s.review(
          conductor: conductor,
          outcome: ReviewOutcome.accepted,
          now: at(2),
        ),
        throwsArgumentError,
      );
    });

    test('JSON round-trip and malformed records', () {
      final s = draft()
          .attachRecording(
            assignment: assignment(),
            recordingId: 'r',
            durationMs: 1000,
          )
          .submit(at(1))
          .review(
            conductor: conductor,
            outcome: ReviewOutcome.revisionRequested,
            now: at(2),
            text: 'Perde düşüyor.',
            tags: const [FeedbackTag.pitch, FeedbackTag.pitch],
          );
      final json = wire(s.toJson());
      final back = Submission.fromJson(json);
      expect(back.status, SubmissionStatus.revisionRequested);
      expect(back.feedback.single.tags, [FeedbackTag.pitch]);
      expect(back.listenedAt, at(2));
      // A sent status without its recording is rejected.
      expect(
        () => Submission.fromJson({
          ...json,
          'recordingId': null,
          'durationMs': null,
        }),
        throwsArgumentError,
      );
      expect(
        () => Submission.fromJson({...json, 'feedback': 'x'}),
        throwsFormatException,
      );
    });
  });

  test('progress counts per part; not sent is neutral and drafts are '
      'private', () {
    final a = assignment();
    final members = [
      conductor,
      singer('b1', ChoirPart.bass),
      singer('b2', ChoirPart.bass),
      singer('b3', ChoirPart.bass),
      singer('a1', ChoirPart.alto),
      singer('a2', ChoirPart.alto),
      singer('s1', ChoirPart.soprano),
    ];
    Submission sent(String member) => Submission.start(
      id: 'sub-$member',
      assignment: a,
      member: members.firstWhere((m) => m.userId == member),
    ).attachRecording(assignment: a, recordingId: 'r', durationMs: 1000);
    final subs = [
      sent('b1').submit(at(1)),
      sent('b2'), // draft: not sent
      sent('a1')
          .submit(at(1))
          .review(
            conductor: conductor,
            outcome: ReviewOutcome.accepted,
            now: at(2),
            text: 'Temiz.',
          ),
      sent('a2')
          .submit(at(1))
          .review(
            conductor: conductor,
            outcome: ReviewOutcome.revisionRequested,
            now: at(2),
            tags: const [FeedbackTag.breath],
          ),
    ];
    final rows = assignmentProgress(
      assignment: a,
      members: members,
      submissions: subs,
    );
    expect(rows.map((r) => r.part), [ChoirPart.alto, ChoirPart.bass]);
    final alto = rows.first, bass = rows.last;
    expect(
      [alto.singers, alto.notSent, alto.accepted, alto.revisionRequested],
      [2, 0, 1, 1],
    );
    expect([bass.singers, bass.notSent, bass.toReview], [3, 2, 1]);

    // b1 moved to tenor: the bass take no longer counts for anyone.
    final moved = [
      for (final m in members)
        m.userId == 'b1' ? m.withPart(ChoirPart.tenor) : m,
    ];
    final after = assignmentProgress(
      assignment: a,
      members: moved,
      submissions: subs,
    );
    expect([after.last.singers, after.last.toReview], [2, 0]);
  });
}
