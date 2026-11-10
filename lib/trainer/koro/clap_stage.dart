import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/lang.dart';
import '../ui/kit.dart';

/// The ten ways the hands can clap. All share one motion model (see
/// [ClapStage]); they differ in hand pose and in what the impact shows.
enum ClapStyle {
  classic,
  rings,
  spark,
  trail,
  chalk,
  palmas,
  cupped,
  glow,
  waveform,
  notes;

  static ClapStyle at(int index) =>
      values[index.clamp(0, values.length - 1).toInt()];

  String get title => switch (this) {
    classic => tr('Klasik', 'Classic'),
    rings => tr('Ses halkası', 'Sound rings'),
    spark => tr('Kıvılcım', 'Spark'),
    trail => tr('Hız izi', 'Speed trail'),
    chalk => tr('Tebeşir tozu', 'Chalk dust'),
    palmas => tr('Palmas', 'Palmas'),
    cupped => tr('Kapalı avuç', 'Cupped'),
    glow => tr('Işık', 'Glow'),
    waveform => tr('Dalga formu', 'Waveform'),
    notes => tr('Notalar', 'Notes'),
  };

  String get blurb => switch (this) {
    classic => tr(
      'Avuç avuca, net vuruş çizgileri',
      'Palm to palm, crisp lines',
    ),
    rings => tr('Sesin odaya yayılışı', 'The sound spreading out'),
    spark => tr('Çizgi roman patlaması', 'A comic-book pop'),
    trail => tr('Ellerin hızı görünür', 'You see the speed'),
    chalk => tr('Jimnastikçi alkışı, toz bulutu', 'Gym chalk puffing out'),
    palmas => tr('Flamenko: parmaklar avuca', 'Flamenco: fingers to palm'),
    cupped => tr('Boğuk, içi hava dolu', 'Muted, a pocket of air'),
    glow => tr('Sıcak bir ışık patlaması', 'A warm burst of light'),
    waveform => tr('Osiloskopta alkış', 'The clap on a scope'),
    notes => tr('Her alkış bir nota', 'Every clap, a note'),
  };
}

/// Tells a [ClapStage] when palms meet. [strike] is the impact itself;
/// [expect] announces the next one so the hands can close into it, as a
/// player's hands start moving before the beat rather than on it.
class ClapCue extends ChangeNotifier {
  int _strikes = 0;
  int _expectSerial = 0;
  Duration _expectIn = Duration.zero;

  int get strikes => _strikes;
  int get expectSerial => _expectSerial;
  Duration get expectIn => _expectIn;

  void strike() {
    _strikes++;
    notifyListeners();
  }

  void expect(Duration until) {
    if (until <= Duration.zero) return;
    _expectIn = until;
    _expectSerial++;
    notifyListeners();
  }
}

/// Everything the painter needs for one frame.
@immutable
class ClapPose {
  const ClapPose({
    required this.gap,
    required this.since,
    required this.count,
    required this.seconds,
    this.ghosts = const [],
  });

  static const rest = ClapPose(gap: 1, since: 99, count: 0, seconds: 0);

  /// 0 = palms together, 1 = hands at rest apart.
  final double gap;

  /// Seconds since the last impact (large when there was none).
  final double since;

  /// Impacts so far; seeds the particles so each clap differs.
  final int count;

  /// Running clock, for slow ambient motion.
  final double seconds;

  /// Earlier (gap, opacity) samples, for the speed trail.
  final List<(double, double)> ghosts;

  /// 1 at impact, decaying fast: how hard the palms are pressed.
  double get impact => since > 2 ? 0 : math.exp(-since / 0.075);
}

/// Two hands that clap on [cue]. Runs a ticker only while something is
/// moving, so it settles in tests and costs nothing when idle. With reduced
/// motion the hands just meet for a moment, with no particles.
class ClapStage extends StatefulWidget {
  const ClapStage({
    super.key,
    required this.cue,
    this.style = ClapStyle.classic,
    this.size = const Size(240, 170),
  });

  final ClapCue cue;
  final ClapStyle style;
  final Size size;

