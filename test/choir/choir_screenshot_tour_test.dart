// Visual tour for design review, not a regression gate. Sample data, fake
// audio; real fonts:
//   flutter test test/choir/choir_screenshot_tour_test.dart \
//     --dart-define=TOUR_DIR=/absolute/output/dir
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/app/assignment_editor.dart';
import 'package:resonia/choir/app/assignment_screen.dart';
import 'package:resonia/choir/app/choir_scope.dart';
import 'package:resonia/choir/app/choir_screen.dart';
import 'package:resonia/choir/app/choir_tab.dart';
import 'package:resonia/choir/app/library_screen.dart';
import 'package:resonia/choir/app/practice_screen.dart';
import 'package:resonia/choir/app/review_screen.dart';
import 'package:resonia/choir/app/take_screen.dart';
import 'package:resonia/choir/audio/take_engine.dart';
import 'package:resonia/choir/audio/wav_io.dart';
import 'package:resonia/choir/data/choir_bundle.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/resource.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/trainer/app/scope.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/kit.dart';

const _dir = String.fromEnvironment('TOUR_DIR');
final now = DateTime(2026, 10, 30, 18);

Future<void> _loadFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Inter-$w.ttf',
  ]);
  await load('Lora', [
    'assets/fonts/Lora-Regular.ttf',
    'assets/fonts/Lora-SemiBold.ttf',
  ]);
  await load('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Uint8List smf() {
  final out = BytesBuilder();
  void chunk(String tag, List<int> body) {
    final n = body.length;
    out
      ..add(tag.codeUnits)
      ..add([n >> 24, (n >> 16) & 255, (n >> 8) & 255, n & 255])
      ..add(body);
  }

  List<int> track(String name, List<int> keys) => [
    0,
    0xFF,
    3,
    name.length,
    ...name.codeUnits,
    for (final k in keys) ...[0, 0x90, k, 100, 0x83, 0x60, 0x80, k, 0],
    0,
    0xFF,
    0x2F,
    0,
  ];

  chunk('MThd', [0, 1, 0, 5, 1, 0xE0]);
  chunk('MTrk', [0, 0xFF, 0x51, 3, 7, 0xA1, 0x20, 0, 0xFF, 0x2F, 0]);
  final rows = {
    'Soprano': [72, 74, 76, 77, 79, 77, 76, 74],
    'Alto': [67, 69, 67, 69, 72, 69, 67, 65],
    'Tenor': [64, 65, 64, 65, 67, 65, 64, 62],
    'Bas': [48, 50, 52, 53, 55, 53, 52, 50],
  };
  rows.forEach((name, keys) {
    chunk('MTrk', track(name, [for (var i = 0; i < 8; i++) ...keys]));
  });
  return out.toBytes();
}

class TourPlayer implements ChoirPlayer {
  static var position = Duration.zero;
  @override
  Stream<Duration> get positions => Stream.value(position);
  @override
  Stream<bool> get playingChanges => const Stream.empty();
  @override
  Future<Duration?> open(String path, {bool loop = false}) async =>
      const Duration(minutes: 1, seconds: 48);
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

class TourCapture implements TakeCapture {
  TourCapture(this.output);
  final AudioRouteKind Function() output;
  String? _path;
  @override
  Stream<TakeInterruption> get interruptions => const Stream.empty();
  @override
  Stream<double> get levelsDb => Stream.value(-14);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<AudioRouteSnapshot> route() async =>
      AudioRouteSnapshot(input: AudioRouteKind.builtIn, output: output());
  @override
  Future<int> start({
    required String vocalPath,
    String? accompanimentPath,
  }) async {
    _path = vocalPath;
    return 80;
  }

