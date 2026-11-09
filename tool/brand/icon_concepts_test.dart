// Renders ten iOS app-icon concepts of the Resonia mark for review: a yellow
// eighth note duct-taped flat to a wall with one long grey strip, the way an
// object is taped to a gallery wall. Writes only to build/icon_concepts/; the
// shipped icons stay untouched. Run on demand:
//   flutter test tool/brand/icon_concepts_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _yellowLight = Color(0xFFFFD43D);
const _yellow = Color(0xFFF7C116);
const _yellowDeep = Color(0xFFE5A800);

const _bananaTilt = 0.0;

const _galleryWall = [Color(0xFFF5F5F3), Color(0xFFE8E8E5)];
const _wallTape = [Color(0xFFC4C6C9), Color(0xFFB4B6BA)];
const _wrapTape = [
  Color(0xFF8E9196),
  Color(0xFFDADCDF),
  Color(0xFFA7AAAE),
  Color(0xFF7A7D82),
];

/// One concept: wall, mark finish, tape and composition.
class Concept {
  const Concept({
    required this.id,
    required this.name,
    this.wall = _galleryWall,
    this.scale = 1.15,
    this.gloss = true,
    this.shadowColor = const Color(0x2E4A4036),
    this.noteColors = const [_yellowLight, _yellow, _yellowDeep],
    this.wallTape = _wallTape,
    this.wrapTape = _wrapTape,
    this.tapeTilt = .52,
    this.noteTilt = _bananaTilt,
  });

  final String id;
  final String name;
  final List<Color> wall;
  final double scale;

  /// False draws flat colours with no glaze and no cast shadow.
  final bool gloss;
  final Color shadowColor;
  final List<Color> noteColors;

  /// Matte strip where it lies flat on the wall.
  final List<Color> wallTape;

  /// Metallic shading where the strip wraps over the stem (4 stops).
  final List<Color> wrapTape;
  final double tapeTilt;

  /// Note rotation (radians, positive leans the top right), like the banana
  /// hanging at a slant on the wall. The tape keeps its own [tapeTilt].
  final double noteTilt;

  /// Same concept with the tape laid at [r] radians.
  Concept taped(double r) => Concept(
    id: id,
    name: name,
    wall: wall,
    scale: scale,
    gloss: gloss,
    shadowColor: shadowColor,
    noteColors: noteColors,
    wallTape: wallTape,
    wrapTape: wrapTape,
    tapeTilt: r,
    noteTilt: noteTilt,
  );

  Concept tilted(double r) => Concept(
    id: id,
    name: name,
    wall: wall,
    scale: scale,
    gloss: gloss,
    shadowColor: shadowColor,
    noteColors: noteColors,
    wallTape: wallTape,
    wrapTape: wrapTape,
    // Tape always crosses against the lean, so it meets the stem squarely.
    tapeTilt: r < 0 ? -tapeTilt.abs() : tapeTilt.abs(),
    noteTilt: r,
  );
}

// Grounds chosen for contrast with the yellow note (WCAG ratio vs #F7C116)
// and to stand apart from the blue/white majority of store icons.
const _night = [Color(0xFF26225C), Color(0xFF0F0E2E)]; // ~9.6:1
const _darkShadow = Color(0x73000000);

