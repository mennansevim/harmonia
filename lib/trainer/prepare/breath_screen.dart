import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/scope.dart';
import '../ui/kit.dart';

/// One phase of the guided breathing loop.
class BreathPhase {
  const BreathPhase(this.label, this.verb, this.seconds);
  final String label;
  final String verb;
  final int seconds;
}

/// Draft layout pattern (in 4 · hold 2 · out 6). Not an educator-approved
/// prescription; replace when EDU-01 content arrives.
const breathPattern = [
  BreathPhase('Al', 'Nefes al', 4),
  BreathPhase('Tut', 'Tut', 2),
  BreathPhase('Ver', 'Yavaşça ver', 6),
];

int get _cycleSeconds => breathPattern.fold(0, (s, p) => s + p.seconds);

/// Daily route "Hazırla" step: a visual + haptic breathing guide. The
/// microphone stays off and nothing is measured or scored; finishing only
/// ticks today's route step. Pops `true` to continue the route, `null` on back.
class BreathScreen extends StatefulWidget {
  const BreathScreen({
    super.key,
    this.totalSeconds = 120,
    this.stepLabel = 'ADIM 1 / 3',
  });

  final int totalSeconds;
  final String stepLabel;

  @override
  State<BreathScreen> createState() => _BreathScreenState();
}

class _BreathScreenState extends State<BreathScreen>
    with WidgetsBindingObserver {
  static const _tick = Duration(milliseconds: 100);

  Timer? _timer;
  int _elapsedMs = 0;
  bool _paused = false;
  int _lastPhase = 0;

  int get _totalMs => widget.totalSeconds * 1000;
  bool get _done => _elapsedMs >= _totalMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_tick, (_) => _advance());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// Leaving the app pauses the guide; it never resumes on its own.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_done && !_paused) {
      setState(() => _paused = true);
    }
  }

  void _advance() {
    if (_paused || _done) return;
    setState(() => _elapsedMs += _tick.inMilliseconds);
    final phase = _phaseAt(_elapsedMs).$1;
    if (phase != _lastPhase) {
      _lastPhase = phase;
      HapticFeedback.lightImpact();
    }
    if (_done) {
      _timer?.cancel();
      TrainerScope.read(context).store.markBreathDone();
      HapticFeedback.mediumImpact();
    }
  }

  /// (phase index, ms into that phase) at [ms] from the start.
  (int, int) _phaseAt(int ms) {
    var inCycle = ms % (_cycleSeconds * 1000);
    for (var i = 0; i < breathPattern.length; i++) {
      final len = breathPattern[i].seconds * 1000;
      if (inCycle < len) return (i, inCycle);
      inCycle -= len;
    }
    return (0, 0);
  }

  String _clock(int ms) {
    final s = (ms / 1000).ceil().clamp(0, 5999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final (index, intoPhase) = _phaseAt(_done ? 0 : _elapsedMs);
    final phase = breathPattern[index];
    final phaseMs = phase.seconds * 1000;
    final left = ((phaseMs - intoPhase) / 1000).ceil();
    final cycles = _elapsedMs ~/ (_cycleSeconds * 1000);
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          children: [
            Row(
              children: [
                BackSquare(onTap: () => Navigator.of(context).pop()),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HAZIRLA · ${widget.stepLabel}', style: TT.caps),
                      const SizedBox(height: 2),
                      const Text('Nefesi hazırla', style: TT.h2),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Kalan süre ${_clock(_totalMs - _elapsedMs)}',
                  excludeSemantics: true,
                  child: Text(
                    _clock(_totalMs - _elapsedMs),
                    key: const Key('breath_clock'),
                    style: const TextStyle(
                      color: TC.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    label: _done
                        ? 'Nefes yönlendirmesi tamamlandı'
                        : _paused
                        ? 'Duraklatıldı'
                        : '${phase.verb}, $left saniye',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 168,
                      height: 168,
                      child: CustomPaint(
                        painter: _RingPainter(_done ? 1 : intoPhase / phaseMs),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _done
                                  ? const Icon(
                                      Ic.check,
                                      size: 52,
                                      color: TC.green,
                                    )
                                  : Text(
                                      '$left',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.w800,
                                        color: TC.ink,
                                        height: 1,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                              const SizedBox(height: 5),
                              Text(
                                _done
                                    ? 'Tamamlandı'
                                    : _paused
                                    ? 'Duraklatıldı'
                                    : phase.verb,
                                style: TT.small,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (var i = 0; i < breathPattern.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_done && i == index
                                  ? TC.primary
                                  : TC.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${breathPattern[i].label} '
                              '${breathPattern[i].seconds}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: !_done && i == index
                                    ? Colors.white
                                    : TC.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Omuzlarını serbest bırak. Zorlanır ya da başın dönerse '
                    'dur. Bu taslak bir yönlendirmedir; ölçüm ya da tıbbi '
                    'değerlendirme değildir.',
                    textAlign: TextAlign.center,
                    style: TT.small,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniCard(
                    icon: Ic.wind,
                    title: '$cycles döngü',
                    subtitle: 'Tamamlanan',
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: _MiniCard(
                    icon: Ic.micOff,
                    title: 'Sessiz mod',
                    subtitle: 'Mikrofon kapalı',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_done)
              BigButton(
                key: const Key('breath_continue'),
                label: 'Derse geç',
                icon: Ic.arrowRight,
                onPressed: () => Navigator.of(context).pop(true),
              )
            else ...[
              BigButton(
                key: const Key('breath_pause'),
                label: _paused ? 'Devam et' : 'Duraklat',
                icon: _paused ? Ic.play : Ic.pause,
                onPressed: () => setState(() => _paused = !_paused),
              ),
              const SizedBox(height: 8),
              SoftButton(
                key: const Key('breath_skip'),
                label: 'Nefesi atla, derse geç',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(icon, color: TC.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TT.title.copyWith(fontSize: 13.5),
                overflow: TextOverflow.ellipsis,
              ),
              Text(subtitle, style: TT.small.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final ring = rect.deflate(stroke / 2);
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2,
      Paint()..color = TC.primarySoft,
    );
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2 - stroke,
      Paint()..color = Colors.white,
    );
    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = TC.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
