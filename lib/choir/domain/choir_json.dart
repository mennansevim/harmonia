/// Strict JSON readers shared by the choir domain. Every reader throws
/// [FormatException] naming the field, so a malformed server or disk record
/// is rejected instead of silently defaulted.
library;

T req<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('choir: "$key" missing or not $T');
}

T? opt<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is T) return value as T?;
  throw FormatException('choir: "$key" is not $T');
}

String reqId(Map<String, Object?> json, String key) {
  final value = req<String>(json, key);
  if (value.trim().isEmpty) throw FormatException('choir: "$key" is empty');
  return value;
}

DateTime reqTime(Map<String, Object?> json, String key) =>
    parseTime(req<String>(json, key), key);

DateTime? optTime(Map<String, Object?> json, String key) {
  final raw = opt<String>(json, key);
  return raw == null ? null : parseTime(raw, key);
}

DateTime parseTime(String raw, String key) {
  final t = DateTime.tryParse(raw);
  if (t == null || !t.isUtc) {
    throw FormatException('choir: "$key" must be a UTC ISO-8601 time');
  }
  return t;
}

String writeTime(DateTime t) => t.toUtc().toIso8601String();

E reqEnum<E extends Enum>(
  Map<String, Object?> json,
  String key,
  List<E> values,
) {
  final name = req<String>(json, key);
  for (final v in values) {
    if (v.name == name) return v;
  }
  throw FormatException('choir: "$key" has unknown value "$name"');
}

E? optEnum<E extends Enum>(
  Map<String, Object?> json,
  String key,
  List<E> values,
) => json[key] == null ? null : reqEnum(json, key, values);

List<E> enumList<E extends Enum>(
  Map<String, Object?> json,
  String key,
  List<E> values,
) {
  final raw = req<List<Object?>>(json, key);
  return List.unmodifiable([
    for (final item in raw) reqEnum({key: item}, key, values),
  ]);
}

List<String> idList(Map<String, Object?> json, String key) {
  final raw = req<List<Object?>>(json, key);
  return List.unmodifiable([
    for (final item in raw) reqId({key: item}, key),
  ]);
}
