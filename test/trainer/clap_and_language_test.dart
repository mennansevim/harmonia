import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/koro/clap_rhythm.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

class _Player implements ReferenceClipPlayer {
  final played = <List<int>>[];
  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async {
    played.add(wavBytes);
    return PlaybackHandle(Future.value());
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> close() async {}
}

void main() {
  group('clap rhythms', () {
    test('the pool mixes Western and Turkish rhythms', () {
      final families = clapRhythms.map((r) => r.family).toSet();
      expect(families, RhythmFamily.values.toSet());
      expect(
        clapRhythms.map((r) => r.id).toSet(),
        hasLength(clapRhythms.length),
      );
      for (final r in clapRhythms) {
        final ms = r.onsetsMs;
        for (var i = 1; i < ms.length; i++) {
          expect(ms[i], greaterThan(ms[i - 1]), reason: r.id);
        }
      }
    });

    test('a random pick never repeats the last rhythm', () {
      final random = math.Random(1);
      var last = pickClapRhythm(random);
      for (var i = 0; i < 50; i++) {
        final next = pickClapRhythm(random, after: last.id);
        expect(next.id, isNot(last.id));
        last = next;
      }
    });

    test('the clap sound starts exactly on each onset', () {
      const onsets = [0, 500, 1250];
      final wav = renderClapTrack(onsets);
      double energy(int fromMs, int toMs) {
        var e = 0.0;
        for (var i = fromMs * 48; i < toMs * 48; i++) {
          e += wav.samples[i] * wav.samples[i];
        }
        return e;
      }

      for (final o in onsets) {
        expect(energy(o, o + 20), greaterThan(1), reason: 'clap at $o ms');
      }
      expect(energy(300, 480), lessThan(1e-6));
      expect(energy(1000, 1240), lessThan(1e-6));
    });
  });

  testWidgets('hands follow the clap onsets in order', (tester) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    final player = _Player();
    Navigator.of(tester.element(find.byType(HomeShell))).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ClapRhythmScreen(player: player, random: math.Random(3)),
      ),
    );
    await settle(tester);
    final title = tester
        .widget<Text>(find.byKey(const Key('clap_title')))
        .data!;
    final rhythm = clapRhythms.firstWhere((r) => r.title == title);
    Color fill(int i) =>
        ((tester.widget<Container>(find.byKey(Key('clap_beat_$i'))).decoration
                as BoxDecoration)
            .color)!;
    final empty = fill(0);
    await tester.tap(find.byKey(const Key('clap_again')));
    await tester.pump();
    expect(player.played, hasLength(1));
    final ms = rhythm.onsetsMs;
    await tester.pump(Duration(milliseconds: ms[1] - 5));
    await tester.pump();
    expect(fill(0), isNot(empty));
    expect(fill(1), empty);
    await tester.pump(const Duration(milliseconds: 10));
    expect(fill(1), isNot(empty));
    await tester.pump(Duration(milliseconds: ms.last + 500));
    expect(fill(ms.length - 1), isNot(empty));
    await settle(tester);
  });

  testWidgets('Settings switches the app language and remembers it', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'tab_3');
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_language')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tapKey(tester, 'settings_language');
    await tester.tap(find.text('English'));
    await settle(tester);
    expect(store.language, 'en');
    expect(Lang.en, isTrue);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Settings'), findsWidgets);
    await tapKey(tester, 'settings_language');
    await tester.tap(find.text('Device language'));
    await settle(tester);
    expect(store.language, isNull);
    // Tests run on a Turkish device.
    expect(Lang.en, isFalse);
    expect(find.text('Dil'), findsOneWidget);
  });
}
