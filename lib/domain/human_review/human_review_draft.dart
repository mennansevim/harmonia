/// Local-only contract for preparing a future Plus educator-review request.
///
/// It owns no file path, upload, entitlement, credit or payment state. A draft
/// becoming locally complete must never be interpreted as an accepted request.
enum HumanReviewGoal { conservatoryEar, choir, voice, instrument }

enum HumanReviewProgressScope { none, sevenDays, thirtyDays, selectedSessions }

final class HumanReviewRecordingSelection {
  HumanReviewRecordingSelection({
    required String localToken,
    required this.duration,
    required this.byteLength,
    required String codec,
  }) : localToken = _boundedToken(localToken),
       codec = _boundedToken(codec, maxLength: 16) {
    if (duration <= Duration.zero || duration > const Duration(minutes: 5)) {
      throw ArgumentError.value(duration, 'duration');
    }
    if (byteLength <= 0 || byteLength > 50 * 1024 * 1024) {
      throw ArgumentError.value(byteLength, 'byteLength');
    }
  }

  final String localToken;
  final Duration duration;
  final int byteLength;
  final String codec;

  /// Product hypothesis only; the real range still needs pilot approval.
  bool get matchesProposedPilotLength =>
      duration >= const Duration(seconds: 30) &&
      duration <= const Duration(seconds: 120);
}

final class HumanReviewDraft {
  HumanReviewDraft({
    required this.goal,
    required String question,
    required this.progressScope,
    required this.createdAt,
    this.recording,
    this.consentVersion,
    this.consentGranted = false,
  }) : question = _boundedText(question, maxLength: 400) {
    if (!createdAt.isUtc) {
      throw ArgumentError.value(createdAt, 'createdAt', 'UTC required');
    }
    if (consentGranted &&
        (consentVersion == null || consentVersion!.trim().isEmpty)) {
      throw ArgumentError('Granted consent requires an explicit version');
    }
  }

  final HumanReviewGoal goal;
  final String question;
  final HumanReviewProgressScope progressScope;
  final DateTime createdAt;
  final HumanReviewRecordingSelection? recording;
  final String? consentVersion;
  final bool consentGranted;

  bool get locallyComplete =>
      question.isNotEmpty &&
      recording?.matchesProposedPilotLength == true &&
      consentGranted;
}

enum HumanReviewAvailabilityBlocker {
  backendUnavailable,
  legalReviewPending,
  entitlementUnavailable,
  capacityUnverified,
}

final class HumanReviewAvailability {
  const HumanReviewAvailability({required this.blockers});

  const HumanReviewAvailability.preview()
    : blockers = const {
        HumanReviewAvailabilityBlocker.backendUnavailable,
        HumanReviewAvailabilityBlocker.legalReviewPending,
        HumanReviewAvailabilityBlocker.entitlementUnavailable,
        HumanReviewAvailabilityBlocker.capacityUnverified,
      };

  final Set<HumanReviewAvailabilityBlocker> blockers;
  bool get canSubmit => blockers.isEmpty;
}

abstract interface class HumanReviewGateway {
  Future<HumanReviewAvailability> availability();
  Future<String> submit(
    HumanReviewDraft draft, {
    required String idempotencyKey,
  });
}

/// Fail-closed adapter used until the authorized backend and service exist.
final class UnavailableHumanReviewGateway implements HumanReviewGateway {
  const UnavailableHumanReviewGateway();

  @override
  Future<HumanReviewAvailability> availability() async =>
      const HumanReviewAvailability.preview();

  @override
  Future<String> submit(
    HumanReviewDraft draft, {
    required String idempotencyKey,
  }) => Future.error(
    StateError('Human review submission is not available in this build'),
  );
}

String _boundedToken(String value, {int maxLength = 80}) {
  final normalized = value.trim();
  if (normalized.isEmpty ||
      normalized.length > maxLength ||
      !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(normalized)) {
    throw ArgumentError.value(value, 'value');
  }
  return normalized;
}

String _boundedText(String value, {required int maxLength}) {
  final normalized = value.trim();
  if (normalized.length > maxLength ||
      normalized.runes.any((rune) => rune < 0x20 && rune != 0x0A)) {
    throw ArgumentError.value(value, 'value');
  }
  return normalized;
}
