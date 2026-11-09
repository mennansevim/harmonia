/// Local-only HUM-06 service-operation contract.
///
/// This model records safe state transitions and review recommendations. It
/// does not revoke storage access, restore a service credit, issue a payment
/// refund, authenticate staff or prove that a notification was delivered.
enum HumanReviewServiceStatus {
  triage,
  assigned,
  reviewing,
  needsRerecord,
  waitlisted,
  delivered,
  accessWithdrawn,
  cancelled,
}

final class HumanReviewServiceCase {
  HumanReviewServiceCase._({
    required this.caseToken,
    required this.createdAt,
    required this.status,
    required this.recordingRevision,
    required this.qaRequired,
    this.educatorToken,
    this.dueAt,
    this.lastTransitionAt,
    this.reason,
    this.deliveredAt,
  });

  factory HumanReviewServiceCase.triage({
    required String caseToken,
    required DateTime createdAt,
    required int acceptedPilotOrdinal,
  }) {
    _requireUtc(createdAt, 'createdAt');
    if (acceptedPilotOrdinal < 1) {
      throw ArgumentError.value(acceptedPilotOrdinal, 'acceptedPilotOrdinal');
    }
    return HumanReviewServiceCase._(
      caseToken: _token(caseToken),
      createdAt: createdAt,
      status: HumanReviewServiceStatus.triage,
      recordingRevision: 1,
      qaRequired: acceptedPilotOrdinal <= 20,
      lastTransitionAt: createdAt,
    );
  }

  final String caseToken;
  final DateTime createdAt;
  final HumanReviewServiceStatus status;
  final int recordingRevision;

  /// A policy flag only; it is not evidence that independent QA occurred.
  final bool qaRequired;
  final String? educatorToken;
  final DateTime? dueAt;
  final DateTime? lastTransitionAt;
  final String? reason;
  final DateTime? deliveredAt;

  HumanReviewServiceCase assign({
    required String educatorToken,
    required DateTime at,
    required DateTime dueAt,
  }) {
    _chronology(at);
    _requireUtc(dueAt, 'dueAt');
    if (status != HumanReviewServiceStatus.triage &&
        status != HumanReviewServiceStatus.waitlisted) {
      throw StateError('Only triage or waitlisted cases can be assigned');
    }
    if (!dueAt.isAfter(at)) {
      throw ArgumentError('dueAt must be after assignment');
    }
    return _copy(
      status: HumanReviewServiceStatus.assigned,
      educatorToken: _token(educatorToken),
      dueAt: dueAt,
      lastTransitionAt: at,
      clearReason: true,
    );
  }

  HumanReviewServiceCase startReview({
    required String educatorToken,
    required DateTime at,
  }) {
    _chronology(at);
    if (status != HumanReviewServiceStatus.assigned) {
      throw StateError('Only an assigned case can enter review');
    }
    if (this.educatorToken != _token(educatorToken)) {
      throw StateError('Only the assigned educator can start review');
    }
    return _copy(
      status: HumanReviewServiceStatus.reviewing,
      lastTransitionAt: at,
    );
  }

  HumanReviewServiceCase reassign({
    required String fromEducatorToken,
    required String toEducatorToken,
    required String reason,
    required DateTime at,
    required DateTime dueAt,
  }) {
    _chronology(at);
    _requireUtc(dueAt, 'dueAt');
    if (status != HumanReviewServiceStatus.assigned &&
        status != HumanReviewServiceStatus.reviewing) {
      throw StateError('Only an active assignment can be reassigned');
    }
    final from = _token(fromEducatorToken);
    final to = _token(toEducatorToken);
    if (educatorToken != from) {
      throw StateError('Previous educator does not match active assignment');
    }
    if (from == to) throw ArgumentError('Replacement educator must differ');
    if (!dueAt.isAfter(at)) {
      throw ArgumentError('dueAt must be after reassignment');
    }
    return _copy(
      status: HumanReviewServiceStatus.assigned,
      educatorToken: to,
      dueAt: dueAt,
      lastTransitionAt: at,
      reason: _text(reason, maxLength: 300),
    );
  }

  HumanReviewServiceCase requestRerecord({
    required String reason,
    required DateTime at,
  }) {
    _chronology(at);
    if (status != HumanReviewServiceStatus.triage &&
        status != HumanReviewServiceStatus.assigned &&
        status != HumanReviewServiceStatus.reviewing) {
      throw StateError('A rerecord cannot be requested from this state');
    }
    return _copy(
      status: HumanReviewServiceStatus.needsRerecord,
      lastTransitionAt: at,
      reason: _text(reason, maxLength: 300),
      clearEducator: true,
      clearDueAt: true,
    );
  }

