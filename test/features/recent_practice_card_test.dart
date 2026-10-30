import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/features/home/home_data.dart';
import 'package:resonia/features/home/recent_practice_card.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('activity is readable, static, non-scoring in dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ResoniaTheme.dark() : ResoniaTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecentPracticeCard(
                days: [
                  for (var i = 0; i < 7; i++)
                    PracticeDay(
                      date: DateTime(2026, 10, 14 + i),
                      practiced: i == 6,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Son 7 günde 1 çalışma günü'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(7));
      expect(find.text('20/10 · Çalışıldı'), findsOneWidget);
      expect(find.textContaining('beceri puanı değildir'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 10));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }
}
