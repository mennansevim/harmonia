import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/choir/app/assignment_screen.dart';
import 'package:harmonia/choir/app/choir_scope.dart';
import 'package:harmonia/choir/app/choir_screen.dart';
import 'package:harmonia/choir/app/choir_text.dart';
import 'package:harmonia/choir/app/choir_tab.dart';
import 'package:harmonia/choir/app/review_screen.dart';
import 'package:harmonia/choir/app/take_screen.dart';
import 'package:harmonia/choir/audio/take_engine.dart';
import 'package:harmonia/choir/data/choir_bundle.dart';
import 'package:harmonia/choir/data/choir_store.dart';
import 'package:harmonia/choir/domain/assignment.dart';
import 'package:harmonia/choir/domain/choir.dart';
import 'package:harmonia/choir/domain/submission.dart';
import 'package:harmonia/domain/audio/capture_quality.dart';
import 'package:harmonia/trainer/app/scope.dart';
import 'package:harmonia/trainer/audio/trainer_audio.dart';
import 'package:harmonia/trainer/home/home_shell.dart';
import 'package:harmonia/trainer/state/trainer_store.dart';
import 'package:harmonia/trainer/ui/kit.dart';

final t0 = DateTime(2026, 11, 2, 18);

class FakePlayer implements ChoirPlayer {
  final _positions = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  var plays = 0;
  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<bool> get playingChanges => _playing.stream;
  @override
  Future<Duration?> open(String path, {bool loop = false}) async =>
      const Duration(seconds: 30);
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> close() async {}
}

