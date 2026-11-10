import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/koro/clap_rhythm.dart';
import 'package:resonia/trainer/koro/clap_stage.dart';

import 'package:resonia/trainer/state/trainer_store.dart';

import 'trainer_app_test.dart' show app, settle;

void main() {
  test('every style paints every phase of a clap', () async {
    const phases = [
      ClapPose.rest,
      ClapPose(gap: 0.4, since: 99, count: 1, seconds: 0.5),
      ClapPose(gap: 0, since: 0, count: 2, seconds: 1),
      ClapPose(gap: 0.6, since: 0.08, count: 2, seconds: 1.08),
      ClapPose(gap: 1, since: 0.5, count: 2, seconds: 1.5),
    ];
    for (final style in ClapStyle.values) {
      for (final reduced in [false, true]) {
        for (final pose in phases) {
          final rec = ui.PictureRecorder();
          ClapStagePainter(
            style: style,
            pose: pose,
            reduced: reduced,
          ).paint(Canvas(rec), const Size(240, 170));
          rec.endRecording().dispose();
        }
      }
    }
    expect(ClapStyle.values, hasLength(10));
    expect(ClapStyle.at(99), ClapStyle.notes);
    expect(ClapStyle.at(-1), ClapStyle.classic);
    expect(ClapStyle.named(null), ClapStyle.rings);
    expect(ClapStyle.named('nope'), ClapStyle.rings);
    expect(ClapStyle.named('palmas'), ClapStyle.palmas);
  });

  testWidgets('the stage closes into an expected clap and then settles', (
    tester,
  ) async {
    final cue = ClapCue();
    await tester.pumpWidget(
      Center(
        child: ClapStage(cue: cue, style: ClapStyle.rings),
      ),
    );
    ClapPose pose() => tester
        .widget<CustomPaint>(find.byKey(const Key('clap_stage')))
        .painter
        .let((p) => (p! as ClapStagePainter).pose);
    expect(pose().gap, 1);

    cue.strike();
    await tester.pump();
    expect(pose().gap, closeTo(0, 1e-9));
    expect(pose().impact, closeTo(1, 1e-9));
    cue.expect(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 150));
    expect(pose().gap, greaterThan(0.8), reason: 'recoiled open');
    await tester.pump(const Duration(milliseconds: 200));
    final closing = pose().gap;
    expect(closing, lessThan(0.5), reason: 'closing into the next clap');
    expect(closing, greaterThan(0));

    // Idle: the ticker stops, so nothing keeps the frame scheduler busy.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
    cue.dispose();
  });

  test('a recorded clap is trimmed to its transient and normalised', () {
    final silence = List<double>.filled(4410, 0);
    final hit = [
      for (var i = 0; i < 2205; i++) (i.isEven ? 0.5 : -0.5) * (1 - i / 2205),
    ];
    final wav = Pcm16Wav(sampleRateHz: 44100, samples: [...silence, ...hit]);
    final clip = prepareClapSample(wav)!;
    final peak = clip.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);
    expect(peak, closeTo(clapSamplePeak, 0.02));
    // Leading 100 ms of silence gone: the clap starts within 1 ms.
    final first = clip.indexWhere((v) => v.abs() > 0.1);
    expect(first, lessThan(48));
    expect(clip.length, lessThanOrEqualTo(19200));
    expect(
      prepareClapSample(Pcm16Wav(sampleRateHz: 48000, samples: silence)),
      isNull,
    );
    final track = renderClapTrack(const [0, 500], clap: clip);
    expect(track.samples.length, greaterThan(24000));
  });

  testWidgets('the bundled clap recording loads and is usable', (tester) async {
    final clip = await tester.runAsync(loadClapSample);
    expect(clip, isNotNull);
    expect(clip!.length, inInclusiveRange(4800, 19200));
    final peak = clip.fold(0.0, (m, v) => v.abs() > m ? v.abs() : m);
    expect(peak, closeTo(clapSamplePeak, 0.01));
    // The transient is at the very start, so it lands on the onset.
    expect(clip.take(480).any((v) => v.abs() > 0.3), isTrue);
  });

  testWidgets('back-to-back claps never clip, pile up or click', (
    tester,
  ) async {
    final clip = (await tester.runAsync(loadClapSample))!;
    double jump(List<double> x) {
      var j = 0.0;
      for (var i = 1; i < x.length; i++) {
        j = math.max(j, (x[i] - x[i - 1]).abs());
      }
      return j;
    }

    final ownJump = jump(clip);
    expect(clip.first, 0, reason: 'faded in, no click at the cut');
    expect(clip.last, 0, reason: 'faded out');
    // From a relaxed tempo down to 60 ms apart (faster than any rhythm).
    for (final gap in [60, 90, 136, 273]) {
      final track = renderClapTrack([
        for (var i = 0; i < 16; i++) i * gap,
      ], clap: clip).samples;
      final peak = track.fold(0.0, (m, v) => math.max(m, v.abs()));
      expect(peak, lessThanOrEqualTo(0.95), reason: 'gap $gap');
      expect(peak, greaterThan(0.7), reason: 'gap $gap: not squashed');
      expect(track.where((v) => v.abs() >= 0.999), isEmpty);
      // The choke adds no step sharper than the clap's own attack.
      expect(jump(track), lessThanOrEqualTo(ownJump + 1e-9));
      expect(track.last, 0, reason: 'the last clap rings out fully');
    }
  });

  testWidgets('the clap look is picked from the sheet and remembered', (
    tester,
  ) async {
    final disk = MemoryTrainerPersistence({
      'onboardingDone': true,
      'setupDone': true,
    });
    final store = TrainerStore(disk, clock: () => DateTime(2026, 10, 29, 9));
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    Navigator.of(
      tester.element(find.byType(HomeShell)),
    ).push(MaterialPageRoute<void>(builder: (_) => const ClapRhythmScreen()));
    await settle(tester);
    // Nothing picked yet: the default look is the sound rings.
    expect(
      tester.widget<ClapStage>(find.byType(ClapStage)).style,
      ClapStyle.rings,
    );
    expect(find.byKey(const Key('clap_style')), findsOneWidget);
    await tester.tap(find.byKey(const Key('clap_style')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClapDemo), findsWidgets);
    await tester.tap(find.byKey(const Key('clap_style_classic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.clapLook, ClapStyle.classic.name);
    await tester.runAsync(() async {
      final again = TrainerStore(disk);
      await again.load();
      expect(again.clapLook, ClapStyle.classic.name);
    });
    final stage = tester.widget<ClapStage>(find.byType(ClapStage));
    expect(stage.style, ClapStyle.classic);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
