import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/music.dart';
import '../ui/audio_reactive_orb.dart' show emaStep, orbAmplitude;
import '../ui/kit.dart';
import 'voice_waves.dart' show OneEuroFilter, waveLock, voiceWavesOnNoteCents;

/// Holds back one-off jumps in the live pitch (a stray octave or a breath
/// misread): a jump larger than [jumpCents] is taken only once [confirm]
/// estimates in a row agree on it, about 40–60 ms at the ~20 ms estimate
/// rate, so a real change of note still lands promptly.
class PitchSpikeGate {
  PitchSpikeGate({this.jumpCents = 150, this.confirm = 3, this.agree = 80});
  final double jumpCents, agree;
  final int confirm;
  double? _held, _candidate;
  int _count = 0;

  double? get value => _held;

  double accept(double cents) {
    final held = _held;
    if (held == null || (cents - held).abs() <= jumpCents) {
      _candidate = null;
      _count = 0;
      return _held = cents;
    }
    final c = _candidate;
    _count = c != null && (cents - c).abs() <= agree ? _count + 1 : 1;
    _candidate = cents;
    if (_count < confirm) return held;
    _candidate = null;
    _count = 0;
    return _held = cents;
  }

  void reset() {
    _held = _candidate = null;
    _count = 0;
  }
}

/// Purple off the note, a soft green inside the pass window; [lock] is the
/// smoothed 0–1 closeness, so the colour never snaps. The blend runs
/// through hue, so the middle stays a muted blue-teal instead of grey.
Color flowColor(double lock) =>
    Color(_flowRamp[(lock.clamp(0.0, 1.0) * (_flowSteps - 1)).round()]);

const _flowSteps = 48;
final _flowRamp = () {
  final a = HSLColor.fromColor(TC.primaryFill), b = HSLColor.fromColor(TC.teal);
  var dh = b.hue - a.hue;
  if (dh > 180) dh -= 360;
  if (dh < -180) dh += 360;
  return Int32List.fromList([
    for (var i = 0; i < _flowSteps; i++)
      HSLColor.fromAHSL(
        1,
        (a.hue + dh * i / (_flowSteps - 1) + 360) % 360,
        // A little quieter in the middle, so the passage stays calm.
        (a.saturation + (b.saturation - a.saturation) * i / (_flowSteps - 1)) *
            (1 - 0.3 * math.sin(math.pi * i / (_flowSteps - 1))),
        a.lightness + (b.lightness - a.lightness) * i / (_flowSteps - 1),
      ).toColor().toARGB32(),
  ]);
}();

/// The singer's pitch as a light stream of particles along the note lane.
/// A small marker sits at a fixed spot and moves only up and down with the
/// detected pitch; the particles it leaves drift left and fade, so the trail
/// is the pitch history. Loudness changes only how dense and wide the
/// stream is, never its height. With no clear voice nothing is emitted and
/// the stream fades; nothing is invented.
///
/// Display only: the take is still judged on the whole recording, and the
/// success mark shows only when that judgement arrives as [flash].
class ParticleFlow extends StatefulWidget {
  const ParticleFlow({
    super.key,
    required this.target,
    required this.notation,
    this.pitchMidi,
    this.pitchSerial,
    this.levelDb = -60,
    this.listening = false,
    this.reference = false,
    this.flash = 0,
    this.holdSeconds = 3,
    this.height = 230,
  });
  final int target;
  final NoteNotation notation;

  /// Latest live estimate (fractional MIDI), null when no clear pitch.
  final double? pitchMidi;

  /// Changes with every new estimate, so a rebuild for another reason is
  /// not mistaken for a fresh reading. Null: any new value counts.
  final int? pitchSerial;
  final double levelDb;

  /// The microphone take is running.
  final bool listening;

  /// The reference note is sounding.
  final bool reference;

  /// 0–1 after a take the real judgement matched.
  final double flash;

  /// How long the take asks the note to be held; the ring around the
  /// marker fills with time on the note. Progress, not a verdict.
  final double holdSeconds;
  final double height;

  @override
  State<ParticleFlow> createState() => _ParticleFlowState();
}

