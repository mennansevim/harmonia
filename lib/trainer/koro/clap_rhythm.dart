import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/audio/audio_capture.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/lang.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../../infrastructure/audio/pcm16_wav.dart';
import '../app/scope.dart';
import '../ui/kit.dart';
import 'aksak_patterns.dart';

enum RhythmFamily { western, turkish }

/// One rhythm to clap: onsets in beats at [bpm] beats per minute.
class ClapRhythm {
  const ClapRhythm(this.id, this.title, this.family, this.beats, this.bpm);
  final String id;
  final String title;
  final RhythmFamily family;
  final List<double> beats;
  final double bpm;

  List<int> get onsetsMs => [for (final b in beats) (b * 60000 / bpm).round()];

  factory ClapRhythm.of(RhythmPattern p, RhythmFamily family) => ClapRhythm(
    p.exercise.exercise.id,
    p.title,
    family,
    p.exercise.protocol.rhythmOnsetsBeats,
    p.exercise.protocol.tempoBpm,
  );
}

/// Developer drafts, like the patterns they extend; not educator-approved.
/// Western: the rhythm-echo drafts plus tresillo, son clave and a waltz.
/// Turkish: the aksak drafts plus sofyan (düm – te ke).
List<ClapRhythm> get clapRhythms => [
  for (final p in draftRhythmPatterns) ClapRhythm.of(p, RhythmFamily.western),
  ClapRhythm(
    'draft-clap-tresillo',
    tr('Tresillo (3+3+2)', 'Tresillo (3+3+2)'),
    RhythmFamily.western,
    const [0, 1.5, 3, 4, 5.5, 7],
    90,
  ),
  ClapRhythm(
    'draft-clap-son-clave',
    tr('Son clave (3-2)', 'Son clave (3-2)'),
    RhythmFamily.western,
    const [0, 1.5, 3, 5, 6],
    100,
  ),
  ClapRhythm(
    'draft-clap-waltz',
    tr('Vals (3/4)', 'Waltz (3/4)'),
    RhythmFamily.western,
    const [0, 1, 2, 3, 4, 5],
    120,
  ),
  for (final p in draftAksakPatterns) ClapRhythm.of(p, RhythmFamily.turkish),
  ClapRhythm(
    'draft-clap-sofyan',
    tr('Sofyan (4/4: düm – te ke)', 'Sofyan (4/4: düm – te ke)'),
    RhythmFamily.turkish,
    const [0, 2, 3, 4, 6, 7],
    90,
  ),
];

/// A random rhythm, never the same one twice in a row.
ClapRhythm pickClapRhythm(math.Random random, {String? after}) {
  final pool = clapRhythms.where((r) => r.id != after).toList();
  return pool[random.nextInt(pool.length)];
}

/// Synthesised hand claps (no recorded samples): each clap is three short
/// noise bursts a few milliseconds apart, as real claps are.
Pcm16Wav renderClapTrack(
  List<int> onsetsMs, {
  int sampleRateHz = 48000,
  int tailMs = 500,
}) {
  if (onsetsMs.isEmpty) throw ArgumentError('Clap track needs onsets');
  final length = ((onsetsMs.last + tailMs) * sampleRateHz / 1000).ceil();
  final samples = List<double>.filled(length, 0);
  final noise = math.Random(7);
  for (final onset in onsetsMs) {
    for (final (offsetMs, gain, decay) in const [
      (0.0, 0.55, 0.004),
      (6.0, 0.45, 0.005),
      (12.0, 0.7, 0.018),
    ]) {
      final start = ((onset + offsetMs) * sampleRateHz / 1000).round();
      final n = (0.08 * sampleRateHz).round();
      var last = 0.0;
      for (var i = 0; i < n && start + i < length; i++) {
        final t = i / sampleRateHz;
        final white = noise.nextDouble() * 2 - 1;
        // A first-order high-pass keeps the bright, papery colour of a clap.
        final bright = white - last * 0.6;
        last = white;
        samples[start + i] += gain * math.exp(-t / decay) * bright;
      }
    }
  }
  return Pcm16Wav(
    sampleRateHz: sampleRateHz,
    samples: [for (final s in samples) s.clamp(-1.0, 1.0)],
  );
}

/// Plays a random Western or Turkish rhythm as claps while two hands clap
/// on every onset, driven by the same onset list as the audio. Device output
/// latency is not measured, so the picture may lead the sound slightly.
class ClapRhythmScreen extends StatefulWidget {
  const ClapRhythmScreen({super.key, this.player, this.random});
  final ReferenceClipPlayer? player;
  final math.Random? random;
  @override
  State<ClapRhythmScreen> createState() => _ClapRhythmScreenState();
}

