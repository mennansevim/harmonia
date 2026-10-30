import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/choir/app/piece_audio.dart';
import 'package:harmonia/choir/data/choir_bundle.dart';
import 'package:harmonia/choir/data/choir_store.dart';
import 'package:harmonia/choir/domain/assignment.dart';
import 'package:harmonia/choir/domain/choir.dart';
import 'package:harmonia/choir/domain/resource.dart';
import 'package:harmonia/choir/domain/submission.dart';
import 'package:harmonia/choir/midi/part_renderer.dart';

final t0 = DateTime.utc(2026, 11, 2, 18);

class Device {
  Device(this.root, int seed) {
    store = ChoirStore(
      persistence: persistence,
      mediaRoot: () async => root,
      clock: () => clock,
      random: Random(seed),
    );
    bundles = ChoirBundles(store, () async => root);
  }
  final Directory root;
  final persistence = MemoryChoirPersistence();
  late final ChoirStore store;
  late final ChoirBundles bundles;
  DateTime clock = t0;
}

void main() {
  late Directory tmp;
  late Device teacher, singer;
  late File midi, take;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('choir-store-');
    teacher = Device(await Directory('${tmp.path}/t').create(), 1);
    singer = Device(await Directory('${tmp.path}/s').create(), 2);
    await teacher.store.load();
    await singer.store.load();
    midi = await File('${tmp.path}/eser.mid').writeAsBytes([1, 2, 3, 4]);
    take = await File('${tmp.path}/take.wav').writeAsBytes(List.filled(64, 7));
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<(Choir, Assignment)> publish() async {
    final c = await teacher.store.createChoir('Oda Korosu', 'Ayşe');
    final ref = await teacher.store.addMidi(
      choir: c,
      sourcePath: midi.path,
      fileName: 'eser.mid',
      rights: RightsDeclaration.ownRecording,
      trackParts: const {0: ChoirPart.alto},
    );
    final a = Assignment(
      id: 'a1',
      choirId: c.id,
      title: 'Hafta ödevi',
      parts: const [ChoirPart.alto, ChoirPart.bass],
      pieces: [
        AssignmentPiece(
          id: 'solfej',
          title: 'Gloria',
          mode: PieceMode.solfege,
          fromMeasure: 12,
          toMeasure: 30,
          withAccompaniment: true,
          midiReferenceId: ref.id,
        ),
        AssignmentPiece(id: 'soz', title: 'Kyrie', mode: PieceMode.lyrics),
      ],
      createdAt: t0,
      dueAt: t0.add(const Duration(days: 3)),
      maxRecordingSeconds: 600,
    );
    await teacher.store.publish(a);
    return (c, a);
  }

  Future<(Choir, Assignment)> joined() async {
    final (c, a) = await publish();
    final result = await singer.bundles.open(
      await teacher.bundles.exportChoir(c),
    );
    expect(result.outcome, BundleOutcome.needsJoin);
    await singer.bundles.join(
      result.preview!,
      displayName: 'Mert',
      part: ChoirPart.alto,
    );
    return (c, a);
  }

  Future<Submission> sendTake(Assignment a, String pieceId) async {
    final piece = a.piece(pieceId)!;
    final draft = await singer.store.keepTake(
      assignment: a,
      piece: piece,
      sourcePath: take.path,
      fileName: 'take.wav',
      durationMs: 4000,
      kind: TakeKind.accompaniedMix,
    );
    return singer.store.markSent(draft);
  }

  test('a piece renders from the store across the isolate boundary', () async {
    final (c, a) = await publish();
    final bytes = BytesBuilder()
      ..add('MThd'.codeUnits)
      ..add([0, 0, 0, 6, 0, 0, 0, 1, 1, 0xE0])
      ..add('MTrk'.codeUnits)
      ..add([0, 0, 0, 13])
      ..add([0, 0x90, 60, 100, 0x83, 0x60, 0x80, 60, 0, 0, 0xFF, 0x2F, 0]);
    final file = await File(
      '${tmp.path}/real.mid',
    ).writeAsBytes(bytes.toBytes());
    final ref = await teacher.store.addMidi(
      choir: c,
      sourcePath: file.path,
      fileName: 'real.mid',
      rights: RightsDeclaration.ownRecording,
      trackParts: const {0: ChoirPart.alto},
    );
    final part = await renderPiece(
      store: teacher.store,
      piece: AssignmentPiece(
        id: 'x',
        title: 'x',
        mode: PieceMode.solfege,
        midiReferenceId: ref.id,
      ),
      mix: const PartMix(ownPart: ChoirPart.alto),
    );
    expect(part.samples, isNotEmpty);
    expect(await encodeRendered(part), isNotEmpty);
    expect(a.id, 'a1');
  });

  test('state survives a restart', () async {
    final (c, a) = await joined();
    await sendTake(a, 'solfej');
    final again = ChoirStore(
      persistence: singer.persistence,
      mediaRoot: () async => singer.root,
    );
    await again.load();
    expect(again.myId, singer.store.myId);
    expect(again.choir(c.id)!.name, 'Oda Korosu');
    expect(again.meIn(c.id)!.part, ChoirPart.alto);
    expect(
      again.mySubmission('a1', 'solfej')!.status,
      SubmissionStatus.submitted,
    );
  });

  test('an unreadable store is reported and never overwritten', () async {
    final broken = MemoryChoirPersistence()
      ..document = {'schema': 99, 'myId': 'x'};
    final store = ChoirStore(persistence: broken, mediaRoot: () async => tmp);
    await store.load();
    expect(store.loadError, isNotNull);
    await store.save();
    expect(broken.document!['schema'], 99);
  });

  test('whole round: assignment, take, feedback with a voice note', () async {
    final (c, a) = await joined();
    expect(singer.store.assignmentsOf(c.id).single.pieces, hasLength(2));
    final midiPath = await singer.store.mediaPath(
      a.pieces.first.midiReferenceId!,
    );
    expect(await File(midiPath).readAsBytes(), [1, 2, 3, 4]);

    final sent = await sendTake(a, 'solfej');
    final inbox = await teacher.bundles.open(
      await singer.bundles.exportSubmission(sent),
    );
    expect(inbox.outcome, BundleOutcome.takeReceived);
    final queue = teacher.store.reviewQueue(c.id);
    expect(queue.single.takeKind, TakeKind.accompaniedMix);
    expect(teacher.store.singersOf(c.id).single.displayName, 'Mert');
    expect(
      await File(
        await teacher.store.mediaPath(queue.single.recordingId!),
      ).length(),
      64,
    );

    final voice = await teacher.store.addMedia(take.path, 'not.wav');
    final reviewed = await teacher.store.review(
      submission: queue.single,
      outcome: ReviewOutcome.revisionRequested,
      tags: const [FeedbackTag.breathLeak],
      marks: [FeedbackMark(atMs: 2300, tag: FeedbackTag.breathLeak)],
      voiceNoteId: voice,
    );
    expect(teacher.store.reviewQueue(c.id), isEmpty);

    final back = await singer.bundles.open(
      await teacher.bundles.exportFeedback(reviewed),
    );
    expect(back.outcome, BundleOutcome.feedbackReceived);
    final mine = singer.store.mySubmission('a1', 'solfej')!;
    expect(mine.status, SubmissionStatus.revisionRequested);
    expect(mine.latestFeedback!.marks.single.atMs, 2300);
    expect(await File(await singer.store.mediaPath(voice)).exists(), isTrue);

    // A new take opens attempt 2 and replaces the conductor's old one.
    final second = await sendTake(a, 'solfej');
    expect(second.attempt, 2);
    expect(second.feedback, hasLength(1));
    final again = await teacher.bundles.open(
      await singer.bundles.exportSubmission(second),
    );
    expect(again.outcome, BundleOutcome.takeReceived);
    expect(teacher.store.reviewQueue(c.id).single.attempt, 2);

    // Takes are large: a replaced one leaves nothing behind on either side.
    final old = sent.recordingId!;
    expect(await File(await singer.store.mediaPath(old)).exists(), isFalse);
    expect(await File(await teacher.store.mediaPath(old)).exists(), isFalse);
    expect(
      await File(await singer.store.mediaPath(second.recordingId!)).exists(),
      isTrue,
    );
  });

  test('opening the same take twice changes nothing', () async {
    final (_, a) = await joined();
    final path = await singer.bundles.exportSubmission(
      await sendTake(a, 'soz'),
    );
    await teacher.bundles.open(path);
    final twice = await teacher.bundles.open(path);
    expect(twice.outcome, BundleOutcome.nothingNew);
    expect(teacher.store.submissions, hasLength(1));
  });

  test(
    'an updated choir package adds work and keeps the singer\'s own',
    () async {
      final (c, a) = await joined();
      await sendTake(a, 'soz');
      await teacher.store.addResource(
        ChoirResource(
          id: 'r1',
          choirId: c.id,
          kind: ResourceKind.rehearsalRecording,
          title: '5 Kasım provası',
          authorId: teacher.store.myId,
          createdAt: t0,
          fileId: await teacher.store.addMedia(take.path, 'prova.wav'),
          fileName: 'prova.wav',
        ),
      );
      final update = await singer.bundles.open(
        await teacher.bundles.exportChoir(c),
      );
      expect(update.outcome, BundleOutcome.choirUpdated);
      expect(singer.store.resourcesOf(c.id).single.title, '5 Kasım provası');
      expect(singer.store.mySubmission('a1', 'soz'), isNotNull);
    },
  );

  test('work using a file with no sharing right cannot be published', () async {
    final c = await teacher.store.createChoir('K', 'Ayşe');
    final ref = await teacher.store.addMidi(
      choir: c,
      sourcePath: midi.path,
      fileName: 'x.mid',
      rights: RightsDeclaration.unknown,
      trackParts: const {},
    );
    await expectLater(
      teacher.store.publish(
        Assignment(
          id: 'a',
          choirId: c.id,
          title: 'x',
          parts: const [ChoirPart.alto],
          pieces: [
            AssignmentPiece(
              id: 'p',
              title: 'x',
              mode: PieceMode.solfege,
              midiReferenceId: ref.id,
            ),
          ],
          createdAt: t0,
        ),
      ),
      throwsArgumentError,
    );
    expect(teacher.store.assignments, isEmpty);
  });

  group('refuses', () {
    Future<void> rejects(String path, BundleProblem problem, Device on) =>
        expectLater(
          on.bundles.open(path),
          throwsA(
            isA<BundleRejected>().having((e) => e.problem, 'problem', problem),
          ),
        );

    test('a random file, and a zip of something else', () async {
      await rejects(take.path, BundleProblem.notABundle, singer);
      final zip = '${tmp.path}/x.zip';
      final encoder = ZipFileEncoder()..create(zip);
      encoder.addArchiveFile(ArchiveFile.string('a.txt', 'x'));
      await encoder.close();
      await rejects(zip, BundleProblem.notABundle, singer);
    });

    test('one\'s own choir package', () async {
      final (c, _) = await publish();
      await rejects(
        await teacher.bundles.exportChoir(c),
        BundleProblem.ownChoir,
        teacher,
      );
    });

    test('a take for a choir this device does not run', () async {
      final (_, a) = await joined();
      final path = await singer.bundles.exportSubmission(
        await sendTake(a, 'soz'),
      );
      await rejects(path, BundleProblem.notForYou, singer);
      final stranger = Device(await Directory('${tmp.path}/x').create(), 3);
      await stranger.store.load();
      await rejects(path, BundleProblem.unknownChoir, stranger);
    });

    test('feedback meant for someone else', () async {
      final (c, a) = await joined();
      final sent = await sendTake(a, 'soz');
      await teacher.bundles.open(await singer.bundles.exportSubmission(sent));
      final reviewed = await teacher.store.review(
        submission: teacher.store.reviewQueue(c.id).single,
        outcome: ReviewOutcome.accepted,
        text: 'Güzel',
      );
      final other = Device(await Directory('${tmp.path}/y').create(), 4);
      await other.store.load();
      await other.bundles.join(
        (await other.bundles.open(
          await teacher.bundles.exportChoir(c),
        )).preview!,
        displayName: 'Ece',
        part: ChoirPart.alto,
      );
      await rejects(
        await teacher.bundles.exportFeedback(reviewed),
        BundleProblem.notForYou,
        other,
      );
    });

    test('a tampered file, leaving nothing behind', () async {
      final (c, _) = await publish();
      final path = await teacher.bundles.exportChoir(c);
      final input = InputFileStream(path);
      final archive = ZipDecoder().decodeStream(input);
      final forged = '${tmp.path}/forged.harmonia';
      final encoder = ZipFileEncoder()..create(forged);
      for (final entry in archive.files) {
        final bytes = entry.name == 'manifest.json'
            ? entry.readBytes()!
            : Uint8List.fromList([9, 9, 9, 9]);
        encoder.addArchiveFile(ArchiveFile.bytes(entry.name, bytes));
      }
      await encoder.close();
      await input.close();
      final preview = (await singer.bundles.open(forged)).preview!;
      await expectLater(
        singer.bundles.join(preview, displayName: 'Mert', part: ChoirPart.alto),
        throwsA(isA<BundleRejected>()),
      );
      expect(singer.store.references, isEmpty);
      expect(singer.store.choirs, isEmpty);
    });

    test('a path-like media id in a manifest', () async {
      final (c, _) = await publish();
      final path = await teacher.bundles.exportChoir(c);
      final input = InputFileStream(path);
      final archive = ZipDecoder().decodeStream(input);
      final manifest =
          jsonDecode(
                utf8.decode(archive.findFile('manifest.json')!.readBytes()!),
              )
              as Map<String, Object?>;
      final refs = manifest['references'] as List<Object?>;
      (refs.single as Map<String, Object?>)['id'] = '../../evil.dart';
      (manifest['files'] as Map<String, Object?>)['../../evil.dart'] = 'x';
      final assignment =
          (manifest['assignments'] as List<Object?>).single
              as Map<String, Object?>;
      ((assignment['pieces'] as List<Object?>).first
              as Map<String, Object?>)['midiReferenceId'] =
          '../../evil.dart';
      final forged = '${tmp.path}/evil.harmonia';
      final encoder = ZipFileEncoder()..create(forged);
      encoder.addArchiveFile(
        ArchiveFile.string('manifest.json', jsonEncode(manifest)),
      );
      await encoder.close();
      await input.close();
      final preview = (await singer.bundles.open(forged)).preview!;
      await expectLater(
        singer.bundles.join(preview, displayName: 'Mert', part: ChoirPart.alto),
        throwsA(isA<BundleRejected>()),
      );
    });
  });

  test('the nearest open work shows on Today until it is sent', () async {
    final (_, a) = await joined();
    expect(singer.store.nextDue()!.$2.id, 'a1');
    await sendTake(a, 'solfej');
    expect(singer.store.nextDue(), isNotNull);
    await sendTake(a, 'soz');
    expect(singer.store.nextDue(), isNull);
  });

  test('a take sent after the due time is labelled, not refused', () async {
    final (_, a) = await joined();
    singer.clock = t0.add(const Duration(days: 4));
    final sent = await sendTake(a, 'soz');
    expect(sent.sentLate(a), isTrue);
  });

  test('deleting removes data and media from this device', () async {
    final (c, a) = await joined();
    final sent = await sendTake(a, 'soz');
    final media = File(await singer.store.mediaPath(sent.recordingId!));
    expect(await media.exists(), isTrue);
    await singer.store.forgetChoir(singer.store.choir(c.id)!);
    expect(singer.store.assignments, isEmpty);
    expect(await media.exists(), isFalse);

    await teacher.store.clearAll();
    expect(teacher.persistence.document, isNull);
    expect(
      await Directory('${teacher.root.path}/choir_media').exists(),
      isFalse,
    );
  });
}
