import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/skill_map/skill_map_screen.dart';
import 'package:harmonia/features/learning/micro_lesson_screen.dart';

class _History extends InMemoryResultHistory {
  bool fails = true;
  int loads = 0;
  Completer<List<ResultHistoryEntry>>? pending;
  @override
  Future<List<ResultHistoryEntry>> load() async {
    loads++;
    if (pending != null) return pending!.future;
    if (fails) {
      throw const HistoryStorageException(HistoryStorageFailure.unavailable);
    }
    return super.load();
  }
}

Future<void> _open(WidgetTester tester, _History history) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SkillMapScreen(goal: PracticeGoal.foundations, history: history),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unavailable history is not shown as unattempted mastery', (
    tester,
  ) async {
    final history = _History();
    await _open(tester, history);
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_state_pitch-high-low')),
      150,
    );
    final chip = tester.widget<Chip>(
      find.byKey(const Key('skill_state_pitch-high-low')),
    );
    expect((chip.label as Text).data, 'Durum alınamadı');
    expect(find.byKey(const Key('skill_report')), findsNothing);
    expect(find.byKey(const Key('report_focus_action')), findsNothing);
    expect(history.loads, 1);
  });
  testWidgets('explicit retry restores report, empty history not an error', (
    tester,
  ) async {
    final history = _History();
    await _open(tester, history);
    history.fails = false;
    await tester.scrollUntilVisible(find.text('Yeniden dene'), 100);
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    expect(history.loads, 2);
    expect(find.byKey(const Key('skill_report')), findsOneWidget);
    expect(find.byKey(const Key('skill_map_history_error')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('skill_state_pitch-high-low')),
      150,
    );
    final chip = tester.widget<Chip>(
      find.byKey(const Key('skill_state_pitch-high-low')),
    );
    expect((chip.label as Text).data, 'Henüz ölçülmedi');
    expect(await history.load(), isEmpty);
  });
  testWidgets('text lessons remain accessible without inventing progress', (
    tester,
  ) async {
    final history = _History();
    await _open(tester, history);
    final lesson = find.byKey(const Key('open_lesson_lesson-high-low'));
    await tester.scrollUntilVisible(lesson, 150);
    await tester.tap(lesson);
    await tester.pumpAndSettle();
    expect(find.byType(MicroLessonScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(history.loads, 1);
    expect(find.byKey(const Key('skill_report')), findsNothing);
  });
  testWidgets(
    'pending retry hides stale states, disposal rejects late UI work',
    (tester) async {
      final history = _History();
      await _open(tester, history);
      history.pending = Completer();
      await tester.tap(find.text('Yeniden dene'));
      await tester.pump();
      expect(find.byKey(const Key('skill_map_loading')), findsOneWidget);
      expect(find.byKey(const Key('skill_report')), findsNothing);
      expect(find.text('Durum alınamadı'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      history.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(history.loads, 2);
    },
  );
}
