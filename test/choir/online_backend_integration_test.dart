// Opt-in: SupabaseChoirBackend against a real local Supabase (ADR-041).
//
//   supabase start
//   RESONIA_SUPABASE_URL=http://127.0.0.1:54321 \
//   RESONIA_SUPABASE_KEY=<publishable key> \
//   RESONIA_SUPABASE_SECRET=<secret key> \
//   RESONIA_MAILPIT_URL=http://127.0.0.1:54324 \
//   RESONIA_FUNCTIONS_URL=http://127.0.0.1:54321/functions/v1 \
//   flutter test --no-pub test/choir/online_backend_integration_test.dart
//
// Skipped without those variables. Never point it at a shared project: it
// creates users.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/choir/online/choir_backend.dart';
import 'package:resonia/choir/online/invite_code.dart';
import 'package:resonia/choir/online/supabase_choir_backend.dart';
import 'package:resonia/choir/online/supabase_choir_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _env = Platform.environment;
final _url = _env['RESONIA_SUPABASE_URL'];
final _key = _env['RESONIA_SUPABASE_KEY'];
final _secret = _env['RESONIA_SUPABASE_SECRET'];
final _mailpit = _env['RESONIA_MAILPIT_URL'];
final _functions = _env['RESONIA_FUNCTIONS_URL'];
final _skip = _url == null || _key == null || _secret == null
    ? 'set RESONIA_SUPABASE_URL/KEY/SECRET to run against local Supabase'
    : null;

/// flutter_test answers every HTTP call with 400 inside a test; this suite
/// needs the real local server.
class _RealNetwork extends HttpOverrides {}

Future<void> Function() _online(Future<void> Function() body) =>
    () => HttpOverrides.runWithHttpOverrides(body, _RealNetwork());

SupabaseClient _client(String key) => SupabaseClient(
  _url!,
  key,
  // No session storage in a test process, so no PKCE; the app's client gets
  // storage from Supabase.initialize.
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
);

