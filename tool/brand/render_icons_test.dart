// Renders the Resonia app icon set from the photoreal master render so every
// slot shows the same glossy yellow note with grey tape across the stem
// ("hush, then sing"). Not part of the test suite; run on demand:
//   flutter test tool/brand/render_icons_test.dart
//
// Source: tool/brand/source/logo_master.webp (1254 px, cream wall). The
// chosen composition is the "krem orta" crop: note ~83 % of the icon height.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_key.dart';

/// Square crop of the master centred on the note's bounding box.
const _crop = Rect.fromLTWH(645 - 530, 612 - 530, 1060, 1060);

/// Share of the Android adaptive canvas the crop fills, so the note stays
/// inside the 66 dp safe circle of the 108 dp layer.
const _adaptiveFill = .72;

Future<ui.Image> _image(int px, void Function(Canvas, double) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), px.toDouble());
  return recorder.endRecording().toImage(px, px);
}

Future<Uint8List> _rgba(ui.Image img) async => (await img.toByteData(
  format: ui.ImageByteFormat.rawStraightRgba,
))!.buffer.asUint8List();

Future<List<int>> _png(ui.Image img) async => (await img.toByteData(
  format: ui.ImageByteFormat.png,
))!.buffer.asUint8List();

/// PNG without an alpha channel (colour type 2): App Store Connect rejects
/// a marketing icon that carries alpha, even when every pixel is opaque.
List<int> _rgbPng(Uint8List rgba, int w, int h) {
  final table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    }
    return c;
  });
  int crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = table[(c ^ b) & 0xFF] ^ (c >>> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  List<int> u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...u32(data.length), ...body, ...u32(crc(body))];
  }

  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      raw
        ..addByte(rgba[i])
        ..addByte(rgba[i + 1])
        ..addByte(rgba[i + 2]);
    }
  }
  return [
    137, 80, 78, 71, 13, 10, 26, 10, //
    ...chunk('IHDR', [...u32(w), ...u32(h), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', ZLibCodec(level: 9).encode(raw.takeBytes())),
    ...chunk('IEND', const []),
  ];
}

/// Separable max filter (dilation) of a 0-1 mask.
Float32List _dilate(Float32List m, int w, int h, int r) {
  var cur = m;
  for (final horizontal in [true, false]) {
    final next = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var v = 0.0;
        for (var d = -r; d <= r; d++) {
          final xx = horizontal ? x + d : x, yy = horizontal ? y : y + d;
          if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
          v = math.max(v, cur[yy * w + xx]);
        }
        next[y * w + x] = v;
      }
    }
    cur = next;
  }
  return cur;
}

void main() {
  test('render icons', () async {
    final root = Directory.current.path;
    final master = await decodeImage(
      File('$root/tool/brand/source/logo_master.webp').readAsBytesSync(),
    );
    final w = master.width, h = master.height;
    final src = await _rgba(master);
    final key = keyMaster(src, w, h);
    final object = await imageFromPixels(key.rgba, w, h);

    final shadowPx = Uint8List(w * h * 4);
    for (var p = 0; p < w * h; p++) {
      shadowPx[p * 4 + 3] = (key.shadow[p] * 2.2 * 255).clamp(0, 255).round();
    }
    final shadow = await imageFromPixels(shadowPx, w, h);

    // Single-ink silhouette with a gap around the tape (Android themed).
    final ring = _dilate(key.tape, w, h, 12);
    final monoPx = Uint8List(w * h * 4);
    for (var p = 0; p < w * h; p++) {
      final a = math.max(key.note[p] * (1 - ring[p]), key.tape[p]);
      monoPx
        ..[p * 4] = 255
        ..[p * 4 + 1] = 255
        ..[p * 4 + 2] = 255
        ..[p * 4 + 3] = (a * 255).round();
    }
    final mono = await imageFromPixels(monoPx, w, h);

    final hq = Paint()..filterQuality = FilterQuality.high;
    void full(Canvas c, double s, ui.Image img) =>
        c.drawImageRect(img, _crop, Rect.fromLTWH(0, 0, s, s), hq);
    void inset(Canvas c, double s, ui.Image img) => c.drawImageRect(
      img,
      _crop,
      Rect.fromCenter(
        center: Offset(s / 2, s / 2),
        width: s * _adaptiveFill,
        height: s * _adaptiveFill,
      ),
      hq,
    );

    // iOS: opaque full-bleed square without alpha (system applies mask).
    final ios = '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final store = await _image(1024, (c, s) => full(c, s, master));
    await File(
      '$ios/Icon-App-1024x1024@1x.png',
    ).writeAsBytes(_rgbPng(await _rgba(store), 1024, 1024));
    // Dark: the system supplies the dark ground, so only the object.
    final dark = await _image(1024, (c, s) => full(c, s, object));
    await File(
      '$ios/Icon-App-1024x1024-dark.png',
    ).writeAsBytes(await _png(dark));
    // Tinted: grayscale luminance of the object; the system applies tint.
    final tintPx = await _rgba(dark);
    for (var i = 0; i < tintPx.length; i += 4) {
      final l = (.299 * tintPx[i] + .587 * tintPx[i + 1] + .114 * tintPx[i + 2])
          .round();
      tintPx
        ..[i] = l
        ..[i + 1] = l
        ..[i + 2] = l;
    }
    final tinted = await imageFromPixels(tintPx, 1024, 1024);
    await File(
      '$ios/Icon-App-1024x1024-tinted.png',
    ).writeAsBytes(await _png(tinted));

    // Android adaptive background = the master's cream wall.
    final wall = wallColor(src, w, h);
    final hex = wall
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    final colors = File('$root/android/app/src/main/res/values/colors.xml');
    colors.writeAsStringSync(
      colors.readAsStringSync().replaceFirst(
        RegExp(r'<color name="ic_launcher_background">#[0-9A-Fa-f]{6}</color>'),
        '<color name="ic_launcher_background">#$hex</color>',
      ),
    );

    final res = '$root/android/app/src/main/res';
    const legacy = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    for (final e in legacy.entries) {
      final img = await _image(e.value, (c, s) {
        c.clipRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, s, s),
            Radius.circular(s * .22),
          ),
        );
        full(c, s, master);
      });
      await File('$res/${e.key}/ic_launcher.png').writeAsBytes(await _png(img));
    }
    const adaptive = {
      'mipmap-mdpi': 108,
      'mipmap-hdpi': 162,
      'mipmap-xhdpi': 216,
      'mipmap-xxhdpi': 324,
      'mipmap-xxxhdpi': 432,
    };
    for (final e in adaptive.entries) {
      final fg = await _image(e.value, (c, s) {
        inset(c, s, shadow);
        inset(c, s, object);
      });
      await File(
        '$res/${e.key}/ic_launcher_foreground.png',
      ).writeAsBytes(await _png(fg));
      final mn = await _image(e.value, (c, s) => inset(c, s, mono));
      await File(
        '$res/${e.key}/ic_launcher_monochrome.png',
      ).writeAsBytes(await _png(mn));
    }

    // Preview: Android circle mask on the cream background.
    final preview = Directory('$root/build/icon_preview')
      ..createSync(recursive: true);
    final circle = await _image(432, (c, s) {
      c.clipPath(
        Path()..addOval(
          Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s / 3),
        ),
      );
      c.drawColor(
        Color.fromARGB(255, wall[0], wall[1], wall[2]),
        BlendMode.src,
      );
      inset(c, s, shadow);
      inset(c, s, object);
    });
    await File(
      '${preview.path}/android_circle.png',
    ).writeAsBytes(await _png(circle));
  });
}
