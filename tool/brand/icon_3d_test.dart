// Layered, depth-ready app icon concepts redrawn as vector shapes (no
// photo), following Apple's layered icon guidance (background + a few
// filled foreground layers, clean edges, system adds glass/shadows) and
// Android adaptive icons (108 dp layers, 66 dp safe zone, monochrome).
//
// For each concept writes to build/icon_3d/<id>/:
//   ios/      default/dark/tinted 1024 previews (baked effects = bitmap
//             fallback) and flat SVG layers + spec.json for Icon Composer
//   android/  foreground/background/monochrome 432 px (xxxhdpi)
//   layers.png exploded depth view; board.png presentation
// and build/icon_3d/board.png for all. Shipped icons are not touched.
//   flutter test tool/brand/icon_3d_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Tf = Offset Function(Offset);

Offset _id(Offset o) => o;

/// Records absolute commands so one geometry gives a Path and SVG data.
class Geo {
  Geo([this.tf = _id]);
  final Tf tf;
  final path = Path();
  final _d = <String>[];

  String _f(double v) => v.toStringAsFixed(1);

  void m(double x, double y) {
    final p = tf(Offset(x, y));
    path.moveTo(p.dx, p.dy);
    _d.add('M${_f(p.dx)} ${_f(p.dy)}');
  }

  void l(double x, double y) {
    final p = tf(Offset(x, y));
    path.lineTo(p.dx, p.dy);
    _d.add('L${_f(p.dx)} ${_f(p.dy)}');
  }

  void c(double x1, double y1, double x2, double y2, double x, double y) {
    final a = tf(Offset(x1, y1)), b = tf(Offset(x2, y2));
    final p = tf(Offset(x, y));
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, p.dx, p.dy);
    _d.add(
      'C${_f(a.dx)} ${_f(a.dy)} ${_f(b.dx)} ${_f(b.dy)} '
      '${_f(p.dx)} ${_f(p.dy)}',
    );
  }

  void z() {
    path.close();
    _d.add('Z');
  }

  String get d => _d.join(' ');
}

Tf _rot(Offset center, double deg, [Tf then = _id]) {
  final a = deg * math.pi / 180, ca = math.cos(a), sa = math.sin(a);
  return (o) => then(
    Offset(
      center.dx + o.dx * ca - o.dy * sa,
      center.dy + o.dx * sa + o.dy * ca,
    ),
  );
}

const _k = .5523;

Geo _ellipse(Offset c, double rx, double ry, double deg, Tf g) {
  final e = Geo(_rot(c, deg, g));
  e.m(rx, 0);
  e.c(rx, ry * _k, rx * _k, ry, 0, ry);
  e.c(-rx * _k, ry, -rx, ry * _k, -rx, 0);
  e.c(-rx, -ry * _k, -rx * _k, -ry, 0, -ry);
  e.c(rx * _k, -ry, rx, -ry * _k, rx, 0);
  e.z();
  return e;
}

Geo _rrect(Rect r, double rad, Tf g) {
  final e = Geo(g);
  final x0 = r.left, y0 = r.top, x1 = r.right, y1 = r.bottom;
  final k = _k * rad;
  e.m(x0 + rad, y0);
  e.l(x1 - rad, y0);
  e.c(x1 - rad + k, y0, x1, y0 + rad - k, x1, y0 + rad);
  e.l(x1, y1 - rad);
  e.c(x1, y1 - rad + k, x1 - rad + k, y1, x1 - rad, y1);
  e.l(x0 + rad, y1);
  e.c(x0 + rad - k, y1, x0, y1 - rad + k, x0, y1 - rad);
  e.l(x0, y0 + rad);
  e.c(x0, y0 + rad - k, x0 + rad - k, y0, x0 + rad, y0);
  e.z();
  return e;
}

/// The note: tilted oval head, rounded stem, curling flag (1024 space).
class Note {
  Note(Tf g)
    : head = _ellipse(const Offset(440, 712), 142, 104, -24, g),
      stem = _rrect(const Rect.fromLTRB(520, 236, 586, 700), 33, g),
      flag = Geo(g) {
    flag
      ..m(553, 236)
      ..c(612, 236, 660, 254, 706, 282)
      ..c(762, 322, 794, 360, 777, 404)
      ..c(771, 420, 756, 424, 750, 411)
      ..c(748, 376, 712, 344, 640, 324)
      ..c(616, 317, 598, 312, 586, 310)
      ..l(586, 270)
      ..z();
  }

