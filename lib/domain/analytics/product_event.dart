/// ANALYTICS-01 event names. Nothing here sends data: a future provider
/// adapter needs a separate decision, consent and approval. Events carry
/// only allow-listed keys with enum/bool/small-int/id values — never audio,
/// PCM, free text, names, e-mail, precise location or a persistent device id.
enum ProductEventName {
  appOpened,
  goalSelected,
  exerciseStarted,
  exerciseFinished,
  resultDetailsOpened,
  nextStepShown,
  nextStepApplied,
  calibrationFinished,
  microphonePermission,
  historyDeleted,
  profileDeleted,
}

/// Allowed property keys per event, with a validator for each value.
final Map<ProductEventName, Map<String, bool Function(Object?)>> _schema = {
  ProductEventName.appOpened: {},
  ProductEventName.goalSelected: {'goal': _enumValue(_goals)},
  ProductEventName.exerciseStarted: {
    'exerciseId': _contentId,
    'skill': _enumValue(_skills),
    'mode': _enumValue(_modes),
    'contentVersion': _contentId,
  },
  ProductEventName.exerciseFinished: {
    'exerciseId': _contentId,
    'skill': _enumValue(_skills),
    'measured': _bool,
    'retryReason': _nullable(_token),
    'referencePlays': _smallInt,
    'retentionCheck': _bool,
  },
  ProductEventName.resultDetailsOpened: {'skill': _enumValue(_skills)},
  ProductEventName.nextStepShown: {'kind': _token, 'surface': _token},
  ProductEventName.nextStepApplied: {'kind': _token, 'surface': _token},
  ProductEventName.calibrationFinished: {'status': _token, 'route': _token},
  ProductEventName.microphonePermission: {'granted': _bool},
  ProductEventName.historyDeleted: {
    'scope': _enumValue({'one', 'all'}),
  },
  ProductEventName.profileDeleted: {},
};

const _goals = {'conservatory', 'foundations', 'choir'};
const _skills = {'pitch', 'interval', 'chord', 'rhythm', 'melody', 'range'};
const _modes = {'learning', 'recall_exam', 'sight_reading', 'choir_practice'};
final _tokenPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{0,39}$');
final _contentPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,63}$');

bool _bool(Object? v) => v is bool;
bool _smallInt(Object? v) => v is int && v >= 0 && v <= 1000;
bool _token(Object? v) => v is String && _tokenPattern.hasMatch(v);
bool _contentId(Object? v) => v is String && _contentPattern.hasMatch(v);
bool Function(Object?) _enumValue(Set<String> allowed) =>
    (v) => v is String && allowed.contains(v);
bool Function(Object?) _nullable(bool Function(Object?) inner) =>
    (v) => v == null || inner(v);

class ProductEvent {
  ProductEvent._(this.name, this.properties, this.sessionId, this.occurredAt);

  /// Throws ArgumentError for unknown keys, missing keys or invalid values.
  /// [sessionId] is a random per-launch id, not a device/user identifier.
  factory ProductEvent({
    required ProductEventName name,
    required String sessionId,
    required DateTime occurredAt,
    Map<String, Object?> properties = const {},
  }) {
    final schema = _schema[name]!;
    if (!RegExp(r'^[a-f0-9]{16,32}$').hasMatch(sessionId)) {
      throw ArgumentError('Session id must be a random hex token');
    }
    for (final key in properties.keys) {
      if (!schema.containsKey(key)) {
        throw ArgumentError('Property "$key" is not allowed for ${name.name}');
      }
    }
    for (final entry in schema.entries) {
      if (!properties.containsKey(entry.key) ||
          !entry.value(properties[entry.key])) {
        throw ArgumentError('Invalid "${entry.key}" for ${name.name}');
      }
    }
    // Minute precision: enough for D1/D7/D30 and funnels, less re-identifying.
    final t = occurredAt.toUtc();
    return ProductEvent._(
      name,
      Map.unmodifiable(properties),
      sessionId,
      DateTime.utc(t.year, t.month, t.day, t.hour, t.minute),
    );
  }

  final ProductEventName name;
  final Map<String, Object?> properties;
  final String sessionId;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'event': name.name,
    'sessionId': sessionId,
    'occurredAt': occurredAt.toIso8601String(),
    'properties': properties,
  };
}

/// Destination for validated events. The only implementation in the app is
/// a bounded in-memory log; no network sink exists.
abstract interface class ProductEventSink {
  void record(ProductEvent event);
}

class InMemoryEventLog implements ProductEventSink {
  InMemoryEventLog({this.capacity = 500});
  final int capacity;
  final List<ProductEvent> _events = [];
  List<ProductEvent> get events => List.unmodifiable(_events);

  @override
  void record(ProductEvent event) {
    if (_events.length >= capacity) _events.removeAt(0);
    _events.add(event);
  }

  void clear() => _events.clear();
}
