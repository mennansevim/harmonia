import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/harmonia_theme.dart';
import 'playback_visual.dart';

/// Draws the clip that is actually playing: its real amplitude envelope with
/// a moving playhead, and a zoomed oscilloscope of the samples under the
/// playhead, so a higher tone visibly packs more cycles. Runs only while a
/// clip plays and never longer than the clip; reduced motion shows a still.
class WaveformPlaybackView extends StatefulWidget {
  const WaveformPlaybackView({
    super.key,
    required this.playback,
    this.height = 132,
    this.idleLabel = 'Dinlemek için dokun',
  });

  final ValueListenable<PlaybackVisual?> playback;
  final double height;
  final String idleLabel;

  @override
  State<WaveformPlaybackView> createState() => _WaveformPlaybackViewState();
}

class _WaveformPlaybackViewState extends State<WaveformPlaybackView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);

  /// Frame-clock time since this clip started drawing.
  Duration _elapsed = Duration.zero;
  PlaybackVisual? _visual;
  PlaybackVisual? _last;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _visual = _last = widget.playback.value;
    widget.playback.addListener(_onPlayback);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visual != null && !_reduced && !_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(WaveformPlaybackView old) {
    super.didUpdateWidget(old);
    if (old.playback != widget.playback) {
      old.playback.removeListener(_onPlayback);
      widget.playback.addListener(_onPlayback);
      _onPlayback();
    }
  }

  void _onPlayback() {
    if (!mounted) return;
    final v = widget.playback.value;
    final changed = v != _visual;
    setState(() {
      _visual = v;
      if (v != null) _last = v;
      if (changed) _elapsed = Duration.zero;
    });
    if (_ticker.isActive) _ticker.stop();
    if (v != null && !_reduced) _ticker.start();
  }

  bool get _reduced => mounted && HarmoniaMotion.reduced(context);

  double get _progress {
    final v = _visual;
    if (v == null) return _last == null ? 0 : 1;
    final total = v.duration.inMicroseconds;
    return total == 0 ? 1 : (_elapsed.inMicroseconds / total).clamp(0.0, 1.0);
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    if (_progress >= 1) _ticker.stop();
    _frame.value++;
  }

  @override
  void dispose() {
    widget.playback.removeListener(_onPlayback);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final playing = _visual != null;
    return Semantics(
      label: playing ? 'Ses çalıyor' : widget.idleLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WavePainter(
              repaint: _frame,
              visual: _visual,
              last: _last,
              progressOf: () => _progress,
              reduced: HarmoniaMotion.reduced(context),
              active: palette.wave,
              second: palette.waveSecond,
              track: palette.line,
              glow: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required Listenable repaint,
    required this.visual,
    required this.last,
    required this.progressOf,
    required this.reduced,
    required this.active,
    required this.second,
    required this.track,
    required this.glow,
  }) : super(repaint: repaint);

  final PlaybackVisual? visual;
  final PlaybackVisual? last;
  final double Function() progressOf;
  final bool reduced;
  final Color active, second, track, glow;

  @override
  void paint(Canvas canvas, Size size) {
    final v = visual ?? last;
    final mid = size.height / 2;
    final barArea = Rect.fromLTWH(0, 0, size.width, size.height);
    const buckets = PlaybackVisual.envelopeBuckets;
    const bars = 56;
    final gap = 3.0;
    final barW = math.max(2.0, (barArea.width - gap * (bars - 1)) / bars);
    final progress = reduced && visual != null ? 1.0 : progressOf();

    final trackPaint = Paint()..color = track;
    final playedPaint = Paint()
      ..shader = LinearGradient(
        colors: [active, Color.lerp(active, second, .55)!],
      ).createShader(barArea);

    for (var i = 0; i < bars; i++) {
      double amp;
      if (v == null) {
        // Calm resting shape before anything played.
        amp = 0.10 + 0.06 * math.sin(i / bars * math.pi * 3).abs();
      } else {
        final from = i * buckets ~/ bars;
        final to = math.max(from + 1, (i + 1) * buckets ~/ bars);
        amp = 0.0;
        for (var b = from; b < to; b++) {
          amp = math.max(amp, v.envelope[b]);
        }
        amp = amp <= 0.002 ? 0.04 : 0.12 + 0.88 * math.min(1.0, amp * 1.25);
      }
      final h = amp * (size.height * 0.62);
      final x = i * (barW + gap);
      final played = (i + 0.5) / bars <= progress && v != null;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mid - h / 2, barW, h),
          Radius.circular(barW / 2),
        ),
        played ? playedPaint : trackPaint,
      );
    }

    final live = visual;
    if (live == null || reduced || progress >= 1) return;

    // Playhead.
    final px = progress * size.width;
    canvas.drawLine(
      Offset(px, size.height * 0.08),
      Offset(px, size.height * 0.92),
      Paint()
        ..color = active
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Oscilloscope of the real samples under the playhead (8 ms window).
    final rate = live.sampleRateHz;
    final center = (progress * live.samples.length).floor();
    final window = (rate * 0.008).round();
    final start = (center - window ~/ 2).clamp(0, live.samples.length);
    final end = math.min(live.samples.length, start + window);
    if (end - start < 8) return;
    var peak = 0.0;
    for (var i = start; i < end; i++) {
      peak = math.max(peak, live.samples[i].abs());
    }
    if (peak < 0.01) return; // silence between tones: nothing to draw
    final scopeW = math.min(size.width * 0.46, 180.0);
    final left = (px - scopeW / 2).clamp(0.0, size.width - scopeW);
    final path = Path();
    final steps = math.min(240, end - start);
    for (var s = 0; s <= steps; s++) {
      final idx = start + (s * (end - start - 1) ~/ steps);
      final y =
          mid - live.samples[idx] / math.max(peak, 0.2) * size.height * 0.34;
      final x = left + s / steps * scopeW;
      s == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = glow.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = second,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.visual != visual ||
      old.last != last ||
      old.reduced != reduced ||
      old.active != active;
}