void main() {
  final run = DateTime.now().microsecondsSinceEpoch;
  const password = 'local-test-only-pw';

  Future<SupabaseChoirBackend> person(String name) async {
    final email = '$name.$run@resonia.test';
    await _client(_secret!).auth.admin.createUser(
      AdminUserAttributes(email: email, password: password, emailConfirm: true),
    );
    final client = _client(_key!);
    await client.auth.signInWithPassword(email: email, password: password);
    return SupabaseChoirBackend(client);
  }

  Matcher refused(BackendProblem p) => throwsA(
    isA<ChoirBackendException>().having((e) => e.problem, 'problem', p),
  );

  test(
    'join, approve, part, leader, isolation, leave, delete',
    _online(() async {
      final sef = await person('sef');
      final ayse = await person('ayse');
      final other = await person('baska-sef');

      final choirId = await sef.createChoir('Entegrasyon Korosu', 'Şef');
      final code = await sef.createInvite(choirId, validDays: 7);
      expect(parseInviteCode(code), code);
      expect((await sef.invites(choirId)).single.code, code);

      expect(
        await ayse.previewInvite(code.toLowerCase()),
        'Entegrasyon Korosu',
      );
      final request = await ayse.requestJoin(code, 'Ayşe', ChoirPart.soprano);
      final mine = await ayse.myJoinRequests();
      expect(mine.single.choirName, 'Entegrasyon Korosu');
      expect(mine.single.status, JoinStatus.pending);
      expect(await ayse.myChoirs(), isEmpty);
      expect(await ayse.members(choirId), isEmpty, reason: 'not approved yet');

      final pending = await sef.joinRequests(choirId);
      expect(pending.single.displayName, 'Ayşe');
      expect(pending.single.wantedPart, ChoirPart.soprano);
      await sef.decideJoin(request, approve: true, part: ChoirPart.alto);
      await expectLater(
        sef.decideJoin(request, approve: true),
        refused(BackendProblem.alreadyDecided),
      );
      final aysesId = ayse.userId!;
      await sef.setSectionLeader(choirId, aysesId, true);

      final hers = (await ayse.myChoirs()).single;
      expect(hers.choir.name, 'Entegrasyon Korosu');
      expect(hers.me.part, ChoirPart.alto);
      expect(hers.me.leadsPart, isTrue);
      expect((await ayse.members(choirId)).length, 2);
      expect(await ayse.invites(choirId), isEmpty, reason: 'conductor only');

      // Another choir's conductor sees and changes nothing here.
      await other.createChoir('Başka Koro', 'Başka');
      expect(await other.members(choirId), isEmpty);
      expect(await other.joinRequests(choirId), isEmpty);
      await expectLater(
        other.setMemberPart(choirId, aysesId, ChoirPart.bass),
        refused(BackendProblem.notAllowed),
      );
      await expectLater(
        ayse.createInvite(choirId),
        refused(BackendProblem.notAllowed),
      );

      // Moving part ends leading.
      await sef.setMemberPart(choirId, aysesId, ChoirPart.tenor);
      final moved = (await sef.members(
        choirId,
      )).firstWhere((m) => m.userId == aysesId);
      expect([moved.part, moved.leadsPart], [ChoirPart.tenor, false]);

      await sef.revokeInvite(code);
      await expectLater(
        other.previewInvite(code),
        refused(BackendProblem.inviteInvalid),
      );

      await ayse.removeMember(choirId, aysesId);
      expect(await ayse.myChoirs(), isEmpty);
      expect(await ayse.members(choirId), isEmpty);

      await sef.deleteChoir(choirId);
      expect(await sef.myChoirs(), isEmpty);
    }),
    skip: _skip,
  );

  test(
    'email code sign-in through the local mail catcher',
    _online(() async {
      final backend = SupabaseChoirBackend(_client(_key!));
      final email = 'kod.$run@resonia.test';
      await backend.sendEmailCode(email);
      final http = HttpClient();
      Future<Object?> get(String path) async {
        final request = await http.getUrl(Uri.parse('$_mailpit$path'));
        final response = await request.close();
        return jsonDecode(await response.transform(utf8.decoder).join());
      }

      String? token;
      for (var i = 0; i < 20 && token == null; i++) {
        final list =
            await get('/api/v1/search?query=to:$email') as Map<String, Object?>;
        final messages = (list['messages'] as List?) ?? const [];
        if (messages.isNotEmpty) {
          final id = (messages.first as Map<String, Object?>)['ID'];
          final message = await get('/api/v1/message/$id') as Map;
          token = RegExp(
            r'\b(\d{6})\b',
          ).firstMatch(message['Text'] as String)?.group(1);
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      http.close();
      expect(token, isNotNull, reason: 'the mail carries a 6-digit code');

      await expectLater(
        backend.verifyEmailCode(email, token == '000000' ? '111111' : '000000'),
        throwsA(isA<ChoirBackendException>()),
      );
      await backend.verifyEmailCode(email, token!);
      expect(backend.userId, isNotNull);
      expect(backend.email, email);
      expect(await backend.myChoirs(), isEmpty);
      await backend.signOut();
      expect(backend.userId, isNull);
    }),
    skip: _skip ?? (_mailpit == null ? 'set RESONIA_MAILPIT_URL' : null),
  );

  test(
    'Drive, repertoire, take, section leader and conductor end to end',
    _online(() async {
      final tmp = await Directory.systemTemp.createTemp('choir_e2e');
      addTearDown(() => tmp.delete(recursive: true));
      Future<ChoirStore> storeOf(SupabaseChoirBackend b) async {
        final root = await Directory(
          '${tmp.path}/${b.userId}',
        ).create(recursive: true);
        final store =
            ChoirStore(
                persistence: MemoryChoirPersistence(),
                mediaRoot: () async => root,
              )
              ..remote = SupabaseChoirRemote(
                b.client,
                functionsUrl: _functions!,
                apiKey: _key!,
              );
        await store.load();
        return store;
      }

      Future<String> file(String name, List<int> bytes) async =>
          (await File('${tmp.path}/$name').writeAsBytes(bytes)).path;

      final sef = await person('e2e-sef');
      final ayse = await person('e2e-ayse');
      final ece = await person('e2e-ece');
      final aylin = await person('e2e-aylin');
      final choirId = await sef.createChoir('Uçtan Uca', 'Şef');
      final code = await sef.createInvite(choirId);
      for (final (b, part) in [
        (ayse, ChoirPart.soprano),
        (ece, ChoirPart.soprano),
        (aylin, ChoirPart.alto),
      ]) {
        await sef.decideJoin(
          await b.requestJoin(code, b.email!.split('.').first, part),
          approve: true,
        );
      }
      await sef.setSectionLeader(choirId, ayse.userId!, true);

      // Drive: not connected → the conductor's browser flow (local stand-in).
      expect((await sef.driveStatus(choirId)).connected, isFalse);
      await expectLater(
        ece.startDriveConnect(choirId),
        refused(BackendProblem.notAllowed),
      );
      final consent = await sef.startDriveConnect(choirId);
      final http = HttpClient();
      final page = await (await http.getUrl(consent)).close();
      expect(page.statusCode, 200);
      expect(
        await page.transform(utf8.decoder).join(),
        contains('Drive bağlandı'),
      );
      http.close();
      final status = await sef.driveStatus(choirId);
      expect([status.connected, status.email], [true, 'yerel-drive@dev.local']);
      expect((await ece.driveStatus(choirId)).email, isNull);

      // Conductor: MIDI and an assignment.
      final sefStore = await storeOf(sef);
      await sefStore.syncOnline(choirId);
      final midi = await sefStore.addMidi(
        choir: sefStore.choir(choirId)!,
        sourcePath: await file('g.mid', [77, 84, 104, 100, 0, 0, 0, 6]),
        fileName: 'gloria.mid',
        rights: RightsDeclaration.ownRecording,
        trackParts: const {1: ChoirPart.soprano},
      );
      final a = Assignment(
        id: sefStore.newHex(),
        choirId: choirId,
        title: 'Gloria',
        parts: const [ChoirPart.soprano, ChoirPart.alto],
        pieces: [
          AssignmentPiece(
            id: 'p1',
            title: 'Gloria',
            mode: PieceMode.lyrics,
            midiReferenceId: midi.id,
          ),
        ],
        createdAt: DateTime.now().toUtc(),
      );
      await sefStore.publish(a);

      // Singer: MIDI comes down, the take goes up.
      final eceStore = await storeOf(ece);
      await eceStore.syncOnline(choirId);
      expect(await File(await eceStore.ensureMedia(midi.id)).readAsBytes(), [
        77,
        84,
        104,
        100,
        0,
        0,
        0,
        6,
      ]);
      final draft = await eceStore.keepTake(
        assignment: eceStore.assignmentsOf(choirId).single,
        piece: a.pieces.single,
        sourcePath: await file('take.wav', List.filled(4096, 7)),
        fileName: 'take.wav',
        durationMs: 30000,
        kind: TakeKind.accompaniedMix,
      );
      final sent = await eceStore.markSent(draft);
      expect(sent.status, SubmissionStatus.submitted);

      // Another part hears nothing; the conductor waits.
      final aylinStore = await storeOf(aylin);
      await aylinStore.syncOnline(choirId);
      await expectLater(
        aylinStore.ensureMedia(sent.recordingId!),
        throwsA(isA<ChoirBackendException>()),
      );
      await sefStore.syncOnline(choirId);
      expect(sefStore.reviewQueue(choirId), isEmpty);

      // Section leader hears it and forwards with a sung note.
      final ayseStore = await storeOf(ayse);
      await ayseStore.syncOnline(choirId);
      final queued = ayseStore.reviewQueue(choirId).single;
      expect(
        (await File(
          await ayseStore.ensureMedia(queued.recordingId!),
        ).readAsBytes()).length,
        4096,
      );
      final voice = await ayseStore.addMedia(
        await file('voice.wav', [5, 5, 5]),
        'voice.wav',
      );
      await ayseStore.leaderDecide(
        submission: queued,
        forward: true,
        text: 'Temiz',
        voiceNoteId: voice,
      );

      // Conductor: hears take and note, asks again.
      await sefStore.syncOnline(choirId);
      final mine = sefStore.reviewQueue(choirId).single;
      expect(
        await File(
          await sefStore.ensureMedia(mine.feedback.single.voiceNoteId!),
        ).readAsBytes(),
        [5, 5, 5],
      );
      await sefStore.review(
        submission: mine,
        outcome: ReviewOutcome.revisionRequested,
        text: 'Girişi yeniden',
      );

      await eceStore.syncOnline(choirId);
      final back = eceStore.mySubmission(a.id, 'p1')!;
      expect(back.status, SubmissionStatus.revisionRequested);
      expect(back.feedback.map((f) => f.text), ['Temiz', 'Girişi yeniden']);

      await sef.deleteChoir(choirId);
    }),
    skip: _skip ?? (_functions == null ? 'set RESONIA_FUNCTIONS_URL' : null),
  );
}