class FakeCapture implements TakeCapture {
  FakeCapture(this.output);
  final AudioRouteKind Function() output;
  @override
  Stream<TakeInterruption> get interruptions => const Stream.empty();
  @override
  Stream<double> get levelsDb => const Stream.empty();
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<AudioRouteSnapshot> route() async =>
      AudioRouteSnapshot(input: AudioRouteKind.builtIn, output: output());
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

class FakeFiles implements ChoirFiles {
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
  late ChoirStore store;
  late FakeFiles files;
  var output = AudioRouteKind.wired;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('choir-ui-');
    output = AudioRouteKind.wired;
    files = FakeFiles();
    store = ChoirStore(
      persistence: MemoryChoirPersistence(),
      mediaRoot: () async => tmp,
      clock: () => t0,
    );
    await store.load();
    await store.setConsent();
  });

  tearDown(() => tmp.delete(recursive: true));

  Widget app(Widget home, {Locale locale = const Locale('tr')}) => ChoirScope(
    store: store,
    bundles: ChoirBundles(store, () async => tmp),
    files: files,
    newPlayer: FakePlayer.new,
    newCapture: () => FakeCapture(() => output),
    workDirectory: () async => tmp,
    child: MaterialApp(
      theme: trainerTheme(),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    ),
  );

  /// A singer in a choir with a two-piece assignment.
  Future<(Choir, Assignment)> singerSetup() async {
    final choir = Choir(
      id: 'c1',
      name: 'Oda Korosu',
      conductorId: 'sef',
      createdAt: t0.toUtc(),
    );
    store.choirs.add(choir);
    store.members.add(
      ChoirMember(
        userId: store.myId,
        choirId: 'c1',
        displayName: 'Mert',
        role: ChoirRole.singer,
        part: ChoirPart.alto,
        joinedAt: t0.toUtc(),
      ),
    );
    final midi = '${'a' * 16}.mid';
    final a = Assignment(
      id: 'a1',
      choirId: 'c1',
      title: 'Hafta ödevi',
      parts: const [ChoirPart.alto],
      pieces: [
        AssignmentPiece(
          id: 'p1',
          title: 'Gloria',
          mode: PieceMode.solfege,
          fromMeasure: 12,
          toMeasure: 30,
          withAccompaniment: true,
          midiReferenceId: midi,
        ),
        AssignmentPiece(id: 'p2', title: 'Kyrie', mode: PieceMode.lyrics),
      ],
      createdAt: t0.toUtc(),
      dueAt: t0.add(const Duration(days: 2)).toUtc(),
    );
    store.assignments.add(a);
    return (choir, a);
  }

  test('section labels capitalise Turkish correctly', () {
    expect(const CT(false).caps('Hangi bölüm?'), 'HANGİ BÖLÜM?');
    expect(
      const CT(false).caps('Sesin eşlikle aynı mı?'),
      'SESİN EŞLİKLE AYNI MI?',
    );
    expect(const CT(true).caps('Which passage?'), 'WHICH PASSAGE?');
  });

  testWidgets('with no choir the tab explains itself and offers both ways', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Scaffold(body: ChoirTab())));
    expect(find.text('Koronun tek yeri'), findsOneWidget);
    expect(find.byKey(const Key('choir_open_package')), findsOneWidget);
    await tester.tap(find.text('Koro oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create_choir_name')), 'Oda');
    await tester.enterText(find.byKey(const Key('create_my_name')), 'Ayşe');
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_confirm')));
    await tester.pumpAndSettle();
    expect(store.choirs.single.name, 'Oda');
    expect(find.text('Oda'), findsOneWidget);
  });

  testWidgets('a singer sees each piece, how to sing it and when it is due', (
    tester,
  ) async {
    await singerSetup();
    await tester.pumpWidget(app(const AssignmentScreen(assignmentId: 'a1')));
    await tester.pump();
    expect(find.text('gün kaldı'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Gloria'), findsOneWidget);
    expect(
      find.textContaining('Solfej · Ölçü 12–30 · Eşlikli'),
      findsOneWidget,
    );
    expect(find.text('Nota değerleriyle oku.'), findsOneWidget);
    expect(find.byKey(const Key('piece_practise_p1')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kyrie'), 100);
    expect(find.textContaining('Sözlü · Tamamı · Eşliksiz'), findsOneWidget);
    expect(find.byKey(const Key('piece_practise_p2')), findsNothing);
  });

  testWidgets('it reads in English on a non-Turkish device', (tester) async {
    await singerSetup();
    await tester.pumpWidget(
      app(
        const AssignmentScreen(assignmentId: 'a1'),
        locale: const Locale('en'),
      ),
    );
    await tester.pump();
    expect(find.text('days left'), findsOneWidget);
    expect(find.textContaining('Bars 12–30'), findsOneWidget);
  });

  group('the accompanied take', () {
    Future<void> open(WidgetTester tester, Assignment a) async {
      await tester.pumpWidget(
        app(TakeScreen(assignment: a, piece: a.piece('p1')!)),
      );
      await tester.pumpAndSettle();
    }

    bool startEnabled(WidgetTester tester) =>
        tester
            .widget<BigButton>(find.byKey(const Key('take_start')))
            .onPressed !=
        null;

    testWidgets('wired headphones go straight on', (tester) async {
      final (_, a) = await singerSetup();
      await open(tester, a);
      expect(find.byKey(const Key('take_route_ready')), findsOneWidget);
      expect(find.text('Tek telefon yeter'), findsOneWidget);
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('the speaker is blocked, with a way forward', (tester) async {
      output = AudioRouteKind.builtIn;
      final (_, a) = await singerSetup();
      await open(tester, a);
      expect(find.byKey(const Key('take_route_speaker')), findsOneWidget);
      expect(startEnabled(tester), isFalse);
      expect(find.text('Başka cihazdaki kaydı ekle'), findsOneWidget);
      output = AudioRouteKind.wired;
      await tester.tap(find.byKey(const Key('take_check_route')));
      await tester.pumpAndSettle();
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('Bluetooth warns about delay but stays allowed', (
      tester,
    ) async {
      output = AudioRouteKind.bluetooth;
      final (_, a) = await singerSetup();
      await open(tester, a);
      expect(find.textContaining('gecikme ekler'), findsOneWidget);
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('an unknown route needs the singer\'s word', (tester) async {
      output = AudioRouteKind.unknown;
      final (_, a) = await singerSetup();
      await open(tester, a);
      expect(startEnabled(tester), isFalse);
      await tester.tap(find.byKey(const Key('take_confirm_headphones')));
      await tester.pump();
      expect(startEnabled(tester), isTrue);
    });

    testWidgets('recording asks for consent once, and backing out leaves', (
      tester,
    ) async {
      final (_, a) = await singerSetup();
      store.recordingConsent = false;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      TakeScreen(assignment: a, piece: a.piece('p1')!),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Kayıt izni'), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('go'), findsOneWidget);
      expect(store.recordingConsent, isFalse);
    });
  });

  group('the conductor', () {
    Future<Submission> received() async {
      final (choir, a) = await singerSetup();
      final conductorId = store.myId;
      store.choirs
        ..clear()
        ..add(
          Choir(
            id: choir.id,
            name: choir.name,
            conductorId: conductorId,
            createdAt: choir.createdAt,
          ),
        );
      store.members
        ..clear()
        ..add(
          ChoirMember(
            userId: conductorId,
            choirId: 'c1',
            displayName: 'Ayşe',
            role: ChoirRole.conductor,
            joinedAt: t0.toUtc(),
          ),
        )
        ..add(
          ChoirMember(
            userId: 'mert',
            choirId: 'c1',
            displayName: 'Mert',
            role: ChoirRole.singer,
            part: ChoirPart.alto,
            joinedAt: t0.toUtc(),
          ),
        );
      final sent =
          Submission.start(
                id: 's1',
                assignment: a,
                pieceId: 'p1',
                member: store.members.last,
              )
              .attachRecording(
                assignment: a,
                recordingId: '${'b' * 16}.wav',
                durationMs: 30000,
                kind: TakeKind.accompaniedMix,
              )
              .submit(t0.toUtc());
      store.submissions.add(sent);
      return sent;
    }

    testWidgets('sees the queue and who is waiting', (tester) async {
      await received();
      await tester.pumpWidget(app(const ChoirScreen(choirId: 'c1')));
      await tester.pump();
      expect(find.text('1 kayıt bekliyor'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Mert'), 150);
      expect(find.text('Mert'), findsOneWidget);
    });

    testWidgets('must say something, then the feedback can be shared', (
      tester,
    ) async {
      await received();
      await tester.pumpWidget(app(const ReviewScreen(submissionId: 's1')));
      await tester.pump();
      expect(find.textContaining('Eşlikli'), findsWidgets);
      await tester.dragUntilVisible(
        find.byKey(const Key('review_redo')),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.byKey(const Key('review_redo')));
      await tester.pump();
      expect(find.textContaining('Yorum, etiket'), findsOneWidget);
      expect(store.submissions.single.status, SubmissionStatus.submitted);

      await tester.dragUntilVisible(
        find.byKey(const Key('mark_breathLeak')),
        find.byType(ListView),
        const Offset(0, 200),
      );
      await tester.tap(find.byKey(const Key('mark_breathLeak')));
      await tester.pump();
      expect(find.textContaining('Nefes kaçağı'), findsWidgets);
      await tester.dragUntilVisible(
        find.byKey(const Key('review_redo')),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('review_redo')));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      final s = store.submissions.single;
      expect(s.status, SubmissionStatus.revisionRequested);
      expect(s.latestFeedback!.marks.single.tag, FeedbackTag.breathLeak);
      expect(files.shared, hasLength(1));
    });
  });

  group('in the app shell', () {
    Widget shell(TrainerStore trainer) => TrainerScope(
      store: trainer,
      audio: TrainerAudio(),
      liveAudio: false,
      child: app(const HomeShell()),
    );

    Future<TrainerStore> trainer(String? role) async {
      final s = TrainerStore(MemoryTrainerPersistence());
      await s.load();
      if (role != null) s.answers['role'] = role;
      return s;
    }

    testWidgets('the Koro tab is for those in a choir', (tester) async {
      await tester.pumpWidget(shell(await trainer('solo')));
      await tester.pump();
      expect(find.byKey(const Key('tab_koro')), findsNothing);
      expect(find.byKey(const Key('tab_2')), findsOneWidget);
    });

    testWidgets('a choir singer gets the tab and the deadline on Today', (
      tester,
    ) async {
      await singerSetup();
      await tester.pumpWidget(shell(await trainer('singer')));
      await tester.pump();
      expect(find.byKey(const Key('tab_koro')), findsOneWidget);
      expect(find.textContaining('Koro ödevi: Hafta ödevi'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tab_koro')));
      await tester.pump();
      expect(find.text('Oda Korosu'), findsOneWidget);
    });
  });

  testWidgets('holds up on a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (_, a) = await singerSetup();
    for (final screen in <Widget>[
      const AssignmentScreen(assignmentId: 'a1'),
      TakeScreen(assignment: a, piece: a.piece('p1')!),
      const ChoirScreen(choirId: 'c1'),
    ]) {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.8),
          ),
          child: app(screen),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