class _ParticleFlowState extends State<ParticleFlow>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _model = _FlowModel();
  final _gate = PitchSpikeGate();
  final _filter = OneEuroFilter();
  Duration? _last;
  double? _gated;
  double _pitchAge = 1, _silence = 1;
  List<TextPainter>? _labels;
  (int, NoteNotation, TextStyle)? _labelKey;

  @override
  void initState() {
    super.initState();
    _take(null);
    _wake();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _model.reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void didUpdateWidget(ParticleFlow old) {
    super.didUpdateWidget(old);
    if (widget.target != old.target) {
      _model.clear();
      _gate.reset();
      _filter.reset();
      _gated = null;
    }
    if (widget.listening && !old.listening) _model.hold = 0;
    _take(old);
    _wake();
  }

  /// Reads a new estimate once, however often the parent rebuilds.
  void _take(ParticleFlow? old) {
    final m = widget.pitchMidi;
    final fresh = old == null
        ? m != null
        : widget.pitchSerial != null
        ? widget.pitchSerial != old.pitchSerial
        : m != old.pitchMidi;
    if (!fresh || m == null || !widget.listening) return;
    _gated = _gate.accept((m - widget.target) * 100);
    _pitchAge = 0;
  }

  void _wake() {
    if (!_ticker.isActive) {
      _last = null;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _model.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = _last == null
        ? 1 / 60
        : ((now - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    final m = _model..t += dt;
    _pitchAge += dt;
    final level = widget.listening ? orbAmplitude(widget.levelDb) : 0.0;
    m.amp = emaStep(m.amp, level, dt);
    // A short gap in the pitch estimate inside a held note is bridged.
    final sounding =
        widget.listening && _gated != null && _pitchAge < 0.12 && level > 0.03;
    if (sounding) {
      _silence = 0;
      m.marker = _filter.filter(_gated!, math.max(dt, 1e-3));
    } else {
      _silence += dt;
      if (_silence > 0.15) {
        _filter.reset();
        _gate.reset();
        _gated = null;
      }
    }
    final near = sounding ? waveLock(m.marker) : 0.0;
    m.presence = emaStep(
      m.presence,
      sounding ? 1 : 0,
      dt,
      attack: 0.05,
      release: 0.25,
    );
    m.lock = emaStep(m.lock, near, dt, attack: 0.16, release: 0.22);
    if (near > 0.5) {
      m.hold = math.min(widget.holdSeconds, m.hold + dt);
    }
    m.flash = widget.flash;
    m.step(dt, voice: sounding, piano: widget.reference && !widget.listening);
    // Nothing left to move: let the screen rest until the next change.
    if (!widget.listening && !widget.reference && widget.flash == 0 && m.idle) {
      _ticker.stop();
    }
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
    _model.holdSeconds = widget.holdSeconds;
    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('particle_flow'),
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(painter: _FlowPainter(_model, _lanes(base), base)),
        ),
      ),
    );
  }
}

/// A fixed pool of particles in flat arrays: no allocation per frame.
class _FlowModel extends ChangeNotifier {
  static const capacity = 1024;

  /// Seconds a particle lives; at [_FlowPainter.speed] it has crossed the
  /// lane by then on a phone-width screen.
  static const life = 3.4;

  final born = Float64List(capacity);
  final cents = Float32List(capacity);
  final spread = Float32List(capacity);
  final size = Float32List(capacity);
  final alpha = Float32List(capacity);
  final tint = Float32List(capacity);
  final phase = Float32List(capacity);
  final piano = Uint8List(capacity);
  int head = 0, count = 0;
  final _rnd = math.Random(7);

  bool reduced = false;
  double t = 0, amp = 0, presence = 0, lock = 0, flash = 0;
  double holdSeconds = 3, hold = 0;

  /// Smoothed marker position in cents from the target.
  double marker = 0;

  double _emit = 0, _prevCents = 0;
  bool _wasVoice = false;

  bool get idle =>
      presence < 0.01 && (count == 0 || t - born[_oldestLive] > life);

  int get _oldestLive => (head - count + capacity) % capacity;

  void clear() {
    count = 0;
    hold = 0;
    presence = lock = 0;
    marker = _prevCents = 0;
  }

