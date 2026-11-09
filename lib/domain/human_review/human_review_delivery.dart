import 'human_review_feedback.dart';

/// Student-facing HUM-05 contracts. These values are local projections only;
/// they do not prove delivery, identity, notification transport or entitlement.
enum HumanReviewStudentContentKind { educatorReview, aiCoach }

final class HumanReviewEducatorDelivery {
  HumanReviewEducatorDelivery({
    required String deliveryToken,
    required this.feedback,
    required String educatorDisplayName,
    required String specialtyLabel,
    required this.deliveredAt,
  }) : deliveryToken = _token(deliveryToken),
       educatorDisplayName = _text(
         educatorDisplayName,
         maxLength: 120,
         allowEmpty: false,
       ),
       specialtyLabel = _text(
         specialtyLabel,
         maxLength: 120,
         allowEmpty: false,
       ) {
    _requireUtc(deliveredAt, 'deliveredAt');
    if (deliveredAt.isBefore(feedback.authoredAt)) {
      throw ArgumentError('Delivery cannot predate authored feedback');
    }
  }

  final String deliveryToken;
  final HumanReviewWrittenFeedback feedback;
  final String educatorDisplayName;
  final String specialtyLabel;
  final DateTime deliveredAt;
  HumanReviewStudentContentKind get kind =>
      HumanReviewStudentContentKind.educatorReview;
}

/// Explicitly separate from educator delivery; it has no educator identity,
/// qualification, evidence notes or human-review assignment.
final class HumanReviewAiCoachCard {
  HumanReviewAiCoachCard({
    required String message,
    required String modelVersion,
    required this.generatedAt,
  }) : message = _text(message, maxLength: 800, allowEmpty: false),
       modelVersion = _token(modelVersion) {
    _requireUtc(generatedAt, 'generatedAt');
  }

  final String message;
  final String modelVersion;
  final DateTime generatedAt;
  HumanReviewStudentContentKind get kind =>
      HumanReviewStudentContentKind.aiCoach;
}

enum HumanReviewClarificationStatus { available, submitted, answered, closed }

final class HumanReviewClarificationThread {
  HumanReviewClarificationThread._({
    required this.threadToken,
    required this.deliveryToken,
    required this.educatorToken,
    required this.availableUntil,
    required this.status,
    this.question,
    this.submittedAt,
    this.answer,
    this.answeredAt,
    this.closedAt,
  });

  factory HumanReviewClarificationThread.available({
    required String threadToken,
    required String deliveryToken,
    required String educatorToken,
    required DateTime availableUntil,
  }) {
    _requireUtc(availableUntil, 'availableUntil');
    return HumanReviewClarificationThread._(
      threadToken: _token(threadToken),
      deliveryToken: _token(deliveryToken),
      educatorToken: _token(educatorToken),
      availableUntil: availableUntil,
      status: HumanReviewClarificationStatus.available,
    );
  }

  final String threadToken;
  final String deliveryToken;
  final String educatorToken;
  final DateTime availableUntil;
  final HumanReviewClarificationStatus status;
  final String? question;
  final DateTime? submittedAt;
  final String? answer;
  final DateTime? answeredAt;
  final DateTime? closedAt;

  HumanReviewClarificationThread submit({
    required String question,
    required DateTime at,
  }) {
    _requireUtc(at, 'at');
    if (status != HumanReviewClarificationStatus.available) {
      throw StateError('Clarification question is no longer available');
    }
    if (!at.isBefore(availableUntil)) {
      throw StateError('Clarification window has expired');
    }
    return HumanReviewClarificationThread._(
      threadToken: threadToken,
      deliveryToken: deliveryToken,
      educatorToken: educatorToken,
      availableUntil: availableUntil,
      status: HumanReviewClarificationStatus.submitted,
      question: _text(question, maxLength: 400, allowEmpty: false),
      submittedAt: at,
    );
  }

