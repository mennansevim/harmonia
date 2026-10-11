/// Snapshot JSON-compatible evidence so later caller mutation cannot change it.
Object? freezeJson(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double && value.isFinite) return value;
  if (value is List) return List<Object?>.unmodifiable(value.map(freezeJson));
  if (value is Map<String, Object?>) return freezeJsonMap(value);
  throw ArgumentError('Evidence must contain finite JSON values only');
}

Map<String, Object?> freezeJsonMap(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key, freezeJson(item))),
    );
