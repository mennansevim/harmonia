// Home-screen mock-ups of the app icon at real proportions (393 x 852 pt
// phone, 60 pt icons, rendered at 2x). Approximates iOS light / dark /
// tinted icon appearances and the Android adaptive circle mask; it is a
// drawing, not a simulator capture. Neighbour apps are generic placeholders.
// Writes only to build/phone_preview/. Run after render_icons_test.dart
// (and logo_variants_test.dart for the variant phones):
//   flutter test tool/brand/phone_preview_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_key.dart';

const _k = 2.0; // render scale (pt -> px)
const _w = 393.0, _h = 852.0; // screen, pt
const _bezel = 12.0;
const _icon = 60.0;
const _cols = 4;
const _side = 27.0;
final _gap = (_w - 2 * _side - _cols * _icon) / (_cols - 1);
const _appName = 'Sinyorina';

enum _Mode { light, dark, tinted, android }

const _tint = Color(0xFFE8B04A);

/// Generic neighbour apps: ground colour + glyph id.
const _crowd = [
  (Color(0xFF3D7BD9), 'Takvim', 0),
  (Color(0xFF34C759), 'Mesaj', 1),
  (Color(0xFFFF9500), 'Notlar', 2),
  (Color(0xFFFF3B30), 'Müzik', 3),
  (Color(0xFF8E8E93), 'Ayarlar', 4),
  (Color(0xFF5856D6), 'Podcast', 5),
  (Color(0xFF30B0C7), 'Hava', 0),
  (Color(0xFFFFCC00), 'Fotoğraf', 1),
  (Color(0xFF1C1C1E), 'Saat', 4),
  (Color(0xFFAF52DE), 'Kitap', 2),
  (Color(0xFF00C7BE), 'Harita', 3),
  (Color(0xFFFF2D55), 'Sağlık', 5),
];

Future<ui.Image> _image(int w, int h, void Function(Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  return recorder.endRecording().toImage(w, h);
}

Future<void> _save(ui.Image img, String path) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

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

ui.Paragraph _text(
  String s,
  double size,
  Color color, {
  double width = 90,
  FontWeight weight = FontWeight.w500,
}) =>
    (ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontFamily: 'Inter',
              fontSize: size,
              fontWeight: weight,
              maxLines: 1,
              ellipsis: '…',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              shadows: color == Colors.white
                  ? const [Shadow(color: Color(0x55000000), blurRadius: 3)]
                  : null,
            ),
          )
          ..addText(s))
        .build()
      ..layout(ui.ParagraphConstraints(width: width));

final _hq = Paint()..filterQuality = FilterQuality.high;

/// Simple white glyphs so neighbours read as "other apps", no brands.
void _glyph(Canvas c, Rect r, int id, Color ink) {
  final p = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = r.width * .07
    ..strokeCap = StrokeCap.round;
  final o = r.center, s = r.width;
  switch (id) {
    case 0:
      c.drawCircle(o, s * .24, p);
    case 1:
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: o, width: s * .5, height: s * .38),
          Radius.circular(s * .12),
        ),
        p,
      );
    case 2:
      for (var i = -1; i <= 1; i++) {
        c.drawLine(
          o + Offset(-s * .22, i * s * .14),
          o + Offset(s * .22, i * s * .14),
          p,
        );
      }
    case 3:
      c.drawPath(
        Path()
          ..moveTo(o.dx - s * .2, o.dy + s * .18)
          ..lineTo(o.dx, o.dy - s * .2)
          ..lineTo(o.dx + s * .2, o.dy + s * .18)
          ..close(),
        p,
      );
    case 4:
      c.drawCircle(o, s * .26, p);
      c.drawLine(o, o + Offset(0, -s * .16), p);
      c.drawLine(o, o + Offset(s * .12, 0), p);
    default:
      c.drawRect(Rect.fromCenter(center: o, width: s * .4, height: s * .4), p);
  }
}

class _Icons {
  _Icons(
    this.store,
    this.dark,
    this.tinted,
    this.fg,
    this.androidBg, {
    this.androidBgImage,
  });
  final ui.Image store, dark, tinted, fg;
  final Color androidBg;
  final ui.Image? androidBgImage;
}

