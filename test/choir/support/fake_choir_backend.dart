import 'dart:async';

import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/online/choir_backend.dart';

/// In-memory server with the same rules as the SQL functions, shared by
/// several "devices": each [FakeChoirBackend] is one signed-in person on a
/// [FakeChoirServer].
class FakeChoirServer {
  final choirs = <Choir>[];
  final members = <ChoirMember>[];
  final invites = <Invite>[];
  final requests = <JoinRequest>[];

  /// email → the code that was "sent".
  final sentCodes = <String, String>{};

  /// choir id → the connected Drive account.
  final drives = <String, String>{};
  var _seq = 0;
  DateTime now = DateTime.utc(2026, 11, 10, 18);

  String nextId(String prefix) => '$prefix-${++_seq}';

  ChoirMember? member(String choirId, String? userId) {
    for (final m in members) {
      if (m.choirId == choirId && m.userId == userId) return m;
    }
    return null;
  }

  bool conducts(String choirId, String? userId) =>
      member(choirId, userId)?.isConductor ?? false;
}

class FakeChoirBackend implements ChoirBackend {
  FakeChoirBackend(this.server, {String? signedInAs}) : _user = signedInAs;

  final FakeChoirServer server;
  String? _user;
  String? _email;
  final _changes = StreamController<String?>.broadcast();

  /// Fails every call with [BackendProblem.offline] while true.
  bool offline = false;

  @override
  String? get userId => _user;

  @override
  String? get email => _email;

  @override
  Stream<String?> get userChanges => _changes.stream;

  Never _deny(String message) =>
      throw ChoirBackendException.fromMessage(message);

  String _me() {
    if (offline) throw const ChoirBackendException(BackendProblem.offline);
    return _user ?? _deny('not signed in');
  }

  @override
  Future<void> sendEmailCode(String email) async {
    if (offline) throw const ChoirBackendException(BackendProblem.offline);
    server.sentCodes[email.trim().toLowerCase()] = '123456';
  }

  @override
  Future<void> verifyEmailCode(String email, String code) async {
    final key = email.trim().toLowerCase();
    if (server.sentCodes[key] != code.trim()) {
      _deny('Token has expired or is invalid');
    }
    _user = 'user:$key';
    _email = key;
    _changes.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _email = null;
    _changes.add(null);
  }

  @override
  Future<List<OnlineChoir>> myChoirs() async {
    final me = _me();
    return [
      for (final m in server.members)
        if (m.userId == me)
          OnlineChoir(
            choir: server.choirs.firstWhere((c) => c.id == m.choirId),
            me: m,
          ),
    ];
  }

  @override
  Future<List<JoinRequest>> myJoinRequests() async {
    final me = _me();
    return [
      for (final r in server.requests.reversed)
        if (r.userId == me)
          JoinRequest(
            id: r.id,
            choirId: r.choirId,
            userId: r.userId,
            displayName: r.displayName,
            status: r.status,
            createdAt: r.createdAt,
            wantedPart: r.wantedPart,
            choirName: server.choirs.firstWhere((c) => c.id == r.choirId).name,
          ),
    ];
  }

  @override
  Future<String> createChoir(String name, String conductorName) async {
    final me = _me();
    final choir = Choir(
      id: server.nextId('choir'),
      name: name.trim(),
      conductorId: me,
      createdAt: server.now,
    );
    server.choirs.add(choir);
    server.members.add(
      ChoirMember(
        userId: me,
        choirId: choir.id,
        displayName: conductorName.trim(),
        role: ChoirRole.conductor,
        joinedAt: server.now,
      ),
    );
    return choir.id;
  }

  @override
  Future<void> deleteChoir(String choirId) async {
    if (!server.conducts(choirId, _me())) _deny('only the conductor deletes');
    server.choirs.removeWhere((c) => c.id == choirId);
    server.members.removeWhere((m) => m.choirId == choirId);
    server.invites.removeWhere((i) => i.choirId == choirId);
    server.requests.removeWhere((r) => r.choirId == choirId);
  }

  @override
  Future<String> createInvite(
    String choirId, {
    int validDays = 14,
    int? maxUses,
  }) async {
    if (!server.conducts(choirId, _me())) _deny('only the conductor invites');
    const letters = 'ABCDEFGHJK';
    final code = 'ABCD22${letters[server.invites.length % 10]}A';
    server.invites.add(
      Invite(
        code: code,
        choirId: choirId,
        createdAt: server.now,
        expiresAt: server.now.add(Duration(days: validDays)),
        maxUses: maxUses,
      ),
    );
    return code;
  }

  @override
  Future<List<Invite>> invites(String choirId) async {
    if (!server.conducts(choirId, _me())) return const [];
    return [
      for (final i in server.invites.reversed)
        if (i.choirId == choirId) i,
    ];
  }