  @override
  Future<void> stop() async =>
      File(_path!).writeAsBytesSync(encodeWav(Int16List(44100 * 12), 44100));
  @override
  Future<void> cancel() async {}
  @override
  Future<void> close() async {}
}

class TourFiles implements ChoirFiles {
  @override
  Future<PickedFile?> pick() async => null;
  @override
  Future<bool> share(String path, {Rect? origin}) async => true;
  @override
  Future<bool> open(String path) async => true;
}

void main() {
  testWidgets('choir screenshot tour', skip: _dir.isEmpty, (tester) async {
    await tester.runAsync(_loadFonts);
    final view = tester.view;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
    addTearDown(view.reset);

    late final Directory tmp;
    late final ChoirStore singer, teacher, empty;
    late final Assignment work;
    late final AssignmentPiece gloria;
    var route = AudioRouteKind.wired;

    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('choir-tour-');
      Future<ChoirStore> device(String name, int seed) async {
        final dir = await Directory('${tmp.path}/$name').create();
        final store = ChoirStore(
          persistence: MemoryChoirPersistence(),
          mediaRoot: () async => dir,
          clock: () => now,
        );
        await store.load();
        return store;
      }

      teacher = await device('t', 1);
      singer = await device('s', 2);
      empty = await device('e', 3);
      await singer.setConsent();
      final midi = await File('${tmp.path}/g.mid').writeAsBytes(smf());
      final take = await File(
        '${tmp.path}/t.wav',
      ).writeAsBytes(encodeWav(Int16List(4410), 44100));
      final choir = await teacher.createChoir('Oda Korosu', 'Ayşe Hoca');
      final ref = await teacher.addMidi(
        choir: choir,
        sourcePath: midi.path,
        fileName: 'gloria.mid',
        rights: RightsDeclaration.ownRecording,
        trackParts: const {
          1: ChoirPart.soprano,
          2: ChoirPart.alto,
          3: ChoirPart.tenor,
          4: ChoirPart.bass,
        },
      );
      gloria = AssignmentPiece(
        id: 'p1',
        title: 'Gloria',
        mode: PieceMode.solfege,
        fromMeasure: 12,
        toMeasure: 30,
        withAccompaniment: true,
        midiReferenceId: ref.id,
      );
      work = Assignment(
        id: 'a1',
        choirId: choir.id,
        title: 'Kasım 1. hafta',
        parts: const [ChoirPart.alto, ChoirPart.bass],
        pieces: [
          gloria,
          AssignmentPiece(
            id: 'p2',
            title: 'Kyrie',
            mode: PieceMode.lyrics,
            sectionNote: 'B harfinden sona',
          ),
        ],
        createdAt: now.toUtc(),
        note: 'Nefes yerlerine dikkat edin.',
        dueAt: DateTime(2026, 11, 2, 23, 59).toUtc(),
        maxRecordingSeconds: 600,
      );
      await teacher.publish(work);
      await teacher.addResource(
        ChoirResource(
          id: 'r1',
          choirId: choir.id,
          kind: ResourceKind.rehearsalRecording,
          title: 'Prova: Gloria ilk bölüm',
          authorId: teacher.myId,
          createdAt: now.toUtc(),
          fileId: await teacher.addMedia(take.path, 'prova.wav'),
          fileName: 'prova.wav',
          rehearsalOn: DateTime(2026, 10, 28),
        ),
      );
      await teacher.addResource(
        ChoirResource(
          id: 'r2',
          choirId: choir.id,
          kind: ResourceKind.score,
          title: 'Gloria nota',
          authorId: teacher.myId,
          createdAt: now.toUtc(),
          fileId: await teacher.addMedia(take.path, 'gloria.pdf'),
          fileName: 'gloria.pdf',
        ),
      );
      await teacher.addResource(
        ChoirResource(
          id: 'r3',
          choirId: choir.id,
          kind: ResourceKind.note,
          title: 'Ders notu',
          authorId: teacher.myId,
          createdAt: now.toUtc(),
          text: 'Altolar 18. ölçüde nefes almasın.',
        ),
      );
      final teacherBundles = ChoirBundles(teacher, () async => tmp);
      final singerBundles = ChoirBundles(singer, () async => tmp);
      final preview = (await singerBundles.open(
        await teacherBundles.exportChoir(choir),
      )).preview!;
      await singerBundles.join(
        preview,
        displayName: 'Mert',
        part: ChoirPart.alto,
      );
      final draft = await singer.keepTake(
        assignment: work,
        piece: gloria,
        sourcePath: take.path,
        fileName: 'take.wav',
        durationMs: 108000,
        kind: TakeKind.accompaniedMix,
      );
      final sent = await singer.markSent(draft);
      await teacherBundles.open(await singerBundles.exportSubmission(sent));
      final voice = await teacher.addMedia(take.path, 'not.wav');
      final reviewed = await teacher.review(
        submission: teacher.reviewQueue(choir.id).single,
        outcome: ReviewOutcome.revisionRequested,
        text: '18. ölçüde nefes kaçıyor, cümleyi bağla. Girişler çok iyi.',
        tags: const [FeedbackTag.breathLeak, FeedbackTag.entry],
        marks: [
          FeedbackMark(atMs: 32400, tag: FeedbackTag.breathLeak),
          FeedbackMark(atMs: 71000, tag: FeedbackTag.pitch),
        ],
        voiceNoteId: voice,
      );
      await singerBundles.open(await teacherBundles.exportFeedback(reviewed));
      // A fresh take for the conductor's queue scene.
      teacher.submissions
        ..clear()
        ..add(
          Submission.fromJson({
            ...reviewed.toJson(),
            'status': 'submitted',
            'listenedAt': null,
            'feedback': <Object?>[],
          }),
        );
    });

    final boundary = GlobalKey();
    var n = 0;

    Widget app(ChoirStore store, Widget home) => RepaintBoundary(
      key: boundary,
      child: ChoirScope(
        store: store,
        bundles: ChoirBundles(store, () async => tmp),
        files: TourFiles(),
        newPlayer: TourPlayer.new,
        newCapture: () => TourCapture(() => route),
        workDirectory: () async => tmp,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: trainerTheme(),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('en'), Locale('tr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: home,
        ),
      ),
    );

    Future<void> settle([int ms = 800]) async {
      for (var i = 0; i < ms ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> shot(String name) async {
      await settle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1.5);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$_dir/${(++n).toString().padLeft(2, '0')}_$name.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    Future<void> show(ChoirStore store, Widget home, String name) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(store, home));
      await settle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await shot(name);
    }

    final trainer = TrainerStore(MemoryTrainerPersistence());
    await tester.runAsync(trainer.load);
    trainer.answers['role'] = 'singer';
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      TrainerScope(
        store: trainer,
        audio: TrainerAudio(),
        liveAudio: false,
        child: app(singer, const HomeShell()),
      ),
    );
    await shot('bugun_son_tarih');
    await tester.tap(find.byKey(const Key('tab_koro')));
    await shot('koro_sekmesi');

