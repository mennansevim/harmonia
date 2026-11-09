// Colour and pattern variants of the photoreal master logo
// (tool/brand/source/logo_master.webp). The note is recoloured by hue shift
// (glaze shading and highlights kept), the tape stays as rendered, and the
// cream wall is replaced by solid, gradient or patterned grounds. Exploration
// only: writes to build/logo_variants/ and touches no shipped icon. Run:
//   flutter test tool/brand/logo_variants_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'photo_key.dart';

const _center = Offset(645, 612);
const _cropSize = 1060.0;
const _dst = Rect.fromLTWH(0, 0, 1024, 1024);

/// Note finishes. `hue` null keeps the original yellow.
class _Finish {
  const _Finish(this.label, {this.hue, this.sat = 1, this.val = 1});
  final String label;
  final double? hue;
  final double sat;
  final double val;
}

const _finishes = {
  'sari': _Finish('Sarı'),
  'turuncu': _Finish('Turuncu', hue: 24, sat: 1.05),
  'kirmizi': _Finish('Kırmızı', hue: 356, sat: 1.05, val: .92),
  'pembe': _Finish('Pembe', hue: 335, sat: .72),
  'mor': _Finish('Mor', hue: 268, sat: .9, val: .86),
  'mavi': _Finish('Mavi', hue: 214, sat: 1, val: .9),
  'turkuaz': _Finish('Turkuaz', hue: 176, sat: .95, val: .88),
  'yesil': _Finish('Yeşil', hue: 138, sat: .85, val: .82),
  'siyah': _Finish('Siyah', hue: 250, sat: .15, val: .2),
  'beyaz': _Finish('İnci', hue: 40, sat: .1, val: 1.06),
};

/// Grounds: base colour, pattern colour, pattern id.
class _Ground {
  const _Ground(this.label, this.base, this.ink, this.pattern, {this.base2});
  final String label;
  final Color base;
  final Color? base2;
  final Color ink;
  final String pattern;
}