  @override
  Future<void> revokeInvite(String code) async {
    final me = _me();
    final i = server.invites.indexWhere(
      (i) => i.code == code && server.conducts(i.choirId, me),
    );
    if (i < 0) _deny('no such invite');
    server.invites[i] = server.invites[i].revoke();
  }

  Invite _valid(String code) {
    for (final i in server.invites) {
      if (i.code == code.toUpperCase() &&
          i.check(server.now) == InviteCheck.ok) {
        return i;
      }
    }
    _deny('invite not valid');
  }

  @override
  Future<String> previewInvite(String code) async {
    _me();
    final invite = _valid(code);
    return server.choirs.firstWhere((c) => c.id == invite.choirId).name;
  }

  @override
  Future<String> requestJoin(String code, String name, ChoirPart? part) async {
    final me = _me();
    final invite = _valid(code);
    if (server.member(invite.choirId, me) != null) _deny('already a member');
    for (final r in server.requests) {
      if (r.choirId == invite.choirId &&
          r.userId == me &&
          r.status == JoinStatus.pending) {
        return r.id;
      }
    }
    final i = server.invites.indexOf(invite);
    server.invites[i] = invite.redeem(server.now);
    final request = JoinRequest(
      id: server.nextId('req'),
      choirId: invite.choirId,
      userId: me,
      displayName: name.trim(),
      status: JoinStatus.pending,
      createdAt: server.now,
      wantedPart: part,
    );
    server.requests.add(request);
    return request.id;
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    final me = _me();
    final before = server.requests.length;
    server.requests.removeWhere(
      (r) =>
          r.id == requestId && r.userId == me && r.status == JoinStatus.pending,
    );
    if (server.requests.length == before) _deny('no such request');
  }

  @override
  Future<List<JoinRequest>> joinRequests(String choirId) async {
    if (!server.conducts(choirId, _me())) return const [];
    return [
      for (final r in server.requests)
        if (r.choirId == choirId && r.status == JoinStatus.pending) r,
    ];
  }

  @override
  Future<void> decideJoin(
    String requestId, {
    required bool approve,
    ChoirPart? part,
  }) async {
    final me = _me();
    final i = server.requests.indexWhere((r) => r.id == requestId);
    if (i < 0 || !server.conducts(server.requests[i].choirId, me)) {
      _deny('no such request');
    }
    final r = server.requests[i];
    if (r.status != JoinStatus.pending) _deny('already decided');
    server.requests[i] = JoinRequest(
      id: r.id,
      choirId: r.choirId,
      userId: r.userId,
      displayName: r.displayName,
      status: approve ? JoinStatus.approved : JoinStatus.declined,
      createdAt: r.createdAt,
      wantedPart: r.wantedPart,
    );
    if (approve) {
      server.members.add(
        ChoirMember(
          userId: r.userId,
          choirId: r.choirId,
          displayName: r.displayName,
          role: ChoirRole.singer,
          part: part ?? r.wantedPart,
          joinedAt: server.now,
        ),
      );
    }
  }

  @override
  Future<List<ChoirMember>> members(String choirId) async {
    if (server.member(choirId, _me()) == null) return const [];
    return [
      for (final m in server.members)
        if (m.choirId == choirId) m,
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  void _changeSinger(
    String choirId,
    String userId,
    ChoirMember Function(ChoirMember) change,
  ) {
    if (!server.conducts(choirId, _me())) {
      _deny('only the conductor assigns parts');
    }
    final i = server.members.indexWhere(
      (m) => m.choirId == choirId && m.userId == userId && m.isSinger,
    );
    if (i < 0) _deny('no such singer');
    server.members[i] = change(server.members[i]);
  }

  @override
  Future<void> setMemberPart(
    String choirId,
    String userId,
    ChoirPart part,
  ) async => _changeSinger(choirId, userId, (m) => m.withPart(part));

  @override
  Future<void> setSectionLeader(
    String choirId,
    String userId,
    bool leads,
  ) async => _changeSinger(choirId, userId, (m) {
    if (m.part == null) _deny('no such singer with a part');
    return m.withLeading(leads);
  });

  @override
  Future<void> removeMember(String choirId, String userId) async {
    final me = _me();
    if (userId != me && !server.conducts(choirId, me)) _deny('not allowed');
    final before = server.members.length;
    server.members.removeWhere(
      (m) => m.choirId == choirId && m.userId == userId && m.isSinger,
    );
    if (server.members.length == before) _deny('no such singer');
  }

  @override
  Future<DriveStatus> driveStatus(String choirId) async {
    final me = _me();
    if (server.member(choirId, me) == null) {
      return const DriveStatus(connected: false);
    }
    final email = server.drives[choirId];
    return DriveStatus(
      connected: email != null,
      email: server.conducts(choirId, me) ? email : null,
    );
  }

  @override
  Future<Uri> startDriveConnect(String choirId) async {
    if (!server.conducts(choirId, _me())) _deny('not allowed');
    return Uri.parse('https://accounts.google.test/consent?choir=$choirId');
  }
}