  void _spawn(double at, double c, {required bool fromPiano}) {
    final i = head;
    head = (head + 1) % capacity;
    if (count < capacity) count++;
    // Roughly normal scatter around the line: the stream's thickness.
    final g =
        (_rnd.nextDouble() + _rnd.nextDouble() + _rnd.nextDouble() - 1.5) / 1.5;
    born[i] = at;
    cents[i] = c;
    piano[i] = fromPiano ? 1 : 0;
    spread[i] = g * (fromPiano ? 2.0 : 1.0 + 4.5 * amp);
    size[i] =
        (0.7 + 0.9 * _rnd.nextDouble()) * (fromPiano ? 0.8 : 0.8 + 0.6 * amp);
    alpha[i] = 0.25 + 0.4 * _rnd.nextDouble();
    tint[i] = lock;
    phase[i] = _rnd.nextDouble() * math.pi * 2;
  }

  void step(double dt, {required bool voice, required bool piano}) {
    // A new phrase starts where it is heard, never streaked from the last.
    if (voice && !_wasVoice) _prevCents = marker;
    _wasVoice = voice;
    if (!reduced && (voice || piano)) {
      // Density follows loudness; the height never does.
      final rate = piano ? 45.0 : 30 + 170 * math.max(amp, 0.08);
      _emit += rate * dt;
      final n = _emit.floor();
      _emit -= n;
      for (var k = 0; k < n; k++) {
        final f = (k + 1) / n;
        final c = piano ? 0.0 : _prevCents + (marker - _prevCents) * f;
        _spawn(t - dt * (1 - f), c, fromPiano: piano);
      }
    } else {
      _emit = 0;
    }
    _prevCents = marker;
    // Particles leave from the front of the ring as they age out.
    while (count > 0 && t - born[_oldestLive] > life) {
      count--;
    }
    notifyListeners();
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.m, this.labels, this.base) : super(repaint: m);
  final _FlowModel m;
  final List<TextPainter> labels;
  final TextStyle base;

  static const left = 40.0, speed = 62.0;
  static const _piano = Color(0xFFB8AECB);
  static const _rim = 6;

  // Reused between frames; the painter is rebuilt with the widget.
  static final _pos = Float32List(_FlowModel.capacity * (_rim + 1) * 2);
  static final _col = Int32List(_FlowModel.capacity * (_rim + 1));
  static final _idx = () {
    final out = Uint16List(_FlowModel.capacity * _rim * 3);
    for (var p = 0, o = 0; p < _FlowModel.capacity; p++) {
      final c = p * (_rim + 1);
      for (var k = 0; k < _rim; k++) {
        out[o++] = c;
        out[o++] = c + 1 + k;
        out[o++] = c + 1 + (k + 1) % _rim;
      }
    }
    return out;
  }();
  static final _cos = [
    for (var k = 0; k < _rim; k++) math.cos(k * math.pi / 3),
  ];
  static final _sin = [
    for (var k = 0; k < _rim; k++) math.sin(k * math.pi / 3),
  ];

  static final _pianoRgb = _piano.toARGB32() & 0xFFFFFF;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, cy = h / 2;
    final sem = h / 5.2, soft = h * 0.44, nx = w * 0.74;
    double yOf(double cents) => cy - soft * _tanh(cents / 100 * sem / soft);
    final on = m.lock * m.presence;

