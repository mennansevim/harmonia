import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widget_previews.dart';

import '../../domain/lang.dart';
import '../domain/music.dart';
import '../ui/kit.dart';
import 'particle_flow.dart';

/// One scripted moment of the demo voice.
typedef DemoVoice = ({double? midi, double levelDb, bool listening});

/// A scripted voice for previews only. It never reads or feeds the
/// microphone path and is not imported by the app: the singer starts below
/// the target, glides up to it, holds it for [hold] seconds with a little
/// natural vibrato, then stops. The demo's success mark is part of the
/// script, not a judgement.
class ParticleFlowDemoScript {
  const ParticleFlowDemoScript({this.target = 57});
  final int target;

  static const lead = 0.4, rise = 1.8, hold = 3.0, rest = 1.6;
  static const length = lead + rise + hold + rest;

  /// When the scripted hold is over.
  static const heldUntil = lead + rise + hold;

  DemoVoice at(double t) {
    t %= length;
    if (t < lead || t >= heldUntil) {
      return (midi: null, levelDb: -60, listening: t < heldUntil);
    }
    final s = t - lead;
    // Small, irregular wobble so the held note looks sung, not drawn.
    final wobble =
        0.06 * math.sin(s * 2 * math.pi * 5.2) +
        0.025 * math.sin(s * 2 * math.pi * 1.7 + 1.1);
    if (s < rise) {
      final k = Curves.easeOutCubic.transform(s / rise);
      final start = target - 2.6;
      return (
        midi: start + (target - start) * k + wobble * k,
        levelDb: -34 + 14 * math.min(1, s / 0.5),
        listening: true,
      );
    }
    return (
      midi: target + wobble,
      levelDb: -20 + 2 * math.sin(s * 3.1),
      listening: true,
    );
  }

  /// The scripted success mark: it rises once the hold is complete.
  double flash(double t) {
    final since = t % length - heldUntil;
    if (since < 0 || since > 0.9) return 0;
    final v = since / 0.9;
    return Curves.easeOut.transform(1 - (v - 0.15).abs().clamp(0.0, 1.0));
  }
}

/// Plays [ParticleFlowDemoScript] through a real [ParticleFlow], labelled as
/// a demo so it can never pass for a measurement.
class ParticleFlowDemo extends StatefulWidget {
  const ParticleFlowDemo({
    super.key,
    this.script = const ParticleFlowDemoScript(),
  });
  final ParticleFlowDemoScript script;
  @override
  State<ParticleFlowDemo> createState() => _ParticleFlowDemoState();
}

class _ParticleFlowDemoState extends State<ParticleFlowDemo>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  double _t = 0;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    // Estimates arrive about every 20 ms, as from the live tracker.
    if ((t / 0.02).floor() != (_t / 0.02).floor()) _serial++;
    setState(() => _t = t);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.script;
    final v = s.at(_t);
    return ColoredBox(
      color: TC.canvas,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tag(tr('DEMO · ÖRNEK VERİ', 'DEMO · SAMPLE DATA'), color: TC.koro),
            const SizedBox(height: 12),
            ParticleFlow(
              target: s.target,
              notation: NoteNotation.letter,
              pitchMidi: v.midi,
              pitchSerial: _serial,
              levelDb: v.levelDb,
              listening: v.listening,
              flash: s.flash(_t),
              holdSeconds: ParticleFlowDemoScript.hold,
              height: 300,
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(name: 'Parçacık akışı · A3 demo', size: Size(390, 400))
Widget particleFlowPreview() => const ParticleFlowDemo();
