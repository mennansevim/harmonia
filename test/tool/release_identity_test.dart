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
    expect(
      manifest,
      contains('xmlns:tools="http://schemas.android.com/tools"'),
    );
    for (final permission in [
      'READ_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VIDEO',
      'READ_MEDIA_AUDIO',
      'ACCESS_NETWORK_STATE',
    ]) {
      expect(
        RegExp(
          'android:name="android.permission.$permission"\\s*'
          'tools:node="remove"',
        ).hasMatch(manifest),
        isTrue,
        reason: permission,
      );
    }
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

  test('iOS launch screen uses the Vocalart brand instead of Flutter art', () {
    final launch = read('ios/Runner/Base.lproj/LaunchScreen.storyboard');
    final background = read(
      'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
    );
    final brand = read(
      'ios/Runner/Assets.xcassets/LaunchBrand.colorset/Contents.json',
    );
    final accent = read(
      'ios/Runner/Assets.xcassets/LaunchAccent.colorset/Contents.json',
    );

    expect(launch, contains('text="Vocalart"'));
    expect(launch, isNot(contains('image="LaunchImage"')));
    expect(launch, contains('name="LaunchBackground"'));
    expect(launch, contains('name="LaunchBrand"'));
    expect(launch, contains('name="LaunchAccent"'));
    expect(background, contains('"red" : "0xF8"'));
    expect(background, contains('"green" : "0xF5"'));
    expect(background, contains('"blue" : "0xEF"'));
    expect(brand, contains('"red" : "0x43"'));
    expect(brand, contains('"red" : "0xF8"'));
    expect(accent, contains('"red" : "0xD9"'));
    expect(RegExp('"appearance" : "luminosity"').allMatches(brand).length, 1);
  });

  test('Android launch surfaces use the explicit Vocalart brand icon', () {
    final colors = read('android/app/src/main/res/values/colors.xml');
    final legacy = read(
      'android/app/src/main/res/drawable/launch_background.xml',
    );
    final legacyV21 = read(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    );

    expect(colors, contains('<color name="launch_background">#F8F5EF</color>'));
    for (final launch in [legacy, legacyV21]) {
      expect(launch, contains('@color/launch_background'));
      expect(launch, contains('@mipmap/ic_launcher_foreground'));
      expect(launch, contains('android:gravity="center"'));
    }

    for (final path in [
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      final styles = read(path);
      expect(
        styles,
        contains(
          '<item name="android:windowSplashScreenAnimatedIcon">'
          '@mipmap/ic_launcher_foreground</item>',
        ),
        reason: path,
      );
      expect(
        styles,
        contains(
          '<item name="android:windowSplashScreenIconBackgroundColor">'
          '@color/ic_launcher_background</item>',
        ),
        reason: path,
      );
    }
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