const concepts = [
  Concept(id: '01', name: 'Gece', wall: _night, shadowColor: _darkShadow),
  Concept(
    id: '02',
    name: 'Mor marka',
    wall: [Color(0xFF7455DB), Color(0xFF5C3FB4)], // ~3.7:1
    shadowColor: Color(0x6628145E),
  ),
  Concept(
    id: '03',
    name: 'Erik',
    wall: [Color(0xFF4A2775), Color(0xFF24113D)], // ~8.2:1
    shadowColor: _darkShadow,
  ),
  Concept(
    id: '04',
    name: 'Siyah',
    wall: [Color(0xFF242426), Color(0xFF0B0B0C)], // ~11:1
    shadowColor: Color(0x99000000),
  ),
  Concept(
    id: '05',
    name: 'Bordo',
    wall: [Color(0xFF9A2A3F), Color(0xFF64111F)], // ~6:1
    shadowColor: _darkShadow,
  ),
  Concept(
    id: '06',
    name: 'Petrol',
    wall: [Color(0xFF138A94), Color(0xFF09525B)], // ~3.6:1
    shadowColor: Color(0x66002A30),
  ),
  Concept(
    id: '07',
    name: 'Gece moru',
    wall: [Color(0xFF1B1A4A), Color(0xFF5A3BB8)],
    shadowColor: _darkShadow,
  ),
  Concept(
    id: '08',
    name: 'Gün batımı',
    wall: [Color(0xFF5B3FC4), Color(0xFFE8546A)],
    shadowColor: Color(0x6628145E),
  ),
  Concept(
    id: '09',
    name: 'Gece yakın',
    wall: _night,
    shadowColor: _darkShadow,
    scale: 1.27,
  ),
  // Reference: the gallery-white original (~1.5:1, low contrast).
  Concept(id: '10', name: 'Galeri (eski)'),
];

// Geometry in units of the mark square (1 = full mark); same silhouette as
// render_icons_test.dart.
const _headCenter = Offset(.405, .745);
const _headSize = Size(.27, .195);
const _headTilt = -.42;
const _stem = Rect.fromLTRB(.495, .15, .565, .74);
const _tapeCenter = Offset(.53, .5);
const _tapeLength = .72;
const _tapeThickness = .15;

/// Strip shift along its length: the upper-left end runs longer, as a
/// hand-placed strip rarely sits centred.
const _tapeSkew = -.03;

/// Width of the shaded lift where the tape leaves the stem for the wall.
const _lift = .016;

Path _notePath(double s) {
  final head = Path()
    ..addOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: _headSize.width * s,
        height: _headSize.height * s,
      ),
    );
  final m = Matrix4.identity()
    ..translateByDouble(_headCenter.dx * s, _headCenter.dy * s, 0, 1)
    ..rotateZ(_headTilt);
  final stem = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          _stem.left * s,
          _stem.top * s,
          _stem.right * s,
          _stem.bottom * s,
        ),
        Radius.circular(_stem.width * s / 2),
      ),
    );
  final flag = Path()
    ..moveTo(.495 * s, .19 * s)
    ..cubicTo(.495 * s, .14 * s, .53 * s, .128 * s, .565 * s, .148 * s)
    ..cubicTo(.62 * s, .178 * s, .66 * s, .198 * s, .70 * s, .218 * s)
    ..cubicTo(.752 * s, .244 * s, .775 * s, .292 * s, .748 * s, .338 * s)
    ..cubicTo(.735 * s, .302 * s, .705 * s, .286 * s, .665 * s, .281 * s)
    ..cubicTo(.625 * s, .276 * s, .59 * s, .29 * s, .565 * s, .312 * s)
    ..lineTo(.495 * s, .312 * s)
    ..close();
  return Path.combine(
    PathOperation.union,
    Path.combine(PathOperation.union, head.transform(m.storage), stem),
    flag,
  );
}

/// Long strip with scissor-cut, slightly uneven ends, centred on the origin.
Path _stripPath(double s) {
  final half = _tapeLength * s / 2;
  final h = _tapeThickness * s / 2;
  const right = [.0, .004, .001, .005, .0];
  const left = [.0, .003, .0, .005, .001];
  final p = Path()..moveTo(-half, -h);
  p.lineTo(half - .006 * s, -h);
  for (var i = 1; i < right.length; i++) {
    p.lineTo(half - right[i] * s, -h + 2 * h * i / (right.length - 1));
  }
  p.lineTo(-half + .004 * s, h);
  for (var i = 1; i < left.length; i++) {
    p.lineTo(-half + left[i] * s, h - 2 * h * i / (left.length - 1));
  }
  return p..close();
}

