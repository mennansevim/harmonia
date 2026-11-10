import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/app/choir_scope.dart';
import 'package:resonia/choir/app/choir_tab.dart';
import 'package:resonia/choir/data/choir_bundle.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/online/choir_backend.dart';
import 'package:resonia/choir/online/invite_code.dart';
import 'package:resonia/choir/online/online_choir_controller.dart';
import 'package:resonia/trainer/ui/kit.dart';

import 'support/fake_choir_backend.dart';

class _NoFiles implements ChoirFiles {
  @override
  Future<PickedFile?> pick() async => null;
  @override
  Future<bool> share(String path, {Rect? origin}) async => false;
  @override
  Future<bool> open(String path) async => false;
}

void main() {
  group('invite codes', () {
    test('typed, dashed, lower case and links all normalise', () {
      expect(parseInviteCode('ABCD22AA'), 'ABCD22AA');
      expect(parseInviteCode(' abcd-22aa '), 'ABCD22AA');
      expect(parseInviteCode('vocalart://join/ABCD22AA'), 'ABCD22AA');
      expect(parseInviteCode('https://vocalart.app/j/ABCD22AA'), 'ABCD22AA');
      expect(parseInviteCode(inviteLink('ABCD2345')), 'ABCD2345');
    });

    test('wrong length, look-alike characters and other links are refused', () {
      expect(parseInviteCode('ABCD22A'), isNull);
      expect(parseInviteCode('ABCD22A0'), isNull, reason: '0 is not used');
      expect(parseInviteCode('ABCD22AI'), isNull, reason: 'I is not used');
      expect(parseInviteCode('https://evil.example/x?c=ABCD22AA'), isNull);
      expect(parseInviteCode('mailto://ABCD22AA'), isNull);
    });

    test('reads aloud in two halves', () {
      expect(formatInviteCode('ABCD22AA'), 'ABCD-22AA');
    });

    test('server messages become problems', () {
      expect(
        ChoirBackendException.fromMessage('invite not valid').problem,
        BackendProblem.inviteInvalid,
      );
      expect(
        ChoirBackendException.fromMessage(
          'only the conductor assigns parts',
        ).problem,
        BackendProblem.notAllowed,
      );
      expect(
        ChoirBackendException.fromMessage(
          'Token has expired or is invalid',
        ).problem,
        BackendProblem.wrongCode,
      );
    });
  });

  group('online choir screens', () {
    late Directory tmp;
    late FakeChoirServer server;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('online_choir');
      server = FakeChoirServer();
    });
    tearDown(() => tmp.delete(recursive: true));

    /// One phone: the Koro tab with an online controller.
    Future<OnlineChoirController> device(
      WidgetTester tester,
      FakeChoirBackend backend,
    ) async {
      final store = ChoirStore(
        persistence: MemoryChoirPersistence(),
        mediaRoot: () async => tmp,
      );
      await store.load();
      final online = OnlineChoirController(backend)..start();
      addTearDown(online.dispose);
      // A fresh phone: nothing left from the previous one's navigator.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ChoirScope(
          store: store,
          bundles: ChoirBundles(store, () async => tmp),
          files: _NoFiles(),
          newPlayer: () => throw UnimplementedError(),
          newCapture: () => throw UnimplementedError(),
          workDirectory: () async => tmp,
          child: OnlineChoirScope(
            controller: online,
            child: MaterialApp(
              theme: trainerTheme(),
              locale: const Locale('tr'),
              supportedLocales: const [Locale('en'), Locale('tr')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: const Scaffold(body: ChoirTab()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return online;
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('sign in with an emailed code', (tester) async {
      final online = await device(tester, FakeChoirBackend(server));
      expect(find.text('Çevrimiçi koro'), findsOneWidget);

      await tap(tester, find.byKey(const Key('online_sign_in')));
      await tester.enterText(
        find.byKey(const Key('sign_in_email')),
        'sef@koro.org',
      );
      await tester.pump();
      await tap(tester, find.byKey(const Key('sign_in_send')));
      expect(server.sentCodes['sef@koro.org'], '123456');

      await tester.enterText(find.byKey(const Key('sign_in_code')), '000000');
      await tester.pump();
      await tap(tester, find.byKey(const Key('sign_in_verify')));
      expect(online.signedIn, isFalse);
      expect(find.text('Kod yanlış ya da süresi dolmuş.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('sign_in_code')), '123456');
      await tester.pump();
      await tap(tester, find.byKey(const Key('sign_in_verify')));
      expect(online.signedIn, isTrue);
      expect(find.byKey(const Key('online_join')), findsOneWidget);
      expect(find.text('sef@koro.org olarak girildi'), findsOneWidget);
    });

    testWidgets('conductor sets up a choir and gets an invite code', (
      tester,
    ) async {
      final sef = FakeChoirBackend(server, signedInAs: 'sef');
      await device(tester, sef);

      await tap(tester, find.text('Koro kur'));
      await tester.enterText(
        find.byKey(const Key('online_choir_name')),
        'Ankara Polifonik',
      );
      await tester.enterText(find.byKey(const Key('online_my_name')), 'Mennan');
      await tester.pump();
      await tap(tester, find.byKey(const Key('online_create_confirm')));

      expect(find.text('Ankara Polifonik'), findsWidgets);
      expect(server.choirs.single.conductorId, 'sef');

      await tap(tester, find.byKey(const Key('open_invite')));
      expect(find.byKey(const Key('invite_qr')), findsOneWidget);
      expect(find.text('ABCD-22AA'), findsOneWidget);

      await tap(tester, find.text('Yeni kod oluştur'));
      expect(server.invites.first.revoked, isTrue);
      expect(find.text('ABCD-22BA'), findsOneWidget);
    });

    testWidgets(
      'singer asks to join; conductor approves, sets part and leader',
      (tester) async {
        // The conductor's side, set up through the same rules.
        final sef = FakeChoirBackend(server, signedInAs: 'sef');
        final choirId = await sef.createChoir('Koro', 'Şef');
        final code = await sef.createInvite(choirId);

        // Singer's phone.
        final ayse = FakeChoirBackend(server, signedInAs: 'ayse');
        final singer = await device(tester, ayse);
        await tap(tester, find.byKey(const Key('online_join')));

        await tester.enterText(find.byKey(const Key('join_code')), 'WRONG123');
        await tester.pump();
        await tap(tester, find.byKey(const Key('join_find')));
        expect(find.text('Bu bir davet kodu değil.'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('join_code')),
          formatInviteCode(code).toLowerCase(),
        );
        await tester.pump();
        await tap(tester, find.byKey(const Key('join_find')));
        expect(find.text('Koro'), findsWidgets);

        await tester.enterText(
          find.byKey(const Key('join_online_name')),
          'Ayşe',
        );
        await tap(tester, find.byKey(const Key('part_chip_soprano')));
        await tap(tester, find.byKey(const Key('join_request')));
        expect(
          find.text('İstek gönderildi. Şef onaylayınca koro burada açılır.'),
          findsOneWidget,
        );
        expect(singer.choirs, isEmpty);
        expect(find.text('Şef onayı bekleniyor'), findsOneWidget);
        // Waiting: nothing of the choir is readable.
        expect(await ayse.members(choirId), isEmpty);

        // Conductor's phone.
        final conductor = await device(tester, sef);
        await tap(tester, find.byKey(Key('online_choir_$choirId')));
        expect(find.text('Soprano istiyor'), findsOneWidget);
        await tap(tester, find.text('Ayşe'));
        await tap(tester, find.byKey(const Key('part_chip_alto')));
        await tap(tester, find.byKey(const Key('decide_approve')));

        expect(server.member(choirId, 'ayse')!.part, ChoirPart.alto);
        expect(find.text('ALTO · 1'), findsOneWidget);

        await tap(tester, find.byKey(const Key('member_ayse')));
        await tap(tester, find.byKey(const Key('member_leader')));
        expect(server.member(choirId, 'ayse')!.leadsPart, isTrue);
        expect(conductor.choir(choirId)!.iConduct, isTrue);

        // Back on the singer's phone the choir is open with her part.
        await device(tester, ayse);
        expect(find.text('Alto · Partisyon şefi'), findsOneWidget);
      },
    );

    testWidgets('a singer cannot run the roster and can leave', (tester) async {
      final sef = FakeChoirBackend(server, signedInAs: 'sef');
      final choirId = await sef.createChoir('Koro', 'Şef');
      final code = await sef.createInvite(choirId);
      final ece = FakeChoirBackend(server, signedInAs: 'ece');
      final request = await ece.requestJoin(code, 'Ece', ChoirPart.tenor);
      await sef.decideJoin(request, approve: true);

      expect(
        () => ece.setSectionLeader(choirId, 'ece', true),
        throwsA(isA<ChoirBackendException>()),
      );
      expect(
        () => ece.createInvite(choirId),
        throwsA(isA<ChoirBackendException>()),
      );

      await device(tester, ece);
      await tap(tester, find.byKey(Key('online_choir_$choirId')));
      expect(find.byKey(const Key('open_invite')), findsNothing);
      await tap(tester, find.text('Korodan ayrıl'));
      await tap(tester, find.byKey(const Key('confirm_yes')));
      expect(server.member(choirId, 'ece'), isNull);
      expect(find.byKey(Key('online_choir_$choirId')), findsNothing);
    });

    testWidgets('no connection is said plainly and can be retried', (
      tester,
    ) async {
      final backend = FakeChoirBackend(server, signedInAs: 'sef')
        ..offline = true;
      final online = await device(tester, backend);
      expect(online.problem, BackendProblem.offline);
      expect(
        find.text('Bağlantı yok. İnternetini kontrol edip yeniden dene.'),
        findsOneWidget,
      );
      backend.offline = false;
      await tap(tester, find.text('Yeniden dene'));
      expect(online.problem, isNull);
    });
  });
}