  final Geo head, stem, flag;
  List<Geo> get parts => [flag, stem, head];
  Path get union => Path.combine(
    PathOperation.union,
    Path.combine(PathOperation.union, flag.path, stem.path),
    head.path,
  );
}

/// Tape strip with torn (zig-zag) ends, local coords centred at origin.
Geo _tape(Tf tf, {double len = 450, double h = 98}) {
  final g = Geo(tf);
  const teeth = 5;
  const amp = 13.0;
  g.m(-len / 2, -h / 2);
  g.l(len / 2, -h / 2);
  for (var i = 0; i < teeth; i++) {
    final y = -h / 2 + h * (i + .5) / teeth;
    g.l(len / 2 - amp, y);
    g.l(len / 2, -h / 2 + h * (i + 1) / teeth);
  }
  g.l(-len / 2, h / 2);
  for (var i = teeth - 1; i >= 0; i--) {
    final y = -h / 2 + h * (i + .5) / teeth;
    g.l(-len / 2 + amp, y);
    g.l(-len / 2, -h / 2 + h * i / teeth);
  }
  g.z();
  return g;
}

const _tapeAngle = -19.0;
const _tapeCenterRaw = Offset(526, 556);

/// Where the tape crosses the stem, along the tape from its centre.
const _stemX = 553.0;
final _creaseX =
    (_stemX - _tapeCenterRaw.dx) /
    math.cos(_tapeAngle * math.pi / 180) *
    _artScale;
const _artScale = 1.14;

enum Look { glass, soft, echo }

class Concept {
  const Concept(
    this.id,
    this.title,
    this.idea,
    this.look, {
    required this.bg,
    required this.bgDark,
    required this.note,
    this.radial = false,
  });
  final String id, title, idea;
  final Look look;
  final List<Color> bg, bgDark, note;
  final bool radial;
}

const _concepts = [
  Concept(
    '1_cam_bant',
    'Cam Bant',
    'Liquid Glass yerlisi: marka moru, düz sarı nota, buzlu cam bant',
    Look.glass,
    bg: [Color(0xFF8A6CF0), Color(0xFF5A3DB8)],
    bgDark: [Color(0xFF2E2A38), Color(0xFF121016)],
    note: [Color(0xFFFFD84F), Color(0xFFFFB000)],
  ),
  Concept(
    '2_yumusak_3d',
    'Yumuşak 3D',
    'Patlıcan sahne ve spot ışığı, hacimli sırlı nota, kumaş bant',
    Look.soft,
    bg: [Color(0xFF6E4BAE), Color(0xFF432A72), Color(0xFF1F1038)],
    bgDark: [Color(0xFF3A2B52), Color(0xFF1A1226), Color(0xFF0B0810)],
    note: [Color(0xFFFFE58A), Color(0xFFFFC531), Color(0xFFE09400)],
    radial: true,
  ),
  Concept(
    '3_yanki',
    'Yankı',
    'Krem zemin mirası, notadan yayılan yarı saydam ses halkaları',
    Look.echo,
    bg: [Color(0xFFFCF4E8), Color(0xFFF0DCC4)],
    bgDark: [Color(0xFF2E2A38), Color(0xFF121016)],
    note: [Color(0xFFFFCC3D), Color(0xFFF5A300)],
  ),
];

/// Geometry centred in the 1024 canvas.
class Art {
  Art._(this.note, this.tape, this.tapeLocal, this.tapeCenter);

  factory Art() {
    final raw = Note(_id).union.getBounds();
    // Scale the figure to ~2/3 of the canvas height (Apple-grid-like
    // presence) and centre it slightly low for optical balance.
    Offset g(Offset o) => (o - raw.center) * _artScale + const Offset(512, 526);
    final tc = g(_tapeCenterRaw);
    const len = 450 * _artScale, h = 100 * _artScale;
    return Art._(
      Note(g),
      _tape(_rot(tc, _tapeAngle), len: len, h: h),
      _tape(_id, len: len, h: h),
      tc,
    );
  }

  final Note note;
  final Geo tape, tapeLocal;
  final Offset tapeCenter;
}

const _full = Rect.fromLTWH(0, 0, 1024, 1024);
const _ringC = Offset(470, 610);
const _rings = [(420.0, .07), (320.0, .09), (225.0, .12)];

