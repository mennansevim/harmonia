/// Deterministic, local-only HUM-03 domain aggregate.
///
/// It models service credits without granting an entitlement, charging money,
/// persisting data or calling a backend. All timestamps are supplied by the
/// caller so tests and future server adapters cannot hide clock decisions.
final class HumanReviewCreditGrant {
  HumanReviewCreditGrant({
    required String id,
    required this.units,
    required this.validFrom,
    required this.validUntil,
  }) : id = _token(id) {
    _requireUtc(validFrom, 'validFrom');
    _requireUtc(validUntil, 'validUntil');
    if (units < 1 || units > 12) {
      throw ArgumentError.value(units, 'units');
    }
    if (!validUntil.isAfter(validFrom)) {
      throw ArgumentError('validUntil must be after validFrom');
    }
  }

  final String id;
  final int units;
  final DateTime validFrom;
  final DateTime validUntil;

  bool isActiveAt(DateTime at) =>
      !at.isBefore(validFrom) && at.isBefore(validUntil);
}

enum HumanReviewCreditReservationStatus { reserved, consumed, restored }

final class HumanReviewCreditReservation {
  const HumanReviewCreditReservation({
    required this.id,
    required this.requestToken,
    required this.grantId,
    required this.reservedAt,
    required this.status,
    this.consumedAt,
    this.restoredAt,
  });

  final String id;
  final String requestToken;
  final String grantId;
  final DateTime reservedAt;
  final HumanReviewCreditReservationStatus status;
  final DateTime? consumedAt;
  final DateTime? restoredAt;

  HumanReviewCreditReservation copyWith({
    required HumanReviewCreditReservationStatus status,
    DateTime? consumedAt,
    DateTime? restoredAt,
  }) => HumanReviewCreditReservation(
    id: id,
    requestToken: requestToken,
    grantId: grantId,
    reservedAt: reservedAt,
    status: status,
    consumedAt: consumedAt ?? this.consumedAt,
    restoredAt: restoredAt ?? this.restoredAt,
  );
}

enum HumanReviewCreditEventType { reserved, consumed, restored }

final class HumanReviewCreditEvent {
  const HumanReviewCreditEvent({
    required this.type,
    required this.reservationId,
    required this.requestToken,
    required this.grantId,
    required this.at,
    required this.idempotencyKey,
  });

  final HumanReviewCreditEventType type;
  final String reservationId;
  final String requestToken;
  final String grantId;
  final DateTime at;
  final String idempotencyKey;
}

final class HumanReviewCreditUnavailable implements Exception {
  const HumanReviewCreditUnavailable();

  @override
  String toString() => 'No active human-review credit is available';
}

final class HumanReviewCreditLedger {
  HumanReviewCreditLedger({required Iterable<HumanReviewCreditGrant> grants})
    : _grants = {for (final grant in grants) grant.id: grant} {
    if (_grants.isEmpty) {
      throw ArgumentError('At least one grant is required');
    }
    if (_grants.length != grants.length) {
      throw ArgumentError('Grant ids must be unique');
    }
  }

  final Map<String, HumanReviewCreditGrant> _grants;
  final Map<String, HumanReviewCreditReservation> _reservations = {};
  final Map<String, _IdempotentOutcome> _outcomes = {};
  final List<HumanReviewCreditEvent> _events = [];
  int _nextReservation = 1;

  List<HumanReviewCreditReservation> get reservations =>
      List.unmodifiable(_reservations.values);
  List<HumanReviewCreditEvent> get events => List.unmodifiable(_events);

  int availableUnitsAt(DateTime at) {
    _requireUtc(at, 'at');
    return _grants.values
        .where((grant) => grant.isActiveAt(at))
        .fold(0, (sum, grant) => sum + grant.units - _usedUnits(grant.id));
  }