/// Our icon in a given mode, in [r] (pt space already scaled by canvas).
void _ours(Canvas c, Rect r, _Mode m, _Icons ic, {ui.Image? override}) {
  final src = Rect.fromLTWH(0, 0, 1024, 1024);
  if (override != null) {
    c.save();
    c.clipPath(_squircle(r));
    c.drawImageRect(override, src, r, _hq);
    c.restore();
    return;
  }
  switch (m) {
    case _Mode.light:
      c.save();
      c.clipPath(_squircle(r));
      c.drawImageRect(ic.store, src, r, _hq);
      c.restore();
    case _Mode.dark:
      c.save();
      c.clipPath(_squircle(r));
      c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF313134), Color(0xFF111113)],
          ).createShader(r),
      );
      c.drawImageRect(ic.dark, src, r, _hq);
      c.restore();
    case _Mode.tinted:
      c.save();
      c.clipPath(_squircle(r));
      c.drawRect(r, Paint()..color = const Color(0xFF151515));
      c.drawImageRect(
        ic.tinted,
        src,
        r,
        Paint()
          ..filterQuality = FilterQuality.high
          ..colorFilter = const ColorFilter.mode(_tint, BlendMode.modulate),
      );
      c.restore();
    case _Mode.android:
      c.save();
      c.clipPath(Path()..addOval(r));
      // Adaptive layer is 108 dp, visible circle 72 dp: scale 1.5x.
      final full = Rect.fromCenter(
        center: r.center,
        width: r.width * 1.5,
        height: r.height * 1.5,
      );
      final bgImg = ic.androidBgImage;
      if (bgImg == null) {
        c.drawRect(r, Paint()..color = ic.androidBg);
      } else {
        c.drawImageRect(bgImg, Rect.fromLTWH(0, 0, 432, 432), full, _hq);
      }
      c.drawImageRect(ic.fg, Rect.fromLTWH(0, 0, 432, 432), full, _hq);
      c.restore();
  }
}

void _neighbour(Canvas c, Rect r, _Mode m, Color col, int glyph) {
  final shape = m == _Mode.android ? (Path()..addOval(r)) : _squircle(r);
  c.save();
  c.clipPath(shape);
  switch (m) {
    case _Mode.light || _Mode.android:
      c.drawRect(r, Paint()..color = col);
      _glyph(c, r, glyph, Colors.white);
    case _Mode.dark:
      c.drawRect(r, Paint()..color = const Color(0xFF1E1E20));
      _glyph(c, r, glyph, col.computeLuminance() < .05 ? Colors.white : col);
    case _Mode.tinted:
      c.drawRect(r, Paint()..color = const Color(0xFF151515));
      _glyph(c, r, glyph, _tint);
  }
  c.restore();
}

