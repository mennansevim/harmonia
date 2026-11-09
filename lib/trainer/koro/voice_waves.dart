import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/music.dart';
import '../ui/audio_reactive_orb.dart' show emaStep, orbAmplitude;
import '../ui/kit.dart';
import 'range_ladder.dart';

/// Half-width of the "on the note" colour, from the ladder's own pass rule
/// (closeness ≥ [rangePassMark] in a ±[rangeToleranceCents] window), so the
/// display never disagrees with the judgement. Display only.
const double voiceWavesOnNoteCents =
    rangeToleranceCents * (1 - rangePassMark / 100);

/// 1€ filter (Casiez, Roussel & Vogel, CHI 2012): smooths a lot while the
/// value is steady and little while it moves, so a held note stops
/// trembling without the line lagging behind a slide.
class OneEuroFilter {
  OneEuroFilter({
    // Tuned on ±6-cent jitter at 60 Hz: steady notes settle to about ±2.4
    // cents while a two-semitone jump still lands within a quarter second.
    this.minCutoff = 0.8,
    this.beta = 0.004,
    this.derivativeCutoff = 1,
  });
  final double minCutoff, beta, derivativeCutoff;
  double? _x;
  double _dx = 0;

  double? get value => _x;

  void reset() {
    _x = null;
    _dx = 0;
  }

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  double filter(double x, double dt) {
    final prev = _x;
    if (prev == null) return _x = x;
    if (dt <= 0) return prev;
    _dx += _alpha(derivativeCutoff, dt) * ((x - prev) / dt - _dx);
    final cutoff = minCutoff + beta * _dx.abs();
    return _x = prev + _alpha(cutoff, dt) * (x - prev);
  }
}

/// One moment of the wave: cents from the target, display level 0–1.
class WaveSample {
  const WaveSample({
    required this.cents,
    required this.amp,
    required this.voiced,
    this.piano = false,
  });
  const WaveSample.silent() : cents = 0, amp = 0, voiced = false, piano = false;
  final double cents, amp;
  final bool voiced;

  /// The reference note, not the singer.
  final bool piano;

  static WaveSample lerp(WaveSample a, WaveSample b, double k) => WaveSample(
    cents: a.cents + (b.cents - a.cents) * k,
    amp: a.amp + (b.amp - a.amp) * k,
    voiced: k < 0.5 ? a.voiced : b.voiced,
    piano: k < 0.5 ? a.piano : b.piano,
  );
}

/// History sampled at a fixed [rate], interpolated between frames, so the
/// wave scrolls evenly whatever the frame rate.
class WaveTrack {
  WaveTrack({this.rate = 120, this.seconds = 6});
  final double rate, seconds;
  final _samples = <WaveSample>[];
  double _acc = 0;
  int _total = 0;
  WaveSample? _prev;
  WaveSample _current = const WaveSample.silent();

  WaveSample get current => _current;
  int get length => _samples.length;

  /// Id of the newest sample; ids never shift when old samples drop off, so
  /// a drawing can pin itself to the same moments frame after frame.
  int get newestId => _total - 1;

  /// The sample with [id], or null once it has left the history.
  WaveSample? byId(int id) {
    final i = id - (_total - _samples.length);
    return i < 0 || i >= _samples.length ? null : _samples[i];
  }

  /// Seconds between the sample with [id] and now.
  double ageOf(int id) => (newestId - id) / rate + _acc;

  void add(double dt, WaveSample now) {
    final prev = _prev ?? now;
    _acc += dt;
    final step = 1 / rate;
    while (_acc >= step) {
      _acc -= step;
      final k = dt > 0 ? (1 - _acc / dt).clamp(0.0, 1.0) : 1.0;
      _samples.add(WaveSample.lerp(prev, now, k));
      _total++;
    }
    _prev = now;
    _current = now;
    final max = (rate * seconds).ceil();
    if (_samples.length > max) _samples.removeRange(0, _samples.length - max);
  }

  /// The sample [age] seconds before now, or null before the history.
  WaveSample? at(double age) {
    if (_samples.isEmpty) return null;
    final pos = _samples.length - 1 - (age - _acc) * rate;
    if (pos < 0) return null;
    final i = pos.floor();
    if (i >= _samples.length - 1) return _samples.last;
    return WaveSample.lerp(_samples[i], _samples[i + 1], pos - i);
  }

  void clear() {
    _samples.clear();
    _acc = 0;
    _total = 0;
    _prev = null;
    _current = const WaveSample.silent();
  }
}