Future<ui.Image> _image(int w, int h, void Function(Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  return recorder.endRecording().toImage(w, h);
}

Future<void> _save(ui.Image img, String path) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void _paintBg(Canvas c, Concept k, bool dark) {
  final cols = dark ? k.bgDark : k.bg;
  final shader = k.radial
      ? RadialGradient(
          center: const Alignment(0, -.12),
          radius: .82,
          colors: cols,
          stops: const [0, .55, 1],
        ).createShader(_full)
      : LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: cols,
        ).createShader(_full);
  c.drawRect(_full, Paint()..shader = shader);
}

void _paintRings(Canvas c, Concept k, bool dark, {bool fx = true}) {
  if (k.look != Look.echo) return;
  final ink = dark ? const Color(0xFFB9A6FF) : const Color(0xFF7455DB);
  for (final (r, a) in _rings) {
    final disc = Path()..addOval(Rect.fromCircle(center: _ringC, radius: r));
    if (fx) {
      c.drawPath(
        disc.shift(const Offset(0, 10)),
        Paint()
          ..color = Color.fromRGBO(40, 20, 80, a * .6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    c.drawPath(disc, Paint()..color = ink.withValues(alpha: a));
    if (fx) {
      c.save();
      c.clipPath(disc);
      c.drawPath(
        disc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: .45),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(disc.getBounds()),
      );
      c.restore();
    }
  }
}

/// Note with baked effects ([fx]) or flat fill.
void _paintNote(
  Canvas c,
  Concept k,
  Art a, {
  bool fx = true,
  bool outerShadow = true,
}) {
  final u = a.note.union, b = u.getBounds();
  if (fx && outerShadow) {
    c.drawPath(
      u.shift(const Offset(0, 18)),
      Paint()
        ..color = const Color(0x66140A28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
  }
  if (!fx) {
    c.drawPath(u, Paint()..color = k.note.first);
    return;
  }
  if (k.look == Look.soft) {
    // Per-part volume: stem and flag first, head last so the stem tucks
    // behind the head instead of showing a cap on it.
    final sb = a.note.stem.path.getBounds();
    c.drawPath(
      a.note.stem.path,
      Paint()
        ..shader = LinearGradient(
          colors: [k.note[1], k.note[0], k.note[1], k.note[2]],
          stops: const [0, .3, .62, 1],
        ).createShader(sb),
    );
    final fb = a.note.flag.path.getBounds();
    c.drawPath(
      a.note.flag.path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: k.note,
          stops: const [0, .45, 1],
        ).createShader(fb),
    );
    final hb = a.note.head.path.getBounds();
    c.drawPath(
      a.note.head.path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.45),
          radius: .95,
          colors: k.note,
          stops: const [0, .45, 1],
        ).createShader(hb),
    );
    // Glaze highlights.
    final hc = hb.center;
    c.save();
    c.translate(hc.dx - 48, hc.dy - 34);
    c.rotate(-24 * math.pi / 180);
    c.drawOval(
      const Rect.fromLTWH(-50, -16, 100, 32),
      Paint()
        ..color = Colors.white.withValues(alpha: .75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sb.left + 13, sb.top + 60, 11, sb.height * .62),
        const Radius.circular(6),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: .5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    c.drawOval(
      Rect.fromCenter(
        center: fb.topLeft + const Offset(110, 46),
        width: 70,
        height: 18,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  } else {
    c.drawPath(
      u,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: k.note,
        ).createShader(b),
    );
  }
  // Rim light top-left, occlusion bottom-right (system-like bevel).
  c.save();
  c.clipPath(u);
  c.drawPath(
    u,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = k.look == Look.soft ? 22 : 16
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .7),
          Colors.white.withValues(alpha: 0),
          const Color(0x00000000),
          const Color(0x38602000),
        ],
        stops: const [0, .38, .6, 1],
      ).createShader(b),
  );
  c.restore();
}

