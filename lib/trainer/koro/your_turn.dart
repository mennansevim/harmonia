import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/lang.dart';
import '../../infrastructure/audio/pcm16_wav.dart';
import '../ui/kit.dart';

/// The hand-over moment of an echo exercise: a lime banner whose microphone
/// badge pulses for as long as the app is listening, so it is obvious that
/// it is now the learner's turn and that the microphone is on.
class YourTurnCue extends StatefulWidget {
  const YourTurnCue({
    super.key,
    required this.action,
    required this.detail,
    this.icon = Ic.mic,
  });

  /// What to do now, e.g. "Alkışla!".
  final String action;
  final String detail;
  final IconData icon;
  @override
  State<YourTurnCue> createState() => _YourTurnCueState();
}

class _YourTurnCueState extends State<YourTurnCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label:
        '${tr('Sıra sende', 'Your turn')}. ${widget.action} ${widget.detail}',
    child: ExcludeSemantics(
      child: Container(
        key: const Key('your_turn'),
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        decoration: BoxDecoration(
          color: TC.sun,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: TC.limeShadow, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return CustomPaint(
                    painter: _RingPainter(t),
                    child: Center(
                      child: Transform.scale(
                        scale: 1 + 0.08 * math.sin(t * 2 * math.pi),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: TC.ink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(widget.icon, color: TC.sun, size: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('SIRA SENDE', 'YOUR TURN'),
                    style: TT.caps.copyWith(color: TC.onSun),
                  ),
                  Text(
                    widget.action,
                    key: const Key('your_turn_action'),
                    style: TT.h2.copyWith(color: TC.onSun),
                  ),
                  Text(
                    widget.detail,
                    style: TT.small.copyWith(color: TC.onSun),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final phase in [0.0, 0.5]) {
      final v = (t + phase) % 1;
      canvas.drawCircle(
        c,
        23 + 9 * v,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = TC.ink.withValues(alpha: 0.5 * (1 - v)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

/// "Go": two quick rising tones played just before the microphone opens.
Pcm16Wav renderGoCue({int sampleRateHz = 48000}) {
  final samples = <double>[];
  for (final hz in const [880.0, 1318.5]) {
    final n = (0.11 * sampleRateHz).round();
    for (var i = 0; i < n; i++) {
      final t = i / sampleRateHz;
      final env = math.min(1.0, t / 0.005) * math.exp(-t / 0.06);
      samples.add(0.45 * env * math.sin(2 * math.pi * hz * t));
    }
  }
  return Pcm16Wav(sampleRateHz: sampleRateHz, samples: samples);
}
