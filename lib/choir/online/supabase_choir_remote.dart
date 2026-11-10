import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/choir_remote.dart';
import '../domain/assignment.dart';
import '../domain/choir.dart';
import '../domain/resource.dart';
import '../domain/submission.dart';
import 'choir_backend.dart';

/// [ChoirRemote] on Supabase + the `media` Edge Function (ADR-041). Bytes go
/// straight to the choir's Drive through a one-off upload URL; reads come
/// back through the function after its permission check.
class SupabaseChoirRemote implements ChoirRemote {
  SupabaseChoirRemote(
    this.client, {
    required this.functionsUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final SupabaseClient client;

  /// e.g. `https://<ref>.supabase.co/functions/v1`.
  final String functionsUrl;
  final String apiKey;
  final http.Client _http;

  @override
  String? get userId => client.auth.currentUser?.id;

  Map<String, String> get _auth => {
    'authorization': 'Bearer ${client.auth.currentSession?.accessToken ?? ''}',
    'apikey': apiKey,
  };

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) =>
      _guard(() async {
        final res = await _http.post(
          Uri.parse('$functionsUrl/$path'),
          headers: {..._auth, 'content-type': 'application/json'},
          body: jsonEncode(body),
        );
        final data = res.body.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode != 200) {
          throw ChoirBackendException(switch (res.statusCode) {
            401 || 403 || 404 => BackendProblem.notAllowed,
            409 when data['error'] == 'drive not connected' =>
              BackendProblem.driveMissing,
            _ => BackendProblem.unknown,
          }, '${data['error'] ?? res.statusCode}');
        }
        return data;
      });

  @override
  Future<String> upload(
    String choirId,
    RemoteMediaKind kind,
    File file, {
    String label = '',
    String? work,
    String? shelf,
    String? part,
  }) async {
    final name = file.path.split('/').last;
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? 'bin' : name.substring(dot + 1).toLowerCase();
    final size = await file.length();
    final start = await _post('media/upload', {
      'choirId': choirId,
      'kind': switch (kind) {
        RemoteMediaKind.repertoire => 'repertoire',
        RemoteMediaKind.take => 'take',
        RemoteMediaKind.voiceNote => 'voice_note',
      },
      'ext': ext,
      'mime': _mime(ext),
      'size': size,
      'name': label,
      'work': ?work,
      'shelf': ?shelf,
      'part': ?part,
    });
    final mediaId = start['mediaId'] as String;
    final driveFileId = await _guard(() async {
      final put = await _http.put(
        Uri.parse(start['uploadUrl'] as String),
        headers: {'content-type': _mime(ext)},
        body: await file.readAsBytes(),
      );
      if (put.statusCode != 200 && put.statusCode != 201) {
        throw ChoirBackendException(
          BackendProblem.unknown,
          'upload ${put.statusCode}',
        );
      }
      return (jsonDecode(put.body) as Map<String, dynamic>)['id'] as String;
    });
    final done = await _post('media/finalize', {
      'mediaId': mediaId,
      'driveFileId': driveFileId,
    });
    return mediaIdOf(done['mediaId'] as String, done['ext'] as String);
  }

