import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/practice_preferences.dart';
import 'package:resonia/application/practice_reminder.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/choir/data/choir_store.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';
import 'package:resonia/trainer/app/trainer_app.dart';
import 'package:resonia/trainer/audio/piano_notes.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/domain/music.dart';
import 'package:resonia/trainer/home/home_shell.dart';
import 'package:resonia/trainer/koro/range_ladder.dart';
import 'package:resonia/trainer/koro/range_test.dart';
import 'package:resonia/trainer/state/trainer_store.dart';

/// Sings whatever the voice can reach: [low]..[high] in tune, everything
/// else an octave off (the classic wrong-octave answer).
class _Singer implements RangeProbe {
  _Singer(this.low, this.high);
  final int low;
  final int high;
  int? playing;
  int? comfortMidi = 57;
  final played = <int>[];

  @override
  Future<bool> requestPermission() async => true;
  @override
  Stream<double> get levelDb => const Stream.empty();
  @override
  Future<RangeTake> record(Duration duration) async {
    final comfort = comfortMidi;
    if (comfort != null) {
      comfortMidi = null;
      return RangeTake.pitch(midiToHz(comfort));
    }
    final target = playing!;
    if (target >= low && target <= high) {
      return RangeTake.pitch(midiToHz(target) * 1.01);
    }
    final octave = target > high ? -12 : 12;
    return RangeTake.pitch(midiToHz(target + octave));
  }

  @override
  Future<void> close() async {}

  Future<void> play(int midi) async {
    playing = midi;
    played.add(midi);
  }
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.catalog);
  final String catalog;
  final loaded = <String>[];
  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (key == PianoNoteBank.catalogPath) {
      return ByteData.sublistView(utf8.encode(catalog));
    }
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}

