import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const appId = 'com.mennansevim.vocalart';
  const displayName = 'Vocalart';

  String read(String path) => File(path).readAsStringSync();

  test('Android release identity, launcher label and Kotlin package agree', () {
    final gradle = read('android/app/build.gradle.kts');
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final activity = File(
      'android/app/src/main/kotlin/com/mennansevim/vocalart/MainActivity.kt',
    );

    expect(
      RegExp('namespace = "${RegExp.escape(appId)}"').allMatches(gradle).length,
      1,
    );
    expect(
      RegExp(
        'applicationId = "${RegExp.escape(appId)}"',
      ).allMatches(gradle).length,
      1,
    );
    expect(manifest, contains('android:label="$displayName"'));
    expect(activity.existsSync(), isTrue);
    expect(activity.readAsStringSync(), contains('package $appId'));
    expect(
      Directory('android/app/src/main/kotlin')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('MainActivity.kt'))
          .map((file) => file.path),
      [activity.path],
    );
    expect(gradle, contains('allowDebugReleaseSigning'));
    expect(gradle, contains('releaseTaskRequested'));
    expect(gradle, contains('throw GradleException'));
    expect(
      gradle,
      contains(
        'releaseKeyFields.all { !keystoreProperties.getProperty(it).isNullOrBlank() }',
      ),
    );
  });

  test('iOS release identity, test identity and display name agree', () {
    final project = read('ios/Runner.xcodeproj/project.pbxproj');
    final info = read('ios/Runner/Info.plist');

    expect(
      RegExp(
        'PRODUCT_BUNDLE_IDENTIFIER = ${RegExp.escape(appId)};',
      ).allMatches(project).length,
      3,
    );
    expect(
      RegExp(
        'PRODUCT_BUNDLE_IDENTIFIER = ${RegExp.escape(appId)}'
        r'\.RunnerTests;',
      ).allMatches(project).length,
      3,
    );
    expect(
      RegExp(
        '<key>CFBundleDisplayName</key>\\s*<string>$displayName</string>',
      ).hasMatch(info),
      isTrue,
    );
    expect(
      RegExp(
        '<key>CFBundleName</key>\\s*<string>$displayName</string>',
      ).hasMatch(info),
      isTrue,
    );
    // No networking or custom crypto: answers App Store Connect's export
    // compliance question so every upload is not held for it.
    expect(
      RegExp(
        r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>',
      ).hasMatch(info),
      isTrue,
    );
  });

  test('release platform configuration no longer contains the retired id', () {
    for (final path in [
      'android/app/build.gradle.kts',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner.xcodeproj/project.pbxproj',
      'ios/Runner/Info.plist',
    ]) {
      expect(read(path), isNot(contains('com.resonia.resonia')), reason: path);
    }
  });
}