  @override
  Future<void> download(String mediaId, File to) => _guard(() async {
    final req = http.Request(
      'GET',
      Uri.parse('$functionsUrl/media/${uuidOfMedia(mediaId)}'),
    )..headers.addAll(_auth);
    final res = await _http.send(req);
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw ChoirBackendException(
        res.statusCode == 409
            ? BackendProblem.driveMissing
            : BackendProblem.notAllowed,
        'media ${res.statusCode}',
      );
    }
    final sink = to.openWrite();
    try {
      await res.stream.pipe(sink);
    } catch (_) {
      if (await to.exists()) await to.delete();
      rethrow;
    }
  });

  @override
  Future<OnlineSnapshot> pull(String choirId) => _guard(() async {
    final choirRow = await client
        .from('choirs')
        .select()
        .eq('id', choirId)
        .single();
    final memberRows = await client
        .from('members')
        .select()
        .eq('choir_id', choirId);
    final itemRows = await client
        .from('choir_items')
        .select('kind, body')
        .eq('choir_id', choirId);
    final mediaRows = await client
        .from('media')
        .select('id, ext')
        .eq('choir_id', choirId);
    final subRows = await client
        .from('submissions')
        .select()
        .eq('choir_id', choirId);
    final feedbackRows = await client
        .from('feedback')
        .select()
        .eq('choir_id', choirId)
        .order('created_at', ascending: true);

    final ext = {for (final m in mediaRows) m['id'] as String: m['ext']};
    String? local(Object? uuid) => uuid == null || ext[uuid] == null
        ? null
        : mediaIdOf(uuid as String, ext[uuid] as String);

    final notes = <String, List<Map<String, Object?>>>{};
    for (final f in feedbackRows) {
      (notes[f['submission_id'] as String] ??= []).add({
        'authorId': f['author_id'],
        'createdAt': f['created_at'],
        'attempt': f['attempt'],
        'text': f['text'],
        'tags': f['tags'],
        'marks': f['marks'],
        'voiceNoteId': local(f['voice_note_file_id']),
      });
    }

    List<Map<String, Object?>> bodies(String kind) => [
      for (final r in itemRows)
        if (r['kind'] == kind) (r['body'] as Map).cast<String, Object?>(),
    ];

    final choir = Choir(
      id: choirRow['id'] as String,
      name: choirRow['name'] as String,
      conductorId: choirRow['conductor_id'] as String,
      createdAt: DateTime.parse(choirRow['created_at'] as String),
    );
    return OnlineSnapshot(
      choir: choir,
      members: [
        for (final r in memberRows)
          ChoirMember(
            userId: r['user_id'] as String,
            choirId: choirId,
            displayName: r['display_name'] as String,
            role: ChoirRole.values.byName(r['role'] as String),
            part: r['part'] == null
                ? null
                : ChoirPart.values.byName(r['part'] as String),
            leadsPart: r['leads_part'] as bool? ?? false,
            joinedAt: DateTime.parse(r['joined_at'] as String),
          ),
      ],
      references: bodies('reference').map(ReferenceAsset.fromJson).toList(),
      resources: bodies('resource').map(ChoirResource.fromJson).toList(),
      assignments: bodies('assignment').map(Assignment.fromJson).toList(),
      submissions: [
        for (final r in subRows)
          if (local(r['recording_file_id']) != null)
            Submission.fromJson({
              'id': r['id'],
              'choirId': choirId,
              'assignmentId': r['assignment_id'],
              'pieceId': r['piece_id'],
              'memberId': r['member_id'],
              'part': r['part'],
              'status': r['status'],
              'attempt': r['attempt'],
              'recordingId': local(r['recording_file_id']),
              'durationMs': r['duration_ms'],
              'takeKind': r['take_kind'] ?? TakeKind.accompaniedMix.name,
              'submittedAt': r['submitted_at'],
              'listenedAt': r['listened_at'],
              'forwardedAt': r['forwarded_at'],
              'feedback': notes[r['id']] ?? const [],
            }),
      ],
    );
  });

  Future<void> _put(
    String choirId,
    String kind,
    String id,
    Map<String, Object?> body, {
    String? mediaId,
  }) => _guard(
    () => client.rpc(
      'put_item',
      params: {
        'c': choirId,
        'k': kind,
        'item_id': id,
        'item': body,
        'm': mediaId == null ? null : uuidOfMedia(mediaId),
      },
    ),
  );

  @override
  Future<void> putReference(ReferenceAsset asset) => _put(
    asset.choirId,
    'reference',
    asset.id,
    asset.toJson(),
    mediaId: asset.id,
  );

  @override
  Future<void> putResource(ChoirResource r) =>
      _put(r.choirId, 'resource', r.id, r.toJson(), mediaId: r.fileId);

  @override
  Future<void> deleteResource(ChoirResource r) => _guard(
    () => client.rpc(
      'delete_item',
      params: {'c': r.choirId, 'k': 'resource', 'item_id': r.id},
    ),
  );

  @override
  Future<void> putAssignment(Assignment a) =>
      _put(a.choirId, 'assignment', a.id, a.toJson());

  @override
  Future<void> submitTake(Submission take) => _guard(
    () => client.rpc(
      'submit_take',
      params: {
        'c': take.choirId,
        'assignment': take.assignmentId,
        'piece': take.pieceId,
        'file_id': uuidOfMedia(take.recordingId!),
        'duration': take.durationMs,
        'sung': take.takeKind!.name,
      },
    ),
  );

  @override
  Future<void> markListened(Submission s) =>
      _guard(() => client.rpc('mark_listened', params: {'sub_id': s.id}));

  Map<String, Object?> _note(Feedback? f) => {
    'body': f?.text ?? '',
    'tag_list': [for (final t in f?.tags ?? const <FeedbackTag>[]) t.name],
    'mark_list': [
      for (final m in f?.marks ?? const <FeedbackMark>[]) m.toJson(),
    ],
    'voice': f?.voiceNoteId == null ? null : uuidOfMedia(f!.voiceNoteId!),
  };

  @override
  Future<void> leaderDecide(
    Submission s, {
    required bool forward,
    Feedback? note,
  }) => _guard(
    () => client.rpc(
      'leader_decide',
      params: {'sub_id': s.id, 'forward': forward, ..._note(note)},
    ),
  );

  @override
  Future<void> conductorReview(
    Submission s, {
    required bool accept,
    required Feedback note,
  }) => _guard(
    () => client.rpc(
      'conductor_review',
      params: {'sub_id': s.id, 'accept': accept, ..._note(note)},
    ),
  );

  static String _mime(String ext) => switch (ext) {
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'mp3' => 'audio/mpeg',
    'mid' || 'midi' => 'audio/midi',
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    _ => 'application/octet-stream',
  };

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ChoirBackendException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ChoirBackendException.fromMessage(e.message);
    } on SocketException catch (e) {
      throw ChoirBackendException(BackendProblem.offline, e.message);
    } on http.ClientException catch (e) {
      throw ChoirBackendException(BackendProblem.offline, e.message);
    }
  }
}
