import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/app/choir_scope.dart';
import 'package:resonia/choir/app/review_screen.dart';
import 'package:resonia/choir/audio/take_engine.dart';
import 'package:resonia/choir/data/choir_bundle.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/choir/online/online_choir_controller.dart';
import 'package:resonia/choir/online/online_choir_screen.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/trainer/ui/kit.dart';

import 'support/fake_choir_backend.dart';
import 'support/fake_choir_remote.dart';

class _Player implements ChoirPlayer {
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<bool> get playingChanges => const Stream.empty();
  @override
  Future<Duration?> open(String path, {bool loop = false}) async =>
      const Duration(seconds: 30);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> close() async {}
}

class _Capture implements TakeCapture {
  @override
  Stream<TakeInterruption> get interruptions => const Stream.empty();
  @override
  Stream<double> get levelsDb => const Stream.empty();
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<AudioRouteSnapshot> route() async => const AudioRouteSnapshot(
    input: AudioRouteKind.builtIn,
    output: AudioRouteKind.wired,
  );
  @override
  Future<int> start({
    required String vocalPath,
    String? accompanimentPath,
  }) async => 0;
  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<void> close() async {}
}

class _Files implements ChoirFiles {
  final shared = <String>[];
  @override
  Future<PickedFile?> pick() async => null;
  @override
  Future<bool> share(String path, {Rect? origin}) async {
    shared.add(path);
    return true;
  }

  @override
  Future<bool> open(String path) async => true;
}

void main() {
  late Directory tmp;
  late FakeChoirServer server;
  late FakeWorkServer work;
  late String choirId;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('online_screens');
    server = FakeChoirServer();
    work = FakeWorkServer(
      server,
      await Directory('${tmp.path}/drive').create(),
    );
    final sef = FakeChoirBackend(server, signedInAs: 'sef');
    choirId = await sef.createChoir('Koro', 'Şef');
    final code = await sef.createInvite(choirId);
    for (final (who, part) in [
      ('ayse', ChoirPart.soprano),
      ('ece', ChoirPart.soprano),
    ]) {
      final b = FakeChoirBackend(server, signedInAs: who);
      await sef.decideJoin(await b.requestJoin(code, who, part), approve: true);
    }
    await sef.setSectionLeader(choirId, 'ayse', true);
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<ChoirStore> storeFor(String user) async {
    final root = await Directory('${tmp.path}/$user').create();
    final store =
        ChoirStore(
            persistence: MemoryChoirPersistence(),
            mediaRoot: () async => root,
          )
          ..remote = FakeChoirRemote(
            work,
            FakeChoirBackend(server, signedInAs: user),
          );
    await store.load();
    return store;
  }

  Widget app(
    ChoirStore store,
    Widget home, {
    OnlineChoirController? online,
    _Files? files,
  }) {
    final scoped = ChoirScope(
      store: store,
      bundles: ChoirBundles(store, () async => tmp),
      files: files ?? _Files(),
      newPlayer: _Player.new,
      newCapture: _Capture.new,
      workDirectory: () async => tmp,
      child: MaterialApp(
        theme: trainerTheme(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('en'), Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: home,
      ),
    );
    return online == null
        ? scoped
        : OnlineChoirScope(controller: online, child: scoped);
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('section leader forwards a take from the review screen', (
    tester,
  ) async {
    final files = _Files();
    late ChoirStore leader;
    late String subId;
    await tester.runAsync(() async {
      server.drives[choirId] = 'koro@gmail.com';
      final sefStore = await storeFor('sef');
      await sefStore.syncOnline(choirId);
      final a = Assignment(
        id: 'a1',
        choirId: choirId,
        title: 'Gloria',
        parts: const [ChoirPart.soprano],
        pieces: [
          AssignmentPiece(id: 'p1', title: 'Gloria', mode: PieceMode.lyrics),
        ],
        createdAt: server.now,
      );
      await sefStore.publish(a);
      final ece = await storeFor('ece');
      await ece.syncOnline(choirId);
      final src = File('${tmp.path}/t.wav')..writeAsBytesSync([1, 2, 3]);
      final draft = await ece.keepTake(
        assignment: a,
        piece: a.pieces.single,
        sourcePath: src.path,
        fileName: 'take.wav',
        durationMs: 30000,
        kind: TakeKind.unaccompanied,
      );
      await ece.markSent(draft);
      leader = await storeFor('ayse');
      await leader.syncOnline(choirId);
      subId = leader.reviewQueue(choirId).single.id;
    });

    await tester.pumpWidget(
      app(leader, ReviewScreen(submissionId: subId), files: files),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Şefe gönder'), findsOneWidget);

    await tap(tester, find.byKey(const Key('review_send')));
    expect(find.text('Bu kayıt ne olsun?'), findsOneWidget);
    await tap(tester, find.byKey(const Key('review_forward')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(work.submissions.single.status, SubmissionStatus.forwarded);
    expect(files.shared, isEmpty, reason: 'online: no share sheet');
  });

  testWidgets('conductor connects Drive; singers wait until then', (
    tester,
  ) async {
    late ChoirStore sefStore;
    late OnlineChoirController sefOnline;
    final opened = <Uri>[];
    await tester.runAsync(() async {
      sefStore = await storeFor('sef');
      sefOnline =
          OnlineChoirController(FakeChoirBackend(server, signedInAs: 'sef'))
            ..openUrl = (u) async {
              opened.add(u);
              return true;
            };
      await sefOnline.refresh();
    });
    addTearDown(sefOnline.dispose);

    await tester.pumpWidget(
      app(sefStore, OnlineChoirScreen(choirId: choirId), online: sefOnline),
    );
    await tester.pumpAndSettle();
    expect(find.text('Drive\'ı bağla'), findsNothing);
    expect(find.text('Koronun Google Drive\'ı'), findsOneWidget);

    await tap(tester, find.byKey(const Key('drive_row')));
    expect(opened.single.host, 'accounts.google.test');

    await tap(tester, find.byKey(const Key('open_online_work')));
    expect(
      find.text('Şef Drive\'ı bağlayınca ödevler ve kayıtlar açılır.'),
      findsOneWidget,
    );

    // The browser finished; the conductor checks again.
    server.drives[choirId] = 'koro@gmail.com';
    await tester.pump(const Duration(seconds: 5));
    await tap(tester, find.text('Bağladım, kontrol et'));
    expect(find.text('Bağlı · koro@gmail.com'), findsOneWidget);

    await tap(tester, find.byKey(const Key('open_online_work')));
    expect(sefStore.isOnline(choirId), isTrue);
    expect(find.byKey(const Key('choir_new_assignment')), findsOneWidget);
    expect(find.byKey(const Key('choir_share')), findsNothing);
  });
}
