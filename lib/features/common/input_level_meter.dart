import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';

/// Live input level from the recorder, drawn as a voice ribbon whose height
/// follows the real dBFS level with spring smoothing. Motion advances only
/// when a new level arrives, so silence or a stalled stream looks still.
/// Display only: never a measurement, score or voice/pitch decision.
class InputLevelMeter extends StatefulWidget {
  const InputLevelMeter({super.key, required this.levels, this.height = 96});
  final Stream<double> levels;
  final double height;
  static const floorDb = -60.0;
  @override
  State<InputLevelMeter> createState() => _InputLevelMeterState();
}

class _InputLevelMeterState extends State<InputLevelMeter>
    with SingleTickerProviderStateMixin {
  StreamSubscription<double>? _sub;
  double? _db;
  late final AnimationController _level = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );
  double _phase = 0;
  double _phaseFrom = 0;
  double _phaseTo = 0;

  @override
  void initState() {
    super.initState();
    _level.addListener(() {
      _phase = _phaseFrom + (_phaseTo - _phaseFrom) * _level.value;
    });
    _sub = widget.levels.listen((db) {
      if (!mounted) return;
      final target = ((db - InputLevelMeter.floorDb) / -InputLevelMeter.floorDb)
          .clamp(0.0, 1.0);
      setState(() => _db = db);
      _target = target;
      _phaseFrom = _phase;
      _phaseTo = _phase + 0.55 + target * 0.9;
      if (HarmoniaMotion.reduced(context)) {
        _shown = target;
        _phase = _phaseTo;
      } else {
        _from = _shown;
        _level.forward(from: 0);
      }
    });
    _level.addListener(() {
      final t = Curves.easeOutCubic.transform(_level.value);
      // Rise fast, fall slower (display-only peak decay).
      final eased = _target >= _from ? t : t * 0.6;
      _shown = _from + (_target - _from) * eased;
    });
  }

  double _from = 0, _target = 0, _shown = 0;

  @override
  void dispose() {
    _sub?.cancel();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = context.resultColors;
    final scheme = Theme.of(context).colorScheme;
    final db = _db;
    final (label, color) = db == null
        ? ('bekleniyor', colors.notMeasured)
        : db >= -3
        ? ('çok yüksek — telefondan uzaklaş', colors.incorrect)
        : db < -50
        ? ('çok düşük', colors.notMeasured)
        : ('uygun', palette.coral);
    return Semantics(
      key: const Key('input_level_meter'),
      label: 'Giriş seviyesi: $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _level,
                builder: (context, _) => CustomPaint(
                  painter: _RibbonPainter(
                    level: _shown,
                    phase: _phase,
                    color: color,
                    second: scheme.primary,
                    baseline: palette.line,
                    waiting: db == null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: HarmoniaSpacing.xs),
          Text(
            'Giriş seviyesi: $label',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            'Ses düzeyini gösterir; notanın doğru olduğunu göstermez.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({
    required this.level,
    required this.phase,
    required this.color,
    required this.second,
    required this.baseline,
    required this.waiting,
  });
  final double level, phase;
  final Color color, second, baseline;
  final bool waiting;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = baseline
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    if (waiting || level < 0.02) return;
    // Three layered ribbons; a soft window keeps the edges at rest like a
    // real voice trace. Amplitude is the live level, nothing else.
    final layers = [
      (1.0, 1.0, 3.0, color),
      (0.62, 1.7, 2.0, second.withValues(alpha: 0.7)),
      (0.38, 2.6, 1.6, color.withValues(alpha: 0.45)),
    ];
    for (final (gain, freq, width, c) in layers) {
      final path = Path();
      const steps = 96;
      for (var s = 0; s <= steps; s++) {
        final x = s / steps;
        final window = math.pow(math.sin(math.pi * x), 2).toDouble();
        final y =
            mid -
            math.sin(x * math.pi * 2 * freq * 2 + phase * freq) *
                window *
                level *
                gain *
                (size.height * 0.44);
        s == 0 ? path.moveTo(0, y) : path.lineTo(x * size.width, y);
      }
      if (gain == 1.0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..color = c.withValues(alpha: 0.14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(_RibbonPainter old) =>
      old.level != level ||
      old.phase != phase ||
      old.color != color ||
      old.waiting != waiting;
}
