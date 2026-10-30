// The choir loop on a simulator or device with the real plugins:
//   flutter test integration_test/choir_journey_test.dart -d <device-id>
// Grant the microphone first (simulator: `xcrun simctl privacy <id> grant
// microphone <bundle-id>`). Proves playback and capture run together and the
// files flow from conductor to singer and back. A simulator has no headphones
// or real acoustic path: this is not a latency, bleed or device acceptance.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/app/piece_audio.dart';
import 'package:resonia/choir/audio/plugin_take_engine.dart';
import 'package:resonia/choir/audio/take_controller.dart';
import 'package:resonia/choir/audio/wav_io.dart';
import 'package:resonia/choir/data/choir_bundle.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/choir/domain/assignment.dart';
import 'package:resonia/choir/domain/choir.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/choir/midi/part_renderer.dart';
import 'package:integration_test/integration_test.dart';

/// A real SMF: 120 BPM, soprano and bass, one bar of 4/4.
Uint8List smf() {
  final out = BytesBuilder();
  void u32(int v) =>
      out.add([v >> 24, (v >> 16) & 255, (v >> 8) & 255, v & 255]);
  void chunk(String tag, List<int> body) {
    out.add(tag.codeUnits);
    u32(body.length);
    out.add(body);
  }

  List<int> name(String text) => [0, 0xFF, 3, text.length, ...text.codeUnits];
  List<int> line(int key) => [
    for (var i = 0; i < 4; i++) ...[
      0, 0x90, key, 100, //
      0x83, 0x60, 0x80, key, 0,
    ],
    0,
    0xFF,
    0x2F,
    0,
  ];

  chunk('MThd', [0, 1, 0, 3, 1, 0xE0]);
  chunk('MTrk', [0, 0xFF, 0x51, 3, 7, 0xA1, 0x20, 0, 0xFF, 0x2F, 0]);
  chunk('MTrk', [...name('Soprano'), ...line(72)]);
  chunk('MTrk', [...name('Bas'), ...line(48)]);
  return out.toBytes();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('conductor to singer and back, on real audio plugins', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final root = await Directory.systemTemp.createTemp('choir-e2e-');
    Future<ChoirStore> device(String name) async {
      final dir = await Directory('${root.path}/$name').create();
      final store = ChoirStore(
        persistence: MemoryChoirPersistence(),
        mediaRoot: () async => dir,
      );
      await store.load();
      return store;
    }

    final teacher = await device('teacher');
    final singer = await device('singer');
    final teacherBundles = ChoirBundles(teacher, () async => root);
    final singerBundles = ChoirBundles(singer, () async => root);

    final midi = await File('${root.path}/eser.mid').writeAsBytes(smf());
    final choir = await teacher.createChoir('Deneme Korosu', 'Şef');
    final ref = await teacher.addMidi(
      choir: choir,
      sourcePath: midi.path,
      fileName: 'eser.mid',
      rights: RightsDeclaration.ownRecording,
      trackParts: const {1: ChoirPart.soprano, 2: ChoirPart.bass},
    );
    final piece = AssignmentPiece(
      id: 'p',
      title: 'Eser',
      mode: PieceMode.solfege,
      fromMeasure: 1,
      toMeasure: 1,
      withAccompaniment: true,
      midiReferenceId: ref.id,
    );
    final assignment = Assignment(
      id: 'a',
      choirId: choir.id,
      title: 'Ödev',
      parts: const [ChoirPart.soprano],
      pieces: [piece],
      createdAt: DateTime.now().toUtc(),
      maxRecordingSeconds: 600,
    );
    await teacher.publish(assignment);

    final joined = await singerBundles.open(
      await teacherBundles.exportChoir(choir),
    );
    await singerBundles.join(
      joined.preview!,
      displayName: 'Korist',
      part: ChoirPart.soprano,
    );

    // The real thing: MIDI plays while the microphone records.
    final capture = PluginTakeCapture();
    expect(
      await capture.requestPermission(),
      isTrue,
      reason: 'grant the microphone first (see top of file)',
    );
    final work = await root.createTemp('take-');
    final take = TakeController(
      capture: capture,
      workDirectory: work,
      maxSeconds: 600,
      render: () => renderPiece(
        store: singer,
        piece: piece,
        mix: const PartMix(ownPart: ChoirPart.soprano, countInBars: 1),
      ),
    );
    await take.begin();
    expect(take.phase, TakePhase.recording, reason: '${take.failure}');
    expect(take.countIn, const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(seconds: 4));
    await take.finish();
    expect(take.phase, TakePhase.review, reason: '${take.failure}');
    final mixed = readWav(await File(take.resultPath).readAsBytes());
    expect(mixed.sampleRateHz, choirSampleRateHz);
    expect(mixed.durationMs, greaterThan(1500));
    expect(mixed.samples.any((s) => s.abs() > 300), isTrue);

    final player = PluginChoirPlayer();
    final length = await player.open(take.resultPath);
    expect(length, isNotNull);
    await player.close();

    await take.setAlignment(120);
    expect(take.phase, TakePhase.review);

    final draft = await singer.keepTake(
      assignment: assignment,
      piece: piece,
      sourcePath: take.resultPath,
      fileName: 'take.wav',
      durationMs: take.resultDurationMs!,
      kind: take.kind,
    );
    final sent = await singer.markSent(draft);
    final inbox = await teacherBundles.open(
      await singerBundles.exportSubmission(sent),
    );
    expect(inbox.outcome, BundleOutcome.takeReceived);

    final reviewed = await teacher.review(
      submission: teacher.reviewQueue(choir.id).single,
      outcome: ReviewOutcome.revisionRequested,
      tags: const [FeedbackTag.breathLeak],
    );
    final back = await singerBundles.open(
      await teacherBundles.exportFeedback(reviewed),
    );
    expect(back.outcome, BundleOutcome.feedbackReceived);
    expect(
      singer.mySubmission('a', 'p')!.status,
      SubmissionStatus.revisionRequested,
    );

    take.dispose();
    await capture.close();
    await root.delete(recursive: true);
  });
}
