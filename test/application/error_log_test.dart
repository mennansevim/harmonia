import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/app/app_channel.dart';
import 'package:resonia/app/error_handling.dart';
import 'package:resonia/application/app_shell_controller.dart';
import 'package:resonia/application/error_log.dart';
import 'package:resonia/application/profile_repository.dart';
import 'package:resonia/features/settings/settings_screen.dart';

void main() {
  final at = DateTime.utc(2026, 10, 13, 21, 5, 33);

  test('records type and app frame only; message text never kept', () {
    final log = LocalErrorLog(clock: () => at);
    final stack = StackTrace.fromString(
      '#0 foo (package:flutter/src/x.dart:1:1)\n'
      '#1 bar (package:resonia/features/home/home_screen.dart:42:7)\n',
    );
    log.record(
      StateError('user typed: my secret'),
      stack,
      ErrorOrigin.framework,
    );
    final r = log.records.single;
    expect(r.type, 'StateError');
    expect(r.location, 'lib/features/home/home_screen.dart:42');
    expect(r.at, DateTime.utc(2026, 10, 13, 21, 5));
    final report = log.report(channel: 'beta');
    expect(report, isNot(contains('secret')));
    final doc = jsonDecode(report) as Map<String, Object?>;
    expect(doc['format'], 'resonia-error-report');
    expect(doc['channel'], 'beta');
  });

  test('no app frame → null location; bounded with dropped count', () {
    final log = LocalErrorLog(capacity: 2, clock: () => at);
    for (var i = 0; i < 3; i++) {
      log.record(Exception('x'), null, ErrorOrigin.platform);
    }
    expect(log.records, hasLength(2));
    expect(log.dropped, 1);
    expect(log.records.first.location, isNull);
    expect(() => log.records.clear(), throwsUnsupportedError);
  });

  testWidgets('settings shows the section only after an error and copies', (
    tester,
  ) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final log = LocalErrorLog(clock: () => at);
    final shell = AppShellController(InMemoryProfileRepository());
    addTearDown(shell.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: shell,
          channel: AppChannel.beta,
          errorLog: log,
        ),
      ),
    );
    expect(find.byKey(const Key('error_summary')), findsNothing);
    log.record(ArgumentError('x'), null, ErrorOrigin.framework);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 beklenmeyen hata'), findsOneWidget);
    await tester.tap(find.byKey(const Key('copy_error_report')));
    await tester.pumpAndSettle();
    expect(copied, contains('"type": "ArgumentError"'));
  });

  test('global handlers route framework and platform errors', () {
    final savedFlutter = FlutterError.onError;
    final savedPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
    });
    final log = LocalErrorLog(clock: () => at);
    installGlobalErrorHandlers(log);
    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('a'), stack: StackTrace.empty),
    );
    expect(
      PlatformDispatcher.instance.onError!(
        UnsupportedError('b'),
        StackTrace.empty,
      ),
      isTrue,
    );
    expect(
      [for (final r in log.records) r.origin],
      [ErrorOrigin.framework, ErrorOrigin.platform],
    );
  });
}
