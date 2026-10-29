import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/application/microphone_permission_recovery.dart';
import 'package:harmonia/features/common/ui/microphone_permission_recovery_card.dart';

final class _Recovery implements MicrophonePermissionRecovery {
  _Recovery({this.result = true, this.failure, this.gate});

  final bool result;
  final Object? failure;
  final Completer<bool>? gate;
  int calls = 0;

  @override
  Future<bool> openAppSettings() async {
    calls++;
    if (failure case final error?) throw error;
    return gate == null ? result : gate!.future;
  }
}

void main() {
  testWidgets('opens settings only after explicit tap and explains return', (
    tester,
  ) async {
    final recovery = _Recovery();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophonePermissionRecoveryCard(recovery: recovery),
        ),
      ),
    );

    expect(recovery.calls, 0);
    await tester.tap(find.byKey(const Key('microphone_open_settings')));
    await tester.pumpAndSettle();

    expect(recovery.calls, 1);
    expect(
      find.textContaining('Harmonia’ya dönüp yeniden dene'),
      findsOneWidget,
    );
  });

  testWidgets('prevents duplicate settings launches while one is pending', (
    tester,
  ) async {
    final gate = Completer<bool>();
    final recovery = _Recovery(gate: gate);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophonePermissionRecoveryCard(recovery: recovery),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('microphone_open_settings')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('microphone_open_settings')));
    expect(recovery.calls, 1);
    expect(find.text('Ayarlar açılıyor…'), findsOneWidget);

    gate.complete(true);
    await tester.pumpAndSettle();
    expect(recovery.calls, 1);
  });

  testWidgets('reports launch failure without claiming settings opened', (
    tester,
  ) async {
    final recovery = _Recovery(result: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophonePermissionRecoveryCard(recovery: recovery),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('microphone_open_settings')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Telefon ayarları açılamadı'), findsOneWidget);
    expect(find.textContaining('Harmonia’ya dönüp'), findsNothing);
  });

  testWidgets('turns platform exceptions into the same recoverable message', (
    tester,
  ) async {
    final recovery = _Recovery(failure: StateError('channel failed'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrophonePermissionRecoveryCard(recovery: recovery),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('microphone_open_settings')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Telefon ayarları açılamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