/// One icon = finish + ground.
const _variants = <(String, String, _Ground)>[
  // Renkler: düz zemin, nota rengi değişir.
  ('r1', 'sari', _Ground('Krem', Color(0xFFF7E8D8), Color(0x00000000), 'duz')),
  (
    'r2',
    'kirmizi',
    _Ground('Pudra', Color(0xFFF6DCD6), Color(0x00000000), 'duz'),
  ),
  (
    'r3',
    'pembe',
    _Ground(
      'Gece',
      Color(0xFF26225C),
      Color(0x00000000),
      'duz',
      base2: Color(0xFF0F0E2E),
    ),
  ),
  ('r4', 'mor', _Ground('Lila', Color(0xFFE9E1F7), Color(0x00000000), 'duz')),
  ('r5', 'mavi', _Ground('Buz', Color(0xFFDDE9F5), Color(0x00000000), 'duz')),
  (
    'r6',
    'turkuaz',
    _Ground('Mercan', Color(0xFFF4B9A6), Color(0x00000000), 'duz'),
  ),
  ('r7', 'yesil', _Ground('Nane', Color(0xFFE2F0E2), Color(0x00000000), 'duz')),
  (
    'r8',
    'turuncu',
    _Ground(
      'Lacivert',
      Color(0xFF1D2B53),
      Color(0x00000000),
      'duz',
      base2: Color(0xFF0E1630),
    ),
  ),
  (
    'r9',
    'siyah',
    _Ground('Limon', Color(0xFFF5E46A), Color(0x00000000), 'duz'),
  ),
  (
    'r10',
    'beyaz',
    _Ground(
      'Erik',
      Color(0xFF4A2775),
      Color(0x00000000),
      'duz',
      base2: Color(0xFF24113D),
    ),
  ),
  // Desenler: sarı nota, zemin deseni değişir.
  (
    'd1',
    'sari',
    _Ground('Porte', Color(0xFFF7E8D8), Color(0x2E6B4A2A), 'porte'),
  ),
  (
    'd2',
    'sari',
    _Ground(
      'Puantiye',
      Color(0xFF7455DB),
      Color(0x33FFFFFF),
      'puantiye',
      base2: Color(0xFF5C3FB4),
    ),
  ),
  (
    'd3',
    'sari',
    _Ground('Çizgili', Color(0xFF1D2B53), Color(0x22FFFFFF), 'cizgili'),
  ),
  (
    'd4',
    'sari',
    _Ground('Kareli', Color(0xFFF4F1EA), Color(0x335B7DB5), 'kareli'),
  ),
  (
    'd5',
    'sari',
    _Ground('Dalga', Color(0xFF0F5E63), Color(0x30FFFFFF), 'dalga'),
  ),
  (
    'd6',
    'sari',
    _Ground(
      'Güneş',
      Color(0xFFF08A5D),
      Color(0x26FFFFFF),
      'gunes',
      base2: Color(0xFFD9583B),
    ),
  ),
  ('d7', 'sari', _Ground('Dama', Color(0xFF242426), Color(0x14FFFFFF), 'dama')),
  (
    'd8',
    'sari',
    _Ground('Konfeti', Color(0xFFF7E8D8), Color(0xFF000000), 'konfeti'),
  ),
  (
    'd9',
    'sari',
    _Ground(
      'Notalar',
      Color(0xFF9A2A3F),
      Color(0x26FFFFFF),
      'notalar',
      base2: Color(0xFF64111F),
    ),
  ),
  (
    'd10',
    'sari',
    _Ground(
      'Halka',
      Color(0xFF26225C),
      Color(0x24FFFFFF),
      'halka',
      base2: Color(0xFF0F0E2E),
    ),
  ),
  // Karışık: renk + desen.
  (
    'k1',
    'mavi',
    _Ground('Porte', Color(0xFFF4F1EA), Color(0x332A4A7B), 'porte'),
  ),
  (
    'k2',
    'pembe',
    _Ground('Puantiye', Color(0xFF1D2B53), Color(0x26FFFFFF), 'puantiye'),
  ),
  (
    'k3',
    'kirmizi',
    _Ground('Çizgili', Color(0xFFF4F1EA), Color(0x22C0392B), 'cizgili'),
  ),
  (
    'k4',
    'turkuaz',
    _Ground(
      'Güneş',
      Color(0xFF26225C),
      Color(0x1EFFFFFF),
      'gunes',
      base2: Color(0xFF0F0E2E),
    ),
  ),
  (
    'k5',
    'mor',
    _Ground('Dalga', Color(0xFFF5E46A), Color(0x407455DB), 'dalga'),
  ),
  (
    'k6',
    'yesil',
    _Ground('Kareli', Color(0xFF173B2C), Color(0x22FFFFFF), 'kareli'),
  ),
  (
    'k7',
    'beyaz',
    _Ground(
      'Notalar',
      Color(0xFF7455DB),
      Color(0x2EFFFFFF),
      'notalar',
      base2: Color(0xFF4A2775),
    ),
  ),
  (
    'k8',
    'siyah',
    _Ground('Konfeti', Color(0xFFF4F1EA), Color(0xFF000000), 'konfeti'),
  ),
  (
    'k9',
    'turuncu',
    _Ground('Halka', Color(0xFF0F5E63), Color(0x26FFFFFF), 'halka'),
  ),
  (
    'k10',
    'kirmizi',
    _Ground('Dama', Color(0xFFF7E8D8), Color(0x1A9A2A3F), 'dama'),
  ),
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

/// HSV hue shift of the note only; tape and highlights are left alone.
Uint8List _recolor(MasterKey key, _Finish f) {
  final src = key.rgba;
  final out = Uint8List.fromList(src);
  // Original yellow: only the cream-tinted underside rim is repainted.
  final hue = f.hue ?? 47;
  for (var p = 0; p < key.note.length; p++) {
    final i = p * 4;
    if (src[i + 3] == 0) continue;
    // Whole object minus tape, so the wall reflection on the note's
    // underside (outside the note mask) takes the finish too.
    final rim = f.hue == null ? 1 - key.note[p] : 1.0;
    final wgt = ((1 - key.tape[p]) * rim).clamp(0.0, 1.0);
    if (wgt <= 0) continue;
    final r = src[i] / 255, g = src[i + 1] / 255, b = src[i + 2] / 255;
    final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
    final s = mx == 0 ? 0.0 : (mx - mn) / mx;
    // Pale glaze highlights keep their brightness; body takes the finish.
    final body = ((s - .12) / .25).clamp(0.0, 1.0);
    // Underside rim (outside the note mask) is greyish cream: give it the
    // body's saturation and a slightly darker value so it reads as glaze.
    final under = (1 - key.note[p]).clamp(0.0, 1.0);
    final bodyS = (.9 * f.sat).clamp(0.0, 1.0);
    final ns = (s * f.sat + (bodyS - s * f.sat) * under).clamp(0.0, 1.0);
    final v0 = mx * (1 + (f.val - 1) * body);
    final nv = (v0 + (mx * .8 * f.val - v0) * under).clamp(0.0, 1.0);
    final rgb = _hsv(hue, ns, nv);
    for (var k = 0; k < 3; k++) {
      final o = src[i + k] / 255;
      out[i + k] = ((o + (rgb[k] - o) * wgt) * 255).round().clamp(0, 255);
    }
  }
  return out;
}

List<double> _hsv(double h, double s, double v) {
  final c = v * s, hp = (h % 360) / 60;
  final x = c * (1 - ((hp % 2) - 1).abs());
  final m = v - c;
  final (r, g, b) = switch (hp.floor()) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  return [r + m, g + m, b + m];
}

void _paintGround(Canvas c, _Ground g) {
  c.drawRect(
    _dst,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [g.base, g.base2 ?? g.base],
      ).createShader(_dst),
  );
  final ink = Paint()
    ..color = g.ink
    ..isAntiAlias = true;
  switch (g.pattern) {
    case 'porte':
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      for (var staff = 0; staff < 5; staff++) {
        final y0 = 60.0 + staff * 220;
        for (var l = 0; l < 5; l++) {
          final y = y0 + l * 26;
          c.drawLine(Offset(0, y), Offset(1024, y), ink);
        }
      }
    case 'puantiye':
      for (var row = 0; row < 12; row++) {
        for (var col = 0; col < 12; col++) {
          final x = col * 96.0 + (row.isOdd ? 48 : 0);
          c.drawCircle(Offset(x, row * 96.0), 18, ink);
        }
      }
    case 'cizgili':
      c.save();
      c.translate(512, 512);
      c.rotate(-math.pi / 4);
      for (var i = -14; i <= 14; i++) {
        c.drawRect(Rect.fromLTWH(i * 80.0, -800, 40, 1600), ink);
      }
      c.restore();
    case 'kareli':
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (var i = 0; i <= 1024; i += 64) {
        c.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble(), 1024), ink);
        c.drawLine(Offset(0, i.toDouble()), Offset(1024, i.toDouble()), ink);
      }
    case 'dalga':
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      for (var row = 0; row < 16; row++) {
        final path = Path();
        final y0 = row * 72.0;
        for (var x = 0; x <= 1024; x += 8) {
          final y = y0 + math.sin(x / 1024 * 6 * math.pi) * 16;
          x == 0 ? path.moveTo(0, y) : path.lineTo(x.toDouble(), y);
        }
        c.drawPath(path, ink);
      }
    case 'gunes':
      const rays = 24;
      final o = const Offset(512, 560);
      for (var i = 0; i < rays; i += 2) {
        final a0 = i * 2 * math.pi / rays, a1 = (i + 1) * 2 * math.pi / rays;
        c.drawPath(
          Path()
            ..moveTo(o.dx, o.dy)
            ..lineTo(o.dx + math.cos(a0) * 1500, o.dy + math.sin(a0) * 1500)
            ..lineTo(o.dx + math.cos(a1) * 1500, o.dy + math.sin(a1) * 1500)
            ..close(),
          ink,
        );
      }
    case 'dama':
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < 8; x++) {
          if ((x + y).isEven) {
            c.drawRect(Rect.fromLTWH(x * 128.0, y * 128.0, 128, 128), ink);
          }
        }
      }
    case 'konfeti':
      final rnd = math.Random(7);
      const colors = [
        Color(0xFFE85D75),
        Color(0xFF7455DB),
        Color(0xFF2BA9A0),
        Color(0xFFF2A93B),
        Color(0xFF3D7BD9),
      ];
      for (var i = 0; i < 90; i++) {
        final p = Paint()
          ..color = colors[i % colors.length].withValues(alpha: .55);
        final pos = Offset(rnd.nextDouble() * 1024, rnd.nextDouble() * 1024);
        c.save();
        c.translate(pos.dx, pos.dy);
        c.rotate(rnd.nextDouble() * math.pi);
        if (i.isEven) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-16, -5, 32, 10),
              const Radius.circular(5),
            ),
            p,
          );
        } else {
          c.drawCircle(Offset.zero, 7, p);
        }
        c.restore();
      }
    case 'notalar':
      ink.strokeWidth = 5;
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 7; col++) {
          final o = Offset(
            col * 160.0 + (row.isOdd ? 80 : 0) + 20,
            row * 160.0 + 40,
          );
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(-.25);
          c.drawOval(const Rect.fromLTWH(-20, 34, 30, 22), ink);
          c.drawRect(const Rect.fromLTWH(6, -16, 5, 58), ink);
          c.drawPath(
            Path()
              ..moveTo(8, -16)
              ..quadraticBezierTo(30, -4, 26, 16)
              ..quadraticBezierTo(24, 2, 8, 0)
              ..close(),
            ink,
          );
          c.restore();
        }
      }
    case 'halka':
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      for (var r = 60.0; r < 1000; r += 70) {
        c.drawCircle(const Offset(512, 560), r, ink);
      }
  }
}

