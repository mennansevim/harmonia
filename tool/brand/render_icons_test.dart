// Renders the Harmonia app icon set from code so it stays crisp and
// reproducible. Not part of the test suite; run on demand:
//   flutter test tool/brand/render_icons_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _top = Color(0xFF6B57FF);
const _bottom = Color(0xFF4630DD);
const _sun = Color(0xFFFFC531);

/// The mark: a note head and stem with two sound arcs. [glyphScale] sizes
/// the glyph inside the square (1 = full-bleed icon composition).
void paintGlyph(
  Canvas canvas,
  double s, {
  Color ink = Colors.white,
  Color? accent,
}) {
  final white = Paint()
    ..color = ink
    ..isAntiAlias = true;
  canvas.save();
  canvas.translate(s * .40, s * .665);
  canvas.rotate(-0.38);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: s * .30, height: s * .215),
    white,
  );
  canvas.restore();
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(s * .505, s * .215, s * .072, s * .47),
      Radius.circular(s * .036),
    ),
    white,
  );
  final wave = Paint()
    ..color = accent ?? ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * .052
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  for (var i = 0; i < 2; i++) {
    final r = s * (.12 + i * .1);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s * .585, s * .30), radius: r),
      -math.pi * .36,
      math.pi * .52,
      false,
      wave,
    );
  }
}

Future<List<int>> _render(int px, void Function(Canvas, double) paint) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, px.toDouble());
  final image = await recorder.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Full-bleed composition: glyph at 76 % size, optically centred.
void _iconGlyph(Canvas c, double s) {
  c.save();
  c.translate(s * .095, s * .125);
  paintGlyph(c, s * .76, accent: _sun);
  c.restore();
}

void _background(Canvas c, double s) {
  c.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_top, _bottom],
      ).createShader(Rect.fromLTWH(0, 0, s, s)),
  );
}

void main() {
  test('render icons', () async {
    final root = Directory.current.path;
    // iOS: opaque, full-bleed square (the system applies the mask).
    final ios = '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const iosSizes = {
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final e in iosSizes.entries) {
      final bytes = await _render(e.value, (c, s) {
        _background(c, s);
        _iconGlyph(c, s);
      });
      await File('$ios/${e.key}').writeAsBytes(bytes);
    }

    // Android legacy launcher icons (pre-26) and adaptive layers.
    final res = '$root/android/app/src/main/res';
    const legacy = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };
    for (final e in legacy.entries) {
      final bytes = await _render(e.value, (c, s) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, s, s),
          Radius.circular(s * .22),
        );
        c.clipRRect(r);
        _background(c, s);
        _iconGlyph(c, s);
      });
      await File('$res/${e.key}/ic_launcher.png').writeAsBytes(bytes);
    }
    // Adaptive foreground: 108 dp canvas, glyph inside the 66 dp safe zone.
    const adaptive = {
      'mipmap-mdpi': 108,
      'mipmap-hdpi': 162,
      'mipmap-xhdpi': 216,
      'mipmap-xxhdpi': 324,
      'mipmap-xxxhdpi': 432,
    };
    for (final e in adaptive.entries) {
      for (final (name, ink, accent) in [
        ('ic_launcher_foreground.png', Colors.white, _sun),
        ('ic_launcher_monochrome.png', Colors.white, Colors.white),
      ]) {
        final bytes = await _render(e.value, (c, s) {
          final inset = s * (21 / 108);
          c.translate(inset, inset);
          paintGlyph(c, s - inset * 2, ink: ink, accent: accent);
        });
        await File('$res/${e.key}/$name').writeAsBytes(bytes);
      }
    }
    // Preview for review.
    await File('$root/build/icon_preview.png').writeAsBytes(
      await _render(512, (c, s) {
        _background(c, s);
        _iconGlyph(c, s);
      }),
    );
  });
}
