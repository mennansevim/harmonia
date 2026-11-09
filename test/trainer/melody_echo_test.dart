import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/melody_session.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/koro/melody_echo.dart';
import 'package:resonia/trainer/koro/melody_echo_levels.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/fake_recording_pitch_worker.dart';
import 'trainer_app_test.dart' show app, memoryStore, settle;

class _Backend extends FakeRoutedAudioLabBackend
    implements MelodyReferenceBackend {
  _Backend(this.reference);
  @override
  final DiagnosticMelodyReference reference;
}

/// Sine tones for [hz], 600 ms each with 200 ms gaps, at 16 kHz.
List<double> _sung(List<double> hz) {
  const rate = 16000;
  final out = List<double>.filled(rate * 3 ~/ 10, 0, growable: true);
  for (final f in hz) {
    for (var i = 0; i < rate * 6 ~/ 10; i++) {
      out.add(0.3 * math.sin(2 * math.pi * f * i / rate));
    }
    out.addAll(List.filled(rate * 2 ~/ 10, 0.0));
  }
  return out;
}

void main() {
  group('echo levels', () {
    test('go from easy to hard and stay within the reference limits', () {
      expect(echoLevels, hasLength(6));
      var previous = 0;
      for (final level in echoLevels) {
        expect(level.melodies.length, greaterThanOrEqualTo(4));
        final notes = level.melodies.first.steps.length;
        expect(notes, greaterThanOrEqualTo(previous));
        previous = notes;
        for (final m in level.melodies) {
          expect(m.steps.length, inInclusiveRange(3, 5));
          expect(m.highest - m.lowest, lessThanOrEqualTo(12));
        }
      }
      final ids = [
        for (final l in echoLevels)
          for (final m in l.melodies) m.id,
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('melodies are placed inside every practice range', () {
      for (final part in VoicePart.values) {
        for (final level in echoLevels) {
          for (final m in level.melodies) {
            for (final shift in [-2, 0, 2]) {
              final notes = placeMelody(m, part.low, part.high, shift: shift);
              expect(notes.reduce(math.min), greaterThanOrEqualTo(part.low));
              expect(notes.reduce(math.max), lessThanOrEqualTo(part.high));
              // The diagnostic reference accepts 80–1200 Hz only.
              for (final n in notes) {
                expect(midiToHz(n), inInclusiveRange(80, 1200));
              }
            }
          }
        }
      }
    });

    test('the measured range wins over the part, then a neutral default', () {
      expect(echoRange('45-70', VoicePart.soprano), (45, 70));
      expect(echoRange('bad', VoicePart.bass), (40, 64));
      expect(echoRange('60-62', null), (53, 69));
      expect(echoRange(null, null), (53, 69));
    });

    test('never picks the same melody twice in a row', () {
      final random = math.Random(1);
      var last = pickEchoMelody(random, 2);
      for (var i = 0; i < 40; i++) {
        final next = pickEchoMelody(random, 2, after: last.id);
        expect(next.id, isNot(last.id));
        last = next;
      }
    });
  });

  testWidgets('listen, sing, compare, and a matched melody unlocks a level', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    late _Backend backend;
    var rounds = 0;
    Navigator.of(tester.element(find.byType(HomeShell))).push(
      MaterialPageRoute<void>(
        builder: (_) => MelodyEchoScreen(
          onRoundFinished: () => rounds++,
          random: math.Random(4),
          worker: FakeRecordingPitchWorker.new,
          backendFactory: (reference) => backend = _Backend(reference),
        ),
      ),
    );
    await settle(tester);
    expect(find.textContaining('SEVİYE 1/6'), findsOneWidget);
    expect(find.byKey(const Key('echo_start')), findsOneWidget);

    await tester.tap(find.byKey(const Key('echo_start')));
    await tester.pump();
    backend.nextClip(List.filled(32000, 0.0));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('echo_status'))).data,
      'Dinle',
    );

    backend.nextClip(_sung(backend.reference.frequenciesHz));
    backend.playbackEnd.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byKey(const Key('echo_finish')), findsOneWidget);

    await tester.tap(find.byKey(const Key('echo_finish')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('echo_status'))).data,
      'Ezgiyi tuttun',
    );
    for (var i = 0; i < backend.reference.frequenciesHz.length; i++) {
      expect(
        tester.widget<Text>(find.byKey(Key('echo_verdict_$i'))).data,
        'Tuttu',
      );
    }
    expect(store.melodyEchoLevel, 1);
    expect(rounds, 1, reason: 'one finished round reports once');
    expect(find.byKey(const Key('echo_next')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  test('the echo level is read back from the saved document', () async {
    final store = memoryStore({'melodyEchoLevel': 3});
    await store.load();
    expect(store.melodyEchoLevel, 3);
  });
}