void main() {
  test('logo variants', () async {
    final root = Directory.current.path;
    final out = Directory('$root/build/logo_variants')
      ..createSync(recursive: true);
    final master = await decodeImage(
      File('$root/tool/brand/source/logo_master.webp').readAsBytesSync(),
    );
    final w = master.width, h = master.height;
    final raw = (await master.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    final key = keyMaster(raw, w, h);

    final shadowPx = Uint8List(w * h * 4);
    for (var p = 0; p < w * h; p++) {
      shadowPx[p * 4 + 3] = (key.shadow[p] * 2.2 * 255).clamp(0, 255).round();
    }
    final shadow = await imageFromPixels(shadowPx, w, h);

    final notes = <String, ui.Image>{};
    for (final e in _finishes.entries) {
      notes[e.key] = await imageFromPixels(_recolor(key, e.value), w, h);
    }

    final crop = Rect.fromCenter(
      center: _center,
      width: _cropSize,
      height: _cropSize,
    );
    final hq = Paint()..filterQuality = FilterQuality.high;
    final icons = <(String, String, ui.Image)>[];
    for (final (id, finish, ground) in _variants) {
      final img = await _image(1024, 1024, (c) {
        _paintGround(c, ground);
        c.drawImageRect(shadow, crop, _dst, hq);
        c.drawImageRect(notes[finish]!, crop, _dst, hq);
      });
      final name = '${id}_${finish}_${ground.pattern}';
      await _save(img, '${out.path}/$name.png');
      icons.add((name, '${_finishes[finish]!.label} · ${ground.label}', img));
    }

    final loader = FontLoader('Inter')
      ..addFont(
        File(
          '$root/assets/fonts/Inter-Medium.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await loader.load();

    // One contact sheet per group (renkler / desenler / karisik) and all.
    Future<void> sheet(String file, List<(String, String, ui.Image)> list) {
      const cols = 5, cell = 300.0, pad = 40.0, labelH = 50.0;
      final rows = (list.length + cols - 1) ~/ cols;
      return _image(
        (cols * cell + pad).toInt(),
        (rows * (cell + labelH) + pad).toInt(),
        (c) {
          c.drawColor(const Color(0xFFE9E9EE), BlendMode.src);
          for (var i = 0; i < list.length; i++) {
            final x = pad + (i % cols) * cell;
            final y = pad + (i ~/ cols) * (cell + labelH);
            final rect = Rect.fromLTWH(x, y, cell - pad, cell - pad);
            c.save();
            c.clipPath(_squircle(rect));
            c.drawImageRect(list[i].$3, _dst, rect, hq);
            c.restore();
            final para =
                (ui.ParagraphBuilder(
                        ui.ParagraphStyle(
                          textAlign: TextAlign.center,
                          fontFamily: 'Inter',
                          fontSize: 20,
                        ),
                      )
                      ..pushStyle(ui.TextStyle(color: const Color(0xFF3A3A40)))
                      ..addText(list[i].$2))
                    .build()
                  ..layout(ui.ParagraphConstraints(width: cell));
            c.drawParagraph(para, Offset(x - pad / 2, y + cell - pad + 10));
          }
        },
      ).then((img) => _save(img, '${out.path}/$file'));
    }

    await sheet('sheet_renkler.png', icons.sublist(0, 10));
    await sheet('sheet_desenler.png', icons.sublist(10, 20));
    await sheet('sheet_karisik.png', icons.sublist(20));
    await sheet('sheet_hepsi.png', icons);
  });
}