  @override
  State<ClapStage> createState() => _ClapStageState();
}

class _ClapStageState extends State<ClapStage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _base = 0;
  double _elapsed = 0;
  double? _last;
  double? _next;
  double _lead = 0;
  int _count = 0;
  int _seenStrikes = 0;
  int _seenExpect = 0;
  bool _reduced = false;

  double get _now => _base + _elapsed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _seenStrikes = widget.cue.strikes;
    _seenExpect = widget.cue.expectSerial;
    widget.cue.addListener(_onCue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ResoniaMotion.reduced(context);
  }

  @override
  void didUpdateWidget(ClapStage old) {
    super.didUpdateWidget(old);
    if (old.cue != widget.cue) {
      old.cue.removeListener(_onCue);
      widget.cue.addListener(_onCue);
      _seenStrikes = widget.cue.strikes;
      _seenExpect = widget.cue.expectSerial;
    }
  }

  @override
  void dispose() {
    widget.cue.removeListener(_onCue);
    _ticker.dispose();
    super.dispose();
  }

  void _onCue() {
    if (!_ticker.isActive) {
      _base += _elapsed;
      _elapsed = 0;
      _ticker.start();
    }
    final now = _now;
    final cue = widget.cue;
    if (cue.strikes != _seenStrikes) {
      _seenStrikes = cue.strikes;
      _last = now;
      _next = null;
      _count++;
    }
    if (cue.expectSerial != _seenExpect) {
      _seenExpect = cue.expectSerial;
      final d = cue.expectIn.inMicroseconds / 1e6;
      _next = now + d;
      // Close over at most 180 ms, never more than 60% of the gap, so the
      // hands still visibly open between fast claps.
      _lead = math.min(0.18, d * 0.6);
    }
    setState(() {});
  }

  void _tick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / 1e6;
    final now = _now;
    final last = _last, next = _next;
    final settled = last == null || now - last > 1.3;
    final waiting = next != null && now < next + 0.4;
    if (settled && !waiting) {
      _ticker.stop();
      _next = null;
    }
    setState(() {});
  }

  /// Hand opening at time [t]: a critically damped recoil after the last
  /// impact, met by an accelerating close into the expected one.
  double _gapAt(double t) {
    var g = 1.0;
    final last = _last;
    if (last != null && t >= last) {
      final x = (t - last) / 0.042;
      g = 1 - math.exp(-x) * (1 + x);
    }
    final next = _next;
    if (next != null && _lead > 0) {
      final u = next - t;
      if (u <= _lead) {
        final k = (u / _lead).clamp(0.0, 1.0);
        g = math.min(g, k * k);
      }
    }
    return g;
  }

  ClapPose _pose() {
    final now = _now;
    final since = _last == null ? 99.0 : now - _last!;
    if (_reduced) {
      return ClapPose(
        gap: since < 0.12 ? 0 : 1,
        since: since < 0.12 ? 0 : 99,
        count: _count,
        seconds: 0,
      );
    }
    final ghosts = <(double, double)>[];
    if (widget.style == ClapStyle.trail) {
      if (_next != null) {
        // Closing: where the hands were a few frames ago.
        for (var i = 1; i <= 3; i++) {
          final g = _gapAt(now - i * 0.022);
          ghosts.add((g, 0.32 - i * 0.08));
        }
      } else if (since < 0.08) {
        // A snap with no warning (the learner's own clap): a smear.
        final f = 1 - since / 0.08;
        for (var i = 1; i <= 3; i++) {
          ghosts.add((i * 0.22, (0.3 - i * 0.07) * f));
        }
      }
    }
    return ClapPose(
      gap: _gapAt(now),
      since: since,
      count: _count,
      seconds: now,
      ghosts: ghosts,
    );
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(
        key: const Key('clap_stage'),
        size: widget.size,
        painter: ClapStagePainter(
          style: widget.style,
          pose: _pose(),
          reduced: _reduced,
        ),
      ),
    ),
  );
}

/// Paints the hands and the impact for one [pose]. Pure: the same pose
/// always paints the same frame, which keeps goldens repeatable.
class ClapStagePainter extends CustomPainter {
  ClapStagePainter({
    required this.style,
    required this.pose,
    this.reduced = false,
  });

