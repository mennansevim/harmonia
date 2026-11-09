import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/human_review/human_review_draft.dart';

void main() {
  HumanReviewRecordingSelection recording({int seconds = 60}) =>
      HumanReviewRecordingSelection(
        localToken: 'take-01',
        duration: Duration(seconds: seconds),
        byteLength: 1024,
        codec: 'wav',
      );

  test('complete draft stays local and requires versioned consent', () {
    final draft = HumanReviewDraft(
      goal: HumanReviewGoal.conservatoryEar,
      question: '  Giriş sesimi nasıl daha kararlı tutabilirim?  ',
      progressScope: HumanReviewProgressScope.sevenDays,
      createdAt: DateTime.utc(2026, 11, 7),
      recording: recording(),
      consentVersion: 'pilot-v1',
      consentGranted: true,
    );

    expect(draft.question, 'Giriş sesimi nasıl daha kararlı tutabilirim?');
    expect(draft.locallyComplete, isTrue);
    expect(draft.recording!.localToken, 'take-01');
  });

  test('proposed recording range is explicit and not a service promise', () {
    expect(recording(seconds: 29).matchesProposedPilotLength, isFalse);
    expect(recording(seconds: 30).matchesProposedPilotLength, isTrue);
    expect(recording(seconds: 120).matchesProposedPilotLength, isTrue);
    expect(recording(seconds: 121).matchesProposedPilotLength, isFalse);
  });

  test('invalid token, size, duration and control text fail closed', () {
    expect(
      () => HumanReviewRecordingSelection(
        localToken: '../private.wav',
        duration: const Duration(seconds: 60),
        byteLength: 10,
        codec: 'wav',
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewRecordingSelection(
        localToken: 'take',
        duration: Duration.zero,
        byteLength: 10,
        codec: 'wav',
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewDraft(
        goal: HumanReviewGoal.voice,
        question: 'bad\u0000text',
        progressScope: HumanReviewProgressScope.none,
        createdAt: DateTime.utc(2026),
      ),
      throwsArgumentError,
    );
  });

  test(
    'consent cannot be inferred and local completeness is not acceptance',
    () {
      final noConsent = HumanReviewDraft(
        goal: HumanReviewGoal.choir,
        question: 'Girişimi değerlendirir misiniz?',
        progressScope: HumanReviewProgressScope.thirtyDays,
        createdAt: DateTime.utc(2026),
        recording: recording(),
      );
      expect(noConsent.locallyComplete, isFalse);
      expect(
        () => HumanReviewDraft(
          goal: HumanReviewGoal.choir,
          question: 'Soru',
          progressScope: HumanReviewProgressScope.none,
          createdAt: DateTime.utc(2026),
          consentGranted: true,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'unavailable adapter exposes every external gate and never submits',
    () async {
      const gateway = UnavailableHumanReviewGateway();
      final availability = await gateway.availability();
      expect(availability.canSubmit, isFalse);
      expect(
        availability.blockers,
        containsAll(HumanReviewAvailabilityBlocker.values),
      );
      final draft = HumanReviewDraft(
        goal: HumanReviewGoal.instrument,
        question: '',
        progressScope: HumanReviewProgressScope.none,
        createdAt: DateTime.utc(2026),
      );
      await expectLater(
        gateway.submit(draft, idempotencyKey: 'attempt-1'),
        throwsStateError,
      );
    },
  );
}