  HumanReviewCreditReservation reserve({
    required String requestToken,
    required String idempotencyKey,
    required DateTime at,
  }) {
    final request = _token(requestToken);
    final key = _token(idempotencyKey);
    _requireUtc(at, 'at');
    final fingerprint = 'reserve:$request';
    final replay = _replay(key, fingerprint);
    if (replay != null) return replay;

    final prior = _reservations.values.where(
      (reservation) => reservation.requestToken == request,
    );
    if (prior.isNotEmpty) {
      throw StateError('A request token cannot reserve more than once');
    }

    final candidates =
        _grants.values
            .where(
              (grant) =>
                  grant.isActiveAt(at) && _usedUnits(grant.id) < grant.units,
            )
            .toList()
          ..sort((a, b) {
            final expiry = a.validUntil.compareTo(b.validUntil);
            return expiry != 0 ? expiry : a.id.compareTo(b.id);
          });
    if (candidates.isEmpty) throw const HumanReviewCreditUnavailable();

    final grant = candidates.first;
    final reservation = HumanReviewCreditReservation(
      id: 'review-reservation-${_nextReservation++}',
      requestToken: request,
      grantId: grant.id,
      reservedAt: at,
      status: HumanReviewCreditReservationStatus.reserved,
    );
    _reservations[reservation.id] = reservation;
    _record(
      key: key,
      fingerprint: fingerprint,
      reservation: reservation,
      type: HumanReviewCreditEventType.reserved,
      at: at,
    );
    return reservation;
  }

  HumanReviewCreditReservation consume({
    required String reservationId,
    required String idempotencyKey,
    required DateTime at,
  }) => _transition(
    reservationId: reservationId,
    idempotencyKey: idempotencyKey,
    at: at,
    action: 'consume',
    target: HumanReviewCreditReservationStatus.consumed,
    eventType: HumanReviewCreditEventType.consumed,
  );

  HumanReviewCreditReservation restore({
    required String reservationId,
    required String idempotencyKey,
    required DateTime at,
  }) => _transition(
    reservationId: reservationId,
    idempotencyKey: idempotencyKey,
    at: at,
    action: 'restore',
    target: HumanReviewCreditReservationStatus.restored,
    eventType: HumanReviewCreditEventType.restored,
  );

  HumanReviewCreditReservation _transition({
    required String reservationId,
    required String idempotencyKey,
    required DateTime at,
    required String action,
    required HumanReviewCreditReservationStatus target,
    required HumanReviewCreditEventType eventType,
  }) {
    final reservationToken = _token(reservationId);
    final key = _token(idempotencyKey);
    _requireUtc(at, 'at');
    final fingerprint = '$action:$reservationToken';
    final replay = _replay(key, fingerprint);
    if (replay != null) return replay;

    final current = _reservations[reservationToken];
    if (current == null) throw StateError('Unknown reservation');
    final latestTransitionAt =
        current.restoredAt ?? current.consumedAt ?? current.reservedAt;
    if (at.isBefore(latestTransitionAt)) {
      throw StateError('Transition cannot predate the current state');
    }
    if (target == HumanReviewCreditReservationStatus.consumed &&
        current.status != HumanReviewCreditReservationStatus.reserved) {
      throw StateError('Only a reserved credit can be consumed');
    }
    if (target == HumanReviewCreditReservationStatus.restored &&
        current.status == HumanReviewCreditReservationStatus.restored) {
      throw StateError('A restored credit cannot be restored twice');
    }

    final updated = current.copyWith(
      status: target,
      consumedAt: target == HumanReviewCreditReservationStatus.consumed
          ? at
          : null,
      restoredAt: target == HumanReviewCreditReservationStatus.restored
          ? at
          : null,
    );
    _reservations[updated.id] = updated;
    _record(
      key: key,
      fingerprint: fingerprint,
      reservation: updated,
      type: eventType,
      at: at,
    );
    return updated;
  }

  int _usedUnits(String grantId) => _reservations.values
      .where(
        (reservation) =>
            reservation.grantId == grantId &&
            reservation.status != HumanReviewCreditReservationStatus.restored,
      )
      .length;

  HumanReviewCreditReservation? _replay(String key, String fingerprint) {
    final outcome = _outcomes[key];
    if (outcome == null) return null;
    if (outcome.fingerprint != fingerprint) {
      throw StateError('Idempotency key reused for a different command');
    }
    return outcome.reservation;
  }

  void _record({
    required String key,
    required String fingerprint,
    required HumanReviewCreditReservation reservation,
    required HumanReviewCreditEventType type,
    required DateTime at,
  }) {
    _outcomes[key] = _IdempotentOutcome(
      fingerprint: fingerprint,
      reservation: reservation,
    );
    _events.add(
      HumanReviewCreditEvent(
        type: type,
        reservationId: reservation.id,
        requestToken: reservation.requestToken,
        grantId: reservation.grantId,
        at: at,
        idempotencyKey: key,
      ),
    );
  }
}

final class _IdempotentOutcome {
  const _IdempotentOutcome({
    required this.fingerprint,
    required this.reservation,
  });

  final String fingerprint;
  final HumanReviewCreditReservation reservation;
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

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) throw ArgumentError.value(value, name, 'UTC required');
}
