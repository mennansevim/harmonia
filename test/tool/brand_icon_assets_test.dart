import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _iconDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

Future<({int width, int height, List<int> rgba})> _decode(String name) async {
  final bytes = await File('$_iconDirectory/$name').readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = (
    width: image.width,
    height: image.height,
    rgba: data!.buffer.asUint8List(),
  );
  image.dispose();
  codec.dispose();
  return result;
}

void main() {
  test('iOS catalog declares default, dark and tinted single-size icons', () {
    final catalog =
        jsonDecode(File('$_iconDirectory/Contents.json').readAsStringSync())
            as Map<String, Object?>;
    final images = (catalog['images'] as List<Object?>)
        .cast<Map<String, Object?>>();

    expect(images, hasLength(3));
    expect(images.map((image) => image['filename']), [
      'Icon-App-1024x1024@1x.png',
      'Icon-App-1024x1024-dark.png',
      'Icon-App-1024x1024-tinted.png',
    ]);
    for (final image in images) {
      expect(image['idiom'], 'universal');
      expect(image['platform'], 'ios');
      expect(image['size'], '1024x1024');
      expect(File('$_iconDirectory/${image['filename']}').existsSync(), isTrue);
    }
    expect(
      ((images[1]['appearances'] as List<Object?>).single
          as Map<String, Object?>)['value'],
      'dark',
    );
    expect(
      ((images[2]['appearances'] as List<Object?>).single
          as Map<String, Object?>)['value'],
      'tinted',
    );
  });

  test(
    'appearance artwork is 1024 square with transparent background',
    () async {
      for (final name in [
        'Icon-App-1024x1024-dark.png',
        'Icon-App-1024x1024-tinted.png',
      ]) {
        final image = await _decode(name);
        expect((image.width, image.height), (1024, 1024));
        expect(image.rgba[3], 0, reason: '$name corner must stay transparent');
        expect(
          image.rgba.any((channel) => channel != 0),
          isTrue,
          reason: '$name must contain rendered artwork',
        );
      }
    },
  );

  test('default store icon is opaque and 1024 square', () async {
    final image = await _decode('Icon-App-1024x1024@1x.png');
    expect((image.width, image.height), (1024, 1024));
    var opaque = true;
    for (var i = 3; i < image.rgba.length; i += 4) {
      if (image.rgba[i] != 255) {
        opaque = false;
        break;
      }
    }
    expect(opaque, isTrue);
  });

  test('tinted icon contains grayscale artwork only', () async {
    final image = await _decode('Icon-App-1024x1024-tinted.png');
    var grayscale = true;
    for (var i = 0; i < image.rgba.length; i += 4) {
      if (image.rgba[i + 3] == 0) continue;
      if (image.rgba[i] != image.rgba[i + 1] ||
          image.rgba[i + 1] != image.rgba[i + 2]) {
        grayscale = false;
        break;
      }
    }
    expect(grayscale, isTrue);
  });
}