  final ClapStyle style;
  final ClapPose pose;
  final bool reduced;

  static final _outline = Paint()
    ..color = TC.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5.6
    ..strokeJoin = StrokeJoin.round;
  static final _cuffLine = Paint()
    ..color = TC.ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2;
  static final _crease = Paint()
    ..color = TC.ink.withValues(alpha: 0.32)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;

  // Hand geometry, local to one hand, palm toward the viewer: origin at the
  // wrist, fingers up (-y), thumb on the inner side (+x, toward the other
  // hand). [_hand] then turns it toward the other hand by squeezing x
  // about the inner edge, which reads as a 3/4 view.
  static const _inner = 22.0;
  static final _palm = RRect.fromLTRBR(-22, -64, 22, -6, _r(17));
  static const _fingerBase = -54.0;

  /// (centre x, top y, width) from little finger to index.
  static const _fingers = [
    (-16.0, -90.0, 10.5),
    (-5.5, -104.0, 11.0),
    (5.5, -110.0, 11.5),
    (16.0, -101.0, 11.0),
  ];
  static final _thumb = RRect.fromLTRBR(-7.5, -38, 7.5, 4, _r(7.5));
  static const _thumbAt = Offset(16, -26);
  static final _cuff = RRect.fromLTRBR(-19, -14, 19, 2, _r(6));

  static Radius _r(double r) => Radius.circular(r);

  /// Index fingertip pad, local: the palmas striking point.
  static const _tipPad = Offset(16, -97);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final wrist = size.height - 16;
    final p = pose;
    final impact = p.impact;
    final shake = reduced ? 0.0 : impact * 1.6 * math.sin(p.since * 95);
    canvas.save();
    canvas.translate(0, shake);

    final mid = Offset(cx, wrist - 62);
    final top = Offset(cx, wrist - 118);
    canvas.drawCircle(
      Offset(cx, wrist - 64),
      60 * (1 + 0.05 * impact),
      Paint()..color = TC.limeSoft,
    );

    if (!reduced && style == ClapStyle.glow) _glow(canvas, mid, p);
    if (!reduced && style == ClapStyle.waveform) {
      _waveform(canvas, size, wrist, p);
    }

