import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/human_review/human_review_operations.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 9, 9);

  HumanReviewServiceCase assignedCase({int ordinal = 1}) =>
      HumanReviewServiceCase.triage(
        caseToken: 'case-1',
        createdAt: t0,
        acceptedPilotOrdinal: ordinal,
      ).assign(
        educatorToken: 'educator-a',
        at: t0.add(const Duration(minutes: 1)),
        dueAt: t0.add(const Duration(days: 3)),
      );

  HumanReviewServiceCase deliveredCase({int ordinal = 1}) =>
      assignedCase(ordinal: ordinal)
          .startReview(
            educatorToken: 'educator-a',
            at: t0.add(const Duration(hours: 1)),
          )
          .deliver(
            educatorToken: 'educator-a',
            at: t0.add(const Duration(hours: 2)),
          );

  test('first twenty accepted pilot cases require independent QA', () {
    expect(
      HumanReviewServiceCase.triage(
        caseToken: 'case-20',
        createdAt: t0,
        acceptedPilotOrdinal: 20,
      ).qaRequired,
      isTrue,
    );
    expect(
      HumanReviewServiceCase.triage(
        caseToken: 'case-21',
        createdAt: t0,
        acceptedPilotOrdinal: 21,
      ).qaRequired,
      isFalse,
    );
  });

  test('assignment and review are educator scoped', () {
    final assigned = assignedCase();
    expect(
      () => assigned.startReview(
        educatorToken: 'educator-b',
        at: t0.add(const Duration(hours: 1)),
      ),
      throwsStateError,
    );
    final reviewing = assigned.startReview(
      educatorToken: 'educator-a',
      at: t0.add(const Duration(hours: 1)),
    );
    expect(reviewing.status, HumanReviewServiceStatus.reviewing);
  });

  test('rerecord clears access and returns a new revision to triage', () {
    final rerecord = assignedCase().requestRerecord(
      reason: 'Background noise prevents a bounded review.',
      at: t0.add(const Duration(hours: 1)),
    );
    expect(rerecord.status, HumanReviewServiceStatus.needsRerecord);
    expect(rerecord.educatorToken, isNull);
    expect(rerecord.dueAt, isNull);

    final resubmitted = rerecord.submitRerecord(
      recordingToken: 'recording-v2',
      at: t0.add(const Duration(hours: 2)),
    );
    expect(resubmitted.status, HumanReviewServiceStatus.triage);
    expect(resubmitted.recordingRevision, 2);
    expect(resubmitted.qaRequired, isTrue);
  });

  test(
    'reassignment requires the active educator and a different replacement',
    () {
      final assigned = assignedCase();
      expect(
        () => assigned.reassign(
          fromEducatorToken: 'educator-b',
          toEducatorToken: 'educator-c',
          reason: 'Availability changed.',
          at: t0.add(const Duration(hours: 1)),
          dueAt: t0.add(const Duration(days: 4)),
        ),
        throwsStateError,
      );
      final replacement = assigned.reassign(
        fromEducatorToken: 'educator-a',
        toEducatorToken: 'educator-c',
        reason: 'Availability changed.',
        at: t0.add(const Duration(hours: 1)),
        dueAt: t0.add(const Duration(days: 4)),
      );
      expect(replacement.educatorToken, 'educator-c');
      expect(replacement.status, HumanReviewServiceStatus.assigned);
    },
  );

  test('delay only moves an active due date forward', () {
    final assigned = assignedCase();
    expect(
      () => assigned.extendDueDate(
        at: t0.add(const Duration(hours: 2)),
        newDueAt: t0.add(const Duration(days: 2)),
        reason: 'Capacity changed.',
      ),
      throwsArgumentError,
    );
    expect(
      () => assigned.extendDueDate(
        at: t0.add(const Duration(days: 5)),
        newDueAt: t0.add(const Duration(days: 4)),
        reason: 'A past replacement deadline is invalid.',
      ),
      throwsArgumentError,
    );
    final delayed = assigned.extendDueDate(
      at: t0.add(const Duration(hours: 2)),
      newDueAt: t0.add(const Duration(days: 4)),
      reason: 'Capacity changed.',
    );
    expect(delayed.dueAt, t0.add(const Duration(days: 4)));
  });

  test(
    'access withdrawal is terminal and does not claim credit restoration',
    () {
      final withdrawn = assignedCase().withdrawAccess(
        reason: 'Student withdrew sharing permission.',
        at: t0.add(const Duration(hours: 1)),
      );
      expect(withdrawn.status, HumanReviewServiceStatus.accessWithdrawn);
      expect(withdrawn.educatorToken, isNull);
      expect(withdrawn.dueAt, isNull);
      expect(
        () => withdrawn.assign(
          educatorToken: 'educator-b',
          at: t0.add(const Duration(hours: 2)),
          dueAt: t0.add(const Duration(days: 4)),
        ),
        throwsStateError,
      );
    },
  );

  test('independent QA requires permission and follows delivery', () {
    final delivered = deliveredCase();
    final check = HumanReviewQualityCheck(
      serviceCase: delivered,
      deliveryToken: 'delivery-1',
      deliveryEducatorToken: 'educator-a',
      qualityReviewerToken: 'qa-reviewer-1',
      permissionReference: 'permission-v1',
      rubricVersion: 'rubric-v1',
      outcome: HumanReviewQualityOutcome.accepted,
      note: 'Evidence and tasks follow the approved rubric.',
      checkedAt: t0.add(const Duration(hours: 3)),
    );
    expect(check.caseToken, delivered.caseToken);
    expect(
      () => HumanReviewQualityCheck(
        serviceCase: delivered,
        deliveryToken: 'delivery-1',
        deliveryEducatorToken: 'educator-a',
        qualityReviewerToken: 'educator-a',
        permissionReference: 'permission-v1',
        rubricVersion: 'rubric-v1',
        outcome: HumanReviewQualityOutcome.accepted,
        note: 'Self review is not independent.',
        checkedAt: t0.add(const Duration(hours: 3)),
      ),
      throwsArgumentError,
    );
  });

  test('appeal opens only in window and resolves once', () {
    final delivered = deliveredCase();
    final appeal = HumanReviewAppeal.open(
      serviceCase: delivered,
      appealToken: 'appeal-1',
      reason: 'The delivered tasks do not match the selected goal.',
      openedAt: t0.add(const Duration(days: 1)),
      appealUntil: t0.add(const Duration(days: 8)),
    );
    final resolved = appeal.resolve(
      resolverToken: 'quality-lead-1',
      resolution: HumanReviewAppealResolution.replacementReviewRecommended,
      note: 'Independent replacement review should be considered.',
      at: t0.add(const Duration(days: 2)),
    );
    expect(resolved.isResolved, isTrue);
    expect(
      () => resolved.resolve(
        resolverToken: 'quality-lead-2',
        resolution: HumanReviewAppealResolution.upheld,
        note: 'A second resolution is invalid.',
        at: t0.add(const Duration(days: 3)),
      ),
      throwsStateError,
    );
  });

  test(
    'service-credit resolution is a recommendation, not a ledger mutation',
    () {
      final appeal =
          HumanReviewAppeal.open(
            serviceCase: deliveredCase(),
            appealToken: 'appeal-credit',
            reason: 'The service could not be used as delivered.',
            openedAt: t0.add(const Duration(days: 1)),
            appealUntil: t0.add(const Duration(days: 8)),
          ).resolve(
            resolverToken: 'quality-lead-1',
            resolution:
                HumanReviewAppealResolution.serviceCreditReviewRecommended,
            note:
                'Credit eligibility must be decided by the authorized ledger.',
            at: t0.add(const Duration(days: 2)),
          );
      expect(
        appeal.resolution,
        HumanReviewAppealResolution.serviceCreditReviewRecommended,
      );
    },
  );

  test('unsafe time and text fail closed', () {
    expect(
      () => HumanReviewServiceCase.triage(
        caseToken: 'case-local-time',
        createdAt: DateTime(2026, 11, 9),
        acceptedPilotOrdinal: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => assignedCase().cancel(
        reason: 'bad\u0000reason',
        at: t0.add(const Duration(hours: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      () => assignedCase().cancel(
        reason: 'Student cancelled.',
        at: t0.subtract(const Duration(minutes: 1)),
      ),
      throwsStateError,
    );
  });

  test('operations gateway stays fail closed without a backend', () async {
    const gateway = UnavailableHumanReviewOperationsGateway();
    final serviceCase = assignedCase();
    await expectLater(
      gateway.recordCase(serviceCase, idempotencyKey: 'case-write-1'),
      throwsStateError,
    );
    final appeal = HumanReviewAppeal.open(
      serviceCase: deliveredCase(),
      appealToken: 'appeal-2',
      reason: 'A bounded appeal reason.',
      openedAt: t0.add(const Duration(days: 1)),
      appealUntil: t0.add(const Duration(days: 8)),
    );
    await expectLater(
      gateway.recordAppeal(appeal, idempotencyKey: 'appeal-write-1'),
      throwsStateError,
    );
  });
}
