// Loads the app's real fonts for screenshot tours; widget tests otherwise
// draw every glyph as a box.
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTourFonts() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Inter', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      'assets/fonts/Inter-$w.ttf',
  ]);
  await load('Lora', [
    'assets/fonts/Lora-Regular.ttf',
    'assets/fonts/Lora-SemiBold.ttf',
  ]);
  final packages = File('.dart_tool/package_config.json').readAsStringSync();
  final lucide = RegExp(
    r'"rootUri":\s*"(file:[^"]*lucide_icons_flutter[^"]*)"',
  ).firstMatch(packages)!;
  await load('packages/lucide_icons_flutter/Lucide300', [
    '${Uri.parse(lucide[1]!).toFilePath()}/assets/build_font/'
        'LucideVariable-w300.ttf',
  ]);
  await load('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}