/// Tape: frosted glass (glass/echo) or woven fabric (soft).
void _paintTape(
  Canvas c,
  Concept k,
  Art a,
  ui.Image? below, {
  bool fx = true,
  bool outerShadow = true,
}) {
  final t = a.tape.path;
  if (!fx) {
    c.drawPath(
      t,
      Paint()
        ..color = k.look == Look.soft
            ? const Color(0xFFA6AAB1)
            : Colors.white.withValues(alpha: .45),
    );
    return;
  }
  // Shadow on the note (always) and on the ground (if allowed).
  final shadow = Paint()
    ..color = Color.fromRGBO(30, 15, 0, k.look == Look.soft ? .4 : .22)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  c.save();
  if (!outerShadow) c.clipPath(a.note.union);
  c.drawPath(t.shift(const Offset(3, 11)), shadow);
  c.restore();

  if (k.look == Look.soft) {
    c.save();
    c.translate(a.tapeCenter.dx, a.tapeCenter.dy);
    c.rotate(_tapeAngle * math.pi / 180);
    final lp = a.tapeLocal.path, lb = lp.getBounds();
    c.drawPath(
      lp,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCDD0D5), Color(0xFFA7ABB2), Color(0xFF8A8E95)],
        ).createShader(lb),
    );
    c.save();
    c.clipPath(lp);
    final weave = Paint()..strokeWidth = 1.6;
    for (var y = lb.top; y < lb.bottom; y += 5) {
      weave.color = Colors.white.withValues(alpha: .07);
      c.drawLine(Offset(lb.left, y), Offset(lb.right, y), weave);
    }
    for (var x = lb.left; x < lb.right; x += 7) {
      weave.color = Colors.black.withValues(alpha: .05);
      c.drawLine(Offset(x, lb.top), Offset(x, lb.bottom), weave);
    }
    // Crease where the tape wraps the stem.
    c.drawRect(
      Rect.fromLTWH(_creaseX - 14, lb.top, 28, lb.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: .14),
            Colors.white.withValues(alpha: .28),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(_creaseX - 14, lb.top, 28, lb.height)),
    );
    c.drawLine(
      Offset(lb.left, lb.top + 2),
      Offset(lb.right, lb.top + 2),
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..strokeWidth = 3,
    );
    c.restore();
    c.restore();
    return;
  }

  // Frosted glass: blurred, slightly magnified view of what is below.
  c.save();
  c.clipPath(t);
  if (below != null) {
    c.save();
    c.translate(a.tapeCenter.dx, a.tapeCenter.dy);
    c.scale(1.05);
    c.translate(-a.tapeCenter.dx, -a.tapeCenter.dy);
    c.drawImage(
      below,
      Offset.zero,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
    );
    c.restore();
  }
  c.drawPath(t, Paint()..color = Colors.white.withValues(alpha: .5));
  c.drawPath(
    t,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: .9),
          Colors.white.withValues(alpha: .25),
          Colors.white.withValues(alpha: .6),
        ],
      ).createShader(t.getBounds()),
  );
  c.restore();
}

enum Mode { light, dark }

/// Full composite (background optional) at 1024.
Future<ui.Image> _compose(
  Concept k,
  Art a, {
  Mode mode = Mode.light,
  bool bg = true,
  bool rings = true,
  bool outerShadow = true,
}) async {
  final dark = mode == Mode.dark;
  final below = await _image(1024, 1024, (c) {
    if (bg) _paintBg(c, k, dark);
    if (rings) _paintRings(c, k, dark);
    if (dark) {
      c.saveLayer(_full, Paint()..colorFilter = _dim);
    }
    _paintNote(c, k, a, outerShadow: outerShadow);
    if (dark) c.restore();
  });
  return _image(1024, 1024, (c) {
    c.drawImage(below, Offset.zero, Paint());
    if (dark) c.saveLayer(_full, Paint()..colorFilter = _dim);
    _paintTape(c, k, a, below, outerShadow: outerShadow);
    if (dark) c.restore();
  });
}

/// Dark appearance: slightly subdued foreground (HIG: dark icons are
/// more subdued).
const _dim = ColorFilter.matrix([
  .9, 0, 0, 0, 0, //
  0, .88, 0, 0, 0,
  0, 0, .86, 0, 0,
  0, 0, 0, 1, 0,
]);

const _gray = ColorFilter.matrix([
  .299, .587, .114, 0, 0, //
  .299, .587, .114, 0, 0,
  .299, .587, .114, 0, 0,
  0, 0, 0, 1, 0,
]);

Future<ui.Image> _scaled(int size, ui.Image src, double k) => _image(
  size,
  size,
  (c) {
    c.translate(size / 2, size / 2);
    c.scale(size / 1024 * k);
    c.translate(-512, -512);
    c.drawImage(src, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  },
);

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
  double width = 400,
  FontWeight weight = FontWeight.w500,
  TextAlign align = TextAlign.left,
}) =>
    (ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              fontFamily: 'Inter',
              fontSize: size,
              fontWeight: weight,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(s))
        .build()
      ..layout(ui.ParagraphConstraints(width: width));

final _hq = Paint()..filterQuality = FilterQuality.high;