void _paintMark(Canvas c, double s, Concept k) {
  final note = _notePath(s);
  final bounds = Rect.fromLTWH(0, 0, s, s);

  if (k.gloss) {
    // Soft gallery light from the upper left: shadow falls down-right.
    c.drawPath(
      // Keep the light from the upper left whatever the note's rotation.
      note.shift(
        Offset(
              .018 * math.cos(k.noteTilt) + .028 * math.sin(k.noteTilt),
              -.018 * math.sin(k.noteTilt) + .028 * math.cos(k.noteTilt),
            ) *
            s,
      ),
      Paint()
        ..color = k.shadowColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, .026 * s),
    );
  }

  c.saveLayer(bounds, Paint());
  c.drawPath(
    note,
    Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-.6, -1),
        end: const Alignment(.6, 1),
        colors: k.noteColors,
        stops: const [0, .55, 1],
      ).createShader(Rect.fromLTRB(.27 * s, .12 * s, .78 * s, .86 * s)),
  );
  if (k.gloss) {
    final gloss = Paint()..color = const Color(0x80FFF6C8);
    c.save();
    c.translate(.37 * s, .705 * s);
    c.rotate(_headTilt);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: .1 * s, height: .045 * s),
      gloss,
    );
    c.restore();
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(.507 * s, .2 * s, .016 * s, .44 * s),
        Radius.circular(.008 * s),
      ),
      Paint()..color = const Color(0x4DFFF6C8),
    );
    c.drawPath(
      Path()
        ..moveTo(.575 * s, .175 * s)
        ..quadraticBezierTo(.65 * s, .2 * s, .705 * s, .238 * s),
      Paint()
        ..color = const Color(0x59FFF6C8)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = .014 * s,
    );
  }
  _paintTape(c, s, k);
  c.restore();
}