    for (final (g, a) in p.ghosts) {
      if (a <= 0) continue;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)),
      );
      _pair(canvas, cx, wrist, g, 0);
      canvas.restore();
    }
    if (style == ClapStyle.cupped && p.gap < 0.5) {
      // The air pocket between the cupped palms.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, wrist - 52), width: 12, height: 38),
        Paint()..color = TC.ink.withValues(alpha: 0.22 * (1 - p.gap * 2)),
      );
    }
    _pair(canvas, cx, wrist, p.gap, impact);

    if (!reduced) {
      final palmas = _palmasContact(cx, wrist, impact);
      switch (style) {
        case ClapStyle.classic:
          _lines(canvas, top, p);
        case ClapStyle.rings:
          _rings(canvas, mid, p);
        case ClapStyle.spark:
          _spark(canvas, top.translate(0, -4), p);
        case ClapStyle.trail:
          _flash(canvas, mid, p, 26);
        case ClapStyle.chalk:
          _chalk(canvas, mid.translate(0, -18), p);
        case ClapStyle.palmas:
          _twinkle(canvas, palmas, p);
        case ClapStyle.cupped:
          _puff(canvas, Offset(cx, wrist - 30), p);
        case ClapStyle.glow:
          break;
        case ClapStyle.waveform:
          break;
        case ClapStyle.notes:
          _notes(canvas, top, p);
      }
    } else if (p.since < 0.12) {
      _flash(canvas, mid, p.copyFlash(), 22);
    }
    canvas.restore();
  }

  // ---- Hands -------------------------------------------------------------

  /// How square-on a hand faces the viewer: 1 flat, lower turned inward.
  static double _facing(double gap) => 0.64 + 0.2 * gap;

  void _pair(Canvas c, double cx, double wrist, double gap, double impact) {
    if (style == ClapStyle.palmas) {
      _palmasPair(c, cx, wrist, gap, impact);
      return;
    }
    final cupped = style == ClapStyle.cupped;
    // Right hand first: at contact the left palm overlaps it, as one hand
    // always sits a little in front of the other.
    for (final left in [false, true]) {
      final s = left ? -1.0 : 1.0;
      c.save();
      final edge = cupped ? -6 + 48 * gap : -4 + 50 * gap;
      c.translate(cx + s * edge, wrist + 3 * gap);
      c.rotate(s * (cupped ? 0.3 * gap - 0.08 : 0.24 * gap));
      if (!left) c.scale(-1, 1);
      _hand(
        c,
        facing: cupped ? 0.56 + 0.22 * gap : _facing(gap),
        impact: impact,
        spread: gap,
        curl: cupped ? 0.18 : 0,
      );
      c.restore();
    }
  }

  static Offset _rot(Offset o, double a) => Offset(
    o.dx * math.cos(a) - o.dy * math.sin(a),
    o.dx * math.sin(a) + o.dy * math.cos(a),
  );

  static const _palmasTilt = -0.12;
  static const _palmasFacing = 0.9;
  static Offset _palmasOrigin(double cx, double wrist, double impact) =>
      Offset(cx - 26 - 3 * impact, wrist + 2 * impact);
  static Offset _palmasContact(double cx, double wrist, double impact) =>
      _palmasOrigin(cx, wrist, impact) +
      _rot(Offset((2 - _inner) * _palmasFacing, -34), _palmasTilt);

  /// Palmas claras: the left palm waits, the right hand's fingers come down
  /// across it like a stick on a drum head.
  void _palmasPair(Canvas c, double cx, double wrist, double gap, double imp) {
    final o = _palmasOrigin(cx, wrist, imp);
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(_palmasTilt);
    _hand(c, facing: _palmasFacing, impact: imp * 0.5, spread: 0.6);
    c.restore();
    final hit = _palmasContact(cx, wrist, imp);
    final lift = const Offset(0.45, -0.89) * (46 * gap);
    const facing = 0.62;
    c.save();
    c.translate(hit.dx + lift.dx, hit.dy + lift.dy);
    c.rotate(-1.2 + 0.55 * gap);
    c.scale(-1, 1);
    c.translate(-(_tipPad.dx - _inner) * facing, -_tipPad.dy);
    _hand(c, facing: facing, impact: imp, spread: 0.2);
    c.restore();
  }

  /// One hand in local space. [facing] turns it toward the other hand;
  /// [impact] flattens the palm and bends the fingers back; [spread] fans
  /// the fingers (relaxed open hand) and [curl] cups them.
  void _hand(
    Canvas c, {
    required double facing,
    required double impact,
    double spread = 0,
    double curl = 0,
  }) {
    c.save();
    // Inner edge to the origin, then foreshorten about it.
    c.scale(facing * (1 - 0.06 * impact), 1 + 0.02 * impact);
    c.translate(-_inner, 0);

    final skin = Paint()..color = TC.card;
    final shade = Paint()..color = TC.cardShadow;
    final reach = 1 - 0.07 * impact - curl * 0.6;

    void finger(int i, void Function(RRect r) draw) {
      final (x, top, w) = _fingers[i];
      c.save();
      c.translate(x, _fingerBase);
      c.rotate((x / 16) * 0.075 * spread);
      c.scale(1, reach);
      draw(RRect.fromLTRBR(-w / 2, top - _fingerBase, w / 2, 14, _r(w / 2)));
      c.restore();
    }

    void thumb(void Function() draw) {
      c.save();
      c.translate(_thumbAt.dx, _thumbAt.dy);
      c.rotate(0.55 + 0.12 * spread - curl * 1.2);
      draw();
      c.restore();
    }

    // One silhouette: every outline first, then every fill on top.
    for (var i = 0; i < _fingers.length; i++) {
      finger(i, (r) => c.drawRRect(r, _outline));
    }
    c.drawRRect(_palm, _outline);
    for (var i = 0; i < _fingers.length; i++) {
      finger(i, (r) => c.drawRRect(r, skin));
    }
    c.drawRRect(_palm, skin);

    // Volume: the outer edge turns away from the light.
    c.save();
    c.clipRRect(_palm);
    c.drawRect(const Rect.fromLTRB(-30, -80, -13, 0), shade);
    if (impact > 0.02) {
      // The palm flushes where it met the other.
      c.drawRect(
        const Rect.fromLTRB(4, -70, 30, 0),
        Paint()..color = TC.coral.withValues(alpha: 0.26 * impact),
      );
    }
    c.restore();
    for (var i = 0; i < _fingers.length; i++) {
      finger(i, (r) {
        final top = r.top;
        c.drawLine(
          Offset(-r.width * 0.22, top * 0.42),
          Offset(r.width * 0.22, top * 0.42),
          _crease,
        );
        c.drawLine(
          Offset(-r.width * 0.2, top * 0.12),
          Offset(r.width * 0.2, top * 0.12),
          _crease,
        );
      });
    }
    // Palm lines: heart line and life line.
    final lines = Path()
      ..moveTo(-17, -46)
      ..quadraticBezierTo(-2, -40, 12, -48)
      ..moveTo(13, -36)
      ..quadraticBezierTo(2, -26, 6, -12);
    c.drawPath(lines, _crease);

    thumb(() {
      c.drawRRect(_thumb, _outline);
      c.drawRRect(_thumb, skin);
      c.drawLine(const Offset(-3, -22), const Offset(3, -22), _crease);
    });

    c.drawRRect(_cuff, Paint()..color = TC.primary);
    c.drawRRect(_cuff, _cuffLine);
    c.restore();
  }

  // ---- Impacts -----------------------------------------------------------

  static double _easeOut(double k) => 1 - math.pow(1 - k, 3).toDouble();

  /// Comic impact marks fanning up from the fingertips.
  void _lines(Canvas c, Offset at, ClapPose p) {
    final k = p.since / 0.24;
    if (k >= 1) return;
    final e = _easeOut(k);
    final paint = Paint()
      ..color = TC.ink.withValues(alpha: 1 - k * k)
      ..strokeWidth = 3.6 - 1.6 * k
      ..strokeCap = StrokeCap.round;
    for (final deg in [-155.0, -122.0, -90.0, -58.0, -25.0]) {
      final a = deg * math.pi / 180;
      final d = Offset(math.cos(a), math.sin(a));
      final inner = 12 + 30 * e;
      final len = deg == -90 ? 20.0 : 15.0;
      c.drawLine(at + d * inner, at + d * (inner + len * (1 - k * 0.7)), paint);
    }
  }

  /// Sound rings, three echoes expanding from the palms.
  void _rings(Canvas c, Offset at, ClapPose p) {
    const colors = [TC.primary, TC.limeDeep, TC.primary];
    for (var i = 0; i < 3; i++) {
      final k = (p.since - i * 0.08) / 0.6;
      if (k < 0 || k >= 1) continue;
      final e = _easeOut(k);
      c.drawCircle(
        at,
        28 + 98 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - k) + 0.6
          ..color = colors[i].withValues(alpha: 0.85 * (1 - k)),
      );
    }
  }

  /// A lime starburst with sparks.
  void _spark(Canvas c, Offset at, ClapPose p) {
    final s = p.since;
    if (s > 0.5) return;
    final pop = s < 0.1
        ? Curves.easeOutBack.transform(s / 0.1)
        : 1 + 0.08 * ((s - 0.1) / 0.2).clamp(0.0, 1.0);
    final fade = s < 0.14 ? 1.0 : (1 - (s - 0.14) / 0.16).clamp(0.0, 1.0);
    if (fade > 0) {
      final star = Path();
      const points = 9;
      for (var i = 0; i < points * 2; i++) {
        final a = -math.pi / 2 + i * math.pi / points;
        final r = (i.isEven ? 30.0 : 13.0) * pop;
        final o = at + Offset(math.cos(a), math.sin(a)) * r;
        i == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
      }
      star.close();
      c.drawPath(
        star,
        Paint()
          ..color = TC.ink.withValues(alpha: fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
      c.drawPath(star, Paint()..color = TC.sun.withValues(alpha: fade));
    }
    final r = math.Random(p.count * 7919 + 3);
    const colors = [TC.coral, TC.primary, TC.limeDeep, TC.sun];
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + (r.nextDouble() * 2 - 1) * 1.5;
      final v = 220 + r.nextDouble() * 200;
      final k = s / 0.42;
      if (k >= 1) continue;
      final d = Offset(math.cos(a), math.sin(a));
      final travel = v * (1 - math.exp(-3.4 * s)) / 3.4;
      final o = at + d * (18 + travel) + Offset(0, 260 * s * s);
      c.drawLine(
        o,
        o - d * (7 * (1 - k)),
        Paint()
          ..color = colors[i % colors.length].withValues(alpha: 1 - k)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// A brief bright ellipse where the palms meet.
  void _flash(Canvas c, Offset at, ClapPose p, double r) {
    final k = p.since / 0.14;
    if (k >= 1) return;
    c.drawOval(
      Rect.fromCenter(center: at, width: r * (1 + k), height: r * 2.6),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * (1 - k))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  /// Gym chalk thrown off the palms: soft puffs that drift and spread.
  void _chalk(Canvas c, Offset at, ClapPose p) {
    final s = p.since;
    if (s > 1.0) return;
    final r = math.Random(p.count * 104729 + 5);
    const tones = [
      Color(0xFFD9D3DE),
      Color(0xFFC7BFCE),
      Color(0xFFE6E1EA),
      Color(0xFFB9B0C2),
    ];
    final blur = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (var i = 0; i < 26; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final a = side < 0
          ? math.pi + r.nextDouble() * 1.4 - 0.2
          : -r.nextDouble() * 1.4 + 0.2;
      final v = 70 + r.nextDouble() * 170;
      final life = 0.55 + r.nextDouble() * 0.45;
      final k = s / life;
      if (k >= 1) continue;
      final travel = v * (1 - math.exp(-4 * s)) / 4;
      final o =
          at +
          Offset(math.cos(a), math.sin(a)) * travel +
          Offset(0, (r.nextDouble() * 60 - 50) * k + r.nextDouble() * 50 - 25);
      final size = 3 + (6 + r.nextDouble() * 7) * _easeOut(k);
      blur.color = tones[i % tones.length].withValues(alpha: 0.6 * (1 - k));
      c.drawCircle(o, size, blur);
      // A brighter core: chalk is white, its shadow is what shows on cream.
      core.color = Colors.white.withValues(alpha: 0.9 * (1 - k));
      c.drawCircle(o.translate(-1, -1), size * 0.55, core);
    }
  }

  /// The sharp "crack" of palmas claras: a four-point twinkle and specks.
  void _twinkle(Canvas c, Offset at, ClapPose p) {
    final k = p.since / 0.26;
    if (k >= 1) return;
    final e = _easeOut(k);
    final len = 22 * (1 - k * 0.5) * (0.6 + 0.4 * e);
    final paint = Paint()
      ..color = TC.coral.withValues(alpha: 1 - k)
      ..strokeWidth = 3.4 * (1 - k) + 0.8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4 + 0.3;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawLine(at + d * (6 + 8 * e), at + d * (6 + 8 * e + len), paint);
    }
    final r = math.Random(p.count * 31 + 9);
    for (var i = 0; i < 7; i++) {
      final a = math.pi + (r.nextDouble() - 0.5) * 2.4 - 0.4;
      final o =
          at +
          Offset(math.cos(a), math.sin(a)) *
              (10 + 50 * e * (0.5 + r.nextDouble()));
      c.drawCircle(
        o,
        2.4 * (1 - k),
        Paint()..color = (i.isEven ? TC.sun : TC.ink).withValues(alpha: 1 - k),
      );
    }
  }

  /// Air pushed out of the cupped palms: low, soft and round.
  void _puff(Canvas c, Offset at, ClapPose p) {
    final k = p.since / 0.55;
    if (k >= 1) return;
    final e = _easeOut(k);
    final soft = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
      ..color = TC.heroMuted.withValues(alpha: 0.7 * (1 - k));
    for (final s in [-1.0, 1.0]) {
      c.drawCircle(
        at + Offset(s * (14 + 36 * e), 6 + 10 * e),
        8 + 16 * e,
        soft,
      );
    }
    c.drawCircle(at.translate(0, 14 + 8 * e), 6 + 10 * e, soft);
    c.drawOval(
      Rect.fromCenter(
        center: at.translate(0, -24),
        width: 60 + 80 * e,
        height: 90 + 70 * e,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - k)
        ..color = TC.primarySoft.withValues(alpha: 0.9 * (1 - k)),
    );
  }

  /// A warm light behind the hands with slowly turning rays.
  void _glow(Canvas c, Offset at, ClapPose p) {
    final i = p.impact;
    final r = 64 + 40 * i;
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TC.sun.withValues(alpha: 0.35 + 0.65 * i),
            TC.sun.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
    if (i < 0.02) return;
    final ray = Paint()
      ..color = TC.limeShadow.withValues(alpha: 0.9 * i)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var n = 0; n < 12; n++) {
      final a = n * math.pi / 6 + p.seconds * 0.5;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawLine(at + d * 64, at + d * (64 + 34 * i), ray);
    }
  }

  /// An oscilloscope trace under the hands; each clap rings through it.
  void _waveform(Canvas c, Size size, double wrist, ClapPose p) {
    final base = wrist + 10;
    final cx = size.width / 2;
    final s = p.since;
    final path = Path()..moveTo(0, base);
    for (var x = 0.0; x <= size.width; x += 2) {
      final d = (x - cx).abs();
      final front = 340 * s;
      var y = 0.0;
      if (d < front && s < 1.2) {
        final env = math.exp(-s / 0.32) * math.exp(-d / 80);
        final edge = ((front - d) / 18).clamp(0.0, 1.0);
        y = 18 * env * edge * math.sin(0.33 * d - 70 * s);
      }
      path.lineTo(x, base - y);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..color = TC.primary.withValues(alpha: 0.45 + 0.55 * p.impact),
    );
  }

  /// Eighth notes popping off the fingertips and floating away.
  void _notes(Canvas c, Offset at, ClapPose p) {
    final s = p.since;
    if (s > 1.0) return;
    final r = math.Random(p.count * 613 + 1);
    const colors = [TC.primary, TC.coral, TC.limeDeep, TC.sky];
    final flip = p.count.isEven ? 1.0 : -1.0;
    for (var i = 0; i < 3; i++) {
      final dx = ((i - 1) * 55 + (r.nextDouble() * 20 - 10)) * flip;
      final dy = -(95 + r.nextDouble() * 50);
      final k = s / 0.95;
      final travel = 1 - math.exp(-3.2 * s);
      final o =
          at +
          Offset(dx * travel, dy * travel) +
          Offset(math.sin(s * 9 + i) * 4, 0);
      final pop = s < 0.14 ? Curves.easeOutBack.transform(s / 0.14) : 1.0;
      final alpha = k < 0.55 ? 1.0 : (1 - (k - 0.55) / 0.45).clamp(0.0, 1.0);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate((r.nextDouble() - 0.5) * 0.6 + math.sin(s * 6 + i) * 0.12);
      c.scale(pop * (0.9 + 0.25 * r.nextDouble()));
      _note(c, colors[(p.count + i) % colors.length], alpha, beamed: i == 1);
      c.restore();
    }
  }

  void _note(Canvas c, Color color, double alpha, {bool beamed = false}) {
    final ink = Paint()
      ..color = TC.ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color.withValues(alpha: alpha);
    void head(Offset at) {
      c.save();
      c.translate(at.dx, at.dy);
      c.rotate(-0.4);
      final oval = Rect.fromCenter(center: Offset.zero, width: 12, height: 9);
      c.drawOval(oval, ink);
      c.drawOval(oval, fill);
      c.restore();
    }

    if (beamed) {
      head(const Offset(-7, 4));
      head(const Offset(9, 0));
      c.drawLine(const Offset(-1.8, 2), const Offset(-1.8, -18), ink);
      c.drawLine(const Offset(14.2, -2), const Offset(14.2, -22), ink);
      final beam = Path()
        ..moveTo(-1.8, -18)
        ..lineTo(14.2, -22)
        ..lineTo(14.2, -17)
        ..lineTo(-1.8, -13)
        ..close();
      c.drawPath(beam, Paint()..color = TC.ink.withValues(alpha: alpha));
    } else {
      head(Offset.zero);
      c.drawLine(const Offset(5.2, -2), const Offset(5.2, -22), ink);
      final flag = Path()
        ..moveTo(5.2, -22)
        ..cubicTo(6, -15, 14, -14, 11, -5);
      c.drawPath(flag, ink);
    }
  }

  @override
  bool shouldRepaint(ClapStagePainter old) =>
      old.style != style ||
      old.reduced != reduced ||
      old.pose.gap != pose.gap ||
      old.pose.since != pose.since ||
      old.pose.count != pose.count ||
      old.pose.seconds != pose.seconds ||
      old.pose.ghosts.length != pose.ghosts.length;
}

extension on ClapPose {
  /// Reduced motion: a flash at full strength, nothing else.
  ClapPose copyFlash() =>
      ClapPose(gap: gap, since: 0, count: count, seconds: 0);
}

/// A looping demo of one style, for the picker.
class ClapDemo extends StatefulWidget {
  const ClapDemo({super.key, required this.style, this.offset = 0});
  final ClapStyle style;

  /// Seconds into the loop to start, so a grid of demos does not clap in
  /// unison.
  final double offset;

  /// Ta, ta, ta-ta, ta: quarter, quarter, two eighths, quarter.
  static const loop = [0.0, 0.5, 1.0, 1.25, 1.5];
  static const period = 2.4;

  @override
  State<ClapDemo> createState() => _ClapDemoState();
}

class _ClapDemoState extends State<ClapDemo>
    with SingleTickerProviderStateMixin {
  final _cue = ClapCue();
  late final Ticker _ticker;
  int _next = 0;
  double _cycleStart = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration e) {
    final t = e.inMicroseconds / 1e6 + widget.offset;
    while (true) {
      final at = _cycleStart + ClapDemo.loop[_next];
      if (t < at) break;
      _cue.strike();
      _next++;
      if (_next == ClapDemo.loop.length) {
        _next = 0;
        _cycleStart += ClapDemo.period;
      }
      final nextAt = _cycleStart + ClapDemo.loop[_next];
      _cue.expect(Duration(microseconds: ((nextAt - t) * 1e6).round()));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ClapStage(cue: _cue, style: widget.style);
}

/// Bottom sheet listing all ten styles, each clapping. Returns the pick.
Future<ClapStyle?> showClapStylePicker(
  BuildContext context, {
  required ClapStyle current,
}) => showTrainerSheet<ClapStyle>(
  context,
  (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.78,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Alkış görünümü', 'Clap look'), style: TT.h3),
        const SizedBox(height: 4),
        Text(
          tr(
            'Hepsi aynı ritmi çalıyor; beğendiğine dokun.',
            'All play the same rhythm; tap the one you like.',
          ),
          style: TT.small,
        ),
        const SizedBox(height: 12),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
            ),
            itemCount: ClapStyle.values.length,
            itemBuilder: (context, i) {
              final style = ClapStyle.values[i];
              final picked = style == current;
              return Semantics(
                button: true,
                selected: picked,
                label: '${style.title}. ${style.blurb}',
                child: GestureDetector(
                  key: Key('clap_style_${style.name}'),
                  onTap: () => Navigator.of(context).pop(style),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: picked ? TC.primarySoft : TC.canvas,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: picked ? TC.primary : TC.line,
                        width: picked ? 2 : 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: FittedBox(
                            child: ClapDemo(style: style, offset: i * 0.17),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          style.title,
                          style: TT.h3.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          style.blurb,
                          style: TT.small.copyWith(fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  ),
);
