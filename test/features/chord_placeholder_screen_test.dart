import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/resonia_app.dart';
import 'package:resonia/infrastructure/audio/orphan_audio_cleaner.dart';
import 'package:resonia/application/result_history.dart';
import 'package:resonia/application/profile_repository.dart';
import 'package:resonia/domain/models/learner_profile.dart';
import 'package:resonia/domain/audio/chord_recording_catalog.dart';
import 'package:resonia/features/chord_exercise/chord_placeholder_screen.dart';
import 'package:resonia/infrastructure/audio/asset_chord_recording_catalog.dart';
import 'package:resonia/features/common/ui/resonia_ui.dart';
import 'package:resonia/app/theme/resonia_theme.dart';

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
  testWidgets(
    'closed lesson shell explains flow without progress or playback',
    (tester) async {
      final repository = FakeCatalogRepository();
      await tester.pumpWidget(
        MaterialApp(home: ChordPlaceholderScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LessonScaffold), findsOneWidget);
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(find.text('Kapalı'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chord_help')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Canlı akor tanıma yapılmıyor'),
        findsOneWidget,
      );
      for (final count in [2, 3, 4]) {
        for (final action in ['listen', 'repeat']) {
          final button = tester.widget<ChunkyButton>(
            find.byKey(Key('chord_${action}_$count')),
          );
          expect(button.onPressed, isNull);
          expect(button.tone, ChunkyTone.neutral);
        }
      }
      expect(repository.calls, 1);
    },
  );

  testWidgets('immediate retry failures remain visible without auto retries', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: ChordPlaceholderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chord_error')), findsOneWidget);
    expect(find.text('private diagnostic'), findsNothing);
    expect(repository.calls, 2);
    await tester.pump(const Duration(seconds: 5));
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending retry hides old error and late failure after disposal', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: ChordPlaceholderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    repository.fail = false;
    repository.gate = Completer();
    await tester.tap(find.text('Yeniden dene'));
    await tester.pump();
    expect(find.byKey(const Key('chord_loading')), findsOneWidget);
    expect(find.byKey(const Key('chord_error')), findsNothing);
    expect(find.text('Yeniden dene'), findsNothing);
    expect(find.byKey(const Key('chord_listen_2')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repository.gate!.completeError(StateError('private late failure'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dark reduced-motion placeholder fits large text and tap guidelines',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = FakeCatalogRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ResoniaTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: ChordPlaceholderScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('chord_help')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chord_help')));
      await tester.pumpAndSettle();
      for (final count in [2, 3, 4]) {
        await tester.ensureVisible(find.byKey(Key('chord_repeat_$count')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      expect(find.byType(LessonProgressBar), findsNothing);
    },
  );

  testWidgets('lesson close returns without reloading or starting an attempt', (
    tester,
  ) async {
    final repository = FakeCatalogRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChordPlaceholderScreen(repository: repository),
                ),
              ),
              child: const Text('Örnekleri aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Örnekleri aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('lesson_close')));
    await tester.pumpAndSettle();
    expect(find.text('Örnekleri aç'), findsOneWidget);
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });

  test('bundled manifest loads only pending catalog, no audio files', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await AssetChordRecordingCatalog().load();
    expect(catalog.slots.map((s) => s.voiceCount), [2, 3, 4]);
  });
  testWidgets(
    'home entry opens real bundled placeholders with disabled actions',
    (tester) async {
      await tester.pumpWidget(
        ResoniaApp(
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
      await tester.tap(find.byKey(const Key('tab_practice')));
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
              .widget<ChunkyButton>(find.byKey(Key('chord_listen_$count')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<ChunkyButton>(find.byKey(Key('chord_repeat_$count')))
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