/// One phone. [slots] index -> our icon (null = generic neighbour).
Future<ui.Image> _phone(
  _Mode m,
  _Icons ic,
  String title, {
  Map<int, (ui.Image?, String)> slots = const {},
}) {
  final W = ((_w + 2 * _bezel) * _k).toInt();
  final H = ((_h + 2 * _bezel + 46) * _k).toInt();
  return _image(W, H, (c) {
    c.scale(_k);
    final body = Rect.fromLTWH(0, 0, _w + 2 * _bezel, _h + 2 * _bezel);
    c.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(66)),
      Paint()..color = const Color(0xFF0B0B0C),
    );
    c.translate(_bezel, _bezel);
    final screen = Rect.fromLTWH(0, 0, _w, _h);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(screen, const Radius.circular(55)));
    final dark = m != _Mode.light;
    c.drawRect(
      screen,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: switch (m) {
            _Mode.light => const [Color(0xFF9EC5E8), Color(0xFFF3D3C4)],
            _Mode.android => const [Color(0xFF3E5C76), Color(0xFF9A8C98)],
            _ => const [Color(0xFF1B2440), Color(0xFF3A2238)],
          },
        ).createShader(screen),
    );
    if (m == _Mode.tinted) {
      c.drawRect(screen, Paint()..color = const Color(0x66000000));
    }
    // Status bar + island.
    final ink = dark || m == _Mode.light ? Colors.white : Colors.white;
    c.drawParagraph(
      _text('9:41', 17, ink, width: 80, weight: FontWeight.w600),
      const Offset(28, 17),
    );
    if (m != _Mode.android) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(_w / 2, 30),
            width: 124,
            height: 36,
          ),
          const Radius.circular(18),
        ),
        Paint()..color = Colors.black,
      );
    }
    for (var i = 0; i < 3; i++) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(_w - 92 + i * 6.0, 26 - i * 2.5, 4, 6 + i * 2.5),
          const Radius.circular(1),
        ),
        Paint()..color = ink,
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(_w - 58, 21, 27, 13),
        const Radius.circular(4),
      ),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(_w - 56, 23, 20, 9),
        const Radius.circular(2),
      ),
      Paint()..color = ink,
    );

    // Grid: 6 rows of 4.
    var n = 0;
    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < _cols; col++) {
        final idx = row * _cols + col;
        final r = Rect.fromLTWH(
          _side + col * (_icon + _gap),
          72 + row * 102.0,
          _icon,
          _icon,
        );
        String label;
        if (slots.containsKey(idx)) {
          final (img, name) = slots[idx]!;
          _ours(c, r, m, ic, override: img);
          label = name;
        } else {
          final (col0, name, g) = _crowd[n++ % _crowd.length];
          _neighbour(c, r, m, col0, g);
          label = name;
        }
        c.drawParagraph(
          _text(label, 12, Colors.white, width: _icon + 24),
          Offset(r.left - 12, r.bottom + 5),
        );
      }
    }
    // Page dots + dock.
    for (var i = 0; i < 3; i++) {
      c.drawCircle(
        Offset(_w / 2 - 12 + i * 12.0, _h - 128),
        3.5,
        Paint()..color = i == 0 ? Colors.white : const Color(0x80FFFFFF),
      );
    }
    final dock = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, _h - 108, _w - 24, 92),
      const Radius.circular(36),
    );
    c.drawRRect(dock, Paint()..color = const Color(0x40FFFFFF));
    for (var col = 0; col < 4; col++) {
      final r = Rect.fromLTWH(
        _side + col * (_icon + _gap),
        _h - 108 + 16,
        _icon,
        _icon,
      );
      final (col0, _, g) = _crowd[(col + 5) % _crowd.length];
      _neighbour(c, r, m, col0, g);
    }
    c.restore();
    // Caption under the phone.
    c.drawParagraph(
      _text(
        title,
        18,
        const Color(0xFF2A2A30),
        width: _w,
        weight: FontWeight.w600,
      ),
      Offset(0, _h + _bezel + 14),
    );
  });
}

Future<ui.Image> _row(List<ui.Image> phones) {
  const gap = 60.0;
  final w = phones.fold<double>(gap, (s, p) => s + p.width + gap);
  final h = phones.map((p) => p.height).reduce(math.max) + 2 * gap;
  return _image(w.toInt(), h.toInt(), (c) {
    c.drawColor(const Color(0xFFE9E9EE), BlendMode.src);
    var x = gap;
    for (final p in phones) {
      c.drawImage(p, Offset(x, gap), Paint());
      x += p.width + gap;
    }
  });
}

Future<ui.Image> _load(String path) async =>
    decodeImage(File(path).readAsBytesSync());