  HumanReviewServiceCase submitRerecord({
    required String recordingToken,
    required DateTime at,
  }) {
    _chronology(at);
    if (status != HumanReviewServiceStatus.needsRerecord) {
      throw StateError('No rerecord is currently requested');
    }
    _token(recordingToken);
    return HumanReviewServiceCase._(
      caseToken: caseToken,
      createdAt: createdAt,
      status: HumanReviewServiceStatus.triage,
      recordingRevision: recordingRevision + 1,
      qaRequired: qaRequired,
      lastTransitionAt: at,
    );
  }

  HumanReviewServiceCase waitlist({
    required String reason,
    required DateTime at,
  }) {
    _chronology(at);
    if (status != HumanReviewServiceStatus.triage) {
      throw StateError('Only a triage case can be waitlisted');
    }
    return _copy(
      status: HumanReviewServiceStatus.waitlisted,
      lastTransitionAt: at,
      reason: _text(reason, maxLength: 300),
    );
  }

  HumanReviewServiceCase extendDueDate({
    required DateTime at,
    required DateTime newDueAt,
    required String reason,
  }) {
    _chronology(at);
    _requireUtc(newDueAt, 'newDueAt');
    if (status != HumanReviewServiceStatus.assigned &&
        status != HumanReviewServiceStatus.reviewing) {
      throw StateError('Only an active assignment can be delayed');
    }
    if (dueAt == null || !newDueAt.isAfter(dueAt!) || !newDueAt.isAfter(at)) {
      throw ArgumentError(
        'A delayed due date must move forward and stay future',
      );
    }
    return _copy(
      dueAt: newDueAt,
      lastTransitionAt: at,
      reason: _text(reason, maxLength: 300),
    );
  }

  HumanReviewServiceCase deliver({
    required String educatorToken,
    required DateTime at,
  }) {
    _chronology(at);
    if (status != HumanReviewServiceStatus.reviewing) {
      throw StateError('Only a reviewed case can be delivered');
    }
    if (this.educatorToken != _token(educatorToken)) {
      throw StateError('Only the active educator can deliver');
    }
    return _copy(
      status: HumanReviewServiceStatus.delivered,
      deliveredAt: at,
      lastTransitionAt: at,
      clearReason: true,
    );
  }

  HumanReviewServiceCase withdrawAccess({
    required String reason,
    required DateTime at,
  }) {
    _chronology(at);
    if (status == HumanReviewServiceStatus.delivered ||
        status == HumanReviewServiceStatus.accessWithdrawn ||
        status == HumanReviewServiceStatus.cancelled) {
      throw StateError('Access cannot be withdrawn from this state');
    }
    return _copy(
      status: HumanReviewServiceStatus.accessWithdrawn,
      lastTransitionAt: at,
      reason: _text(reason, maxLength: 300),
      clearEducator: true,
      clearDueAt: true,
    );
  }

  HumanReviewServiceCase cancel({
    required String reason,
    required DateTime at,
  }) {
    _chronology(at);
    if (status == HumanReviewServiceStatus.delivered ||
        status == HumanReviewServiceStatus.accessWithdrawn ||
        status == HumanReviewServiceStatus.cancelled) {
      throw StateError('Case cannot be cancelled from this state');
    }
    return _copy(
      status: HumanReviewServiceStatus.cancelled,
      lastTransitionAt: at,
      reason: _text(reason, maxLength: 300),
      clearEducator: true,
      clearDueAt: true,
    );
  }

  void _chronology(DateTime at) {
    _requireUtc(at, 'at');
    if (at.isBefore(lastTransitionAt ?? createdAt)) {
      throw StateError('Transition cannot move backwards in time');
    }
  }

  HumanReviewServiceCase _copy({
    HumanReviewServiceStatus? status,
    String? educatorToken,
    DateTime? dueAt,
    DateTime? lastTransitionAt,
    String? reason,
    DateTime? deliveredAt,
    bool clearEducator = false,
    bool clearDueAt = false,
    bool clearReason = false,
  }) => HumanReviewServiceCase._(
    caseToken: caseToken,
    createdAt: createdAt,
    status: status ?? this.status,
    recordingRevision: recordingRevision,
    qaRequired: qaRequired,
    educatorToken: clearEducator ? null : educatorToken ?? this.educatorToken,
    dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
    lastTransitionAt: lastTransitionAt ?? this.lastTransitionAt,
    reason: clearReason ? null : reason ?? this.reason,
    deliveredAt: deliveredAt ?? this.deliveredAt,
  );
}

enum HumanReviewQualityOutcome { accepted, revisionRequired }