  HumanReviewClarificationThread respond({
    required String educatorToken,
    required String answer,
    required DateTime at,
  }) {
    _requireUtc(at, 'at');
    if (status != HumanReviewClarificationStatus.submitted) {
      throw StateError('Only a submitted clarification can be answered');
    }
    if (this.educatorToken != _token(educatorToken)) {
      throw StateError('Clarification educator does not match delivery');
    }
    if (at.isBefore(submittedAt!)) {
      throw StateError('Answer cannot predate the question');
    }
    return HumanReviewClarificationThread._(
      threadToken: threadToken,
      deliveryToken: deliveryToken,
      educatorToken: this.educatorToken,
      availableUntil: availableUntil,
      status: HumanReviewClarificationStatus.answered,
      question: question,
      submittedAt: submittedAt,
      answer: _text(answer, maxLength: 1000, allowEmpty: false),
      answeredAt: at,
    );
  }

  HumanReviewClarificationThread close({required DateTime at}) {
    _requireUtc(at, 'at');
    if (status != HumanReviewClarificationStatus.answered) {
      throw StateError('Only an answered clarification can be closed');
    }
    if (at.isBefore(answeredAt!)) {
      throw StateError('Closure cannot predate the answer');
    }
    return HumanReviewClarificationThread._(
      threadToken: threadToken,
      deliveryToken: deliveryToken,
      educatorToken: educatorToken,
      availableUntil: availableUntil,
      status: HumanReviewClarificationStatus.closed,
      question: question,
      submittedAt: submittedAt,
      answer: answer,
      answeredAt: answeredAt,
      closedAt: at,
    );
  }
}

enum HumanReviewNotificationEvent { feedbackReady, clarificationAnswered }

/// A deliberately content-free push contract. The app must fetch authorized
/// detail after opening; no audio, question, answer, score or educator data is
/// permitted in the notification payload.
final class HumanReviewNotificationEnvelope {
  HumanReviewNotificationEnvelope({
    required this.event,
    required String opaqueToken,
  }) : opaqueToken = _token(opaqueToken);

  final HumanReviewNotificationEvent event;
  final String opaqueToken;

  Map<String, String> toPayload() => Map.unmodifiable({
    'schema': 'human-review-notification-v1',
    'event': event.name,
    'token': opaqueToken,
  });
}

final class HumanReviewTaskSelection {
  HumanReviewTaskSelection({
    required HumanReviewWrittenFeedback feedback,
    required Iterable<String> selectedExerciseIds,
  }) : selectedExerciseIds = List.unmodifiable(
         selectedExerciseIds.map(_token),
       ) {
    final selected = this.selectedExerciseIds.toSet();
    if (selected.length != this.selectedExerciseIds.length) {
      throw ArgumentError('Selected exercise ids must be unique');
    }
    final offered = feedback.practiceAssignments
        .map((task) => task.exerciseId)
        .toSet();
    if (!offered.containsAll(selected)) {
      throw ArgumentError('Only delivered practice tasks can be selected');
    }
  }

  final List<String> selectedExerciseIds;
}

abstract interface class HumanReviewStudentGateway {
  Future<HumanReviewEducatorDelivery> loadDelivery(String deliveryToken);
  Future<String> submitClarification(
    HumanReviewClarificationThread thread, {
    required String idempotencyKey,
  });
}

final class UnavailableHumanReviewStudentGateway
    implements HumanReviewStudentGateway {
  const UnavailableHumanReviewStudentGateway();

  @override
  Future<HumanReviewEducatorDelivery> loadDelivery(String deliveryToken) =>
      Future.error(
        StateError('Human review delivery is not available in this build'),
      );

  @override
  Future<String> submitClarification(
    HumanReviewClarificationThread thread, {
    required String idempotencyKey,
  }) => Future.error(
    StateError('Human review clarification is not available in this build'),
  );
}

String _token(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.length > 100 ||
      !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'value');
  }
  return normalized;
}

String _text(String value, {required int maxLength, required bool allowEmpty}) {
  final normalized = value.trim();
  if ((!allowEmpty && normalized.isEmpty) ||
      normalized.length > maxLength ||
      normalized.runes.any((rune) => rune < 0x20 && rune != 0x0A)) {
    throw ArgumentError.value(value, 'value');
  }
  return normalized;
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name, 'UTC required');
}
