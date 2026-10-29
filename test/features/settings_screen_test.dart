import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/app_channel.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/application/app_shell_controller.dart';
import 'package:harmonia/application/error_log.dart';
import 'package:harmonia/application/profile_repository.dart';
import 'package:harmonia/application/practice_preferences.dart';
import 'package:harmonia/application/result_history.dart';
import 'package:harmonia/domain/models/learner_profile.dart';
import 'package:harmonia/features/common/ui/harmonia_ui.dart';
import 'package:harmonia/features/settings/settings_screen.dart';

class _Profiles extends InMemoryProfileRepository {
  _Profiles()
    : super(
        LearnerProfile(
          goal: PracticeGoal.conservatory,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      );
  int saves = 0, deletes = 0;
  Future<void>? deleteWait;
  bool failDelete = false;

  @override
  Future<void> save(LearnerProfile profile) async {
    saves++;
    await super.save(profile);
  }

  @override
  Future<void> delete() async {
    deletes++;
    if (deleteWait case final wait?) await wait;
    if (failDelete) {
      throw const ProfileStorageException(ProfileStorageFailure.unavailable);
    }
    await super.delete();
  }
}

void main() {
  int copies = 0;
  String? copied;
  Object? copyError;
  Completer<void>? copyGate;

  setUp(() {
    copies = 0;
    copied = null;
    copyError = null;
    copyGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copies++;
            copied = (call.arguments as Map)['text'] as String;
            if (copyGate case final gate?) await gate.future;
            if (copyError case final error?) throw error;
          }
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  Future<AppShellController> pump(
    WidgetTester tester,
    _Profiles profiles, {
    LocalErrorLog? log,
    ResultHistoryRepository? history,
    bool dark = false,
    PracticePreferencesRepository? preferences,
    ValueNotifier<bool>? hapticsEnabled,
  }) async {
    final controller = AppShellController(profiles);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? HarmoniaTheme.dark() : HarmoniaTheme.light(),
        home: SettingsScreen(
          controller: controller,
          channel: AppChannel.beta,
          errorLog: log,
          history: history,
          preferences: preferences,
          hapticsEnabled: hapticsEnabled,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> reveal(
    WidgetTester tester,
    String key, [
    double step = 160,
  ]) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), step);
    await tester.pumpAndSettle();
  }

  LocalErrorLog errors() {
    final log = LocalErrorLog();
    addTearDown(log.dispose);
    log.record(StateError('secret/path'), null, ErrorOrigin.framework);
    return log;
  }

  testWidgets('grouped settings and help do not mutate or copy', (
    tester,
  ) async {
    final profiles = _Profiles();
    await pump(tester, profiles);
    expect(find.text('Misafir • bu cihazda'), findsOneWidget);
    expect(find.byType(LessonProgressBar), findsNothing);
    await reveal(tester, 'settings_microphone_help');
    await tester.tap(find.text('İzin ve kulaklık rehberi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bluetooth kulaklıkta'), findsOneWidget);
    await reveal(tester, 'settings_privacy_help');
    await tester.tap(find.text('Ne saklanır, ne silinir?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Profili silmek çalışma geçmişini silmez'),
      findsOneWidget,
    );
    expect(profiles.saves, 0);
    expect(profiles.deletes, 0);
    expect(copies, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('haptics toggle saves before publishing app-wide state', (
    tester,
  ) async {
    final preferences = InMemoryPracticePreferences();
    final enabled = ValueNotifier<bool>(true);
    addTearDown(enabled.dispose);
    await pump(
      tester,
      _Profiles(),
      preferences: preferences,
      hapticsEnabled: enabled,
    );
    await reveal(tester, 'haptics_toggle');
    await tester.tap(find.byKey(const Key('haptics_toggle')));
    await tester.pumpAndSettle();
    expect(enabled.value, isFalse);
    expect(await preferences.loadHapticsEnabled(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'clipboard errors replace success without private details, retry works',
    (tester) async {
      await pump(tester, _Profiles(), log: errors());
      await reveal(tester, 'copy_error_report');
      await tester.tap(find.byKey(const Key('copy_error_report')));
      await tester.pumpAndSettle();
      expect(find.text('Hata raporu panoya kopyalandı.'), findsOneWidget);
      expect(copied, contains('"channel": "beta"'));
      expect(copied, isNot(contains('secret/path')));
      for (final (error, message) in [
        (
          PlatformException(code: 'private', message: 'secret/path'),
          'Panoya kopyalama doğrulanamadı',
        ),
        (
          MissingPluginException('secret/path'),
          'Bu cihazda pano kullanılamıyor',
        ),
      ]) {
        copyError = error;
        await tester.tap(find.byKey(const Key('copy_error_report')));
        await tester.pumpAndSettle();
        expect(find.textContaining(message), findsOneWidget);
        expect(find.text('Hata raporu panoya kopyalandı.'), findsNothing);
        expect(find.textContaining('secret/path'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      copyError = null;
      await tester.tap(find.byKey(const Key('copy_error_report')));
      await tester.pumpAndSettle();
      expect(copies, 4);
      expect(find.text('Hata raporu panoya kopyalandı.'), findsOneWidget);
    },
  );

  testWidgets(
    'pending copy rejects duplicate and late failure after disposal is safe',
    (tester) async {
      await pump(tester, _Profiles(), log: errors());
      await reveal(tester, 'copy_error_report');
      copyGate = Completer<void>();
      final copy = tester
          .widget<ChunkyButton>(find.byKey(const Key('copy_error_report')))
          .onPressed!;
      copy();
      copy();
      await tester.pump();
      expect(copies, 1);
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('copy_error_report')))
            .onPressed,
        isNull,
      );
      expect(find.text('Kopyalanıyor…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      copyError = PlatformException(code: 'late', message: 'secret/path');
      copyGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(copies, 1);
    },
  );

  testWidgets(
    'profile confirmation and pending delete are single-flight; failure allows retry',
    (tester) async {
      final profiles = _Profiles();
      await pump(tester, profiles);
      await reveal(tester, 'delete_profile');
      final remove = tester
          .widget<ChunkyButton>(find.byKey(const Key('delete_profile')))
          .onPressed!;
      remove();
      remove();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Çalışma geçmişin silinmez'), findsOneWidget);
      expect(profiles.deletes, 0);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(await profiles.load(), isNotNull);
      final gate = Completer<void>();
      profiles.deleteWait = gate.future;
      profiles.failDelete = true;
      await tester.tap(find.byKey(const Key('delete_profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_profile')));
      await tester.pumpAndSettle();
      remove();
      expect(profiles.deletes, 1);
      expect(
        tester
            .widget<ChunkyButton>(find.byKey(const Key('delete_profile')))
            .onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Profil silinemedi. Yeniden dene.'), findsOneWidget);
      expect(await profiles.load(), isNotNull);
      profiles.failDelete = false;
      await tester.tap(find.byKey(const Key('delete_profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_profile')));
      await tester.pumpAndSettle();
      expect(profiles.deletes, 2);
      expect(await profiles.load(), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaving confirmation cannot delete a profile later', (
    tester,
  ) async {
    final profiles = _Profiles();
    await pump(tester, profiles);
    await reveal(tester, 'delete_profile');
    await tester.tap(find.byKey(const Key('delete_profile')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(profiles.deletes, 0);
    expect(await profiles.load(), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history and local transfer routes remain reachable', (
    tester,
  ) async {
    final profiles = _Profiles();
    final history = InMemoryResultHistory();
    await pump(tester, profiles, history: history);
    await reveal(tester, 'open_history_settings');
    await tester.tap(find.byKey(const Key('open_history_settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await reveal(tester, 'open_data_transfer');
    await tester.tap(find.byKey(const Key('open_data_transfer')));
    await tester.pumpAndSettle();
    expect(find.text('Ses kaydı içermez'), findsOneWidget);
    expect(copies, 0);
    expect(await history.load(), isEmpty);
    expect(profiles.deletes, 0);
  });

  testWidgets(
    'dark reduced-motion 320px large text exposes help and safe account controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
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
      final profiles = _Profiles();
      await pump(tester, profiles, dark: true);
      await reveal(tester, 'settings_microphone_help');
      await tester.tap(find.text('İzin ve kulaklık rehberi'));
      await tester.pumpAndSettle();
      await reveal(tester, 'subscription_status');
      expect(
        find.textContaining('satın alma veya abonelik yok'),
        findsOneWidget,
      );
      await reveal(tester, 'delete_profile');
      await tester.tap(find.byKey(const Key('delete_profile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      await reveal(tester, 'about_channel');
      expect(
        find.textContaining('Sınav kazanma garantisi verilmez'),
        findsOneWidget,
      );
      expect(profiles.deletes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
