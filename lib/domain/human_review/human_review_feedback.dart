/// Local-only HUM-04 contract for educator-scoped written feedback.
///
/// Assignment tokens do not prove identity or qualification. A future backend
/// must authenticate the educator, authorize the assignment and retain audit
/// evidence. This model deliberately has no AI author or auto-fill path.
final class HumanReviewAssignment {
  HumanReviewAssignment({
    required String id,
    required String requestToken,
    required String educatorToken,
    required String qualificationToken,
    required this.assignedAt,
    required this.accessUntil,
    this.revokedAt,
  }) : id = _token(id),
       requestToken = _token(requestToken),
       educatorToken = _token(educatorToken),
       qualificationToken = _token(qualificationToken) {
    _requireUtc(assignedAt, 'assignedAt');
    _requireUtc(accessUntil, 'accessUntil');
    if (!accessUntil.isAfter(assignedAt)) {
      throw ArgumentError('accessUntil must be after assignedAt');
    }
    if (revokedAt case final value?) {
      _requireUtc(value, 'revokedAt');
      if (value.isBefore(assignedAt)) {
        throw ArgumentError('revokedAt cannot predate assignment');
      }
    }
  }

  final String id;
  final String requestToken;
  final String educatorToken;
  final String qualificationToken;
  final DateTime assignedAt;
  final DateTime accessUntil;
  final DateTime? revokedAt;

  bool permits({required String educatorToken, required DateTime at}) {
    _requireUtc(at, 'at');
    return this.educatorToken == educatorToken &&
        !at.isBefore(assignedAt) &&
        at.isBefore(accessUntil) &&
        (revokedAt == null || at.isBefore(revokedAt!));
  }
}

final class HumanReviewEvidenceNote {
  HumanReviewEvidenceNote({
    required this.offset,
    required String observation,
    String? possibleExplanation,
  }) : observation = _text(observation, maxLength: 500, allowEmpty: false),
       possibleExplanation = _optionalText(
         possibleExplanation,
         maxLength: 500,
       ) {
    if (offset.isNegative || offset > const Duration(minutes: 5)) {
      throw ArgumentError.value(offset, 'offset');
    }
  }

  final Duration offset;
  final String observation;

  /// A bounded hypothesis kept separate from the observed evidence.
  final String? possibleExplanation;
}

final class HumanReviewPracticeAssignment {
  HumanReviewPracticeAssignment({
    required String exerciseId,
    required String objective,
    required String instruction,
    required String successCondition,
    required this.repetitions,
    required this.minutes,
  }) : exerciseId = _token(exerciseId),
       objective = _text(objective, maxLength: 240, allowEmpty: false),
       instruction = _text(instruction, maxLength: 500, allowEmpty: false),
       successCondition = _text(
         successCondition,
         maxLength: 300,
         allowEmpty: false,
       ) {
    if (repetitions < 1 || repetitions > 20) {
      throw ArgumentError.value(repetitions, 'repetitions');
    }
    if (minutes < 1 || minutes > 30) {
      throw ArgumentError.value(minutes, 'minutes');
    }
  }

  final String exerciseId;
  final String objective;
  final String instruction;
  final String successCondition;
  final int repetitions;
  final int minutes;
}

final class HumanReviewWrittenFeedback {
  HumanReviewWrittenFeedback({
    required this.assignment,
    required String educatorToken,
    required this.authoredAt,
    required this.recordingDuration,
    required Iterable<HumanReviewEvidenceNote> strengths,
    required Iterable<HumanReviewEvidenceNote> priorities,
    required Iterable<HumanReviewPracticeAssignment> practiceAssignments,
    required String followUpGoal,
    required String rubricVersion,
    String? recordingLimitations,
  }) : educatorToken = _token(educatorToken),
       strengths = List.unmodifiable(strengths),
       priorities = List.unmodifiable(priorities),
       practiceAssignments = List.unmodifiable(practiceAssignments),
       followUpGoal = _text(followUpGoal, maxLength: 400, allowEmpty: false),
       rubricVersion = _token(rubricVersion),
       recordingLimitations = _optionalText(
         recordingLimitations,
         maxLength: 500,
       ) {
    _requireUtc(authoredAt, 'authoredAt');
    if (recordingDuration <= Duration.zero ||
        recordingDuration > const Duration(minutes: 5)) {
      throw ArgumentError.value(recordingDuration, 'recordingDuration');
    }
    if (!assignment.permits(
      educatorToken: this.educatorToken,
      at: authoredAt,
    )) {
      throw StateError('Assignment does not permit this educator and time');
    }
    if (this.strengths.isEmpty || this.strengths.length > 3) {
      throw ArgumentError('Feedback requires one to three strengths');
    }
    if (this.priorities.length > 2) {
      throw ArgumentError('Feedback supports at most two priorities');
    }
    if (this.practiceAssignments.length != 3) {
      throw ArgumentError('Feedback requires exactly three practice tasks');
    }
    final exerciseIds = this.practiceAssignments
        .map((assignment) => assignment.exerciseId)
        .toSet();
    if (exerciseIds.length != this.practiceAssignments.length) {
      throw ArgumentError('Practice exercise ids must be unique');
    }
    for (final note in [...this.strengths, ...this.priorities]) {
      if (note.offset > recordingDuration) {
        throw ArgumentError('Evidence offset exceeds recording duration');
      }
    }
  }

  final HumanReviewAssignment assignment;
  final String educatorToken;
  final DateTime authoredAt;
  final Duration recordingDuration;
  final List<HumanReviewEvidenceNote> strengths;
  final List<HumanReviewEvidenceNote> priorities;
  final List<HumanReviewPracticeAssignment> practiceAssignments;
  final String followUpGoal;
  final String rubricVersion;
  final String? recordingLimitations;
}

abstract interface class HumanReviewFeedbackGateway {
  Future<String> deliver(
    HumanReviewWrittenFeedback feedback, {
    required String idempotencyKey,
  });
}

/// Fail-closed until authenticated assignment delivery and educator audit exist.
final class UnavailableHumanReviewFeedbackGateway
    implements HumanReviewFeedbackGateway {
  const UnavailableHumanReviewFeedbackGateway();

  @override
  Future<String> deliver(
    HumanReviewWrittenFeedback feedback, {
    required String idempotencyKey,
  }) => Future.error(
    StateError('Educator feedback delivery is not available in this build'),
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

String? _optionalText(String? value, {required int maxLength}) {
  if (value == null) return null;
  final normalized = _text(value, maxLength: maxLength, allowEmpty: true);
  return normalized.isEmpty ? null : normalized;
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name, 'UTC required');
}