    await show(empty, const Scaffold(body: ChoirTab()), 'koro_ilk_acilis');
    final choirId = singer.choirs.single.id;
    await show(singer, ChoirScreen(choirId: choirId), 'korist_koro');
    await show(
      singer,
      const AssignmentScreen(assignmentId: 'a1'),
      'korist_odev',
    );
    await tester.tap(find.text('Kyrie'));
    await shot('korist_eser');
    await show(
      singer,
      PracticeScreen(
        piece: gloria,
        part: ChoirPart.alto,
        crumb: 'Oda Korosu / Çalış',
        onReady: () {},
      ),
      'korist_midi_calisma',
    );

    final fresh = singer.submissions.toList();
    singer.submissions.clear();
    await show(
      singer,
      TakeScreen(assignment: work, piece: gloria),
      'kayit_kulaklik_hazir',
    );
    route = AudioRouteKind.builtIn;
    await show(
      singer,
      TakeScreen(assignment: work, piece: gloria),
      'kayit_hoparlor_engeli',
    );
    route = AudioRouteKind.bluetooth;
    await show(
      singer,
      TakeScreen(assignment: work, piece: gloria),
      'kayit_bluetooth_uyarisi',
    );
    route = AudioRouteKind.wired;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(singer, TakeScreen(assignment: work, piece: gloria)),
    );
    await settle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('take_start')));
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await shot('kayit_suruyor');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('take_stop')));
      await tester.pump();
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await shot('kayit_hizalama');
    singer.submissions.addAll(fresh);

    await show(teacher, ChoirScreen(choirId: choirId), 'sef_koro');
    await show(
      teacher,
      const AssignmentScreen(assignmentId: 'a1'),
      'sef_odev_takip',
    );
    await show(
      teacher,
      AssignmentEditor(choir: teacher.choirs.single),
      'sef_yeni_odev',
    );
    await show(
      teacher,
      PieceEditor(choir: teacher.choirs.single),
      'sef_eser_ekle',
    );
    TourPlayer.position = const Duration(seconds: 32, milliseconds: 400);
    await show(
      teacher,
      ReviewScreen(submissionId: teacher.submissions.single.id),
      'sef_dinleme',
    );
    await tester.tap(find.byKey(const Key('review_add_mark')));
    await shot('sef_not_ekle');
    await tester.tap(find.byKey(const Key('mark_breathLeak')));
    await shot('sef_dinleme_isaret');
    await tester.tap(find.byKey(const Key('review_comment')));
    await tester.enterText(
      find.byKey(const Key('review_comment')),
      'Girişler çok iyi.',
    );
    await tester.ensureVisible(find.byKey(const Key('review_send')));
    await tester.tap(find.byKey(const Key('review_send')));
    await shot('sef_karar');
    await show(singer, LibraryScreen(choirId: choirId), 'kaynaklar');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => tmp.delete(recursive: true));
  });
}
