// Separates the photoreal master render (yellow note + grey tape on a flat
// cream wall) from its ground, so icon slots that need a transparent or
// different ground can reuse the exact render. Shared by
// render_icons_test.dart and photo_icon_test.dart.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Keyed master: straight-alpha object pixels, the wall shadow strength,
/// and the separate note and tape coverage masks (0-1 per pixel).
class MasterKey {
  MasterKey(this.rgba, this.shadow, this.note, this.tape);

  final Uint8List rgba;
  final Float32List shadow;
  final Float32List note;
  final Float32List tape;
}

/// Average wall colour of the master's four corners.
List<int> wallColor(Uint8List src, int w, int h) {
  var r = 0, g = 0, b = 0, n = 0;
  for (final (x0, y0) in [(0, 0), (w - 40, 0), (0, h - 40), (w - 40, h - 40)]) {
    for (var y = y0; y < y0 + 40; y++) {
      for (var x = x0; x < x0 + 40; x++) {
        final i = (y * w + x) * 4;
        r += src[i];
        g += src[i + 1];
        b += src[i + 2];
        n++;
      }
    }
  }
  return [r ~/ n, g ~/ n, b ~/ n];
}

Future<ui.Image> decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<ui.Image> imageFromPixels(Uint8List rgba, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Separates the note and tape from the flat cream ground.
///
/// Returns un-premultiplied RGBA of the object (cream removed from edge
/// pixels) and a per-pixel shadow strength the ground should darken by.
MasterKey keyMaster(Uint8List src, int w, int h) {
  // Ground colour from the four corners, interpolated across the frame.
  List<double> corner(int x0, int y0) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (var y = y0; y < y0 + 40; y++) {
      for (var x = x0; x < x0 + 40; x++) {
        final i = (y * w + x) * 4;
        r += src[i];
        g += src[i + 1];
        b += src[i + 2];
        n++;
      }
    }
    return [r / n, g / n, b / n];
  }

  final tl = corner(0, 0), tr = corner(w - 40, 0);
  final bl = corner(0, h - 40), br = corner(w - 40, h - 40);
  List<double> bgAt(int x, int y) {
    final u = x / (w - 1), v = y / (h - 1);
    return List.generate(
      3,
      (k) =>
          tl[k] * (1 - u) * (1 - v) +
          tr[k] * u * (1 - v) +
          bl[k] * (1 - u) * v +
          br[k] * u * v,
    );
  }

  final ratio = Float32List(w * h);
  final note = Float32List(w * h);
  final tapeCore = <math.Point<double>>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = y * w + x, i = p * 4;
      final bg = bgAt(x, y);
      final r = src[i].toDouble(), g = src[i + 1].toDouble();
      final b = src[i + 2].toDouble();
      final lum = .299 * r + .587 * g + .114 * b;
      ratio[p] = lum / (.299 * bg[0] + .587 * bg[1] + .114 * bg[2]);
      final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
      final sat = mx == 0 ? 0.0 : (mx - mn) / mx;
      // Hue in degrees; the note is yellow (~45-55), the cream wall and
      // its reflection on the glaze's underside are orange-beige (~30-38).
      var hue = 0.0;
      if (mx != mn) {
        if (mx == r) {
          hue = 60 * (((g - b) / (mx - mn)) % 6);
        } else if (mx == g) {
          hue = 60 * ((b - r) / (mx - mn) + 2);
        } else {
          hue = 60 * ((r - g) / (mx - mn) + 4);
        }
      }
      // Saturated yellow body, plus glaze highlights brighter than the wall.
      note[p] = math.max(
        _smooth(.3, .46, sat) * _smooth(35, 42, hue),
        _smooth(1.02, 1.06, ratio[p]),
      );
      if (sat < .16 && ratio[p] < .62) {
        tapeCore.add(math.Point(x.toDouble(), y.toDouble()));
      }
    }
  }

  // Close small holes in the note mask (dilate, then erode, radius 4).
  Float32List filter(Float32List m, bool grow) {
    const rad = 4;
    var cur = m;
    for (final horizontal in [true, false]) {
      final next = Float32List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var v = grow ? 0.0 : 1.0;
          for (var d = -rad; d <= rad; d++) {
            final xx = horizontal ? x + d : x, yy = horizontal ? y : y + d;
            if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
            final s = cur[yy * w + xx];
            v = grow ? math.max(v, s) : math.min(v, s);
          }
          next[y * w + x] = v;
        }
      }
      cur = next;
    }
    return cur;
  }

  final closed = filter(filter(note, true), false);
  // Fill enclosed holes (pale glaze highlights): anything not reachable
  // from the border through background pixels belongs to the note.
  final outside = Uint8List(w * h);
  final stack = <int>[];
  for (var x = 0; x < w; x++) {
    stack
      ..add(x)
      ..add((h - 1) * w + x);
  }
  for (var y = 0; y < h; y++) {
    stack
      ..add(y * w)
      ..add(y * w + w - 1);
  }
  while (stack.isNotEmpty) {
    final q = stack.removeLast();
    if (outside[q] == 1 || closed[q] >= .5) continue;
    outside[q] = 1;
    final x = q % w, y = q ~/ w;
    if (x > 0) stack.add(q - 1);
    if (x < w - 1) stack.add(q + 1);
    if (y > 0) stack.add(q - w);
    if (y < h - 1) stack.add(q + w);
  }
  for (var q = 0; q < w * h; q++) {
    if (outside[q] == 0) closed[q] = 1;
  }
  // Feather the edge (two 3x3 box passes) so the cut reads as a soft,
  // antialiased silhouette instead of a stair-stepped key.
  for (var pass = 0; pass < 2; pass++) {
    final copy = Float32List.fromList(closed);
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        var sum = 0.0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            sum += copy[(y + dy) * w + x + dx];
          }
        }
        closed[y * w + x] = sum / 9;
      }
    }
  }

  // Tape: a convex strip, so take the hull of its dark core and give the
  // edge a one-pixel antialiased falloff.
  final hull = _convexHull(tapeCore);
  double tapeAlpha(double x, double y) {
    var inside = double.infinity;
    for (var k = 0; k < hull.length; k++) {
      final a = hull[k], b = hull[(k + 1) % hull.length];
      final ex = b.x - a.x, ey = b.y - a.y;
      // Counter-clockwise hull: inside is to the left of each edge.
      final d =
          (ex * (y - a.y) - ey * (x - a.x)) / math.sqrt(ex * ex + ey * ey);
      inside = math.min(inside, d);
    }
    return (inside + 1).clamp(0.0, 1.0);
  }

  var minX = w.toDouble(), minY = h.toDouble(), maxX = 0.0, maxY = 0.0;
  for (final p in hull) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }

  final out = Uint8List(w * h * 4);
  final shadow = Float32List(w * h);
  final tapeA = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = y * w + x, i = p * 4;
      var a = closed[p];
      if (x >= minX - 2 && x <= maxX + 2 && y >= minY - 2 && y <= maxY + 2) {
        tapeA[p] = tapeAlpha(x.toDouble(), y.toDouble());
        a = math.max(a, tapeA[p]);
      }
      final bg = bgAt(x, y);
      if (a > 0) {
        // Un-mix the wall from solid-ish edge pixels; faint fringe pixels
        // keep their colour (un-mixing them amplifies noise into red).
        for (var k = 0; k < 3; k++) {
          final c = a > .5 ? (src[i + k] - (1 - a) * bg[k]) / a : src[i + k];
          out[i + k] = c.clamp(0, 255).round();
        }
        out[i + 3] = (a * 255).round();
      }
      shadow[p] = ((1 - ratio[p]) * (1 - a)).clamp(0.0, .5);
    }
  }
  return MasterKey(out, shadow, closed, tapeA);
}

/// Andrew's monotone chain; returns the hull counter-clockwise in a y-down
/// frame (left of each edge is inside).
List<math.Point<double>> _convexHull(List<math.Point<double>> pts) {
  final p = [...pts]
    ..sort((a, b) => a.x == b.x ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
  double cross(
    math.Point<double> o,
    math.Point<double> a,
    math.Point<double> b,
  ) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final lower = <math.Point<double>>[], upper = <math.Point<double>>[];
  for (final q in p) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, q) <= 0) {
      lower.removeLast();
    }
    lower.add(q);
  }
  for (final q in p.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, q) <= 0) {
      upper.removeLast();
    }
    upper.add(q);
  }
  return [...lower..removeLast(), ...upper..removeLast()];
}