/// The singer's voice as layered, flowing waves along the note lane: the
/// right edge is now, the left is what was just sung, each part coloured by
/// how it sat against the note (lavender flat, coral sharp, lime on it).
/// While the piano plays, a soft grey wave sits on the lane. Display only:
/// the take is still judged on the whole recording.
class VoiceWaves extends StatefulWidget {
  const VoiceWaves({
    super.key,
    required this.target,
    required this.notation,
    this.pitchMidi,
    this.levelDb = -60,
    this.listening = false,
    this.reference = false,
    this.flash = 0,
    this.height = 230,
  });
  final int target;
  final NoteNotation notation;

  /// Latest live estimate (fractional MIDI), null when no clear pitch.
  final double? pitchMidi;
  final double levelDb;

  /// The microphone take is running.
  final bool listening;

  /// The reference note is sounding.
  final bool reference;

  /// 0–1 after a take the real judgement matched.
  final double flash;
  final double height;

  @override
  State<VoiceWaves> createState() => _VoiceWavesState();
}

class _VoiceWavesState extends State<VoiceWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_tick);
  late final _model = _WaveModel(widget.target);
  final _filter = OneEuroFilter();
  Duration? _last;
  double? _rawCents;
  double _pitchAge = 1, _silence = 1, _amp = 0;
  List<TextPainter>? _labels;
  (int, NoteNotation, TextStyle)? _labelKey;

  @override
  void initState() {
    super.initState();
    _clock.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model.reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(VoiceWaves old) {
    super.didUpdateWidget(old);
    if (widget.target != old.target) {
      _model
        ..target = widget.target
        ..track.clear();
      _filter.reset();
      _rawCents = null;
    }
    final m = widget.pitchMidi;
    if (m != null && widget.listening) {
      _rawCents = (m - widget.target) * 100;
      _pitchAge = 0;
    }
  }

  @override
  void dispose() {
    _clock
      ..removeListener(_tick)
      ..dispose();
    _model.dispose();
    super.dispose();
  }

  void _tick() {
    final now = _clock.lastElapsedDuration;
    if (now == null) return;
    final dt = _last == null
        ? 1 / 60
        : ((now - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final m = _model..t += dt;
    _pitchAge += dt;
    final level = widget.listening ? orbAmplitude(widget.levelDb) : 0.0;
    _amp = emaStep(_amp, level, dt);
    // A short gap in the pitch estimate inside a held note is bridged.
    final sounding =
        widget.listening &&
        _rawCents != null &&
        _pitchAge < 0.12 &&
        level > 0.03;
    if (sounding) {
      _silence = 0;
    } else {
      _silence += dt;
      if (_silence > 0.15) _filter.reset();
    }
    final WaveSample sample;
    if (widget.reference && !widget.listening) {
      sample = WaveSample(
        cents: 0,
        amp: 0.55 + 0.06 * math.sin(m.t * 2.2),
        voiced: true,
        piano: true,
      );
    } else if (sounding) {
      sample = WaveSample(
        cents: _filter.filter(_rawCents!, math.max(dt, 1e-3)),
        amp: math.max(_amp, 0.08),
        voiced: true,
      );
    } else {
      sample = WaveSample(cents: _filter.value ?? 0, amp: _amp, voiced: false);
    }
    m.track.add(dt, sample);
    m.step(dt, widget.flash);
  }

  List<TextPainter> _lanes(TextStyle base) {
    final key = (widget.target, widget.notation, base);
    if (_labels != null && _labelKey == key) return _labels!;
    _labelKey = key;
    return _labels = [
      for (var d = 2; d >= -2; d--)
        TextPainter(
          text: TextSpan(
            text: PitchClass.midiName(widget.target + d, widget.notation),
            style: base.merge(
              TT.small.copyWith(
                fontSize: d == 0 ? 13 : 11,
                fontWeight: d == 0 ? FontWeight.w800 : FontWeight.w600,
                color: d == 0 ? TC.ink : TC.faint,
              ),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 38),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('voice_waves'),
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WavesPainter(_model, _lanes(base), base),
          ),
        ),
      ),
    );
  }
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _tanh(double x) {
  final e = math.exp(2 * x.clamp(-20.0, 20.0));
  return (e - 1) / (e + 1);
}

/// 0 off the note, 1 well inside the pass window.
double waveLock(double cents) =>
    1 - _smooth(voiceWavesOnNoteCents - 10, voiceWavesOnNoteCents, cents.abs());

/// Blends through hue so in-between colours stay clean (lavender to lime
/// passes teal, coral to lime passes amber) instead of turning grey.
Color _mixHue(Color a, Color b, double t) {
  final x = HSLColor.fromColor(a), y = HSLColor.fromColor(b);
  var dh = y.hue - x.hue;
  if (dh > 180) dh -= 360;
  if (dh < -180) dh += 360;
  return HSLColor.fromAHSL(
    x.alpha + (y.alpha - x.alpha) * t,
    (x.hue + dh * t + 360) % 360,
    x.saturation + (y.saturation - x.saturation) * t,
    x.lightness + (y.lightness - x.lightness) * t,
  ).toColor();
}

const _piano = Color(0xFFB8AECB);

/// Lavender when flat, coral when sharp, lime on the note.
Color waveColor(double cents, {bool fill = false}) {
  final off = cents < 0 ? TC.primaryFill : TC.coral;
  final near = _mixHue(TC.primaryFill, off, _smooth(0, 60, cents.abs()));
  return _mixHue(near, fill ? TC.sun : TC.limeShadow, waveLock(cents));
}

class _Spring {
  double x = 0, v = 0;
  void step(double target, double k, double d, double dt) {
    final n = math.max(1, (dt / 0.008).ceil());
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      v += (k * (target - x) - d * v) * h;
      x += v * h;
    }
  }
}

class _WaveModel extends ChangeNotifier {
  _WaveModel(this.target);
  int target;
  final track = WaveTrack();
  bool reduced = false;
  double t = 0, onset = 0, pulse = 0, shine = 0, emit = 0, flash = 0;
  final bloom = _Spring();
  bool _wasVoiced = false, _wasLocked = false;

  void step(double dt, double flash) {
    this.flash = flash;
    final c = track.current;
    final voice = c.voiced && !c.piano;
    if (voice && !_wasVoiced) onset = 1;
    _wasVoiced = voice;
    onset = math.max(0, onset - dt * 1.4);
    final locked = voice && waveLock(c.cents) > 0.7;
    if (locked && !_wasLocked) pulse = 1;
    _wasLocked = locked;
    pulse = math.max(0, pulse - dt * 1.1);
    bloom.step(voice ? c.amp * (0.6 + 0.4 * waveLock(c.cents)) : 0, 90, 12, dt);
    shine = (shine + dt * 0.7) % 1;
    emit += dt * (0.5 + 1.2 * c.amp);
    notifyListeners();
  }
}

class _Pt {
  _Pt(this.x, this.y, this.s);
  final double x, y;
  final WaveSample s;
  double get err => s.piano ? 0 : math.min(s.cents.abs(), 200) / 200;
}

class _WavesPainter extends CustomPainter {
  _WavesPainter(this.m, this.labels, this.base) : super(repaint: m);
  final _WaveModel m;
  final List<TextPainter> labels;
  final TextStyle base;

  static const _left = 40.0, _speed = 62.0, _dx = 4.0;

  /// At 120 Hz and 62 px/s, every 6th sample is about 3 px apart.
  static const _stride = 6;
  static const _layers = [
    TC.primaryFill,
    TC.coral,
    TC.limeShadow,
    Color(0xFF9C84F0),
    TC.peach,
    TC.primaryDeep,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cy = h / 2;
    final sem = h / 5.2, soft = h * 0.44, nx = w * 0.74;
    final motion = m.reduced ? 0.0 : m.t;
    double yOf(double cents) => cy - soft * _tanh(cents / 100 * sem / soft);
    final cur = m.track.current;
    final voice = cur.voiced && !cur.piano;
    final lock = voice ? waveLock(cur.cents) : 0.0;

    // Lanes: the note and two neighbours each side.
    for (var i = 0; i < 5; i++) {
      final d = 2 - i, y = cy - d * sem;
      if (d == 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            _left,
            y - 13,
            w - 4,
            y + 13,
            const Radius.circular(13),
          ),
          Paint()
            ..color = Color.lerp(
              TC.primarySoft,
              TC.limeSoft,
              math.max(lock, m.flash),
            )!,
        );
      } else {
        canvas.drawLine(
          Offset(_left, y),
          Offset(w - 4, y),
          Paint()
            ..color = TC.line
            ..strokeWidth = 1,
        );
      }
      final p = labels[i];
      p.paint(canvas, Offset(0, y - p.height / 2));
    }

    // Phrases: silence splits the line so a new note never draws a jump.
    // The past is pinned to every [_stride]th sample by id, so each point
    // slides left with its own moment instead of being re-sampled at fixed
    // screen positions (that re-sampling made the trail and its edges crawl).
    final track = m.track;
    final points = <(double, WaveSample?)>[];
    final newest = track.newestId;
    if (newest >= 0) {
      var id = newest - newest % _stride;
      while (id >= 0 && nx - track.ageOf(id) * _speed >= _left - _dx * 2) {
        id -= _stride;
      }
      for (id += _stride; id <= newest; id += _stride) {
        points.add((nx - track.ageOf(id) * _speed, track.byId(id)));
      }
      if (newest % _stride != 0) {
        points.add((nx - track.ageOf(newest) * _speed, track.byId(newest)));
      }
    }
    for (var x = nx + _dx; x <= w + _dx; x += _dx) {
      points.add((x, cur.voiced ? cur : null));
    }
    final runs = <List<_Pt>>[];
    var run = <_Pt>[];
    for (final (x, s) in points) {
      if (s != null && s.voiced && s.amp > 0.04) {
        // The piano's phrase and the singer's are drawn apart, never joined.
        if (run.isNotEmpty && run.last.s.piano != s.piano) {
          runs.add(run);
          run = <_Pt>[];
        }
        run.add(_Pt(x, yOf(s.cents), s));
      } else if (run.isNotEmpty) {
        runs.add(run);
        run = <_Pt>[];
      }
    }
    if (run.isNotEmpty) runs.add(run);
    // A blip shorter than ~0.4 s of trail is noise, not a sung phrase:
    // drawing it would stack the layers into stray dashes.
    runs.removeWhere((r) => r.length < 3 || r.last.x - r.first.x < 24);

    Color tone(WaveSample s, {bool fill = false}) =>
        s.piano ? _piano : waveColor(s.cents, fill: fill);
    Shader along(double alpha, {bool fill = false, Color? tint}) {
      final colors = <Color>[], stops = <double>[];
      for (var i = 0; i <= 14; i++) {
        final x = _left + (w - _left) * i / 14;
        final s = x <= nx ? m.track.at((nx - x) / _speed) : cur;
        var c = s != null && s.voiced ? tone(s, fill: fill) : TC.primaryFill;
        if (tint != null && !(s?.piano ?? false)) c = _mixHue(c, tint, 0.2);
        colors.add(c.withValues(alpha: alpha));
        stops.add(i / 14);
      }
      return ui.Gradient.linear(Offset(_left, 0), Offset(w, 0), colors, stops);
    }

    final ny = voice ? yOf(cur.cents) : cy;
    final bl = math.max(0.0, m.bloom.x) + 0.6 * m.flash;
    if (bl > 0.01 || m.pulse > 0) {
      final r = 30 + 60 * bl + 44 * m.pulse;
      final c = voice ? tone(cur, fill: true) : TC.sun;
      canvas.drawCircle(
        Offset(nx, ny),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(nx, ny), r, [
            c.withValues(alpha: (0.34 * bl + 0.35 * m.pulse).clamp(0.0, 1.0)),
            c.withValues(alpha: 0),
          ]),
      );
    }

    Path smooth(List<Offset> p, [Path? into]) {
      final path = into ?? (Path()..moveTo(p.first.dx, p.first.dy));
      if (into != null) path.lineTo(p.first.dx, p.first.dy);
      for (var i = 1; i < p.length - 1; i++) {
        path.quadraticBezierTo(
          p[i].dx,
          p[i].dy,
          (p[i].dx + p[i + 1].dx) / 2,
          (p[i].dy + p[i + 1].dy) / 2,
        );
      }
      if (p.length > 1) path.lineTo(p.last.dx, p.last.dy);
      return path;
    }

    double att(double x) {
      final u = (x - nx) / (w * 0.3);
      return math.pow(2 / (2 + u * u * u * u), 2).toDouble();
    }

    double taper(_Pt p, List<_Pt> r) =>
        _smooth(0, 26, p.x - r.first.x) *
        (p.x > nx
            ? 1 - _smooth(nx, w, p.x)
            : r.last.x > nx
            ? 1
            : _smooth(0, 26, r.last.x - p.x));

    final core = along(1, fill: true);
    for (final r in runs) {
      if (r.length < 3) continue;
      canvas.drawPath(
        smooth([for (final p in r) Offset(p.x, p.y)]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 9 + 9 * lock
          ..shader = core
          ..color = Colors.white.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Six layers, back to front: all flow right to left with the trail, each
    // a little faster or slower (parallax), phase and height drifting slowly
    // so the motion never repeats. Same direction everywhere keeps it calm.
    final scale = h / 420;
    for (var i = 0; i < _layers.length; i++) {
      final off = (i - 2.5) * 14 * scale;
      final kx = 0.014 * (1 + i * 0.17) / scale.clamp(0.5, 1.0);
      final speed = kx * _speed * (0.85 + i * 0.09);
      final am = (64 - i * 6.5) * scale;
      final drift = 1.2 * math.sin(motion * 0.37 + i * 1.3);
      final fill = Paint()
        ..shader = along(0.3, fill: i.isOdd, tint: _layers[i])
        ..blendMode = BlendMode.multiply;
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 + i / 5 * 0.6
        ..shader = along(0.7, fill: i.isOdd, tint: _layers[i])
        ..blendMode = BlendMode.multiply;
      for (final r in runs) {
        if (r.length < 3) continue;
        final top = [
          for (final p in r)
            Offset(
              p.x,
              p.y +
                  off * p.err +
                  am *
                      p.s.amp *
                      (0.34 + 0.66 * att(p.x)) *
                      taper(p, r) *
                      (1 +
                          0.5 *
                              m.onset *
                              math.exp(-math.pow((p.x - nx) / 46, 2)) +
                          0.3 * m.pulse) *
                      (0.75 +
                          0.25 *
                              math.sin(
                                0.006 * (p.x + motion * _speed) + i * 1.7,
                              )) *
                      math.sin(kx * p.x + motion * speed + drift + i),
            ),
        ];
        final area = smooth(top);
        for (var j = r.length - 1; j >= 0; j--) {
          area.lineTo(r[j].x, r[j].y + off * r[j].err);
        }
        area.close();
        canvas.drawPath(area, fill);
        canvas.drawPath(smooth(top), line);
      }
    }

    final centre = along(0.9);
    for (final r in runs) {
      if (r.length < 3) continue;
      canvas.drawPath(
        smooth([for (final p in r) Offset(p.x, p.y)]),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6
          ..shader = centre,
      );
    }

    // On the note a lime light runs along the sung line.
    if (lock > 0.2 && !m.reduced) {
      final sx = _left + (nx - _left) * m.shine;
      final sweep = ui.Gradient.linear(
        Offset(sx - 80, 0),
        Offset(sx + 80, 0),
        [
          TC.limeShadow.withValues(alpha: 0),
          TC.limeShadow.withValues(alpha: lock),
          TC.limeShadow.withValues(alpha: 0),
        ],
        [0, 0.5, 1],
      );
      for (final r in runs) {
        final past = [
          for (final p in r)
            if (p.x <= nx) Offset(p.x, p.y),
        ];
        if (past.length < 3) continue;
        canvas.drawPath(
          smooth(past),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 4
            ..shader = sweep
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // "Now": a dashed line, and the voice as a dot with its cents.
    final dash = Paint()
      ..color = TC.ink.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    for (var y = 6.0; y < h - 6; y += 7) {
      canvas.drawLine(Offset(nx, y), Offset(nx, math.min(y + 2, h - 6)), dash);
    }
    if (!voice) return;
    final dotFill = tone(cur, fill: true), dotLine = tone(cur);
    for (var i = 0; i < 2; i++) {
      final p = (m.emit + i / 2) % 1;
      canvas.drawCircle(
        Offset(nx, ny),
        6 + Curves.easeOutCubic.transform(p) * 22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = dotLine.withValues(
            alpha: (1 - p) * (1 - p) * 0.55 * cur.amp,
          ),
      );
    }
    final r = 5 + 3 * cur.amp;
    canvas.drawCircle(
      Offset(nx, ny),
      r + 4,
      Paint()
        ..color = dotFill.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset(nx, ny), r, Paint()..color = dotFill);
    canvas.drawCircle(
      Offset(nx, ny),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = TC.ink,
    );
    final cents = cur.cents.round();
    final text = TextPainter(
      text: TextSpan(
        text: lock > 0.6 ? '✓' : '${cents > 0 ? '+' : ''}$cents',
        style: base.merge(
          TT.small.copyWith(
            fontWeight: FontWeight.w800,
            color: lock > 0.6 ? TC.limeDeep : TC.ink,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(math.min(nx + 12, w - text.width), ny - 16 - text.height / 2),
    );
  }

  @override
  bool shouldRepaint(_WavesPainter old) =>
      old.m != m || old.labels != labels || old.base != base;
}
