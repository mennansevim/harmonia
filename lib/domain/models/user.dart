/// A Harmonia user.
///
/// ADR-004: Guests may complete exercises before creating an account.
/// ADR-003: Raw audio consent is tracked separately from account creation.
class User {
  const User({
    required this.id,
    required this.isGuest,
    required this.createdAt,
    this.displayName,
    this.locale = 'tr',
    this.rawAudioConsentGiven = false,
  });

  final String id;
  final String? displayName;

  /// True until the guest converts to a registered account (ADR-004).
  final bool isGuest;

  final String locale;

  /// Explicit opt-in to store raw recordings (ADR-003). Defaults to false:
  /// raw audio must never be persisted without this being true.
  final bool rawAudioConsentGiven;

  final DateTime createdAt;

  User copyWith({
    String? displayName,
    bool? isGuest,
    String? locale,
    bool? rawAudioConsentGiven,
  }) {
    return User(
      id: id,
      createdAt: createdAt,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest ?? this.isGuest,
      locale: locale ?? this.locale,
      rawAudioConsentGiven: rawAudioConsentGiven ?? this.rawAudioConsentGiven,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          isGuest == other.isGuest &&
          locale == other.locale &&
          rawAudioConsentGiven == other.rawAudioConsentGiven &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    isGuest,
    locale,
    rawAudioConsentGiven,
    createdAt,
  );
}