void _tile(Canvas c, ui.Image img, Rect r, {bool circle = false}) {
  c.save();
  c.clipPath(circle ? (Path()..addOval(r)) : _squircle(r));
  c.drawImageRect(img, _full, r, _hq);
  c.restore();
}

/// Isometric exploded stack of layers, bottom first.
void _exploded(Canvas c, Offset origin, List<(ui.Image, String)> layers) {
  const size = 230.0, step = 92.0;
  for (var i = 0; i < layers.length; i++) {
    final (img, label) = layers[i];
    final y = origin.dy - i * step;
    c.save();
    c.translate(origin.dx, y);
    c.scale(1, .5);
    c.rotate(math.pi / 4);
    final r = Rect.fromCenter(center: Offset.zero, width: size, height: size);
    if (i == 0) {
      c.drawPath(
        _squircle(r).shift(const Offset(10, 10)),
        Paint()
          ..color = const Color(0x33000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      _tile(c, img, r);
    } else {
      c.drawPath(
        _squircle(r),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      c.drawImageRect(img, _full, r, _hq);
    }
    c.restore();
    c.drawParagraph(
      _text(label, 17, const Color(0xFF55505E), width: 160),
      Offset(origin.dx + size * .78, y - 10),
    );
  }
}

void main() {
  test('3d icon concepts', () async {
    final root = Directory.current.path;
    for (final f in ['Medium', 'SemiBold', 'Bold']) {
      final loader = FontLoader('Inter')
        ..addFont(
          File(
            '$root/assets/fonts/Inter-$f.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await loader.load();
    }
    final art = Art();
    final boards = <ui.Image>[];

    for (final k in _concepts) {
      final dir = '$root/build/icon_3d/${k.id}';
      for (final s in ['ios', 'android']) {
        Directory('$dir/$s').createSync(recursive: true);
      }

      // iOS previews (bitmap fallback with baked effects).
      final light = await _compose(k, art);
      final dark = await _compose(k, art, mode: Mode.dark);
      final fgOnly = await _compose(k, art, bg: false);
      final tinted = await _image(1024, 1024, (c) {
        c.drawRect(_full, Paint()..color = Colors.black);
        c.saveLayer(_full, Paint()..colorFilter = _gray);
        c.drawImage(fgOnly, Offset.zero, Paint());
        c.restore();
      });
      await _save(light, '$dir/ios/default.png');
      await _save(dark, '$dir/ios/dark.png');
      await _save(tinted, '$dir/ios/tinted.png');

      // Icon Composer hand-off: flat SVG layers, effects left to system.
      String svg(String body) =>
          '<svg xmlns="http://www.w3.org/2000/svg" width="1024" '
          'height="1024" viewBox="0 0 1024 1024">$body</svg>\n';
      File('$dir/ios/layer_2_note.svg').writeAsStringSync(
        svg(
          art.note.parts
              .map((g) => '<path fill="${_hex(k.note[1])}" d="${g.d}"/>')
              .join(),
        ),
      );
      File('$dir/ios/layer_3_tape.svg').writeAsStringSync(
        svg(
          '<path fill="${k.look == Look.soft ? '#A6AAB1' : '#FFFFFF'}" '
          'd="${art.tape.d}"/>',
        ),
      );
      if (k.look == Look.echo) {
        File('$dir/ios/layer_1_rings.svg').writeAsStringSync(
          svg(
            _rings
                .map(
                  (r) =>
                      '<circle cx="${_ringC.dx}" cy="${_ringC.dy}" '
                      'r="${r.$1}" fill="#7455DB"/>',
                )
                .join(),
          ),
        );
      }
      File('$dir/ios/spec.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'concept': k.title,
          'idea': k.idea,
          'background': {
            'type': k.radial ? 'radial-gradient' : 'linear-gradient',
            'default': k.bg.map(_hex).toList(),
            'dark': k.bgDark.map(_hex).toList(),
          },
          'groups_back_to_front': [
            if (k.look == Look.echo)
              {
                'file': 'layer_1_rings.svg',
                'opacity_per_ring': _rings.map((r) => r.$2).toList(),
                'liquid_glass': 'translucency on, specular low',
              },
            {
              'file': 'layer_2_note.svg',
              'fill': k.note.map(_hex).toList(),
              'liquid_glass': 'specular on, shadow on',
            },
            {
              'file': 'layer_3_tape.svg',
              'opacity': k.look == Look.soft ? 1.0 : .45,
              'liquid_glass': k.look == Look.soft
                  ? 'opaque, shadow on'
                  : 'translucency + blur on, refraction on',
            },
          ],
          'note':
              'Previews bake approximate effects for the bitmap fallback; '
              'Icon Composer should add specular/shadow/translucency itself.',
        }),
      );

      // Android adaptive: 108 dp layers at xxxhdpi (432 px); logo kept
      // inside the 66 dp safe zone; rings ride on the background layer.
      final androidBg = await _image(1024, 1024, (c) {
        _paintBg(c, k, false);
        _paintRings(c, k, false);
      });
      final androidFg = await _compose(
        k,
        art,
        bg: false,
        rings: false,
        outerShadow: false,
      );
      // ~660 px artwork * 432/1024 * .92 = ~256 px, inside the 264 px
      // (66 dp) safe zone.
      const fgScale = .92;
      final fg432 = await _scaled(432, androidFg, fgScale);
      final bg432 = await _scaled(432, androidBg, 1);
      final mono = await _image(1024, 1024, (c) {
        c.saveLayer(_full, Paint());
        c.drawPath(art.note.union, Paint()..color = Colors.white);
        c.drawPath(
          art.tape.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 26
            ..blendMode = BlendMode.clear,
        );
        c.drawPath(art.tape.path, Paint()..color = Colors.white);
        c.restore();
      });
      final mono432 = await _scaled(432, mono, fgScale);
      await _save(fg432, '$dir/android/ic_launcher_foreground.png');
      await _save(bg432, '$dir/android/ic_launcher_background.png');
      await _save(mono432, '$dir/android/ic_launcher_monochrome.png');
      final androidPreview = await _image(1024, 1024, (c) {
        c.drawImageRect(bg432, const Rect.fromLTWH(0, 0, 432, 432), _full, _hq);
        c.drawImageRect(fg432, const Rect.fromLTWH(0, 0, 432, 432), _full, _hq);
      });

      // Exploded layer view.
      final layerImgs = <(ui.Image, String)>[
        (await _image(1024, 1024, (c) => _paintBg(c, k, false)), 'Arka plan'),
        if (k.look == Look.echo)
          (
            await _image(1024, 1024, (c) => _paintRings(c, k, false)),
            'Halkalar',
          ),
        (await _image(1024, 1024, (c) => _paintNote(c, k, art)), 'Nota'),
        (await _image(1024, 1024, (c) => _paintTape(c, k, art, null)), 'Bant'),
      ];

      // Board for this concept.
      const tileS = 250.0;
      final board = await _image(2000, 520, (c) {
        c.drawColor(const Color(0xFFF2F1F5), BlendMode.src);
        c.drawParagraph(
          _text(
            k.title,
            34,
            const Color(0xFF1E1A26),
            weight: FontWeight.w700,
            width: 800,
          ),
          const Offset(48, 30),
        );
        c.drawParagraph(
          _text(k.idea, 19, const Color(0xFF6A6474), width: 1200),
          const Offset(48, 78),
        );
        final tiles = [
          (light, 'iOS · Varsayılan', false),
          (dark, 'iOS · Koyu', false),
          (tinted, 'iOS · Renklendirilmiş', false),
          (androidPreview, 'Android · Uyarlanabilir', true),
        ];
        for (var i = 0; i < tiles.length; i++) {
          final r = Rect.fromLTWH(48 + i * (tileS + 40), 140, tileS, tileS);
          final (img, label, circle) = tiles[i];
          if (i == 2) {
            c.save();
            c.clipPath(_squircle(r));
            c.drawImageRect(
              img,
              _full,
              r,
              Paint()
                ..filterQuality = FilterQuality.high
                ..colorFilter = const ColorFilter.mode(
                  Color(0xFFE8B04A),
                  BlendMode.modulate,
                ),
            );
            c.restore();
          } else {
            _tile(c, img, r, circle: circle);
          }
          c.drawParagraph(
            _text(
              label,
              17,
              const Color(0xFF55505E),
              width: tileS,
              align: TextAlign.center,
            ),
            Offset(r.left, r.bottom + 14),
          );
        }
        _exploded(c, const Offset(1430, 400), layerImgs);
      });
      await _save(board, '$dir/board.png');
      boards.add(board);
    }

    final all = await _image(2000, boards.length * 540 + 40, (c) {
      c.drawColor(const Color(0xFFE6E5EA), BlendMode.src);
      for (var i = 0; i < boards.length; i++) {
        c.drawImage(boards[i], Offset(0, 20 + i * 540.0), Paint());
      }
    });
    await _save(all, '$root/build/icon_3d/board.png');
  });
}
