import '../domain/choir.dart';

/// The choir server (ADR-041) as the app sees it: sign-in, choirs, invites,
/// join requests and the roster. Every call is checked again on the server;
/// nothing here grants access by itself. Supabase in the app
/// ([SupabaseChoirBackend]), an in-memory copy in tests.
abstract interface class ChoirBackend {
  /// The signed-in user id, or null.
  String? get userId;

  /// The signed-in email, for the account row.
  String? get email;

  /// Fires when someone signs in or out.
  Stream<String?> get userChanges;

  /// Sends a 6-digit sign-in code to [email].
  Future<void> sendEmailCode(String email);

  /// Signs in with the code from the mail.
  Future<void> verifyEmailCode(String email, String code);

  Future<void> signOut();

  /// Choirs the user is an approved member of, with their own row.
  Future<List<OnlineChoir>> myChoirs();

  /// The user's own requests: pending ones, and decided ones for 30 days.
  Future<List<JoinRequest>> myJoinRequests();

  Future<String> createChoir(String name, String conductorName);
  Future<void> deleteChoir(String choirId);

  Future<String> createInvite(String choirId, {int validDays, int? maxUses});
  Future<List<Invite>> invites(String choirId);
  Future<void> revokeInvite(String code);

  /// The choir name behind a code, before asking to join.
  Future<String> previewInvite(String code);
  Future<String> requestJoin(String code, String name, ChoirPart? part);
  Future<void> cancelJoinRequest(String requestId);

  /// Pending requests of a choir (conductor only).
  Future<List<JoinRequest>> joinRequests(String choirId);
  Future<void> decideJoin(
    String requestId, {
    required bool approve,
    ChoirPart? part,
  });

  Future<List<ChoirMember>> members(String choirId);
  Future<void> setMemberPart(String choirId, String userId, ChoirPart part);
  Future<void> setSectionLeader(String choirId, String userId, bool leads);

  /// The conductor removes a singer, or a singer leaves ([userId] is self).
  Future<void> removeMember(String choirId, String userId);

  /// Whether the choir's Drive is connected; the account only for the
  /// conductor.
  Future<DriveStatus> driveStatus(String choirId);

  /// The Google consent page that connects the choir's Drive (conductor).
  Future<Uri> startDriveConnect(String choirId);
}

class DriveStatus {
  const DriveStatus({required this.connected, this.email});
  final bool connected;
  final String? email;
}

/// A choir and the user's place in it.
class OnlineChoir {
  const OnlineChoir({required this.choir, required this.me});
  final Choir choir;
  final ChoirMember me;

  String get id => choir.id;
  bool get iConduct => me.isConductor;
}

enum JoinStatus { pending, approved, declined }

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.choirId,
    required this.userId,
    required this.displayName,
    required this.status,
    required this.createdAt,
    this.choirName,
    this.wantedPart,
  });
  final String id;
  final String choirId;
  final String userId;
  final String displayName;
  final JoinStatus status;
  final DateTime createdAt;

  /// Only on the requester's own list.
  final String? choirName;
  final ChoirPart? wantedPart;
}

/// Why a server call was refused, in words the screens can show.
enum BackendProblem {
  /// Expired, revoked, used up or mistyped.
  inviteInvalid,
  alreadyMember,
  alreadyDecided,
  notAllowed,
  wrongCode,

  /// The conductor has not connected the choir's Google Drive yet.
  driveMissing,
  offline,
  unknown,
}

class ChoirBackendException implements Exception {
  const ChoirBackendException(this.problem, [this.detail = '']);
  final BackendProblem problem;
  final String detail;

  /// Maps the server functions' exception texts.
  factory ChoirBackendException.fromMessage(String message) {
    final m = message.toLowerCase();
    final problem = switch (m) {
      _ when m.contains('invite not valid') => BackendProblem.inviteInvalid,
      _ when m.contains('already a member') => BackendProblem.alreadyMember,
      _ when m.contains('already decided') => BackendProblem.alreadyDecided,
      _
          when m.contains('not allowed') ||
              m.contains('only the conductor') ||
              m.contains('no such') =>
        BackendProblem.notAllowed,
      _
          when m.contains('token') &&
              (m.contains('expired') || m.contains('invalid')) =>
        BackendProblem.wrongCode,
      _ => BackendProblem.unknown,
    };
    return ChoirBackendException(problem, message);
  }

  @override
  String toString() => 'ChoirBackendException(${problem.name}: $detail)';
}
