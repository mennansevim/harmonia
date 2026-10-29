import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/app_services.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/home/home_screen.dart';
import 'package:harmonia/infrastructure/audio/orphan_audio_cleaner.dart';

void main() {
  testWidgets('new learner can explicitly open starting check from Today', (
    tester,
  ) async {
    final cleanup = ValueNotifier<OrphanCleanupReport?>(null);
    addTearDown(cleanup.dispose);
    await tester.pumpWidget(
      AppServices(
        history: InMemoryResultHistory(),
        cleanup: cleanup,
        child: MaterialApp(
          home: HomeScreen(
            profile: LearnerProfile(
              goal: PracticeGoal.foundations,
              createdAt: DateTime(2026, 10, 22),
            ),
            onOpenSettings: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('starting_check_open')),
      300,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('İsteğe bağlı'), findsOneWidget);
    await tester.tap(find.byKey(const Key('starting_check_open')));
    await tester.pumpAndSettle();

    expect(find.text('Başlangıç kontrolü'), findsOneWidget);
    expect(
      find.textContaining('sınava hazır olma puanı değildir'),
      findsOneWidget,
    );
  });
}