/// One long matte strip pressed flat onto the wall; where it crosses the
/// stem it wraps around it and turns darker and metallic, with a thin shaded
/// lift on each side where it leaves the stem for the wall.
void _paintTape(Canvas c, double s, Concept k) {
  // Drawn in the note's frame, so subtract the note's own rotation.
  final t = k.tapeTilt - k.noteTilt;
  final h = _tapeThickness * s / 2;
  // Tape-space x of a vertical mark line at mark-x [e], at tape-space y.
  double ex(double e, double y) =>
      ((e - _tapeCenter.dx) * s + y * math.sin(t)) / math.cos(t);
  Path band(double e0, double e1, {double bow = 0}) {
    final mid = (e0 + e1) / 2;
    return Path()
      ..moveTo(ex(e0, -h), -h)
      ..quadraticBezierTo(ex(mid, -h), -h - bow * s, ex(e1, -h), -h)
      ..lineTo(ex(e1, h), h)
      ..quadraticBezierTo(ex(mid, h), h + bow * s, ex(e0, h), h)
      ..close();
  }

  c.save();
  c.translate(_tapeCenter.dx * s, _tapeCenter.dy * s);
  c.rotate(t);

  final strip = _stripPath(s).shift(Offset(_tapeSkew * s, 0));
  // Pressed flat: only a hairline contact shadow on the wall.
  c.drawPath(
    strip.shift(Offset(0, .003 * s)),
    Paint()
      ..color = const Color(0x1F000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, .003 * s),
  );
  c.drawPath(
    strip,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: k.wallTape,
      ).createShader(Rect.fromLTRB(-1, -h, 1, h)),
  );
  c.save();
  c.clipPath(strip);
  // Pebbled matte surface: the wall's grain pressing through the tape.
  final half = _tapeLength * s / 2;
  final rnd = math.Random(11);
  final grain = Paint();
  for (var i = 0; i < 2600; i++) {
    grain.color = rnd.nextBool()
        ? const Color(0x0AFFFFFF)
        : const Color(0x08000000);
    c.drawCircle(
      Offset(
        (_tapeSkew * s) + (rnd.nextDouble() * 2 - 1) * half,
        (rnd.nextDouble() * 2 - 1) * h,
      ),
      (.0015 + rnd.nextDouble() * .002) * s,
      grain,
    );
  }
  c.restore();

  // Wrapped section over the stem: bows slightly where it is stretched.
  final st = _stem.left, sr = _stem.right;
  final wrap = band(st - .004, sr + .004, bow: .008);
  c.drawPath(
    wrap.shift(Offset(.004 * s, .004 * s)),
    Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, .005 * s),
  );
  c.drawPath(
    wrap,
    Paint()
      ..shader = LinearGradient(
        colors: k.wrapTape,
        stops: const [0, .35, .65, 1],
      ).createShader(Rect.fromLTRB(ex(st, 0), -h, ex(sr, 0), h)),
  );
  if (k.gloss) {
    // Lift either side: tape bridging from stem to wall, in shade.
    c.save();
    c.clipPath(strip);
    for (final (e0, e1, dark) in [
      (st - _lift, st, 1.0),
      (sr, sr + _lift, 0.0),
    ]) {
      c.drawPath(
        band(e0, e1),
        Paint()
          ..shader = LinearGradient(
            colors: dark == 1
                ? const [Color(0x00000000), Color(0x38000000)]
                : const [Color(0x47000000), Color(0x00000000)],
          ).createShader(Rect.fromLTRB(ex(e0, 0), -h, ex(e1, 0), h)),
      );
    }
    c.restore();
    // Crumpled wrap: wavy creases along the stem, alternating catch-light
    // and shadow, plus broken specular facets, as hand-pressed tape does.
    c.save();
    c.clipPath(wrap);
    final w = sr - st;
    // Smooth crease running across the tape at stem fraction [f], bending
    // by [bend] (fraction of the stem width) at mid-height.
    Path crease(double f, double bend, double tilt) {
      final y0 = -h * 1.1, y1 = h * 1.1;
      return Path()
        ..moveTo(ex(st + w * (f - tilt), y0), y0)
        ..quadraticBezierTo(
          ex(st + w * (f + bend), 0),
          0,
          ex(st + w * (f + tilt), y1),
          y1,
        );
    }

    // Broad soft sheen, then a few irregular creases.
    for (final (f, bend, tilt, width) in [
      (.3, .12, -.06, .018),
      (.68, -.1, .05, .012),
    ]) {
      c.drawPath(
        crease(f, bend, tilt),
        Paint()
          ..color = const Color(0x59FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * s
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, .006 * s),
      );
    }
    for (final (f, bend, tilt, light) in [
      (.18, -.08, .05, false),
      (.42, .16, -.04, true),
      (.55, -.06, .09, false),
      (.82, .09, -.07, true),
    ]) {
      c.drawPath(
        crease(f, bend, tilt),
        Paint()
          ..color = light ? const Color(0x73FFFFFF) : const Color(0x38000000)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (light ? .004 : .003) * s
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, .0015 * s),
      );
    }
    // Diagonal pinch folds where the tape meets the stem edge.
    for (final (y0, y1) in [(-h, -h * .15), (h * .2, h)]) {
      c.drawPath(
        Path()
          ..moveTo(ex(st, y0), y0)
          ..lineTo(ex(st + w * .45, (y0 + y1) / 2), (y0 + y1) / 2)
          ..lineTo(ex(st, y1), y1)
          ..close(),
        Paint()
          ..color = const Color(0x24FFFFFF)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, .002 * s),
      );
    }
    c.restore();
  }
  c.restore();
}

void _paintIcon(Canvas c, double s, Concept k) {
  final rect = Rect.fromLTWH(0, 0, s, s);
  c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: k.wall,
      ).createShader(rect),
  );
  c.save();
  final sc = k.scale;
  // Centre the mark's bounding box (x .275-.775, y .13-.855) on the icon.
  c.translate(s / 2, s / 2);
  c.rotate(k.noteTilt);
  c.translate(-.525 * sc * s, -.4925 * sc * s);
  _paintMark(c, s * sc, k);
  c.restore();
}

