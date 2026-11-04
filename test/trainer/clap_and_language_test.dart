import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/lang.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/koro/clap_rhythm.dart';

import 'trainer_app_test.dart' show app, memoryStore, settle, tapKey;

class _Ear implements ClapListener {
  void Function(int ms)? _onClap;
  bool stopped = false;
  void clap(int ms) => _onClap?.call(ms);
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(void Function(int ms) onClap) async {
    stopped = false;
    _onClap = onClap;
  }

  @override
  Future<void> stop() async => stopped = true;
  @override
  Future<void> close() async {}
}

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

  test('clap rhythms go from easy to hard', () {
    final ladder = clapRhythmsEasyToHard;
    expect(ladder, hasLength(clapRhythms.length));
    expect(ladder.map((r) => r.id).toSet(), hasLength(ladder.length));
    // The first rhythm is all on the beat; the syncopated clave comes later.
    expect(ladder.first.beats.every((b) => b == b.floorToDouble()), isTrue);
    expect(
      ladder.indexWhere((r) => r.id == 'draft-clap-son-clave'),
      greaterThan(ladder.indexWhere((r) => r.id == 'draft-clap-waltz')),
    );
  });

  testWidgets('listen, count in, clap back, and a clean echo levels up', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    final player = _Player();
    final ear = _Ear();
    Navigator.of(tester.element(find.byType(HomeShell))).push(
      MaterialPageRoute<void>(
        builder: (_) => ClapRhythmScreen(player: player, listener: ear),
      ),
    );
    await settle(tester);
    final rhythm = clapRhythmsEasyToHard.first;
    expect(
      tester.widget<Text>(find.byKey(const Key('clap_title'))).data,
      rhythm.title,
    );
    Color fill(int i) =>
        ((tester.widget<Container>(find.byKey(Key('clap_beat_$i'))).decoration
                as BoxDecoration)
            .color)!;
    final empty = fill(0);
    await tester.tap(find.byKey(const Key('clap_start')));
    await tester.pump();
    await tester.pump();
    expect(player.played, hasLength(1));
    final ms = rhythm.onsetsMs;
    await tester.pump(Duration(milliseconds: ms[1] - 5));
    await tester.pump();
    expect(fill(0), isNot(empty));
    expect(fill(1), empty);
    await tester.pump(Duration(milliseconds: ms.last + 600));
    // Count-in: four beats at the rhythm's tempo, with its own click track.
    expect(tester.widget<Text>(find.byKey(const Key('clap_status'))).data, '1');
    expect(player.played, hasLength(2));
    await tester.pump(Duration(milliseconds: (4 * 60000 / rhythm.bpm).round()));
    await tester.pump();
    await tester.pump();
    // Count-in, then the "go" cue, then the microphone opens.
    expect(player.played, hasLength(3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byKey(const Key('your_turn')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('your_turn_action'))).data,
      'Alkışla!',
    );
    // A late start and steady latency do not matter: the first clap anchors.
    for (final o in ms) {
      ear.clap(o + 700 + (o.isEven ? 30 : -20));
      await tester.pump(const Duration(milliseconds: 1));
    }
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('clap_status'))).data,
      'Ritmi yakaladın',
    );
    expect(ear.stopped, isTrue);
    expect(store.clapLevel, 1);
    expect(find.byKey(const Key('clap_next')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Settings switches the app language and remembers it', (
    tester,
  ) async {
    final store = memoryStore({'onboardingDone': true, 'setupDone': true});
    await store.load();
    await tester.pumpWidget(app(store));
    await settle(tester);
    await tapKey(tester, 'open_settings');
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
    tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .jumpTo(0);
    await tester.pump();
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