final class HumanReviewQualityCheck {
  HumanReviewQualityCheck({
    required HumanReviewServiceCase serviceCase,
    required String deliveryToken,
    required String deliveryEducatorToken,
    required String qualityReviewerToken,
    required String permissionReference,
    required String rubricVersion,
    required this.outcome,
    required String note,
    required this.checkedAt,
  }) : caseToken = serviceCase.caseToken,
       deliveryToken = _token(deliveryToken),
       deliveryEducatorToken = _token(deliveryEducatorToken),
       qualityReviewerToken = _token(qualityReviewerToken),
       permissionReference = _token(permissionReference),
       rubricVersion = _token(rubricVersion),
       note = _text(note, maxLength: 800) {
    _requireUtc(checkedAt, 'checkedAt');
    if (serviceCase.status != HumanReviewServiceStatus.delivered ||
        serviceCase.deliveredAt == null) {
      throw StateError('Quality check requires a delivered case');
    }
    if (this.deliveryEducatorToken != serviceCase.educatorToken) {
      throw StateError('Delivery educator does not match the service case');
    }
    if (this.deliveryEducatorToken == this.qualityReviewerToken) {
      throw ArgumentError('Quality review must be independent');
    }
    if (checkedAt.isBefore(serviceCase.deliveredAt!)) {
      throw ArgumentError('Quality check cannot predate delivery');
    }
  }

  final String caseToken;
  final String deliveryToken;
  final String deliveryEducatorToken;
  final String qualityReviewerToken;
  final String permissionReference;
  final String rubricVersion;
  final HumanReviewQualityOutcome outcome;
  final String note;
  final DateTime checkedAt;
}

enum HumanReviewAppealResolution {
  upheld,
  replacementReviewRecommended,
  serviceCreditReviewRecommended,
}

final class HumanReviewAppeal {
  HumanReviewAppeal._({
    required this.appealToken,
    required this.caseToken,
    required this.openedAt,
    required this.reason,
    this.resolvedAt,
    this.resolverToken,
    this.resolution,
    this.resolutionNote,
  });

  factory HumanReviewAppeal.open({
    required HumanReviewServiceCase serviceCase,
    required String appealToken,
    required String reason,
    required DateTime openedAt,
    required DateTime appealUntil,
  }) {
    _requireUtc(openedAt, 'openedAt');
    _requireUtc(appealUntil, 'appealUntil');
    if (serviceCase.status != HumanReviewServiceStatus.delivered ||
        serviceCase.deliveredAt == null) {
      throw StateError('Only a delivered case can be appealed');
    }
    if (openedAt.isBefore(serviceCase.deliveredAt!) ||
        !openedAt.isBefore(appealUntil)) {
      throw StateError('Appeal is outside the allowed window');
    }
    return HumanReviewAppeal._(
      appealToken: _token(appealToken),
      caseToken: serviceCase.caseToken,
      openedAt: openedAt,
      reason: _text(reason, maxLength: 800),
    );
  }

  final String appealToken;
  final String caseToken;
  final DateTime openedAt;
  final String reason;
  final DateTime? resolvedAt;
  final String? resolverToken;
  final HumanReviewAppealResolution? resolution;
  final String? resolutionNote;
  bool get isResolved => resolution != null;

  HumanReviewAppeal resolve({
    required String resolverToken,
    required HumanReviewAppealResolution resolution,
    required String note,
    required DateTime at,
  }) {
    _requireUtc(at, 'at');
    if (isResolved) throw StateError('Appeal is already resolved');
    if (at.isBefore(openedAt)) {
      throw StateError('Resolution cannot predate appeal');
    }
    return HumanReviewAppeal._(
      appealToken: appealToken,
      caseToken: caseToken,
      openedAt: openedAt,
      reason: reason,
      resolvedAt: at,
      resolverToken: _token(resolverToken),
      resolution: resolution,
      resolutionNote: _text(note, maxLength: 800),
    );
  }
}

abstract interface class HumanReviewOperationsGateway {
  Future<String> recordCase(
    HumanReviewServiceCase serviceCase, {
    required String idempotencyKey,
  });

  Future<String> recordAppeal(
    HumanReviewAppeal appeal, {
    required String idempotencyKey,
  });
}

final class UnavailableHumanReviewOperationsGateway
    implements HumanReviewOperationsGateway {
  const UnavailableHumanReviewOperationsGateway();

  @override
  Future<String> recordCase(
    HumanReviewServiceCase serviceCase, {
    required String idempotencyKey,
  }) => Future.error(
    StateError('Human review operations are not available in this build'),
  );

  @override
  Future<String> recordAppeal(
    HumanReviewAppeal appeal, {
    required String idempotencyKey,
  }) => Future.error(
    StateError('Human review appeals are not available in this build'),
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

String _text(String value, {required int maxLength}) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.length > maxLength ||
      normalized.runes.any((rune) => rune < 0x20 && rune != 0x0A)) {
    throw ArgumentError.value(value, 'value');
  }
  return normalized;
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name, 'UTC required');
}
