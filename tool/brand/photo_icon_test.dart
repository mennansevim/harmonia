// Builds iOS icon candidates straight from the photoreal master render
// (tool/brand/source/logo_master.webp): cream originals at three zoom
// levels, plus versions with the cream ground keyed out and replaced by
// high-contrast grounds. Writes only to build/photo_icons/. Run on demand:
//   flutter test tool/brand/photo_icon_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_key.dart';

/// Square crops of the 1254 px master, centred on the note's bounding box
/// (x 355-935, y 170-1050); smaller crop = bigger note.
const _center = Offset(645, 612);
const _zooms = {'genis': 1180.0, 'orta': 1060.0, 'yakin': 980.0};

const _grounds = {
  'gece': [Color(0xFF26225C), Color(0xFF0F0E2E)],
  'mor': [Color(0xFF7455DB), Color(0xFF5C3FB4)],
  'erik': [Color(0xFF4A2775), Color(0xFF24113D)],
  'siyah': [Color(0xFF242426), Color(0xFF0B0B0C)],
  'bordo': [Color(0xFF9A2A3F), Color(0xFF64111F)],
};

Future<ui.Image> _image(int w, int h, void Function(Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  return recorder.endRecording().toImage(w, h);
}

Future<void> _save(ui.Image img, String path) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

/// iOS-style continuous-corner mask (superellipse approximation).
Path _squircle(Rect r) {
  const n = 5.0;
  final p = Path();
  for (var i = 0; i <= 360; i++) {
    final t = i * math.pi / 180;
    final ct = math.cos(t), st = math.sin(t);
    final x = r.center.dx + r.width / 2 * ct.sign * math.pow(ct.abs(), 2 / n);
    final y = r.center.dy + r.height / 2 * st.sign * math.pow(st.abs(), 2 / n);
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p..close();
}

void main() {
  test('photo icons', () async {
    final root = Directory.current.path;
    final out = Directory('$root/build/photo_icons')
      ..createSync(recursive: true);
    final master = await decodeImage(
      File('$root/tool/brand/source/logo_master.webp').readAsBytesSync(),
    );
    final w = master.width, h = master.height;
    final raw = (await master.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    final keyed = keyMaster(raw, w, h);
    final object = await imageFromPixels(keyed.rgba, w, h);
    // Shadow as a black layer with the keyed strength as alpha.
    final shadowPx = Uint8List(w * h * 4);
    for (var p = 0; p < w * h; p++) {
      shadowPx[p * 4 + 3] = (keyed.shadow[p] * 2.2 * 255).clamp(0, 255).round();
    }
    final shadow = await imageFromPixels(shadowPx, w, h);

    Rect crop(double size) =>
        Rect.fromCenter(center: _center, width: size, height: size);
    const dst = Rect.fromLTWH(0, 0, 1024, 1024);
    final hq = Paint()..filterQuality = FilterQuality.high;

    final icons = <(String, ui.Image)>[];
    for (final z in _zooms.entries) {
      icons.add((
        'krem_${z.key}',
        await _image(1024, 1024, (c) {
          c.drawImageRect(master, crop(z.value), dst, hq);
        }),
      ));
    }
    for (final g in _grounds.entries) {
      icons.add((
        '${g.key}_orta',
        await _image(1024, 1024, (c) {
          c.drawRect(
            dst,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: g.value,
              ).createShader(dst),
          );
          final r = crop(_zooms['orta']!);
          c.drawImageRect(shadow, r, dst, hq);
          c.drawImageRect(object, r, dst, hq);
        }),
      ));
    }
    for (final (name, img) in icons) {
      await _save(img, '${out.path}/$name.png');
    }

    // Home-screen board at @3x (180 px icons) among store-typical tiles.
    final loader = FontLoader('Inter')
      ..addFont(
        File(
          '$root/assets/fonts/Inter-Medium.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await loader.load();
    const crowd = [
      Color(0xFF0A84FF),
      Color(0xFFFFFFFF),
      Color(0xFF34C759),
      Color(0xFFFF3B30),
    ];
    const tile = 180.0, gapX = 90.0, rowH = 300.0, left = 90.0, top = 100.0;
    final rows = icons.length;
    final board = await _image(1179, (top * 2 + rows * rowH).toInt(), (c) {
      final r = Rect.fromLTWH(0, 0, 1179, top * 2 + rows * rowH);
      c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9EC5E8), Color(0xFFF3D3C4)],
          ).createShader(r),
      );
      for (var i = 0; i < rows; i++) {
        final y = top + i * rowH;
        for (var q = 0; q < 4; q++) {
          final rect = Rect.fromLTWH(left + q * (tile + gapX), y, tile, tile);
          c.save();
          c.clipPath(_squircle(rect));
          if (q == 1) {
            c.drawImageRect(icons[i].$2, dst, rect, hq);
          } else {
            final col = crowd[(i + q) % crowd.length];
            c.drawRect(rect, Paint()..color = col);
            c.drawCircle(
              rect.center,
              tile * .24,
              Paint()
                ..color = col == const Color(0xFFFFFFFF)
                    ? const Color(0xFF0A84FF)
                    : const Color(0xE6FFFFFF),
            );
          }
          c.restore();
        }
        final para =
            (ui.ParagraphBuilder(
                    ui.ParagraphStyle(
                      textAlign: TextAlign.center,
                      fontFamily: 'Inter',
                      fontSize: 36,
                    ),
                  )
                  ..pushStyle(
                    ui.TextStyle(
                      color: const Color(0xFFFFFFFF),
                      shadows: const [
                        Shadow(color: Color(0x66000000), blurRadius: 6),
                      ],
                    ),
                  )
                  ..addText(icons[i].$1))
                .build()
              ..layout(const ui.ParagraphConstraints(width: 360));
        c.drawParagraph(
          para,
          Offset(left + tile + gapX + tile / 2 - 180, y + 196),
        );
      }
    });
    await _save(board, '${out.path}/home.png');

    // Contact sheet of all candidates, masked.
    final sheet = await _image(
      4 * 300 + 40,
      ((icons.length + 3) ~/ 4) * 300 + 40,
      (c) {
        c.drawColor(const Color(0xFFE9E9EE), BlendMode.src);
        for (var i = 0; i < icons.length; i++) {
          final rect = Rect.fromLTWH(
            40 + (i % 4) * 300.0,
            40 + (i ~/ 4) * 300.0,
            260,
            260,
          );
          c.save();
          c.clipPath(_squircle(rect));
          c.drawImageRect(icons[i].$2, dst, rect, hq);
          c.restore();
        }
      },
    );
    await _save(sheet, '${out.path}/sheet.png');
  });
}
