import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/analytics/product_event.dart';

const _session = '0123456789abcdef';
final _t = DateTime.utc(2026, 10, 11, 12, 34, 56, 789);

ProductEvent _e(ProductEventName n, Map<String, Object?> p) =>
    ProductEvent(name: n, sessionId: _session, occurredAt: _t, properties: p);

void main() {
  test('valid events serialize with minute precision', () {
    final e = _e(ProductEventName.exerciseFinished, {
      'exerciseId': 'draft-rhythm-quarters',
      'skill': 'rhythm',
      'measured': true,
      'retryReason': null,
      'referencePlays': 2,
      'retentionCheck': false,
    });
    expect(e.toJson()['occurredAt'], '2026-10-11T12:34:00.000Z');
    expect(e.properties['skill'], 'rhythm');
  });

  test('free text, unknown keys and personal data are rejected', () {
    for (final bad in <Map<String, Object?>>[
      {'goal': 'conservatory', 'email': 'a@b.c'},
      {'goal': 'Konservatuvar sınavına hazırlanıyorum'},
      {'goal': 'opera'},
      {},
    ]) {
      expect(() => _e(ProductEventName.goalSelected, bad), throwsArgumentError);
    }
    expect(
      () => _e(ProductEventName.calibrationFinished, {
        'status': 'calibrated',
        'route': 'Mennan kulaklığı',
      }),
      throwsArgumentError,
    );
  });

  test('audio-like payloads cannot be attached anywhere', () {
    for (final name in ProductEventName.values) {
      expect(
        () => _e(name, {'samples': List.filled(10, 0.1)}),
        throwsArgumentError,
        reason: name.name,
      );
    }
  });

  test('session id must be a random token, not a device/user id', () {
    for (final id in ['user-42', 'mennan@example.com', 'ABCDEF', '']) {
      expect(
        () => ProductEvent(
          name: ProductEventName.appOpened,
          sessionId: id,
          occurredAt: _t,
        ),
        throwsArgumentError,
      );
    }
  });

  test('in-memory log is bounded and drops the oldest', () {
    final log = InMemoryEventLog(capacity: 2);
    for (var i = 0; i < 3; i++) {
      log.record(_e(ProductEventName.microphonePermission, {'granted': i > 0}));
    }
    expect(log.events, hasLength(2));
    expect(log.events.first.properties['granted'], isTrue);
  });
}
