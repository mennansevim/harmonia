import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/choir.dart';
import 'choir_backend.dart';

/// [ChoirBackend] on Supabase (ADR-041). Writes go only through the SQL
/// functions in `supabase/migrations`; reads rely on RLS.
class SupabaseChoirBackend implements ChoirBackend {
  SupabaseChoirBackend(this.client);
  final SupabaseClient client;

  @override
  String? get userId => client.auth.currentUser?.id;

  @override
  String? get email => client.auth.currentUser?.email;

  @override
  Stream<String?> get userChanges =>
      client.auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  Future<void> sendEmailCode(String email) =>
      _call(() => client.auth.signInWithOtp(email: email.trim()));

  @override
  Future<void> verifyEmailCode(String email, String code) => _call(
    () => client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim(),
      token: code.trim(),
    ),
  );

  @override
  Future<void> signOut() => _call(() => client.auth.signOut());

  @override
  Future<List<OnlineChoir>> myChoirs() => _call(() async {
    final me = userId;
    if (me == null) return const <OnlineChoir>[];
    final rows = await client
        .from('members')
        .select('*, choirs(id, name, conductor_id, created_at)')
        .eq('user_id', me)
        .order('joined_at', ascending: true);
    return [
      for (final row in rows)
        OnlineChoir(
          choir: _choir(row['choirs'] as Map<String, dynamic>),
          me: _member(row),
        ),
    ];
  });

  @override
  Future<List<JoinRequest>> myJoinRequests() => _call(() async {
    if (userId == null) return const <JoinRequest>[];
    final rows = await client.rpc('my_join_requests') as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        JoinRequest(
          id: r['id'] as String,
          choirId: r['choir_id'] as String,
          userId: userId!,
          displayName: '',
          choirName: r['choir_name'] as String,
          wantedPart: _part(r['wanted_part']),
          status: JoinStatus.values.byName(r['status'] as String),
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  });

  @override
  Future<String> createChoir(String name, String conductorName) => _call(
    () async =>
        await client.rpc(
              'create_choir',
              params: {'choir_name': name, 'conductor_name': conductorName},
            )
            as String,
  );

  @override
  Future<void> deleteChoir(String choirId) =>
      _call(() => client.rpc('delete_choir', params: {'c': choirId}));

  @override
  Future<String> createInvite(
    String choirId, {
    int validDays = 14,
    int? maxUses,
  }) => _call(
    () async =>
        await client.rpc(
              'create_invite',
              params: {
                'c': choirId,
                'valid_days': validDays,
                'max_uses': maxUses,
              },
            )
            as String,
  );

  @override
  Future<List<Invite>> invites(String choirId) => _call(() async {
    final rows = await client
        .from('invites')
        .select()
        .eq('choir_id', choirId)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        Invite(
          code: r['code'] as String,
          choirId: r['choir_id'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
          expiresAt: DateTime.parse(r['expires_at'] as String),
          maxUses: r['max_uses'] as int?,
          uses: r['uses'] as int,
          revoked: r['revoked'] as bool,
        ),
    ];
  });

  @override
  Future<void> revokeInvite(String code) =>
      _call(() => client.rpc('revoke_invite', params: {'invite_code': code}));

  @override
  Future<String> previewInvite(String code) => _call(
    () async =>
        await client.rpc('preview_invite', params: {'invite_code': code})
            as String,
  );

  @override
  Future<String> requestJoin(String code, String name, ChoirPart? part) =>
      _call(
        () async =>
            await client.rpc(
                  'request_join',
                  params: {
                    'invite_code': code,
                    'name': name.trim(),
                    'wanted': part?.name,
                  },
                )
                as String,
      );

  @override
  Future<void> cancelJoinRequest(String requestId) => _call(
    () => client.rpc('cancel_join_request', params: {'request_id': requestId}),
  );

  @override
  Future<List<JoinRequest>> joinRequests(String choirId) => _call(() async {
    final rows = await client
        .from('join_requests')
        .select()
        .eq('choir_id', choirId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return [
      for (final r in rows)
        JoinRequest(
          id: r['id'] as String,
          choirId: r['choir_id'] as String,
          userId: r['user_id'] as String,
          displayName: r['display_name'] as String,
          wantedPart: _part(r['wanted_part']),
          status: JoinStatus.values.byName(r['status'] as String),
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  });

  @override
  Future<void> decideJoin(
    String requestId, {
    required bool approve,
    ChoirPart? part,
  }) => _call(
    () => client.rpc(
      'decide_join',
      params: {'request_id': requestId, 'approve': approve, 'part': part?.name},
    ),
  );

  @override
  Future<List<ChoirMember>> members(String choirId) => _call(() async {
    final rows = await client
        .from('members')
        .select()
        .eq('choir_id', choirId)
        .order('display_name', ascending: true);
    return [for (final r in rows) _member(r)];
  });

  @override
  Future<void> setMemberPart(String choirId, String userId, ChoirPart part) =>
      _call(
        () => client.rpc(
          'set_member_part',
          params: {'c': choirId, 'singer': userId, 'p': part.name},
        ),
      );

  @override
  Future<void> setSectionLeader(String choirId, String userId, bool leads) =>
      _call(
        () => client.rpc(
          'set_section_leader',
          params: {'c': choirId, 'singer': userId, 'leads': leads},
        ),
      );

  @override
  Future<void> removeMember(String choirId, String userId) => _call(
    () => client.rpc('remove_member', params: {'c': choirId, 'who': userId}),
  );

  @override
  Future<DriveStatus> driveStatus(String choirId) => _call(() async {
    final rows =
        await client.rpc('drive_status', params: {'c': choirId}) as List;
    if (rows.isEmpty) return const DriveStatus(connected: false);
    final r = rows.first as Map<String, dynamic>;
    return DriveStatus(
      connected: r['connected'] as bool? ?? false,
      email: r['google_email'] as String?,
    );
  });

  @override
  Future<Uri> startDriveConnect(String choirId) => _call(() async {
    final res = await client.functions.invoke(
      'drive-oauth/start',
      body: {'choirId': choirId},
    );
    return Uri.parse((res.data as Map)['url'] as String);
  });

  static Choir _choir(Map<String, dynamic> r) => Choir(
    id: r['id'] as String,
    name: r['name'] as String,
    conductorId: r['conductor_id'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
  );

  static ChoirMember _member(Map<String, dynamic> r) => ChoirMember(
    userId: r['user_id'] as String,
    choirId: r['choir_id'] as String,
    displayName: r['display_name'] as String,
    role: ChoirRole.values.byName(r['role'] as String),
    part: _part(r['part']),
    leadsPart: r['leads_part'] as bool? ?? false,
    joinedAt: DateTime.parse(r['joined_at'] as String),
  );

  static ChoirPart? _part(Object? name) =>
      name == null ? null : ChoirPart.values.byName(name as String);

  /// Server texts become [ChoirBackendException]s.
  static Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw ChoirBackendException.fromMessage(e.message);
    } on FunctionException catch (e) {
      throw ChoirBackendException(
        e.status == 403 ? BackendProblem.notAllowed : BackendProblem.unknown,
        '${e.details}',
      );
    } on AuthRetryableFetchException catch (e) {
      throw ChoirBackendException(BackendProblem.offline, e.message);
    } on AuthException catch (e) {
      throw ChoirBackendException.fromMessage(e.message);
    } on SocketException catch (e) {
      throw ChoirBackendException(BackendProblem.offline, e.message);
    } on TimeoutException catch (e) {
      throw ChoirBackendException(BackendProblem.offline, '$e');
    } on Exception catch (e) {
      // package:http's ClientException: no connection.
      if ('$e'.startsWith('ClientException')) {
        throw ChoirBackendException(BackendProblem.offline, '$e');
      }
      rethrow;
    }
  }
}
