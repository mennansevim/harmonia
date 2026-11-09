import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/human_review/human_review_delivery.dart';
import 'package:resonia/domain/human_review/human_review_feedback.dart';

void main() {
  final assignedAt = DateTime.utc(2026, 11, 9, 8);

  HumanReviewWrittenFeedback feedback() {
    final assignment = HumanReviewAssignment(
      id: 'assignment-1',
      requestToken: 'request-1',
      educatorToken: 'educator-1',
      qualificationToken: 'qualification-voice-1',
      assignedAt: assignedAt,
      accessUntil: assignedAt.add(const Duration(days: 3)),
    );
    HumanReviewPracticeAssignment task(String id) =>
        HumanReviewPracticeAssignment(
          exerciseId: id,
          objective: 'Girişi sabitle',
          instruction: 'Üç kontrollü tekrar yap.',
          successCondition: 'Üç giriş kararlı duyulsun.',
          repetitions: 3,
          minutes: 5,
        );
    return HumanReviewWrittenFeedback(
      assignment: assignment,
      educatorToken: 'educator-1',
      authoredAt: assignedAt.add(const Duration(hours: 1)),
      recordingDuration: const Duration(seconds: 60),
      strengths: [
        HumanReviewEvidenceNote(
          offset: const Duration(seconds: 10),
          observation: 'İlk giriş dengeli.',
        ),
      ],
      priorities: [
        HumanReviewEvidenceNote(
          offset: const Duration(seconds: 20),
          observation: 'İkinci giriş gecikiyor.',
        ),
      ],
      practiceAssignments: [task('ex-1'), task('ex-2'), task('ex-3')],
      followUpGoal: 'Bir hafta sonra aynı cümleyi kaydet.',
      rubricVersion: 'rubric-v1',
    );
  }

  HumanReviewEducatorDelivery delivery() => HumanReviewEducatorDelivery(
    deliveryToken: 'delivery-1',
    feedback: feedback(),
    educatorDisplayName: 'Doğrulanacak Eğitimci',
    specialtyLabel: 'Şan · doğrulama backend bekliyor',
    deliveredAt: assignedAt.add(const Duration(hours: 2)),
  );

  test('educator delivery and AI coach are distinct content kinds', () {
    final educator = delivery();
    final ai = HumanReviewAiCoachCard(
      message: 'Bugün bir giriş çalışması yapabilirsin.',
      modelVersion: 'gpt-4o-mini-config-v1',
      generatedAt: assignedAt,
    );

    expect(educator.kind, HumanReviewStudentContentKind.educatorReview);
    expect(ai.kind, HumanReviewStudentContentKind.aiCoach);
    expect(educator.feedback.educatorToken, 'educator-1');
  });

  test('delivery cannot predate authored feedback', () {
    expect(
      () => HumanReviewEducatorDelivery(
        deliveryToken: 'delivery-1',
        feedback: feedback(),
        educatorDisplayName: 'Eğitimci',
        specialtyLabel: 'Şan',
        deliveredAt: assignedAt,
      ),
      throwsArgumentError,
    );
  });

  test('one clarification follows available submitted answered closed', () {
    final available = HumanReviewClarificationThread.available(
      threadToken: 'thread-1',
      deliveryToken: delivery().deliveryToken,
      educatorToken: 'educator-1',
      availableUntil: assignedAt.add(const Duration(days: 7)),
    );
    final submitted = available.submit(
      question: 'İkinci giriş için hangi tempoda başlamalıyım?',
      at: assignedAt.add(const Duration(days: 1)),
    );
    final answered = submitted.respond(
      educatorToken: 'educator-1',
      answer: 'Önce yavaş tempoda üç tekrar yap.',
      at: assignedAt.add(const Duration(days: 2)),
    );
    final closed = answered.close(at: assignedAt.add(const Duration(days: 3)));

    expect(submitted.status, HumanReviewClarificationStatus.submitted);
    expect(answered.status, HumanReviewClarificationStatus.answered);
    expect(closed.status, HumanReviewClarificationStatus.closed);
    expect(closed.question, submitted.question);
    expect(closed.answer, answered.answer);
  });

  test(
    'clarification cannot be repeated, skipped or answered by another educator',
    () {
      final available = HumanReviewClarificationThread.available(
        threadToken: 'thread-1',
        deliveryToken: 'delivery-1',
        educatorToken: 'educator-1',
        availableUntil: assignedAt.add(const Duration(days: 7)),
      );
      expect(
        () => available.respond(
          educatorToken: 'educator-1',
          answer: 'Yanıt',
          at: assignedAt,
        ),
        throwsStateError,
      );
      final submitted = available.submit(
        question: 'Sorum nedir?',
        at: assignedAt,
      );
      expect(
        () => submitted.submit(question: 'İkinci soru', at: assignedAt),
        throwsStateError,
      );
      expect(
        () => submitted.respond(
          educatorToken: 'educator-2',
          answer: 'Yanıt',
          at: assignedAt,
        ),
        throwsStateError,
      );
    },
  );

  test('clarification expiry and chronology fail closed', () {
    final available = HumanReviewClarificationThread.available(
      threadToken: 'thread-1',
      deliveryToken: 'delivery-1',
      educatorToken: 'educator-1',
      availableUntil: assignedAt.add(const Duration(days: 1)),
    );
    expect(
      () => available.submit(
        question: 'Geç soru',
        at: assignedAt.add(const Duration(days: 1)),
      ),
      throwsStateError,
    );
    final submitted = available.submit(question: 'Soru', at: assignedAt);
    expect(
      () => submitted.respond(
        educatorToken: 'educator-1',
        answer: 'Yanıt',
        at: assignedAt.subtract(const Duration(seconds: 1)),
      ),
      throwsStateError,
    );
  });

  test('notification payload is minimal and content-free', () {
    final payload = HumanReviewNotificationEnvelope(
      event: HumanReviewNotificationEvent.feedbackReady,
      opaqueToken: 'notification-7Yk2',
    ).toPayload();

    expect(payload.keys, unorderedEquals(['schema', 'event', 'token']));
    expect(payload['event'], 'feedbackReady');
    expect(payload.toString(), isNot(contains('educator')));
    expect(payload.toString(), isNot(contains('question')));
    expect(() => payload['extra'] = 'secret', throwsUnsupportedError);
  });

  test(
    'only unique delivered tasks can be selected without mastery claims',
    () {
      final result = HumanReviewTaskSelection(
        feedback: feedback(),
        selectedExerciseIds: ['ex-1', 'ex-3'],
      );
      expect(result.selectedExerciseIds, ['ex-1', 'ex-3']);
      expect(() => result.selectedExerciseIds.clear(), throwsUnsupportedError);
      expect(
        () => HumanReviewTaskSelection(
          feedback: feedback(),
          selectedExerciseIds: ['ex-1', 'not-offered'],
        ),
        throwsArgumentError,
      );
      expect(
        () => HumanReviewTaskSelection(
          feedback: feedback(),
          selectedExerciseIds: ['ex-1', 'ex-1'],
        ),
        throwsArgumentError,
      );
    },
  );

  test('unsafe tokens, control text and local time are rejected', () {
    expect(
      () => HumanReviewNotificationEnvelope(
        event: HumanReviewNotificationEvent.feedbackReady,
        opaqueToken: '../delivery',
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewAiCoachCard(
        message: 'bad\u0000text',
        modelVersion: 'model-v1',
        generatedAt: assignedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewClarificationThread.available(
        threadToken: 'thread-1',
        deliveryToken: 'delivery-1',
        educatorToken: 'educator-1',
        availableUntil: DateTime(2026, 11, 9),
      ),
      throwsArgumentError,
    );
  });

  test(
    'student gateway is unavailable and performs no fake delivery',
    () async {
      const gateway = UnavailableHumanReviewStudentGateway();
      await expectLater(gateway.loadDelivery('delivery-1'), throwsStateError);
      final thread = HumanReviewClarificationThread.available(
        threadToken: 'thread-1',
        deliveryToken: 'delivery-1',
        educatorToken: 'educator-1',
        availableUntil: assignedAt.add(const Duration(days: 7)),
      );
      await expectLater(
        gateway.submitClarification(thread, idempotencyKey: 'clarification-1'),
        throwsStateError,
      );
    },
  );
}