/// iOS-style continuous-corner mask (superellipse approximation).
Path _squircle(Rect r) {
  const n = 5.0;
  final p = Path();
  final cx = r.center.dx, cy = r.center.dy;
  final a = r.width / 2, b = r.height / 2;
  for (var i = 0; i <= 360; i++) {
    final t = i * math.pi / 180;
    final ct = math.cos(t), st = math.sin(t);
    final x = cx + a * ct.sign * math.pow(ct.abs(), 2 / n);
    final y = cy + b * st.sign * math.pow(st.abs(), 2 / n);
    i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p..close();
}

Future<ui.Image> _image(int w, int h, void Function(Canvas) paint) {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  return recorder.endRecording().toImage(w, h);
}

Future<void> _save(ui.Image img, String path) async {
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

/// Painter for a concept at 1024 px, for drawing into composite boards.
void Function(Canvas) _painter(Concept k) =>
    (c) => _paintIcon(c, 1024, k);

void main() {
  test('render icon concepts', () async {
    final out = Directory('${Directory.current.path}/build/icon_concepts')
      ..createSync(recursive: true);
    final full = <ui.Image>[];
    for (final k in concepts) {
      final img = await _image(1024, 1024, (c) => _paintIcon(c, 1024, k));
      full.add(img);
      await _save(img, '${out.path}/icon_${k.id}.png');
    }

    // Contact sheet: 5 x 2 masked icons on a light grey ground, each with
    // 60 pt / 40 pt home-screen sized copies underneath.
    const cell = 360.0, icon = 280.0, pad = 40.0;
    final sheet = await _image(5 * cell.toInt(), 2 * 470, (c) {
      c.drawColor(const Color(0xFFE9E9EE), BlendMode.src);
      for (var i = 0; i < concepts.length; i++) {
        final ox = (i % 5) * cell + pad, oy = (i ~/ 5) * 470.0 + pad;
        void draw(double x, double y, double size) {
          final r = Rect.fromLTWH(x, y, size, size);
          c.save();
          c.clipPath(_squircle(r));
          c.drawImageRect(
            full[i],
            const Rect.fromLTWH(0, 0, 1024, 1024),
            r,
            Paint()..filterQuality = FilterQuality.high,
          );
          c.restore();
        }

        draw(ox, oy, icon);
        draw(ox, oy + icon + 24, 60);
        draw(ox + 84, oy + icon + 34, 40);
        draw(ox + 140, oy + icon + 44, 29);
      }
    });
    await _save(sheet, '${out.path}/sheet.png');

    // Tape-angle study on the upright 01: 17°, 30°, 45° falling right,
    // 30° rising right, and horizontal.
    const angles = [.3, .52, .79, -.52, 0.0];
    final study = await _image(angles.length * 340 + 40, 380, (c) {
      c.drawColor(const Color(0xFFE9E9EE), BlendMode.src);
      for (var i = 0; i < angles.length; i++) {
        final img = _painter(concepts.first.taped(angles[i]));
        final r = Rect.fromLTWH(40 + i * 340.0, 40, 300, 300);
        c.save();
        c.clipPath(_squircle(r));
        c.translate(r.left, r.top);
        c.scale(300 / 1024);
        img(c);
        c.restore();
      }
    });
    await _save(study, '${out.path}/angles.png');

    // iPhone home screen at @3x: 60 pt icons (180 px), 4 columns, labels.
    final loader = FontLoader('Inter')
      ..addFont(
        File(
          'assets/fonts/Inter-Medium.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await loader.load();
    for (final (file, wall) in [
      ('home_light.png', const [Color(0xFF9EC5E8), Color(0xFFF3D3C4)]),
      ('home_dark.png', const [Color(0xFF1B2438), Color(0xFF060709)]),
    ]) {
      const w = 1179, rows = 3, pitchX = 270.0, pitchY = 330.0;
      const left = 90.0, top = 120.0, size = 180.0;
      final img = await _image(w, (top * 2 + rows * pitchY).toInt(), (c) {
        final r = Rect.fromLTWH(0, 0, w.toDouble(), top * 2 + rows * pitchY);
        c.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: wall,
            ).createShader(r),
        );
        for (var i = 0; i < concepts.length; i++) {
          final x = left + (i % 4) * pitchX, y = top + (i ~/ 4) * pitchY;
          final ir = Rect.fromLTWH(x, y, size, size);
          c.drawPath(
            _squircle(ir.shift(const Offset(0, 6))),
            Paint()
              ..color = const Color(0x33000000)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
          );
          c.save();
          c.clipPath(_squircle(ir));
          c.drawImageRect(
            full[i],
            const Rect.fromLTWH(0, 0, 1024, 1024),
            ir,
            Paint()..filterQuality = FilterQuality.high,
          );
          c.restore();
          final pb =
              ui.ParagraphBuilder(
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
                ..addText('${concepts[i].id} ${concepts[i].name}');
          final para = pb.build()
            ..layout(const ui.ParagraphConstraints(width: pitchX));
          c.drawParagraph(para, Offset(x + size / 2 - pitchX / 2, y + 196));
        }
      });
      await _save(img, '${out.path}/$file');
    }

    // Stand-out test: each concept in the middle of a 3x3 home-screen patch
    // of the colours that dominate the stores (generic tiles, no brands).
    const crowd = [
      Color(0xFF0A84FF),
      Color(0xFFFFFFFF),
      Color(0xFF34C759),
      Color(0xFFFF3B30),
      Color(0xFF1C1C1E),
      Color(0xFF5AC8FA),
      Color(0xFFFF9500),
      Color(0xFFFFFFFF),
    ];
    const tile = 120.0, gap = 36.0, patch = 3 * tile + 2 * gap, m = 40.0;
    final board = await _image(
      (5 * (patch + m) + m).toInt(),
      (2 * (patch + m + 50) + m).toInt(),
      (c) {
        c.drawColor(const Color(0xFF8FA3B8), BlendMode.src);
        for (var i = 0; i < concepts.length; i++) {
          final ox = m + (i % 5) * (patch + m);
          final oy = m + (i ~/ 5) * (patch + m + 50);
          var n = 0;
          for (var r = 0; r < 3; r++) {
            for (var q = 0; q < 3; q++) {
              final rect = Rect.fromLTWH(
                ox + q * (tile + gap),
                oy + r * (tile + gap),
                tile,
                tile,
              );
              c.save();
              c.clipPath(_squircle(rect));
              if (r == 1 && q == 1) {
                c.drawImageRect(
                  full[i],
                  const Rect.fromLTWH(0, 0, 1024, 1024),
                  rect,
                  Paint()..filterQuality = FilterQuality.high,
                );
              } else {
                final col = crowd[n++ % crowd.length];
                c.drawRect(rect, Paint()..color = col);
                c.drawCircle(
                  rect.center,
                  tile * .24,
                  Paint()
                    ..color = col == const Color(0xFFFFFFFF)
                        ? crowd[(n + 2) % crowd.length]
                        : const Color(0xE6FFFFFF),
                );
              }
              c.restore();
            }
          }
          final para =
              (ui.ParagraphBuilder(
                      ui.ParagraphStyle(
                        textAlign: TextAlign.center,
                        fontFamily: 'Inter',
                        fontSize: 30,
                      ),
                    )
                    ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)))
                    ..addText('${concepts[i].id} ${concepts[i].name}'))
                  .build()
                ..layout(const ui.ParagraphConstraints(width: patch));
          c.drawParagraph(para, Offset(ox, oy + patch + 10));
        }
      },
    );
    await _save(board, '${out.path}/standout.png');
  });
}
