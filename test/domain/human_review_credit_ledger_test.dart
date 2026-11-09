import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/human_review/human_review_credit_ledger.dart';

void main() {
  final start = DateTime.utc(2026, 11, 1);

  HumanReviewCreditGrant grant(
    String id, {
    int units = 1,
    int validDays = 30,
  }) => HumanReviewCreditGrant(
    id: id,
    units: units,
    validFrom: start,
    validUntil: start.add(Duration(days: validDays)),
  );

  test('reserves the active credit that expires first', () {
    final ledger = HumanReviewCreditLedger(
      grants: [grant('later', validDays: 60), grant('first', validDays: 10)],
    );

    final reservation = ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'reserve-1',
      at: start,
    );

    expect(reservation.grantId, 'first');
    expect(reservation.status, HumanReviewCreditReservationStatus.reserved);
    expect(ledger.availableUnitsAt(start), 1);
  });

  test('exact reserve retry replays without another event or credit', () {
    final ledger = HumanReviewCreditLedger(grants: [grant('monthly')]);
    final first = ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'same-key',
      at: start,
    );
    final replay = ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'same-key',
      at: start.add(const Duration(hours: 2)),
    );

    expect(replay.id, first.id);
    expect(replay.reservedAt, start);
    expect(ledger.events, hasLength(1));
    expect(ledger.availableUnitsAt(start), 0);
  });

  test('idempotency key cannot be reused for another command', () {
    final ledger = HumanReviewCreditLedger(grants: [grant('monthly')]);
    final reservation = ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'shared-key',
      at: start,
    );

    expect(
      () => ledger.consume(
        reservationId: reservation.id,
        idempotencyKey: 'shared-key',
        at: start,
      ),
      throwsStateError,
    );
    expect(ledger.events, hasLength(1));
  });

  test('same request cannot reserve a second unit with a fresh key', () {
    final ledger = HumanReviewCreditLedger(
      grants: [grant('monthly', units: 2)],
    );
    ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'reserve-1',
      at: start,
    );

    expect(
      () => ledger.reserve(
        requestToken: 'request-1',
        idempotencyKey: 'reserve-2',
        at: start,
      ),
      throwsStateError,
    );
    expect(ledger.availableUnitsAt(start), 1);
  });

  test('consume is idempotent and cannot consume a restored credit', () {
    final ledger = HumanReviewCreditLedger(grants: [grant('monthly')]);
    final reserved = ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'reserve-1',
      at: start,
    );
    final consumed = ledger.consume(
      reservationId: reserved.id,
      idempotencyKey: 'consume-1',
      at: start.add(const Duration(hours: 1)),
    );
    final replay = ledger.consume(
      reservationId: reserved.id,
      idempotencyKey: 'consume-1',
      at: start.add(const Duration(hours: 2)),
    );

    expect(consumed.status, HumanReviewCreditReservationStatus.consumed);
    expect(replay.consumedAt, consumed.consumedAt);
    expect(ledger.events, hasLength(2));
    expect(
      () => ledger.consume(
        reservationId: reserved.id,
        idempotencyKey: 'consume-2',
        at: start.add(const Duration(hours: 2)),
      ),
      throwsStateError,
    );
  });

  test('restore releases one unit exactly once after service failure', () {
    final ledger = HumanReviewCreditLedger(grants: [grant('monthly')]);
    final reserved = ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'reserve-1',
      at: start,
    );
    ledger.consume(
      reservationId: reserved.id,
      idempotencyKey: 'consume-1',
      at: start.add(const Duration(hours: 1)),
    );
    expect(
      () => ledger.restore(
        reservationId: reserved.id,
        idempotencyKey: 'backdated-restore',
        at: start.add(const Duration(minutes: 30)),
      ),
      throwsStateError,
    );
    final restored = ledger.restore(
      reservationId: reserved.id,
      idempotencyKey: 'restore-1',
      at: start.add(const Duration(hours: 2)),
    );
    final replay = ledger.restore(
      reservationId: reserved.id,
      idempotencyKey: 'restore-1',
      at: start.add(const Duration(hours: 3)),
    );

    expect(restored.status, HumanReviewCreditReservationStatus.restored);
    expect(replay.restoredAt, restored.restoredAt);
    final consumeReplay = ledger.consume(
      reservationId: reserved.id,
      idempotencyKey: 'consume-1',
      at: start.add(const Duration(hours: 5)),
    );
    expect(consumeReplay.status, HumanReviewCreditReservationStatus.consumed);
    expect(ledger.availableUnitsAt(start), 1);
    expect(ledger.events, hasLength(3));
    expect(
      () => ledger.restore(
        reservationId: reserved.id,
        idempotencyKey: 'restore-2',
        at: start.add(const Duration(hours: 4)),
      ),
      throwsStateError,
    );
  });

  test('expired and exhausted grants fail closed', () {
    final ledger = HumanReviewCreditLedger(grants: [grant('monthly')]);
    expect(
      () => ledger.reserve(
        requestToken: 'late',
        idempotencyKey: 'reserve-late',
        at: start.add(const Duration(days: 30)),
      ),
      throwsA(isA<HumanReviewCreditUnavailable>()),
    );
    ledger.reserve(
      requestToken: 'request-1',
      idempotencyKey: 'reserve-1',
      at: start,
    );
    expect(
      () => ledger.reserve(
        requestToken: 'request-2',
        idempotencyKey: 'reserve-2',
        at: start,
      ),
      throwsA(isA<HumanReviewCreditUnavailable>()),
    );
  });

  test('invalid grants, local time and mutable snapshots are rejected', () {
    expect(
      () => HumanReviewCreditGrant(
        id: '../credit',
        units: 1,
        validFrom: start,
        validUntil: start.add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
    expect(
      () => HumanReviewCreditGrant(
        id: 'credit',
        units: 0,
        validFrom: start,
        validUntil: start.add(const Duration(days: 1)),
      ),
      throwsArgumentError,
    );
    final ledger = HumanReviewCreditLedger(grants: [grant('monthly')]);
    expect(
      () => ledger.availableUnitsAt(DateTime(2026, 11, 1)),
      throwsArgumentError,
    );
    expect(() => ledger.events.clear(), throwsUnsupportedError);
    expect(() => ledger.reservations.clear(), throwsUnsupportedError);
  });
}