    // Lanes: the note and two neighbours each side, as before.
    for (var i = 0; i < 5; i++) {
      final d = 2 - i, y = cy - d * sem;
      if (d == 0) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            left,
            y - 13,
            w - 4,
            y + 13,
            const Radius.circular(13),
          ),
          Paint()
            ..color = Color.lerp(
              TC.primarySoft,
              TC.limeSoft,
              math.max(on, m.flash),
            )!,
        );
        canvas.drawLine(
          Offset(left + 10, y),
          Offset(w - 14, y),
          Paint()
            ..color = flowColor(on).withValues(alpha: 0.35 + 0.25 * on)
            ..strokeWidth = 1,
        );
      } else {
        canvas.drawLine(
          Offset(left, y),
          Offset(w - 4, y),
          Paint()
            ..color = TC.line
            ..strokeWidth = 1,
        );
      }
      final p = labels[i];
      p.paint(canvas, Offset(0, y - p.height / 2));
    }

    // "Now": a faint dashed line where the marker lives.
    final dash = Paint()
      ..color = TC.ink.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    for (var y = 6.0; y < h - 6; y += 7) {
      canvas.drawLine(Offset(nx, y), Offset(nx, math.min(y + 2, h - 6)), dash);
    }

    if (!m.reduced && m.count > 0) _particles(canvas, w, nx, yOf);

    final my = yOf(m.marker);
    if (m.presence > 0.01) {
      final a = m.presence;
      final c = flowColor(m.lock);
      if (!m.reduced) {
        canvas.drawCircle(
          Offset(nx, my),
          11,
          Paint()
            ..shader = ui.Gradient.radial(Offset(nx, my), 11, [
              c.withValues(alpha: 0.28 * a),
              c.withValues(alpha: 0),
            ]),
        );
      }
      // Time on the note, against the length the take asks for.
      final held = m.holdSeconds > 0 ? m.hold / m.holdSeconds : 0.0;
      canvas.drawCircle(
        Offset(nx, my),
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = TC.ink.withValues(alpha: 0.08 * a),
      );
      if (held > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(nx, my), radius: 9),
          -math.pi / 2,
          math.pi * 2 * held,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = TC.teal.withValues(alpha: a),
        );
      }
      canvas.drawCircle(
        Offset(nx, my),
        4.5,
        Paint()..color = c.withValues(alpha: a),
      );
      canvas.drawCircle(
        Offset(nx, my),
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = TC.card.withValues(alpha: a),
      );
      // Off the note the distance is spelled out; on it, the colour says it.
      final cents = m.marker.round();
      if (cents.abs() > voiceWavesOnNoteCents && a > 0.5) {
        final text = TextPainter(
          text: TextSpan(
            text: '${cents > 0 ? '+' : ''}$cents',
            style: base.merge(
              TT.small.copyWith(fontWeight: FontWeight.w700, color: TC.muted),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(math.min(nx + 14, w - text.width), my - 14 - text.height / 2),
        );
      }
    }

    // The verdict, only once the whole take was judged a match.
    if (m.flash > 0.01) {
      final o = Offset(w - 20, cy);
      canvas.drawCircle(
        o,
        10,
        Paint()..color = TC.teal.withValues(alpha: m.flash),
      );
      final tick = Path()
        ..moveTo(o.dx - 4.5, o.dy + 0.2)
        ..lineTo(o.dx - 1.2, o.dy + 3.4)
        ..lineTo(o.dx + 4.6, o.dy - 3.4);
      canvas.drawPath(
        tick,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = TC.card.withValues(alpha: m.flash),
      );
    }
  }

  void _particles(
    Canvas canvas,
    double w,
    double nx,
    double Function(double) yOf,
  ) {
    var n = 0;
    final fadeIn = w * 0.12;
    for (var k = 0; k < m.count; k++) {
      final i =
          (m.head - m.count + k + _FlowModel.capacity) % _FlowModel.capacity;
      final age = m.t - m.born[i];
      final x = nx - age * speed;
      if (x < left || age < 0) continue;
      final life = 1 - age / _FlowModel.life;
      final edge = _smooth(left, left + fadeIn, x);
      final a = m.alpha[i] * life * life * edge;
      if (a < 0.01) continue;
      // Older particles loosen a little, with a slow, small sway.
      final y =
          yOf(m.cents[i]) +
          m.spread[i] * (1 + 0.4 * age) +
          0.6 * math.sin(m.phase[i] + m.t * 1.3) * math.min(1, age);
      final r = m.size[i] * 2;
      final rgb = m.piano[i] == 1
          ? _pianoRgb
          : _flowRamp[(m.tint[i] * (_flowSteps - 1)).round()] & 0xFFFFFF;
      final v = n * (_rim + 1);
      _pos[v * 2] = x;
      _pos[v * 2 + 1] = y;
      _col[v] = ((a.clamp(0.0, 1.0) * 255).round() << 24) | rgb;
      final rim = rgb;
      for (var j = 0; j < _rim; j++) {
        _pos[(v + 1 + j) * 2] = x + r * _cos[j];
        _pos[(v + 1 + j) * 2 + 1] = y + r * _sin[j];
        _col[v + 1 + j] = rim;
      }
      n++;
    }
    if (n == 0) return;
    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_pos, 0, n * (_rim + 1) * 2),
      colors: Int32List.sublistView(_col, 0, n * (_rim + 1)),
      indices: Uint16List.sublistView(_idx, 0, n * _rim * 3),
    );
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    vertices.dispose();
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.m != m || old.labels != labels || old.base != base;
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _tanh(double x) {
  final e = math.exp(2 * x.clamp(-20.0, 20.0));
  return (e - 1) / (e + 1);
}