void main() {
  test('phone preview', () async {
    final root = Directory.current.path;
    final out = Directory('$root/build/phone_preview')
      ..createSync(recursive: true);
    for (final f in ['Medium', 'SemiBold']) {
      final loader = FontLoader('Inter')
        ..addFont(
          File(
            '$root/assets/fonts/Inter-$f.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    }
    final ios = '$root/ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final colors = File(
      '$root/android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    final hex = RegExp(
      r'ic_launcher_background">#([0-9A-Fa-f]{6})',
    ).firstMatch(colors)!.group(1)!;
    final ic = _Icons(
      await _load('$ios/Icon-App-1024x1024@1x.png'),
      await _load('$ios/Icon-App-1024x1024-dark.png'),
      await _load('$ios/Icon-App-1024x1024-tinted.png'),
      await _load(
        '$root/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png',
      ),
      Color(int.parse('FF$hex', radix: 16)),
    );

    // Our icon in the second row, second column, among neighbours.
    final ours = {5: (null, _appName)};
    final modes = <ui.Image>[
      await _phone(_Mode.light, ic, 'iOS · Açık', slots: ours),
      await _phone(_Mode.dark, ic, 'iOS · Koyu', slots: ours),
      await _phone(_Mode.tinted, ic, 'iOS · Renklendirilmiş', slots: ours),
      await _phone(_Mode.android, ic, 'Android · Uyarlanabilir', slots: ours),
    ];
    await _save(await _row(modes), '${out.path}/modlar.png');

    // Close-up of our dark-mode icon at 3x for edge checks.
    final zoom = await _image(540, 540, (c) {
      c.scale(9);
      _ours(c, const Rect.fromLTWH(0, 0, 60, 60), _Mode.dark, ic);
    });
    await _save(zoom, '${out.path}/koyu_yakin.png');

    // Layered 3D concepts (icon_3d_test.dart): all modes per concept, and
    // the three concepts side by side in light mode.
    final concepts = Directory('$root/build/icon_3d');
    if (concepts.existsSync()) {
      final dirs = concepts.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final lights = <ui.Image>[];
      for (final d in dirs) {
        final id = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final cic = _Icons(
          await _load('${d.path}/ios/default.png'),
          await _load('${d.path}/ios/dark.png'),
          await _load('${d.path}/ios/tinted.png'),
          await _load('${d.path}/android/ic_launcher_foreground.png'),
          Colors.black,
          androidBgImage: await _load(
            '${d.path}/android/ic_launcher_background.png',
          ),
        );
        final spec = File('${d.path}/ios/spec.json');
        final name = spec.existsSync()
            ? (jsonDecode(spec.readAsStringSync()) as Map)['concept'] as String
            : id;
        final row = <ui.Image>[
          await _phone(_Mode.light, cic, '$name · iOS Açık', slots: ours),
          await _phone(_Mode.dark, cic, '$name · iOS Koyu', slots: ours),
          await _phone(_Mode.tinted, cic, '$name · iOS Renkli', slots: ours),
          await _phone(_Mode.android, cic, '$name · Android', slots: ours),
        ];
        await _save(await _row(row), '${out.path}/konsept_$id.png');
        lights.add(row.first);
      }
      await _save(await _row(lights), '${out.path}/konseptler.png');
    }

    // Variant phones: each group's ten icons spread among neighbours.
    final variants = Directory('$root/build/logo_variants');
    if (variants.existsSync()) {
      final files =
          variants
              .listSync()
              .whereType<File>()
              .where((f) => RegExp(r'/[rdk]\d+_').hasMatch(f.path))
              .toList()
            ..sort((a, b) {
              int n(File f) => int.parse(
                RegExp(r'/[rdk](\d+)_').firstMatch(f.path)!.group(1)!,
              );
              return n(a).compareTo(n(b));
            });
      const slotsAt = [0, 2, 5, 7, 8, 10, 13, 15, 17, 18];
      final phones = <ui.Image>[];
      for (final (g, title) in [
        ('r', 'Renkler'),
        ('d', 'Desenler'),
        ('k', 'Karışık'),
      ]) {
        final group = files
            .where((f) => f.uri.pathSegments.last.startsWith(g))
            .toList();
        final slots = <int, (ui.Image?, String)>{};
        for (var i = 0; i < group.length && i < slotsAt.length; i++) {
          final name = group[i].uri.pathSegments.last;
          final parts = name.replaceAll('.png', '').split('_');
          slots[slotsAt[i]] = (
            await _load(group[i].path),
            '${parts[0].toUpperCase()} ${parts[1]}',
          );
        }
        phones.add(await _phone(_Mode.light, ic, title, slots: slots));
      }
      await _save(await _row(phones), '${out.path}/varyantlar.png');
    }
  });
}
