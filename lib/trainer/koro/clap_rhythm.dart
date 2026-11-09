import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/clap_onset_detector.dart';
import '../../domain/audio/event_rhythm_analyzer.dart';
import '../../domain/audio/rhythm_analyzer.dart';
import '../../domain/audio/rhythm_imitation.dart';
import '../../domain/content/rhythm_patterns.dart';
import '../../domain/lang.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../../infrastructure/audio/pcm16_wav.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../app/scope.dart';
import '../ui/applause_burst.dart';
import '../ui/kit.dart';
import 'aksak_patterns.dart';
import 'your_turn.dart';

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

/// Easy to hard by what makes a clap rhythm hard to echo: syncopations
/// (off-beat claps with no clap on their beat), then off-beat claps, then the
/// rhythm's length in time (error builds up over a long rhythm even after
/// tempo normalisation), then the shortest gap (faster is harder), then the
/// number of claps. Ties keep the catalog order.
List<ClapRhythm> get clapRhythmsEasyToHard {
  (int, int, int, double, int) key(ClapRhythm r) {
    final onBeat = {
      for (final b in r.beats)
        if (b == b.floorToDouble()) b,
    };
    final off = r.beats.where((b) => b != b.floorToDouble());
    var gap = double.infinity;
    for (var i = 1; i < r.beats.length; i++) {
      gap = math.min(gap, (r.beats[i] - r.beats[i - 1]) * 60000 / r.bpm);
    }
    return (
      off.where((b) => !onBeat.contains(b.floorToDouble())).length,
      off.length,
      r.onsetsMs.last,
      -gap,
      r.beats.length,
    );
  }

  final all = clapRhythms.indexed.toList();
  all.sort((a, b) {
    final ka = key(a.$2), kb = key(b.$2);
    for (final c in [
      ka.$1.compareTo(kb.$1),
      ka.$2.compareTo(kb.$2),
      ka.$3.compareTo(kb.$3),
      ka.$4.compareTo(kb.$4),
      ka.$5.compareTo(kb.$5),
      a.$1.compareTo(b.$1),
    ]) {
      if (c != 0) return c;
    }
    return 0;
  });
  return [for (final e in all) e.$2];
}

/// Free-tempo claps (no metronome in the learner's turn) drift, so the first
/// clap is the anchor and, when the learner clapped exactly as many times as
/// the rhythm has, the span first→last clap is scaled to the reference span.
/// The ±tolerance and the zero missing / zero extra rule stay as they were.
/// With a different number of claps nothing is scaled (missing or extra
/// claps already fail). Returns onsets on the reference timeline.
List<int> normalizeClapTempo(List<int> reference, List<int> claps) {
  if (claps.isEmpty || reference.isEmpty) return const [];
  final first = claps.first;
  final span = claps.last - first;
  final refSpan = reference.last - reference.first;
  final scale = claps.length == reference.length && span > 0 && refSpan > 0
      ? refSpan / span
      : 1.0;
  return [
    for (final c in claps) ((c - first) * scale).round() + reference.first,
  ];
}

/// Learner span ÷ reference span, or null when it is not meaningful (claps
/// not equal in number to the rhythm, a single clap, or a zero span).
double? clapSpanRatio(List<int> reference, List<int> claps) {
  if (claps.length != reference.length || claps.length < 2) return null;
  final span = claps.last - claps.first;
  final refSpan = reference.last - reference.first;
  if (span <= 0 || refSpan <= 0) return null;
  return span / refSpan;
}

/// A tempo note is shown only when the pace was off by more than this
/// (same hypothesis threshold as the touch rhythm echo).
const clapTempoNoteThreshold = RhythmImitationOutcome.tempoHintThreshold;

/// "Tempo ≈ %N faster/slower", or null when the pace was close enough.
String? clapTempoNote(double? ratio) {
  if (ratio == null || (ratio - 1).abs() <= clapTempoNoteThreshold) return null;
  final pct = ((ratio - 1).abs() * 100).round();
  return ratio < 1
      ? tr('Tempo ≈ %$pct hızlıydı', 'Tempo was ≈ $pct% faster')
      : tr('Tempo ≈ %$pct yavaştı', 'Tempo was ≈ $pct% slower');
}