Future<TrainerStore> _pumpHome(WidgetTester tester) async {
  final store = TrainerStore(
    MemoryTrainerPersistence(null),
    clock: () => DateTime(2026, 11, 3, 9),
  );
  await store.load();
  store
    ..onboardingDone = true
    ..setupDone = true;
  await tester.pumpWidget(
    TrainerApp(
      store: store,
      audio: TrainerAudio.silent(),
      reminders: PracticeReminderCoordinator(
        preferences: InMemoryPracticePreferences(),
        platform: const UnavailablePracticeReminderPlatform(),
      ),
      history: InMemoryResultHistory(),
      choir: ChoirStore(
        persistence: MemoryChoirPersistence(),
        mediaRoot: () async => Directory.systemTemp,
      ),
      purgeTempAudio: () async => const OrphanCleanupReport(),
      liveAudio: false,
      startupCleanup: () async {},
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return store;
}

void main() {
  group('range ladder (Agora play-and-listen port)', () {
    test('the ladder holds the natural notes E1–C7', () {
      expect(rangeLadderNotes.first, 28);
      expect(rangeLadderNotes.last, 96);
      expect(rangeLadderNotes, hasLength(41));
      expect(rangeLadderNotes, contains(neutralStartMidi));
    });

    test('a take within 40 cents of the note is reached', () {
      final a4 = midiToHz(69);
      final j = judgeRangeTake(a4 * 1.02, 69); // about +34 cents
      expect(j.match, RangeMatch.matched);
      expect(j.closeness, greaterThanOrEqualTo(rangePassMark));
      expect(judgeRangeTake(a4 * 1.03, 69).match, RangeMatch.missed);
    });

    test('a wrong octave is never a success', () {
      final j = judgeRangeTake(midiToHz(57), 69);
      expect(j.match, RangeMatch.octaveOff);
      expect(j.octave, -1);
      expect(judgeRangeTake(midiToHz(81), 69).octave, 1);
    });

    test('an unmeasured take carries no pitch or closeness', () {
      final j = judgeRangeTake(null, 69);
      expect(j.match, RangeMatch.unmeasured);
      expect(j.closeness, isNull);
      expect(j.cents, isNull);
    });

    test('climbs, turns after two misses, descends and finishes', () {
      var l = RangeLadder.start(60);
      double hz(int m) => midiToHz(m);
      l = l.record(hz(60)); // C4
      l = l.record(hz(62)); // D4
      expect(l.currentMidi, 64);
      l = l.record(null);
      expect(l.attempt, 2);
      expect(l.currentMidi, 64);
      l = l.record(hz(52)); // E3: octave off
      expect(l.direction, RangeDirection.down);
      expect(l.currentMidi, 59);
      l = l.record(hz(59));
      l = l.record(hz(57));
      l = l.record(hz(40));
      l = l.record(hz(40));
      expect(l.done, isTrue);
      expect(l.reached, {57, 59, 60, 62});
      expect(l.bounds!.lowMidi, 57);
      expect(l.bounds!.highMidi, 62);
      expect(l.bounds!.semitones, 5);
      expect(
        l.log.where((a) => a.judgement.match == RangeMatch.unmeasured),
        hasLength(1),
      );
    });

    test('skipping ends a direction without a take', () {
      final l = RangeLadder.start(60).skipDirection();
      expect(l.direction, RangeDirection.down);
      expect(l.log, isEmpty);
      expect(l.skipDirection().done, isTrue);
    });

    test('one reached note is not a range', () {
      final l = RangeLadder.start(60).record(midiToHz(60));
      expect(l.bounds, isNull);
    });

    test('the comfortable take picks the nearest natural note', () {
      expect(startFromComfort(midiToHz(61)), anyOf(60, 62));
      expect(startFromComfort(midiToHz(48)), 48);
      expect(startFromComfort(null), neutralStartMidi);
    });
  });

  group('recorded piano notes', () {
    test('a catalog without a rights reference is ignored', () async {
      final bundle = _Bundle(
        jsonEncode({
          'kind': 'prerecorded_piano_notes',
          'rightsReference': null,
          'notes': {'C4': 'assets/audio/piano/notes/C4.wav'},
        }),
      );
      final bank = PianoNoteBank(bundle: bundle);
      expect(await bank.wav(60), isNull);
      expect(bundle.loaded, isNot(contains('assets/audio/piano/notes/C4.wav')));
    });

    test('a cleared catalog plays the listed note, synth elsewhere', () async {
      final bundle = _Bundle(
        jsonEncode({
          'kind': 'prerecorded_piano_notes',
          'rightsReference': 'Mennan Sevim, own recording, 2026',
          'notes': {'C4': 'assets/audio/piano/notes/C4.wav'},
        }),
      );
      final bank = PianoNoteBank(bundle: bundle);
      expect(await bank.wav(60), isNotNull);
      expect(await bank.wav(62), isNull);
      expect(await bank.wav(61), isNull);
      expect(PianoNoteBank.noteName(61), isNull);
      expect(PianoNoteBank.noteName(57), 'A3');
    });

    test('the bundled catalog is cleared by its owner', () async {
      final doc =
          jsonDecode(File(PianoNoteBank.catalogPath).readAsStringSync()) as Map;
      expect(doc['kind'], 'prerecorded_piano_notes');
      expect(doc['rightsReference'], contains('Mennan Sevim'));
    });
  });

  testWidgets('play-and-listen run saves the range and the practice register', (
    tester,
  ) async {
    final store = await _pumpHome(tester);
    final singer = _Singer(53, 69);
    Navigator.of(tester.element(find.byType(HomeShell))).push(
      MaterialPageRoute<void>(
        builder: (_) => RangeTestScreen(
          probe: singer,
          playNote: singer.play,
          pause: const Duration(milliseconds: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ses aralığını bul'), findsOneWidget);
    await tester.tap(find.text('Başla'));
    // The idle orb on the comfort page breathes forever: no settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Önce rahat bir ses'), findsOneWidget);
    await tester.tap(find.text('Söyle (3 sn)'));
    for (
      var i = 0;
      i < 400 && find.byKey(const Key('range_result')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('range_result')), findsOneWidget);
    // Comfort take A3 → start there, up to A4, then down to F3.
    expect(singer.played.first, 57);
    expect(find.text('Fa3 – La4'), findsOneWidget);
    expect(store.koroRange, '53-69');
    expect(store.voicePart, isNotNull);
    // Octave-off answers above A4 were played but never reached.
    expect(singer.played, contains(71));
    await tester.pumpAndSettle();
  });

  testWidgets('the skip ends going up and the run can finish', (tester) async {
    await _pumpHome(tester);
    final singer = _Singer(40, 90)..comfortMidi = null;
    // Holds a reference note so the skip lands while it is playing.
    Completer<void>? hold;
    Navigator.of(tester.element(find.byType(HomeShell))).push(
      MaterialPageRoute<void>(
        builder: (_) => RangeTestScreen(
          probe: singer,
          playNote: (m) async {
            await singer.play(m);
            hold = Completer<void>();
            await hold!.future;
          },
          pause: const Duration(milliseconds: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başla'));
    // The idle orb on the comfort page breathes forever: no settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('La3 notasından başla'));
    await tester.pump();
    Future<void> release() async {
      hold!.complete();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    await release(); // A3 reached
    expect(singer.played, [57, 59]);
    expect(find.text('Tizde sınırım bu, pese geç'), findsOneWidget);
    await tester.tap(find.byKey(const Key('range_skip')));
    await release(); // B3 skipped, turn, G3 playing
    expect(singer.played.last, 55);
    expect(find.text('Peste sınırım bu, bitir'), findsOneWidget);
    await release(); // G3 reached, F3 playing
    await tester.tap(find.byKey(const Key('range_skip')));
    await release();
    expect(find.byKey(const Key('range_result')), findsOneWidget);
    expect(find.text('Sol3 – La3'), findsOneWidget);
  });
}
