import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/trainer/ui/applause_burst.dart';

void main() {
  late List<String> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host(
    int shot, {
    bool reduced = false,
    bool haptics = true,
    bool scopeHaptics = true,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: ResoniaHapticsScope(
      enabled: ValueNotifier(scopeHaptics),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ApplauseBurst(
            shot: shot,
            haptics: haptics,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    ),
  );

  final badge = find.byKey(const Key('applause_badge'));
  final particles = find.byKey(const Key('applause_particles'));

  testWidgets('stays hidden until a celebration is counted', (tester) async {
    await tester.pumpWidget(host(0));
    expect(badge, findsNothing);
    expect(particles, findsNothing);
    await tester.pumpWidget(host(0));
    expect(badge, findsNothing);
  });

  testWidgets('plays once per new shot, then clears itself', (tester) async {
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(badge, findsOneWidget);
    expect(particles, findsOneWidget);

    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    expect(particles, findsNothing);
    expect(haptics, [
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.lightImpact',
    ]);

    // Same value on rebuild: no replay.
    await tester.pumpWidget(host(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(badge, findsNothing);
  });

  testWidgets('badge springs past full size before settling', (tester) async {
    await tester.pumpWidget(host(0));
    await tester.pumpWidget(host(1));
    var peak = 0.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final t = tester.widget<Transform>(
        find.ancestor(of: badge, matching: find.byType(Transform)).first,
      );
      peak = peak < t.transform.getMaxScaleOnAxis()
          ? t.transform.getMaxScaleOnAxis()
          : peak;
    }
    expect(peak, greaterThan(1.0));
    await tester.pumpAndSettle();
  });

  testWidgets('haptics follow the widget flag and the app setting', (
    tester,
  ) async {
    await tester.pumpWidget(host(0, haptics: false));
    await tester.pumpWidget(host(1, haptics: false));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);

    await tester.pumpWidget(host(1, scopeHaptics: false));
    await tester.pumpWidget(host(2, scopeHaptics: false));
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
  });

  testWidgets('reduced motion: badge only, no spring, one tap', (tester) async {
    await tester.pumpWidget(host(0, reduced: true));
    await tester.pumpWidget(host(1, reduced: true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(badge, findsOneWidget);
    expect(particles, findsNothing);
    final t = tester.widget<Transform>(
      find.ancestor(of: badge, matching: find.byType(Transform)).first,
    );
    expect(t.transform.getMaxScaleOnAxis(), 1.0);
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
  });

  test('confetti layout is repeatable and falls back down', () {
    final a = ApplausePiece.scatter(7), b = ApplausePiece.scatter(7);
    expect(a.length, ApplausePiece.perWave * ApplauseBurst.claps.length);
    expect([for (final p in a) p.velocity], [for (final p in b) p.velocity]);
    for (final p in a) {
      expect(p.velocity.dy, lessThan(0), reason: 'thrown upward');
      expect(p.at(3).dy, greaterThan(p.at(0.3).dy), reason: 'gravity');
    }
    expect(ApplausePiece.opacity(0), 1);
    expect(ApplausePiece.opacity(ApplausePiece.life), 0);
    expect(ApplausePiece.opacity(-0.1), 0);
  });
}