/// One synthesised hand clap (no recorded samples), modelled on how a real
/// clap sounds: three or four very short noise bursts a few milliseconds
/// apart as the palms meet, then a short body, band-passed around 1.2 kHz
/// where the cupped palms resonate, with a little air on top and two faint
/// room reflections. Ends silent within 200 ms.
List<double> renderClap({int sampleRateHz = 48000}) {
  final rate = sampleRateHz;
  final n = (0.2 * rate).round();
  final noise = math.Random(11);
  // RBJ band-pass at 1.2 kHz, Q 0.9.
  final w0 = 2 * math.pi * 1200 / rate, alpha = math.sin(w0) / (2 * 0.9);
  final a0 = 1 + alpha, a1 = -2 * math.cos(w0), a2 = 1 - alpha;
  var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0, hp = 0.0;
  const bursts = [
    (0.0, 0.85, 0.0022),
    (8.0, 0.7, 0.0025),
    (16.0, 1.0, 0.0028),
    (24.0, 0.55, 0.045),
  ];
  final dry = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    var env = 0.0;
    for (final (ms, gain, decay) in bursts) {
      final d = t - ms / 1000;
      if (d >= 0) env += gain * math.exp(-d / decay);
    }
    final white = noise.nextDouble() * 2 - 1;
    final band = (alpha * white - alpha * x2 - a1 * y1 - a2 * y2) / a0;
    x2 = x1;
    x1 = white;
    y2 = y1;
    y1 = band;
    final air = white - hp;
    hp = white;
    dry[i] = env * (band * 2.2 + air * 0.25);
  }
  final out = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    out[i] = dry[i];
    for (final (ms, gain) in const [(19, 0.18), (37, 0.1)]) {
      final j = i - ms * rate ~/ 1000;
      if (j >= 0) out[i] += dry[j] * gain;
    }
  }
  final fade = (0.04 * rate).round();
  for (var i = 0; i < fade; i++) {
    out[n - 1 - i] *= i / fade;
  }
  final peak = out.fold(0.0, (m, v) => math.max(m, v.abs()));
  return [for (final v in out) v / peak * 0.9];
}

/// Claps on [onsetsMs], mixed from one [renderClap].
Pcm16Wav renderClapTrack(
  List<int> onsetsMs, {
  int sampleRateHz = 48000,
  int tailMs = 300,
}) {
  if (onsetsMs.isEmpty) throw ArgumentError('Clap track needs onsets');
  final clap = renderClap(sampleRateHz: sampleRateHz);
  final length = ((onsetsMs.last + tailMs) * sampleRateHz / 1000).ceil();
  final samples = List<double>.filled(length, 0);
  for (final onset in onsetsMs) {
    final start = (onset * sampleRateHz / 1000).round();
    for (var i = 0; i < clap.length && start + i < length; i++) {
      samples[start + i] += clap[i];
    }
  }
  return Pcm16Wav(
    sampleRateHz: sampleRateHz,
    samples: [for (final s in samples) s.clamp(-1.0, 1.0)],
  );
}

/// Count-in: [beats] woodblock-like ticks at [bpm], the first one accented.
Pcm16Wav renderCountIn(double bpm, {int beats = 4, int sampleRateHz = 48000}) {
  final step = 60000 / bpm;
  final length = ((step * beats) * sampleRateHz / 1000).ceil();
  final samples = List<double>.filled(length, 0);
  for (var b = 0; b < beats; b++) {
    final start = (b * step * sampleRateHz / 1000).round();
    final hz = b == 0 ? 1760.0 : 1320.0;
    for (var i = 0; i < 0.05 * sampleRateHz && start + i < length; i++) {
      final t = i / sampleRateHz;
      samples[start + i] +=
          (b == 0 ? 0.6 : 0.45) *
          math.exp(-t / 0.012) *
          math.sin(2 * math.pi * hz * t);
    }
  }
  return Pcm16Wav(sampleRateHz: sampleRateHz, samples: samples);
}