class _ClapRhythmScreenState extends State<ClapRhythmScreen>
    with TickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random();
  late ClapRhythm _rhythm = pickClapRhythm(_random);
  late final AnimationController _clap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  Ticker? _ticker;
  ReferenceClipPlayer? _player;
  int _next = 0;
  int _hit = -1;
  bool _playing = false;

  @override
  void dispose() {
    _ticker?.dispose();
    _clap.dispose();
    _player?.close();
    super.dispose();
  }

  Future<void> _play() async {
    _ticker?.dispose();
    final onsets = _rhythm.onsetsMs;
    setState(() {
      _playing = true;
      _next = 0;
      _hit = -1;
    });
    if (TrainerScope.read(context).liveAudio || widget.player != null) {
      try {
        _player ??= widget.player ?? JustAudioClipPlayer();
        await _player!.playWav(renderClapTrack(onsets).encode());
      } catch (_) {
        // The animation still shows the rhythm without sound.
      }
    }
    if (!mounted) return;
    final end = onsets.last + 400;
    _ticker = createTicker((elapsed) {
      final ms = elapsed.inMilliseconds;
      var hit = false;
      while (_next < onsets.length && ms >= onsets[_next]) {
        _next++;
        hit = true;
      }
      if (hit) {
        _clap.forward(from: 0).then((_) {
          if (mounted) _clap.reverse();
        });
        setState(() => _hit = _next - 1);
      }
      if (ms >= end) {
        _ticker?.stop();
        setState(() => _playing = false);
      }
    })..start();
  }

  void _shuffle() {
    setState(() => _rhythm = pickClapRhythm(_random, after: _rhythm.id));
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final r = _rhythm;
    final turkish = r.family == RhythmFamily.turkish;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: tr('Alkışla ritim', 'Clap the rhythm')),
            Expanded(
              child: FitOrScroll(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      Tag(
                        turkish
                            ? tr('TÜRK MÜZİĞİ · TASLAK', 'TURKISH · DRAFT')
                            : tr('BATI MÜZİĞİ · TASLAK', 'WESTERN · DRAFT'),
                        color: turkish ? TC.koro : TC.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.title,
                        key: const Key('clap_title'),
                        textAlign: TextAlign.center,
                        style: TT.h2,
                      ),
                      const SizedBox(height: 28),
                      _Hands(clap: _clap),
                      const SizedBox(height: 28),
                      _Beats(rhythm: r, hit: _hit),
                      const SizedBox(height: 16),
                      Text(
                        tr(
                          'Önce dinle ve izle, sonra ellerle birlikte alkışla.',
                          'Listen and watch first, then clap along with the hands.',
                        ),
                        textAlign: TextAlign.center,
                        style: TT.small,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  BigButton(
                    key: const Key('clap_random'),
                    label: tr('Rastgele ritim', 'Random rhythm'),
                    icon: Ic.shuffle,
                    onPressed: _playing ? null : _shuffle,
                  ),
                  TextLink(
                    tr('Bunu tekrar çal', 'Play this again'),
                    key: const Key('clap_again'),
                    onTap: _playing ? () {} : _play,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two hands that meet on every clap.
class _Hands extends StatelessWidget {
  const _Hands({required this.clap});
  final Animation<double> clap;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: clap,
      builder: (context, _) {
        final v = Curves.easeOut.transform(clap.value);
        Widget hand(bool left) => Transform.translate(
          offset: Offset((left ? 1 : -1) * 26 * v, 0),
          child: Transform.rotate(
            angle: (left ? 1 : -1) * (0.45 - 0.45 * v),
            child: Transform.flip(
              flipX: !left,
              child: Icon(Ic.hand, size: 84, color: TC.ink),
            ),
          ),
        );
        return SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90 + 50 * v,
                height: 90 + 50 * v,
                decoration: BoxDecoration(
                  color: TC.sun.withValues(alpha: 0.25 + 0.5 * v),
                  shape: BoxShape.circle,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [hand(true), const SizedBox(width: 8), hand(false)],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// The onsets on a time line; claps already heard are filled.
class _Beats extends StatelessWidget {
  const _Beats({required this.rhythm, required this.hit});
  final ClapRhythm rhythm;
  final int hit;
  @override
  Widget build(BuildContext context) {
    final ms = rhythm.onsetsMs;
    final span = math.max(1, ms.last);
    // Align instead of LayoutBuilder: the page sizes itself intrinsically.
    return ExcludeSemantics(
      child: SizedBox(
        height: 28,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 13,
              height: 2,
              child: Container(color: TC.line),
            ),
            for (var i = 0; i < ms.length; i++)
              Align(
                alignment: Alignment(-1 + 2 * ms[i] / span, 0),
                child: Container(
                  key: Key('clap_beat_$i'),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: i <= hit ? TC.koro : Colors.white,
                    border: Border.all(color: TC.koro, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
