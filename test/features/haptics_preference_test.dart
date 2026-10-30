import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/theme/resonia_theme.dart';
import 'package:resonia/features/common/ui/resonia_ui.dart';

void main() {
  testWidgets('shared haptic scope suppresses and restores button feedback', (
    tester,
  ) async {
    var vibrations = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') vibrations++;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final enabled = ValueNotifier<bool>(false);
    addTearDown(enabled.dispose);
    var taps = 0;
    await tester.pumpWidget(
      ResoniaHapticsScope(
        enabled: enabled,
        child: MaterialApp(
          home: Scaffold(
            body: ChunkyButton(label: 'Dene', onPressed: () => taps++),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Dene'));
    await tester.pump();
    expect(taps, 1);
    expect(vibrations, 0);

    enabled.value = true;
    await tester.pump();
    await tester.tap(find.text('Dene'));
    await tester.pump();
    expect(taps, 2);
    expect(vibrations, 1);
  });
}