/// Hears the learner's claps. [start] resolves once the microphone is
/// really open; [onClap] gets ms since then.
abstract interface class ClapListener {
  Future<bool> requestPermission();
  Future<void> start(void Function(int ms) onClap);
  Future<void> stop();
  Future<void> close();
}

class MicClapListener implements ClapListener {
  final _backend = PluginAudioLabBackend(livePcm: true);
  StreamSubscription<List<double>>? _samples;

  @override
  Future<bool> requestPermission() => _backend.requestMicrophonePermission();

  @override
  Future<void> start(void Function(int ms) onClap) async {
    final detector = ClapOnsetDetector(onClap: onClap);
    await _samples?.cancel();
    _samples = _backend.liveSamples.listen(
      (chunk) => detector.add(chunk, _backend.liveSampleRateHz),
    );
    await _backend.startCapture();
  }

  /// Nothing is kept: the claps were the only thing read from the audio.
  @override
  Future<void> stop() async {
    await _samples?.cancel();
    _samples = null;
    await _backend.discardCapture();
  }

  @override
  Future<void> close() async {
    await _samples?.cancel();
    await _backend.close();
  }
}

enum _Step { ready, listening, countIn, yourTurn, result, denied }

/// Clap-back training: hear a rhythm (hands clap with it), get a count-in at
/// its tempo, then clap it back while the microphone listens. Both rhythms
/// are compared beat by beat with the shared rhythm matcher (±120 ms); the
/// first clap anchors the answer, so device latency and a late start do not
/// count. A clean echo opens the next, harder rhythm. Practice progress
/// only: nothing reaches XP, mastery or history.
class ClapRhythmScreen extends StatefulWidget {
  const ClapRhythmScreen({
    super.key,
    this.player,
    this.listener,
    this.random,
    this.onRoundFinished,
  });

  /// Called once when a round ends with claps heard (a round was done, not
  /// necessarily passed). Used by the exam route's echo step.
  final VoidCallback? onRoundFinished;
  final ReferenceClipPlayer? player;
  final ClapListener? listener;
  final math.Random? random;
  @override
  State<ClapRhythmScreen> createState() => _ClapRhythmScreenState();
}

