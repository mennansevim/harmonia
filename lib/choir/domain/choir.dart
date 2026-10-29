import 'choir_json.dart';

/// Pure choir-module domain (CHOIR-M1, ADR-035). No IO, no backend: these
/// types are what a future server adapter stores and the conductor panel and
/// singer screens read.

enum ChoirRole { conductor, singer }

/// SATB parts. Divisi (S1/S2…) is left for when a pilot choir needs it.
enum ChoirPart {
  soprano('Soprano'),
  alto('Alto'),
  tenor('Tenor'),
  bass('Bas');

  const ChoirPart(this.title);
  final String title;
}

class Choir {
  Choir({
    required this.id,
    required this.name,
    required this.conductorId,
    required this.createdAt,
  }) {
    if (id.trim().isEmpty || conductorId.trim().isEmpty) {
      throw ArgumentError('Choir needs an id and a conductor');
    }
    if (name.trim().isEmpty) throw ArgumentError('Choir needs a name');
  }

  final String id;
  final String name;
  final String conductorId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'conductorId': conductorId,
    'createdAt': writeTime(createdAt),
  };

  factory Choir.fromJson(Map<String, Object?> json) => Choir(
    id: reqId(json, 'id'),
    name: req<String>(json, 'name'),
    conductorId: reqId(json, 'conductorId'),
    createdAt: reqTime(json, 'createdAt'),
  );
}

/// A person in one choir. Singers may be waiting for a part ([part] null);
/// conductors never carry one.
class ChoirMember {
  ChoirMember({
    required this.userId,
    required this.choirId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.part,
  }) {
    if (userId.trim().isEmpty || choirId.trim().isEmpty) {
      throw ArgumentError('Member needs user and choir ids');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError('Member needs a display name');
    }
    if (role == ChoirRole.conductor && part != null) {
      throw ArgumentError('A conductor has no voice part');
    }
  }

  final String userId;
  final String choirId;
  final String displayName;
  final ChoirRole role;
  final ChoirPart? part;
  final DateTime joinedAt;

  bool get isSinger => role == ChoirRole.singer;

  /// The conductor's part assignment; `null` returns the singer to
  /// "unassigned".
  ChoirMember withPart(ChoirPart? next) => ChoirMember(
    userId: userId,
    choirId: choirId,
    displayName: displayName,
    role: role,
    joinedAt: joinedAt,
    part: next,
  );

  Map<String, Object?> toJson() => {
    'userId': userId,
    'choirId': choirId,
    'displayName': displayName,
    'role': role.name,
    'part': part?.name,
    'joinedAt': writeTime(joinedAt),
  };

  factory ChoirMember.fromJson(Map<String, Object?> json) => ChoirMember(
    userId: reqId(json, 'userId'),
    choirId: reqId(json, 'choirId'),
    displayName: req<String>(json, 'displayName'),
    role: reqEnum(json, 'role', ChoirRole.values),
    part: optEnum(json, 'part', ChoirPart.values),
    joinedAt: reqTime(json, 'joinedAt'),
  );
}

enum InviteCheck { ok, expired, revoked, exhausted }

/// A join code for one choir. Invites always expire; [maxUses] `null` means
/// a shared choir code, `1` a personal link.
class Invite {
  Invite({
    required this.code,
    required this.choirId,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses,
    this.uses = 0,
    this.revoked = false,
  }) {
    if (code.trim().length < 6) {
      throw ArgumentError('Invite code must be at least 6 characters');
    }
    if (choirId.trim().isEmpty) throw ArgumentError('Invite needs a choir');
    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError('Invite must expire after it is created');
    }
    if (maxUses != null && maxUses! < 1) {
      throw ArgumentError('maxUses must be at least 1');
    }
    if (uses < 0 || (maxUses != null && uses > maxUses!)) {
      throw ArgumentError('uses out of range');
    }
  }

  final String code;
  final String choirId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int? maxUses;
  final int uses;
  final bool revoked;

  /// Revocation wins over expiry, which wins over exhaustion, so the
  /// message shown is the one the conductor can act on.
  InviteCheck check(DateTime now) {
    if (revoked) return InviteCheck.revoked;
    if (!now.isBefore(expiresAt)) return InviteCheck.expired;
    if (maxUses != null && uses >= maxUses!) return InviteCheck.exhausted;
    return InviteCheck.ok;
  }

  /// Consumes one use; throws [StateError] unless [check] is ok.
  Invite redeem(DateTime now) {
    final status = check(now);
    if (status != InviteCheck.ok) {
      throw StateError('Invite cannot be redeemed: ${status.name}');
    }
    return _copy(uses: uses + 1);
  }

  Invite revoke() => _copy(revoked: true);

  Invite _copy({int? uses, bool? revoked}) => Invite(
    code: code,
    choirId: choirId,
    createdAt: createdAt,
    expiresAt: expiresAt,
    maxUses: maxUses,
    uses: uses ?? this.uses,
    revoked: revoked ?? this.revoked,
  );

  Map<String, Object?> toJson() => {
    'code': code,
    'choirId': choirId,
    'createdAt': writeTime(createdAt),
    'expiresAt': writeTime(expiresAt),
    'maxUses': maxUses,
    'uses': uses,
    'revoked': revoked,
  };

  factory Invite.fromJson(Map<String, Object?> json) => Invite(
    code: reqId(json, 'code'),
    choirId: reqId(json, 'choirId'),
    createdAt: reqTime(json, 'createdAt'),
    expiresAt: reqTime(json, 'expiresAt'),
    maxUses: opt<int>(json, 'maxUses'),
    uses: req<int>(json, 'uses'),
    revoked: req<bool>(json, 'revoked'),
  );
}
