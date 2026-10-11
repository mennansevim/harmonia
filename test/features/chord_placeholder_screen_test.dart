import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/harmonia_app.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/domain/audio/chord_recording_catalog.dart';
import 'package:harmonia/features/chord_exercise/chord_placeholder_screen.dart';
import 'package:harmonia/infrastructure/audio/asset_chord_recording_catalog.dart';

import '../domain/audio/chord_recording_catalog_test.dart' show pendingCatalog;

class FakeCatalogRepository implements ChordRecordingCatalogRepository {
  int calls = 0;
  bool fail = false;
  Completer<ChordRecordingCatalog>? gate;
  @override
  Future<ChordRecordingCatalog> load() async {
    calls++;
    if (fail) throw const FormatException('private diagnostic');
    if (gate != null) return gate!.future;
    return ChordRecordingCatalog.fromJson(pendingCatalog());
  }
}

void main() {
  test('bundled manifest loads only pending catalog, no audio files', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await AssetChordRecordingCatalog().load();
    expect(catalog.slots.map((s) => s.voiceCount), [2, 3, 4]);
  });
  testWidgets(
    'home entry opens real bundled placeholders with disabled actions',
    (tester) async {
      await tester.pumpWidget(
        HarmoniaApp(
          startupCleanup: _noSweep,
          history: InMemoryResultHistory(),
          profiles: InMemoryProfileRepository(
            LearnerProfile(
              goal: PracticeGoal.conservatory,
              createdAt: DateTime.utc(2026, 10, 11),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('2 / 3 / 4 sesli piyano'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 / 3 / 4 sesli piyano'));
      await tester.pump();
      await tester.runAsync(() => AssetChordRecordingCatalog().load());
      await tester.pumpAndSettle();
      expect(find.text('Piyano kaydı bekleniyor'), findsNWidgets(3));
      for (final count in [2, 3, 4]) {
        expect(
          tester
              .widget<FilledButton>(find.byKey(Key('chord_listen_$count')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(find.byKey(Key('chord_repeat_$count')))
              .onPressed,
          isNull,
        );
      }
      expect(find.text('Doğru!'), findsNothing);
      expect(find.textContaining('puan üretilmez'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('placeholder fits 320px with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeCatalogRepository();
    await tester.pumpWidget(
      MaterialApp(home: ChordPlaceholderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('chord_repeat_4')));
    expect(tester.takeException(), isNull);
    expect(repository.calls, 1);
  });
  testWidgets('catalog failure stays unstarted and retry recovers', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: ChordPlaceholderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ses testi başlatılmadı'), findsOneWidget);
    expect(find.text('private diagnostic'), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(find.text('Piyano kaydı bekleniyor'), findsNWidgets(3));
    expect(repository.calls, 2);
  });
  testWidgets('late catalog completion after disposal cannot revive screen', (
    tester,
  ) async {
    final gate = Completer<ChordRecordingCatalog>();
    final repository = FakeCatalogRepository()..gate = gate;
    await tester.pumpWidget(
      MaterialApp(home: ChordPlaceholderScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    gate.complete(ChordRecordingCatalog.fromJson(pendingCatalog()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<OrphanCleanupReport> _noSweep() async => const OrphanCleanupReport();