class _ClapRhythmScreenState extends State<ClapRhythmScreen>
    with TickerProviderStateMixin {
  late final List<ClapRhythm> _ladder = clapRhythmsEasyToHard;
  late int _level;
  late ClapRhythm _rhythm;
  late final AnimationController _clap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  Ticker? _ticker;
  ReferenceClipPlayer? _player;
  ClapListener? _ear;
  _Step _step = _Step.ready;
  int _next = 0;
  int _hit = -1;
  int _count = 0;
  final List<int> _claps = [];
  Timer? _finish;
  RhythmAnalysisResult? _result;
  double? _spanRatio;
  int _run = 0;
  int _cheers = 0;

  @override
  void initState() {
    super.initState();
    _level = 0;
    _rhythm = _ladder.first;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_step == _Step.ready && _result == null && _run == 0) {
      _level = TrainerScope.read(
        context,
      ).store.clapLevel.clamp(0, _ladder.length - 1);
      _rhythm = _ladder[_level];
    }
  }

  @override
  void dispose() {
    _run++;
    _ticker?.dispose();
    _finish?.cancel();
    _clap.dispose();
    _player?.close();
    final ear = _ear;
    if (ear != null) unawaited(ear.stop().whenComplete(ear.close));
    super.dispose();
  }

  bool get _sound =>
      TrainerScope.read(context).liveAudio || widget.player != null;

  Future<void> _playWav(List<int> bytes) async {
    if (!_sound) return;
    try {
      _player ??= widget.player ?? JustAudioClipPlayer();
      await _player!.playWav(bytes);
    } catch (_) {
      // The animation still shows the rhythm without sound.
    }
  }

  void _bang() => _clap.forward(from: 0).then((_) {
    if (mounted) _clap.reverse();
  });

  /// Listen → count-in → your turn, as one run.
  Future<void> _go() async {
    final run = ++_run;
    _ticker?.dispose();
    _finish?.cancel();
    final onsets = _rhythm.onsetsMs;
    setState(() {
      _step = _Step.listening;
      _next = 0;
      _hit = -1;
      _result = null;
      _claps.clear();
    });
    await _playWav(renderClapTrack(onsets).encode());
    if (!mounted || run != _run) return;
    final done = Completer<void>();
    _ticker = createTicker((elapsed) {
      final ms = elapsed.inMilliseconds;
      var hit = false;
      while (_next < onsets.length && ms >= onsets[_next]) {
        _next++;
        hit = true;
      }
      if (hit) {
        _bang();
        setState(() => _hit = _next - 1);
      }
      if (ms >= onsets.last + 500) {
        _ticker?.stop();
        if (!done.isCompleted) done.complete();
      }
    })..start();
    await done.future;
    if (!mounted || run != _run) return;
    await _countIn(run);
    if (!mounted || run != _run) return;
    await _listen(run);
  }

  Future<void> _countIn(int run) async {
    final step = Duration(milliseconds: (60000 / _rhythm.bpm).round());
    setState(() => _step = _Step.countIn);
    unawaited(_playWav(renderCountIn(_rhythm.bpm).encode()));
    for (var b = 1; b <= 4; b++) {
      if (!mounted || run != _run) return;
      setState(() => _count = b);
      await Future<void>.delayed(step);
    }
  }

  Future<void> _listen(int run) async {
    final ear = _ear ??= widget.listener ?? MicClapListener();
    bool granted;
    try {
      granted = await ear.requestPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted || run != _run) return;
    if (!granted) {
      setState(() => _step = _Step.denied);
      return;
    }
    // The hand-over: a felt and heard "go" before the microphone opens, so
    // the cue itself is never taken for a clap.
    HapticFeedback.heavyImpact();
    await _playWav(renderGoCue().encode());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || run != _run) return;
    try {
      await ear.start((ms) {
        if (!mounted || run != _run || _step != _Step.yourTurn) return;
        _bang();
        setState(() => _claps.add(ms));
        _armFinish(run);
      });
    } catch (_) {
      if (mounted) setState(() => _step = _Step.denied);
      return;
    }
    if (!mounted || run != _run) return;
    setState(() => _step = _Step.yourTurn);
    _armFinish(run);
  }

  /// Ends the turn after a pause: the rhythm's longest gap plus the match
  /// window once every clap is in, otherwise 2.5 s (6 s before the first).
  void _armFinish(int run) {
    _finish?.cancel();
    final onsets = _rhythm.onsetsMs;
    var longest = 0;
    for (var i = 1; i < onsets.length; i++) {
      longest = math.max(longest, onsets[i] - onsets[i - 1]);
    }
    final wait = _claps.isEmpty
        ? const Duration(seconds: 6)
        : _claps.length >= onsets.length
        ? Duration(
            milliseconds: math.max(
              600,
              longest + RhythmAnalysisDefaults.toleranceMs,
            ),
          )
        : const Duration(milliseconds: 2500);
    _finish = Timer(wait, () => _judge(run));
  }

  Future<void> _judge(int run) async {
    _finish?.cancel();
    if (!mounted || run != _run || _step != _Step.yourTurn) return;
    await _ear?.stop();
    if (!mounted || run != _run) return;
    final reference = _rhythm.onsetsMs;
    final result = _claps.isEmpty
        ? null
        : await EventRhythmAnalyzer().analyze(
            RhythmAnalysisRequest(
              expectedOnsetsMs: reference,
              userOnsetsMs: normalizeClapTempo(
                reference,
                _claps.take(256).toList(),
              ),
            ),
          );
    if (!mounted || run != _run) return;
    final passed = _passed(result);
    if (result != null) widget.onRoundFinished?.call();
    if (passed) {
      final store = TrainerScope.read(context).store;
      if (_level + 1 > store.clapLevel && _level + 1 < _ladder.length) {
        store.clapLevel = _level + 1;
        store.save();
      }
    }
    setState(() {
      _result = result;
      _spanRatio = clapSpanRatio(reference, _claps.take(256).toList());
      _step = _Step.result;
      if (passed) _cheers++;
    });
  }

  bool _passed(RhythmAnalysisResult? r) =>
      r != null &&
      r.matchedCount == _rhythm.onsetsMs.length &&
      r.missedCount == 0 &&
      r.extraCount == 0;

  void _moveTo(int level) {
    _run++;
    _ticker?.dispose();
    _ticker = null;
    _finish?.cancel();
    setState(() {
      _level = level.clamp(0, _ladder.length - 1);
      _rhythm = _ladder[_level];
      _result = null;
      _claps.clear();
      _hit = -1;
    });
    _go();
  }

  @override
  Widget build(BuildContext context) {
    final r = _rhythm;
    final turkish = r.family == RhythmFamily.turkish;
    final result = _result;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: tr('Alkışla ritim', 'Clap the rhythm'),
              progress: (_level + 1) / _ladder.length,
              progressColor: TC.koro,
            ),
            Expanded(
              child: FitOrScroll(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      Tag(
                        tr(
                          'SEVİYE ${_level + 1}/${_ladder.length} · ${turkish ? 'TÜRK MÜZİĞİ' : 'BATI MÜZİĞİ'}',
                          'LEVEL ${_level + 1}/${_ladder.length} · ${turkish ? 'TURKISH' : 'WESTERN'}',
                        ),
                        color: turkish ? TC.koro : TC.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.title,
                        key: const Key('clap_title'),
                        textAlign: TextAlign.center,
                        style: TT.h2,
                      ),
                      Text(
                        tr(
                          '${r.onsetsMs.length} alkış · ${r.bpm.round()} BPM',
                          '${r.onsetsMs.length} claps · ${r.bpm.round()} BPM',
                        ),
                        style: TT.small,
                      ),
                      const SizedBox(height: 20),
                      ApplauseBurst(
                        shot: _cheers,
                        child: _Hands(clap: _clap),
                      ),
                      const SizedBox(height: 14),
                      if (_step == _Step.yourTurn)
                        YourTurnCue(
                          action: tr('Alkışla!', 'Clap!'),
                          detail: _hint(result),
                        )
                      else ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _headline(result),
                            key: const Key('clap_status'),
                            textAlign: TextAlign.center,
                            style: _step == _Step.countIn
                                ? TT.h1.copyWith(color: TC.koro)
                                : TT.h3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _hint(result),
                          textAlign: TextAlign.center,
                          style: TT.small,
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_step == _Step.result || _step == _Step.yourTurn)
                        _ClapCompare(
                          reference: r.onsetsMs,
                          claps: _claps,
                          result: _step == _Step.result ? result : null,
                        )
                      else
                        _Beats(rhythm: r, hit: _hit),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(children: _buttons(result)),
            ),
          ],
        ),
      ),
    );
  }

  String _headline(RhythmAnalysisResult? result) => switch (_step) {
    _Step.ready => tr(
      'Dinle, sonra aynısını alkışla',
      'Listen, then clap it back',
    ),
    _Step.listening => tr('Dinle', 'Listen'),
    _Step.countIn => '$_count',
    _Step.yourTurn => tr('Sıra sende!', 'Your turn!'),
    _Step.denied => tr('Mikrofon gerekli', 'Microphone needed'),
    _Step.result =>
      result == null
          ? tr('Alkış duyamadım', 'No claps heard')
          : _passed(result)
          ? tr('Ritmi yakaladın', 'You caught the rhythm')
          : tr('Henüz tam değil', 'Not quite yet'),
  };

  String _hint(RhythmAnalysisResult? result) {
    final base = _baseHint(result);
    final note = _step == _Step.result ? clapTempoNote(_spanRatio) : null;
    return note == null ? base : '$base $note.';
  }

  String _baseHint(RhythmAnalysisResult? result) {
    switch (_step) {
      case _Step.ready:
        return tr(
          'Eller ritmi alkışlar. Ardından tempoda 4 sayarım; "Sıra sende" yazınca aynı ritmi alkışla.',
          'The hands clap the rhythm. Then I count four at its tempo; at "Your turn", clap it back.',
        );
      case _Step.listening:
        return tr(
          'Alkışları say, aralıkları hisset.',
          'Count the claps, feel the gaps.',
        );
      case _Step.countIn:
        return tr('Tempoyu tut…', 'Keep the tempo…');
      case _Step.yourTurn:
        return tr(
          '${_claps.length}/${_rhythm.onsetsMs.length} alkış · mikrofon açık',
          '${_claps.length}/${_rhythm.onsetsMs.length} claps · microphone on',
        );
      case _Step.denied:
        return tr(
          'Alkışlarını duymak için mikrofon izni ver: Ayarlar > Vocalart > Mikrofon.',
          'Allow the microphone to hear your claps: Settings > Vocalart > Microphone.',
        );
      case _Step.result:
        if (result == null) {
          return tr(
            'Telefonu yakına koy ve net alkışla. Gürültülü yerde alkışlar seçilemeyebilir.',
            'Keep the phone close and clap clearly. In a noisy room claps may be missed.',
          );
        }
        if (_passed(result)) {
          final store = TrainerScope.of(context).store;
          return store.clapLevel > _level
              ? tr(
                  'Seviye ${store.clapLevel + 1} açıldı.',
                  'Level ${store.clapLevel + 1} unlocked.',
                )
              : tr(
                  'Son seviyedesin; istediğin ritmi tekrar et.',
                  'Top level; repeat any rhythm you like.',
                );
        }
        final parts = [
          if (result.missedCount > 0)
            tr(
              '${result.missedCount} alkış eksik',
              '${result.missedCount} missing',
            ),
          if (result.extraCount > 0)
            tr('${result.extraCount} fazla', '${result.extraCount} extra'),
        ];
        final worst = result.alignment
            .where((m) => m.isMatched && m.offsetMs != null)
            .fold<int?>(
              null,
              (w, m) =>
                  w == null || m.offsetMs!.abs() > w.abs() ? m.offsetMs : w,
            );
        if (worst != null && worst.abs() > 60) {
          parts.add(
            tr(
              'en büyük kayma ${worst.abs()} ms ${worst > 0 ? 'geç' : 'erken'}',
              'largest slip ${worst.abs()} ms ${worst > 0 ? 'late' : 'early'}',
            ),
          );
        }
        return '${parts.join(' · ')}. ${tr('Bir kez daha dinle.', 'Listen once more.')}';
    }
  }

  List<Widget> _buttons(RhythmAnalysisResult? result) {
    switch (_step) {
      case _Step.ready:
        return [
          BigButton(
            key: const Key('clap_start'),
            label: tr('Dinle ve başla', 'Listen and start'),
            icon: Ic.volume2,
            onPressed: _go,
          ),
        ];
      case _Step.listening:
      case _Step.countIn:
        return const [];
      case _Step.yourTurn:
        return [
          BigButton(
            key: const Key('clap_done'),
            label: tr('Bitirdim', 'I am done'),
            icon: Ic.check,
            onPressed: () => _judge(_run),
          ),
        ];
      case _Step.denied:
        return [
          BigButton(
            key: const Key('clap_retry'),
            label: tr('Tekrar dene', 'Try again'),
            onPressed: _go,
          ),
        ];
      case _Step.result:
        if (_passed(result)) {
          return [
            BigButton(
              key: const Key('clap_next'),
              label: _level + 1 < _ladder.length
                  ? tr('Sonraki ritim', 'Next rhythm')
                  : tr('Baştan başla', 'Start over'),
              icon: Ic.arrowRight,
              onPressed: () =>
                  _moveTo(_level + 1 < _ladder.length ? _level + 1 : 0),
            ),
            TextLink(
              tr('Bunu tekrar alkışla', 'Clap this again'),
              key: const Key('clap_again'),
              onTap: _go,
            ),
          ];
        }
        return [
          BigButton(
            key: const Key('clap_again'),
            label: tr('Tekrar dinle ve alkışla', 'Listen and clap again'),
            icon: Ic.rotateCcw,
            onPressed: _go,
          ),
          if (_level > 0)
            TextLink(
              tr('Bir önceki ritme dön', 'Back to the previous rhythm'),
              key: const Key('clap_easier'),
              onTap: () => _moveTo(_level - 1),
            ),
        ];
    }
  }
}

