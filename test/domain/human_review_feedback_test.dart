import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/human_review/human_review_feedback.dart';

void main() {
  final assignedAt = DateTime.utc(2026, 11, 8, 8);

  HumanReviewAssignment assignment({DateTime? revokedAt}) =>
      HumanReviewAssignment(
        id: 'assignment-1',
        requestToken: 'request-1',
        educatorToken: 'educator-1',
        qualificationToken: 'qualification-voice-1',
        assignedAt: assignedAt,
        accessUntil: assignedAt.add(const Duration(days: 3)),
        revokedAt: revokedAt,
      );

  HumanReviewEvidenceNote note({
    int seconds = 18,
    String observation = 'İkinci cümlede başlangıç sesi pesleşiyor.',
  }) => HumanReviewEvidenceNote(
    offset: Duration(seconds: seconds),
    observation: observation,
    possibleExplanation: 'Giriş hazırlığı kararsız olabilir.',
  );

  HumanReviewPracticeAssignment task(String id) =>
      HumanReviewPracticeAssignment(
        exerciseId: id,
        objective: 'Girişi sabitle',
        instruction: 'Referansı dinle ve üç kontrollü tekrar yap.',
        successCondition: 'Üç tekrarda giriş kararlı duyulsun.',
        repetitions: 3,
        minutes: 5,
      );

  HumanReviewWrittenFeedback feedback({
    HumanReviewAssignment? scopedAssignment,
    String educatorToken = 'educator-1',
    DateTime? authoredAt,
    Duration recordingDuration = const Duration(seconds: 60),
    Iterable<HumanReviewEvidenceNote>? strengths,
    Iterable<HumanReviewEvidenceNote>? priorities,
    Iterable<HumanReviewPracticeAssignment>? tasks,
  }) => HumanReviewWrittenFeedback(
    assignment: scopedAssignment ?? assignment(),
    educatorToken: educatorToken,
    authoredAt: authoredAt ?? assignedAt.add(const Duration(hours: 2)),
    recordingDuration: recordingDuration,
    strengths: strengths ?? [note(observation: 'İlk giriş temiz ve dengeli.')],
    priorities: priorities ?? [note()],
    practiceAssignments: tasks ?? [task('ex-1'), task('ex-2'), task('ex-3')],
    followUpGoal: 'Bir hafta sonra aynı cümleyi yeniden kaydet.',
    rubricVersion: 'review-rubric-v1',
    recordingLimitations: 'Arka planda hafif ortam sesi var.',
  );

  test('valid feedback is assignment-scoped and structurally complete', () {
    final result = feedback();

    expect(result.assignment.requestToken, 'request-1');
    expect(result.educatorToken, 'educator-1');
    expect(result.strengths, hasLength(1));
    expect(result.priorities, hasLength(1));
    expect(result.practiceAssignments, hasLength(3));
    expect(result.recordingLimitations, isNotEmpty);
  });

  test('assignment access is educator-specific, bounded and revocable', () {
    final active = assignment();
    expect(active.permits(educatorToken: 'educator-1', at: assignedAt), isTrue);
    expect(
      active.permits(educatorToken: 'educator-2', at: assignedAt),
      isFalse,
    );
    expect(
      active.permits(
        educatorToken: 'educator-1',
        at: assignedAt.add(const Duration(days: 3)),
      ),
      isFalse,
    );
    final revoked = assignment(
      revokedAt: assignedAt.add(const Duration(hours: 1)),
    );
    expect(
      revoked.permits(
        educatorToken: 'educator-1',
        at: assignedAt.add(const Duration(hours: 1)),
      ),
      isFalse,
    );
  });

  test('wrong educator, expired and revoked delivery fail closed', () {
    expect(() => feedback(educatorToken: 'educator-2'), throwsStateError);
    expect(
      () => feedback(authoredAt: assignedAt.add(const Duration(days: 3))),
      throwsStateError,
    );
    expect(
      () => feedback(
        scopedAssignment: assignment(
          revokedAt: assignedAt.add(const Duration(hours: 1)),
        ),
      ),
      throwsStateError,
    );
  });

  test('evidence cannot point beyond the reviewed recording', () {
    expect(
      () => feedback(
        recordingDuration: const Duration(seconds: 20),
        priorities: [note(seconds: 21)],
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewEvidenceNote(
        offset: const Duration(seconds: -1),
        observation: 'Gözlem',
      ),
      throwsArgumentError,
    );
  });

  test(
    'feedback requires strengths, at most two priorities and three tasks',
    () {
      expect(() => feedback(strengths: const []), throwsArgumentError);
      expect(
        () => feedback(priorities: [note(), note(), note()]),
        throwsArgumentError,
      );
      expect(
        () => feedback(tasks: [task('ex-1'), task('ex-2')]),
        throwsArgumentError,
      );
    },
  );

  test('practice tasks are bounded and catalog ids are unique', () {
    expect(
      () => feedback(tasks: [task('same'), task('same'), task('ex-3')]),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewPracticeAssignment(
        exerciseId: 'ex-1',
        objective: 'Hedef',
        instruction: 'Yönerge',
        successCondition: 'Koşul',
        repetitions: 0,
        minutes: 5,
      ),
      throwsArgumentError,
    );
  });

  test('UTC, token and text boundaries reject unsafe data', () {
    expect(
      () => HumanReviewAssignment(
        id: '../assignment',
        requestToken: 'request',
        educatorToken: 'educator',
        qualificationToken: 'qualification',
        assignedAt: assignedAt,
        accessUntil: assignedAt.add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      () => assignment().permits(
        educatorToken: 'educator-1',
        at: DateTime(2026, 11, 8),
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewEvidenceNote(
        offset: Duration.zero,
        observation: 'bad\u0000text',
      ),
      throwsArgumentError,
    );
  });

  test(
    'collections are immutable and unavailable gateway never delivers',
    () async {
      final result = feedback();
      expect(() => result.strengths.clear(), throwsUnsupportedError);
      expect(() => result.practiceAssignments.clear(), throwsUnsupportedError);

      const gateway = UnavailableHumanReviewFeedbackGateway();
      await expectLater(
        gateway.deliver(result, idempotencyKey: 'delivery-1'),
        throwsStateError,
      );
    },
  );
}
