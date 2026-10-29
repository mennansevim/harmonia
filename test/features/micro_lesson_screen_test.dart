import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/content/draft_micro_lessons.dart';
import 'package:harmonia/domain/learning/micro_lesson.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/learning/micro_lesson_screen.dart';
import 'package:harmonia/features/skill_map/skill_map_screen.dart';
import 'package:harmonia/features/common/ui/harmonia_ui.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(find.byKey(Key(key)), 200);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'draft lesson shell preserves text with no completion or progress',
    (tester) async {
      final lesson = draftMicroLessons.lessons.first;
      await tester.pumpWidget(
        MaterialApp(home: MicroLessonScreen(lesson: lesson)),
      );
      expect(find.byType(LessonScaffold), findsOneWidget);
      expect(find.byType(LessonProgressBar), findsNothing);
      expect(find.text(lesson.objective), findsOneWidget);
      for (final step in lesson.steps) {
        expect(find.text(step.instruction), findsOneWidget);
        expect(
          find.byKey(Key('lesson_phase_${step.phase.name}')),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Tamamladım'), findsNothing);
      expect(find.textContaining('öğrenme kanıtı değildir'), findsOneWidget);
    },
  );

  testWidgets('metadata is disclosed explicitly without unlocking practice', (
    tester,
  ) async {
    final lesson = draftMicroLessons.lessons.first;
    await tester.pumpWidget(
      MaterialApp(home: MicroLessonScreen(lesson: lesson)),
    );
    expect(find.text('İçerik sürümü: ${lesson.contentVersion}'), findsNothing);
    await _tap(tester, 'lesson_content_info');
    expect(
      find.text('İçerik sürümü: ${lesson.contentVersion}'),
      findsOneWidget,
    );
    expect(find.textContaining('tamamlanmış ders değildir'), findsOneWidget);
    for (final phase in LessonPhase.values.skip(1)) {
      final button = tester.widget<ChunkyButton>(
        find.byKey(Key('lesson_practice_${phase.name}')),
      );
      expect(button.onPressed, isNull);
      expect(button.tone, ChunkyTone.neutral);
    }
    expect(find.byType(LessonProgressBar), findsNothing);
  });

  testWidgets('reader return action keeps map skill unmeasured', (
    tester,
  ) async {
    final history = InMemoryResultHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMapScreen(goal: PracticeGoal.foundations, history: history),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'open_lesson_lesson-high-low');
    await _tap(tester, 'lesson_reader_back');
    expect(find.byType(MicroLessonScreen), findsNothing);
    expect(find.byType(SkillMapScreen), findsOneWidget);
    expect(await history.load(), isEmpty);
    final chip = tester.widget<Chip>(
      find.byKey(const Key('skill_state_pitch-high-low')),
    );
    expect((chip.label as Text).data, 'Henüz ölçülmedi');
  });

  testWidgets(
    'dark reduced-motion reader fits large text and expanded metadata',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: HarmoniaTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: MicroLessonScreen(lesson: draftMicroLessons.lessons.last),
        ),
      );
      await _tap(tester, 'lesson_content_info');
      for (final phase in LessonPhase.values) {
        await tester.scrollUntilVisible(
          find.byKey(Key('lesson_phase_${phase.name}')),
          200,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('lesson_reader_back')),
        200,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('lesson_reader_back')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(LessonProgressBar), findsNothing);
    },
  );

  testWidgets(
    'reader labels draft, dimension and no mastery; actions disabled',
    (tester) async {
      final lesson = draftMicroLessons.lessons.first;
      await tester.pumpWidget(
        MaterialApp(home: MicroLessonScreen(lesson: lesson)),
      );
      expect(find.byKey(const Key('lesson_review_notice')), findsOneWidget);
      expect(find.text('Hedef boyutu: Algı'), findsOneWidget);
      expect(find.byKey(const Key('lesson_no_mastery_notice')), findsOneWidget);
      for (final phase in LessonPhase.values.skip(1)) {
        final key = Key('lesson_practice_${phase.name}');
        await tester.scrollUntilVisible(find.byKey(key), 200);
        final button = tester.widget<ChunkyButton>(find.byKey(key));
        expect(button.onPressed, isNull);
      }
      expect(find.textContaining('Tamamladım'), findsNothing);
    },
  );
  testWidgets(
    'skill map reading does not write history or change skill status',
    (tester) async {
      final history = InMemoryResultHistory();
      await tester.pumpWidget(
        MaterialApp(
          home: SkillMapScreen(
            goal: PracticeGoal.conservatory,
            history: history,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'open_lesson_lesson-high-low');
      expect(find.byType(MicroLessonScreen), findsOneWidget);
      expect(await history.load(), isEmpty);
      await tester.tap(find.byKey(const Key('lesson_close')));
      await tester.pumpAndSettle();
      final chip = tester.widget<Chip>(
        find.byKey(const Key('skill_state_pitch-high-low')),
      );
      expect((chip.label as Text).data, 'Henüz ölçülmedi');
      expect(await history.load(), isEmpty);
    },
  );
  testWidgets('pulse lesson accessible via map with production dimension', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SkillMapScreen(goal: PracticeGoal.choir)),
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'open_lesson_lesson-pulse');
    expect(find.text('Hedef boyutu: Üretim'), findsOneWidget);
  });
  testWidgets('custom graph gets no unrelated default lessons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkillMapScreen(
          goal: PracticeGoal.foundations,
          graph: SkillGraph([]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Metin taslağını oku'), findsNothing);
  });
  testWidgets('reader fits 320px and 1.8x through all phases', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: MicroLessonScreen(lesson: draftMicroLessons.lessons.last),
      ),
    );
    for (final phase in LessonPhase.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('lesson_phase_${phase.name}')),
        200,
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('reader meets tap labels and contrast guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MicroLessonScreen(lesson: draftMicroLessons.lessons.first),
      ),
    );
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
