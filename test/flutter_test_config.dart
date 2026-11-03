import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/lang.dart';

/// Tests run on a Turkish device unless they say otherwise; English tests set
/// their own locale. The wording language is reset so one test's locale does
/// not leak into screens another test builds without the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = const [
      Locale('tr', 'TR'),
    ];
    Lang.en = false;
  });
  await testMain();
}