/// Reference claps above, the learner's below, anchored on the first clap.
/// Matched pairs are joined and labelled with their offset; missed reference
/// claps stay hollow, extra claps are coral.
class _ClapCompare extends StatelessWidget {
  const _ClapCompare({
    required this.reference,
    required this.claps,
    required this.result,
  });
  final List<int> reference;
  final List<int> claps;
  final RhythmAnalysisResult? result;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tr(
      'Referans ${reference.length} alkış, sen ${claps.length} alkış',
      'Reference ${reference.length} claps, you ${claps.length} claps',
    ),
    child: ExcludeSemantics(
      child: SizedBox(
        key: const Key('clap_compare'),
        height: 132,
        width: double.infinity,
        child: CustomPaint(
          painter: _ComparePainter(
            base: DefaultTextStyle.of(context).style,
            reference: reference,
            claps: claps,
            result: result,
          ),
        ),
      ),
    ),
  );
}

class _ComparePainter extends CustomPainter {
  _ComparePainter({
    required this.base,
    required this.reference,
    required this.claps,
    required this.result,
  });
  final TextStyle base;
  final List<int> reference, claps;
  final RhythmAnalysisResult? result;

  void _text(Canvas c, String s, Offset at, Color colour, {bool bold = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: base.merge(
          TT.small.copyWith(
            fontSize: 11,
            color: colour,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: bold ? 1.2 : 0,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(c, at - Offset(p.width / 2, p.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final first = claps.isEmpty ? 0 : claps.first;
    final mine = [for (final c in claps) c - first + reference.first];
    final end = math.max(reference.last, mine.isEmpty ? 0 : mine.last) + 150;
    const left = 12.0;
    final w = size.width - left * 2;
    double x(int ms) => left + w * ms / end;
    const yRef = 34.0, yYou = 104.0;
    _text(
      canvas,
      tr('REFERANS', 'REFERENCE'),
      Offset(size.width / 2, 8),
      TC.muted,
      bold: true,
    );
    _text(
      canvas,
      tr('SEN', 'YOU'),
      Offset(size.width / 2, size.height - 8),
      TC.muted,
      bold: true,
    );
    final track = Paint()
      ..color = TC.line
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, yRef), Offset(left + w, yRef), track);
    canvas.drawLine(Offset(left, yYou), Offset(left + w, yYou), track);
    final matchedRef = <int>{}, matchedYou = <int>{};
    for (final m in result?.alignment ?? const <RhythmEventMatch>[]) {
      if (!m.isMatched) continue;
      matchedRef.add(m.referenceIndex!);
      matchedYou.add(m.userIndex!);
      final a = Offset(x(reference[m.referenceIndex!]), yRef + 9);
      final b = Offset(x(mine[m.userIndex!]), yYou - 9);
      final off = m.offsetMs ?? 0;
      final colour = off.abs() <= 60 ? TC.teal : TC.amber;
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = colour
          ..strokeWidth = 2,
      );
      if (off.abs() > 25) {
        _text(
          canvas,
          '${off > 0 ? '+' : ''}$off',
          (a + b) / 2 + const Offset(16, 0),
          colour,
        );
      }
    }
    for (var i = 0; i < reference.length; i++) {
      final c = Offset(x(reference[i]), yRef);
      final missed = result != null && !matchedRef.contains(i);
      canvas.drawCircle(c, 8, Paint()..color = missed ? TC.card : TC.koro);
      if (missed) {
        canvas.drawCircle(
          c,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = TC.coral,
        );
      }
    }
    for (var i = 0; i < mine.length; i++) {
      final extra = result != null && !matchedYou.contains(i);
      canvas.drawCircle(
        Offset(x(mine[i]), yYou),
        8,
        Paint()..color = extra ? TC.coral : TC.sun,
      );
      canvas.drawCircle(
        Offset(x(mine[i]), yYou),
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = TC.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_ComparePainter old) => true;
}

/// Two palms seen from the side that swing in from the wrist and meet on
/// every clap, with a burst at the moment of contact.
class _Hands extends StatelessWidget {
  const _Hands({required this.clap});
  final Animation<double> clap;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: clap,
      builder: (context, _) => CustomPaint(
        size: const Size(220, 150),
        painter: _ClapPainter(Curves.easeOut.transform(clap.value)),
      ),
    ),
  );
}

class _ClapPainter extends CustomPainter {
  _ClapPainter(this.v);

  /// 0 = hands open, 1 = palms together.
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final wrist = size.height - 14;
    final glow = Paint()..color = TC.sun.withValues(alpha: 0.35 + 0.45 * v);
    canvas.drawCircle(Offset(cx, wrist - 56), 50 + 16 * v, glow);
    _hand(canvas, cx, wrist, left: true);
    _hand(canvas, cx, wrist, left: false);
    if (v > 0.55) _burst(canvas, Offset(cx, wrist - 112), (v - 0.55) / 0.45);
  }

  void _hand(Canvas canvas, double cx, double wrist, {required bool left}) {
    final s = left ? -1.0 : 1.0;
    canvas.save();
    // Pivot on the wrist: open hands lean out, closed fingertips meet.
    canvas.translate(cx + s * (30 + 16 * (1 - v)), wrist);
    canvas.rotate(s * (0.36 * (1 - v) - 0.18 * v));
    if (left) canvas.scale(-1, 1);
    // Palm facing the viewer, thumb on the inner side (toward the clap).
    final parts = <(Offset, double, RRect)>[
      (
        Offset.zero,
        0,
        RRect.fromLTRBR(-23, -58, 23, -8, const Radius.circular(16)),
      ),
      for (final (x, top) in [
        (-15.0, -90.0),
        (-5.0, -99.0),
        (5.0, -97.0),
        (15.0, -86.0),
      ])
        (
          Offset(x, -50),
          math.pi,
          RRect.fromLTRBR(-5.5, -6, 5.5, -top - 50, const Radius.circular(5.5)),
        ),
      (
        const Offset(-18, -26),
        2.45,
        RRect.fromLTRBR(-6.5, -4, 6.5, 34, const Radius.circular(6.5)),
      ),
    ];
    void each(void Function(RRect r) draw) {
      for (final (at, angle, r) in parts) {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(angle);
        draw(r);
        canvas.restore();
      }
    }

    // Thick ink first, then fill on top: one clean silhouette outline.
    final outline = Paint()
      ..color = TC.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.4;
    each((r) => canvas.drawRRect(r, outline));
    final skin = Paint()..color = TC.card;
    each((r) => canvas.drawRRect(r, skin));
    final crease = Paint()
      ..color = TC.ink.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final x in [-10.0, 0.0, 10.0]) {
      canvas.drawLine(Offset(x, -78), Offset(x, -56), crease);
    }
    final cuff = RRect.fromLTRBR(-20, -12, 20, 4, const Radius.circular(6));
    canvas.drawRRect(cuff, Paint()..color = TC.primary);
    canvas.drawRRect(
      cuff,
      Paint()
        ..color = TC.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );
    canvas.restore();
  }

  void _burst(Canvas canvas, Offset at, double t) {
    final p = Paint()
      ..color = TC.primary.withValues(alpha: 1 - t * 0.6)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    for (final a in [-2.35, -1.9, -1.57, -1.24, -0.8]) {
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(at + d * (10 + 6 * t), at + d * (20 + 10 * t), p);
    }
  }

  @override
  bool shouldRepaint(_ClapPainter old) => old.v != v;
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
