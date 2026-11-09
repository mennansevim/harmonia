import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/melody_session.dart';
import '../../application/single_tone_session.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/live_pitch_tracker.dart';
import '../../domain/audio/pitch_sequence_alignment.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../domain/lang.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/synthetic_melody_backend.dart';
import '../app/scope.dart';
import '../domain/music.dart';
import '../ui/kit.dart';
import 'melody_echo_levels.dart';
import 'your_turn.dart';

/// Melody echo: the reference plays first (notes light up), then the
/// microphone listens, then both shapes are compared note by note. A whole
/// melody matched by the existing exact sequence check moves to the next
/// level. Practice progress only; nothing reaches XP, mastery or history.
class MelodyEchoScreen extends StatefulWidget {
  const MelodyEchoScreen({
    super.key,
    this.backendFactory,
    this.worker,
    this.random,
    this.onRoundFinished,
  });
  final MelodyReferenceBackend Function(DiagnosticMelodyReference)?
  backendFactory;
  final RecordingPitchWorker Function()? worker;
  final math.Random? random;

  /// Called once per round when a measurement was taken (a round was done,
  /// not necessarily passed). Used by the exam route's echo step.
  final VoidCallback? onRoundFinished;
  @override
  State<MelodyEchoScreen> createState() => _MelodyEchoScreenState();
}

/// Synthetic reference timing: 600 ms tones with 200 ms gaps.
const _noteMs = 600, _slotMs = 800;
const _responseWindow = Duration(seconds: 8);

class _MelodyEchoScreenState extends State<MelodyEchoScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final math.Random _random = widget.random ?? math.Random();
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  final Stopwatch _phaseClock = Stopwatch();
  MelodySessionController? _session;
  Future<void>? _closing;
  SingleToneSessionPhase? _seenPhase;
  EchoMelody? _melody;
  List<int> _notes = const [];
  int _level = 0;
  bool _started = false;
  bool _counted = false;
  bool _reported = false;

  /// Whole octaves the melody is moved after a take sung an octave away, so
  /// the next try sits where this voice actually is.
  int _octave = 0;
  int? _octaveHint;

  /// Live display trace of the current answer: ms of captured audio, MIDI
  /// or null. Never scored; the take is judged after it ends.
  final List<(int, double?)> _trace = [];
  StreamSubscription<List<double>>? _live;
  late final LivePitchTracker _tracker = LivePitchTracker(
    onPitch: (hz) {
      if (!mounted ||
          _session?.phase != SingleToneSessionPhase.responding ||
          _trace.length > 600) {
        return;
      }
      setState(
        () => _trace.add((
          // One estimate per 20 ms of captured audio: time from samples,
          // not the wall clock, so UI jank cannot bend the trace.
          _trace.length * 20,
          hz == null ? null : hzToMidi(hz),
        )),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_melody == null) {
      final store = TrainerScope.read(context).store;
      _level = store.melodyEchoLevel.clamp(0, echoLevels.length - 1);
      _pick();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        state != AppLifecycleState.inactive) {
      unawaited(_session?.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick.dispose();
    _live?.cancel();
    final s = _session;
    s?.removeListener(_changed);
    s?.dispose();
    super.dispose();
  }

  void _pick() {
    final store = TrainerScope.read(context).store;
    final (low, high) = echoRange(store.koroRange, store.part);
    final melody = pickEchoMelody(_random, _level, after: _melody?.id);
    _melody = melody;
    _place(placeMelody(melody, low, high, shift: _random.nextInt(5) - 2));
  }

  /// Applies [_octave] while it keeps the reference inside E2–C6.
  void _place(List<int> notes) {
    final moved = [for (final n in notes) n + 12 * _octave];
    final fits = moved.every((n) => n >= 40 && n <= 84);
    _notes = fits ? moved : notes;
    if (!fits) _octave = 0;
  }

  /// The reference is bound to its backend, so a new melody needs a new
  /// session. The old one must finish closing before the next opens.
  void _retire() {
    final old = _session;
    _session = null;
    _live?.cancel();
    _live = null;
    if (old == null) return;
    old.removeListener(_changed);
    _closing = old.close().whenComplete(old.dispose);
  }

  Future<MelodySessionController> _open() async {
    await _closing;
    final reference = DiagnosticMelodyReference(
      id: 'echo-${_melody!.id}',
      contentVersion: 'echo-1',
      frequenciesHz: [for (final m in _notes) midiToHz(m)],
    );
    final backend =
        widget.backendFactory?.call(reference) ??
        SyntheticMelodyBackend.mobile(reference);
    if (backend case final LiveSampleSource live) {
      _live = live.liveSamples.listen(
        (chunk) => _tracker.add(chunk, live.liveSampleRateHz),
      );
    }
    final session = MelodySessionController(
      backend: backend,
      worker: widget.worker?.call() ?? IsolateRecordingPitchWorker(),
      responseWindow: _responseWindow,
    );
    session.addListener(_changed);
    return _session = session;
  }

  void _changed() {
    final s = _session;
    if (!mounted || s == null) return;
    if (s.phase != _seenPhase) {
      _seenPhase = s.phase;
      _phaseClock
        ..reset()
        ..start();
      final animated = {
        SingleToneSessionPhase.calibrating,
        SingleToneSessionPhase.referencePlaying,
        SingleToneSessionPhase.responding,
      }.contains(s.phase);
      animated ? _tick.repeat() : _tick.stop();
      if (s.phase == SingleToneSessionPhase.responding) {
        _trace.clear();
        _tracker.reset();
        HapticFeedback.heavyImpact();
      }
    }
    final outcome = s.outcome;
    if (outcome != null && !_counted) _octaveHint = _octaveAway(outcome);
    if (outcome != null &&
        !_reported &&
        !outcome.needsRetry &&
        outcome.alignment != null) {
      _reported = true;
      widget.onRoundFinished?.call();
    }
    if (outcome != null && !_counted && _passed(outcome)) {
      _counted = true;
      final store = TrainerScope.read(context).store;
      if (_level + 1 > store.melodyEchoLevel &&
          _level + 1 < echoLevels.length) {
        store.melodyEchoLevel = _level + 1;
        store.save();
      }
    }
    setState(() {});
  }

  Future<void> _go() async {
    final s = _session ?? await _open();
    if (!mounted || !s.canStart) return;
    setState(() {
      _started = true;
      _counted = false;
      _reported = false;
      _octaveHint = null;
    });
    final stale =
        s.calibration?.isUsable != true ||
        s.outcome?.retryReason == SessionRetryReason.calibrationRequired;
    if (stale) {
      await s.calibrate();
      if (!mounted || _session != s || s.calibration?.isUsable != true) {
        return;
      }
    }
    await s.startAttempt();
  }

  /// Whole octaves between this take and the reference when most notes
  /// were sung an octave away (an octave error never counts as matched;
  /// this only moves the next try into the singer's octave).
  static int? _octaveAway(MelodySessionOutcome o) {
    final cents = [
      for (final s in o.alignment?.steps ?? const <PitchSequenceStep>[])
        ?s.absoluteCents,
    ]..sort();
    if (cents.length < 2) return null;
    final median = cents[cents.length ~/ 2];
    final octaves = (median / 1200).round();
    return octaves != 0 && (median - octaves * 1200).abs() < 350
        ? octaves
        : null;
  }

  /// Same melody, moved by [_octaveHint] octaves, in a fresh session.
  void _transpose() {
    final shift = _octaveHint;
    if (shift == null) return;
    _retire();
    setState(() {
      _octave += shift;
      _octaveHint = null;
      _place([for (final n in _notes) n - 12 * (_octave - shift)]);
    });
    unawaited(_go());
  }

  void _another() {
    _retire();
    final store = TrainerScope.read(context).store;
    setState(() {
      _level = store.melodyEchoLevel.clamp(0, echoLevels.length - 1);
      _pick();
    });
    unawaited(_go());
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final phase = s?.phase ?? SingleToneSessionPhase.idle;
    final outcome = phase == SingleToneSessionPhase.finished
        ? s?.outcome
        : null;
    final calibrationFailed =
        phase == SingleToneSessionPhase.idle &&
        s?.calibration != null &&
        s!.calibration!.isUsable != true;
    final notation = TrainerScope.of(context).store.notation;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: tr('Ezgi tekrarı', 'Melody echo')),
            Expanded(
              child: FitOrScroll(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: AnimatedBuilder(
                    animation: _tick,
                    builder: (context, _) => Column(
                      children: [
                        Tag(
                          tr(
                            'SEVİYE ${_level + 1}/${echoLevels.length} · ${echoLevels[_level].title.toUpperCase()}',
                            'LEVEL ${_level + 1}/${echoLevels.length} · ${echoLevels[_level].title.toUpperCase()}',
                          ),
                          color: TC.koro,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _melody!.name,
                          key: const Key('echo_melody'),
                          style: TT.h2,
                        ),
                        const SizedBox(height: 22),
                        _EchoGraph(
                          notes: _notes,
                          notation: notation,
                          active:
                              phase == SingleToneSessionPhase.referencePlaying
                              ? _activeNote()
                              : null,
                          revealed: switch (phase) {
                            SingleToneSessionPhase.referencePlaying => math.min(
                              _notes.length,
                              _phaseClock.elapsedMilliseconds ~/ _slotMs + 1,
                            ),
                            SingleToneSessionPhase.preparing => 0,
                            _ => _notes.length,
                          },
                          trace: _trace,
                          verdicts: outcome == null ? null : _verdicts(outcome),
                        ),
                        const SizedBox(height: 22),
                        if (phase == SingleToneSessionPhase.responding) ...[
                          YourTurnCue(
                            action: tr('Söyle!', 'Sing!'),
                            detail: tr(
                              'Aynı sırayla · mikrofon açık',
                              'Same order · microphone on',
                            ),
                          ),
                          const SizedBox(height: 14),
                          ProgressBar(
                            value:
                                (_phaseClock.elapsedMilliseconds /
                                        _responseWindow.inMilliseconds)
                                    .clamp(0.0, 1.0),
                            color: TC.koro,
                            height: 10,
                          ),
                        ] else ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _title(phase, outcome, calibrationFailed),
                              key: const Key('echo_status'),
                              textAlign: TextAlign.center,
                              style: TT.h3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _subtitle(phase, outcome, calibrationFailed),
                            textAlign: TextAlign.center,
                            style: TT.small,
                          ),
                        ],
                        if (outcome != null) ..._comparison(outcome),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(children: _buttons(s, phase, outcome)),
            ),
          ],
        ),
      ),
    );
  }

  int? _activeNote() {
    final ms = _phaseClock.elapsedMilliseconds;
    final i = ms ~/ _slotMs;
    if (i >= _notes.length || ms % _slotMs > _noteMs) return null;
    return i;
  }

  static bool _passed(MelodySessionOutcome o) =>
      !o.needsRetry && o.alignment?.wholeSequenceCorrect == true;

  String _title(
    SingleToneSessionPhase phase,
    MelodySessionOutcome? outcome,
    bool calibrationFailed,
  ) {
    if (calibrationFailed) return tr('Ortam çok gürültülü', 'Too noisy here');
    if (outcome != null) {
      if (outcome.needsRetry) return tr('Ölçüm alınamadı', 'No measurement');
      if (outcome.alignment == null) {
        return tr('Sesini duyamadım', 'I could not hear you');
      }
      return _passed(outcome)
          ? tr('Ezgiyi tuttun', 'You matched the melody')
          : tr('Henüz tam değil', 'Not quite yet');
    }
    return switch (phase) {
      SingleToneSessionPhase.idle => tr(
        'Önce dinle, sonra aynısını söyle',
        'Listen first, then sing it back',
      ),
      SingleToneSessionPhase.calibrating => tr('Sessiz kal', 'Stay quiet'),
      SingleToneSessionPhase.preparing ||
      SingleToneSessionPhase.referencePlaying => tr('Dinle', 'Listen'),
      SingleToneSessionPhase.waiting => tr('Hazırlan…', 'Get ready…'),
      SingleToneSessionPhase.responding => tr(
        'Şimdi sen söyle',
        'Now you sing',
      ),
      SingleToneSessionPhase.assessing || SingleToneSessionPhase.analyzing =>
        tr('Karşılaştırılıyor…', 'Comparing…'),
      _ => '',
    };
  }

  String _subtitle(
    SingleToneSessionPhase phase,
    MelodySessionOutcome? outcome,
    bool calibrationFailed,
  ) {
    if (calibrationFailed) {
      return tr('Sessiz bir yerde tekrar dene.', 'Try again somewhere quiet.');
    }
    if (outcome != null) {
      if (outcome.needsRetry) return _retry(outcome.retryReason!);
      if (outcome.alignment == null) {
        return tr(
          'Mikrofon açıkken ezgiyi biraz daha yüksek sesle söyle.',
          'Sing the melody a little louder while the microphone is on.',
        );
      }
      if (_passed(outcome)) {
        final store = TrainerScope.of(context).store;
        return store.melodyEchoLevel > _level
            ? tr(
                'Seviye ${store.melodyEchoLevel + 1} açıldı.',
                'Level ${store.melodyEchoLevel + 1} unlocked.',
              )
            : tr('Bu seviyeden yeni bir ezgi dene.', 'Try a new melody here.');
      }
      if (_octaveHint case final o?) {
        return tr(
          'Ezgiyi ${o.abs()} oktav ${o < 0 ? 'pes' : 'tiz'} söyledin; oktav farkı tuttu sayılmaz. Ezgiyi senin oktavına taşıyabilirim.',
          'You sang it ${o.abs()} octave${o.abs() > 1 ? 's' : ''} ${o < 0 ? 'lower' : 'higher'}; an octave off does not count. I can move the melody to your octave.',
        );
      }
      return tr(
        'Renkli notalara bakıp bir kez daha dinle.',
        'Check the coloured notes and listen once more.',
      );
    }
    return switch (phase) {
      SingleToneSessionPhase.idle => tr(
        '${_notes.length} nota. Notalar yanarken çalar; sonra mikrofon açılır.',
        '${_notes.length} notes. They light up as they play, then the microphone opens.',
      ),
      SingleToneSessionPhase.calibrating => tr(
        'Ortamı 2 saniye dinliyorum.',
        'Listening to the room for 2 seconds.',
      ),
      SingleToneSessionPhase.preparing ||
      SingleToneSessionPhase.referencePlaying ||
      SingleToneSessionPhase.waiting => tr(
        'Mikrofon kapalı.',
        'Microphone off.',
      ),
      SingleToneSessionPhase.responding => tr(
        'Aynı sırayla söyle. Mikrofon açık.',
        'Sing them in the same order. Microphone on.',
      ),
      _ => '',
    };
  }

  /// What each reference note got, from the exact sequence alignment.
  List<_Verdict> _verdicts(MelodySessionOutcome o) {
    final steps = o.alignment?.steps ?? const <PitchSequenceStep>[];
    return [
      for (var i = 0; i < _notes.length; i++)
        () {
          final step = steps.where((s) => s.referenceIndex == i).firstOrNull;
          if (step == null || o.needsRetry) return const _Verdict.unknown();
          switch (step.kind) {
            case PitchSequenceStepKind.correct:
              return const _Verdict(_Mark.correct);
            case PitchSequenceStepKind.wrongOctave:
              return const _Verdict(_Mark.octave);
            case PitchSequenceStepKind.missing:
            case PitchSequenceStepKind.extra:
              return const _Verdict(_Mark.missing);
            case PitchSequenceStepKind.wrongPitch:
              final cents = step.absoluteCents;
              return _Verdict(
                cents == null || cents > 0 ? _Mark.sharp : _Mark.flat,
                cents: cents?.abs(),
              );
          }
        }(),
    ];
  }

  List<Widget> _comparison(MelodySessionOutcome o) {
    final alignment = o.alignment;
    final extra = alignment?.count(PitchSequenceStepKind.extra) ?? 0;
    return [
      if (extra > 0) ...[
        const SizedBox(height: 8),
        Text(
          tr(
            'Fazladan $extra ses duyuldu; ezgide olmayan sesler de sayılır.',
            '$extra extra note${extra > 1 ? 's' : ''} heard; notes outside the melody count too.',
          ),
          textAlign: TextAlign.center,
          style: TT.small,
        ),
      ],
    ];
  }

  List<Widget> _buttons(
    MelodySessionController? s,
    SingleToneSessionPhase phase,
    MelodySessionOutcome? outcome,
  ) {
    if (s != null && s.canFinishResponse) {
      return [
        BigButton(
          key: const Key('echo_finish'),
          label: tr('Bitirdim', 'I am done'),
          icon: Ic.check,
          onPressed: s.finishResponse,
        ),
      ];
    }
    final ready = s == null || s.canStart;
    if (!ready) return const [];
    if (!_started) {
      return [
        BigButton(
          key: const Key('echo_start'),
          label: tr('Dinle ve başla', 'Listen and start'),
          icon: Ic.volume2,
          onPressed: _go,
        ),
      ];
    }
    if (outcome != null && _passed(outcome)) {
      return [
        BigButton(
          key: const Key('echo_next'),
          label: tr('Sonraki ezgi', 'Next melody'),
          icon: Ic.arrowRight,
          onPressed: _another,
        ),
        TextLink(
          tr('Bunu tekrar söyle', 'Sing this again'),
          key: const Key('echo_again'),
          onTap: _go,
        ),
      ];
    }
    if (_octaveHint != null) {
      return [
        BigButton(
          key: const Key('echo_transpose'),
          label: tr(
            'Oktavıma taşı ve tekrar dinle',
            'Move to my octave and listen',
          ),
          icon: Ic.moveVertical,
          onPressed: _transpose,
        ),
        TextLink(
          tr('Aynı oktavda tekrar dene', 'Try again in this octave'),
          key: const Key('echo_retry'),
          onTap: _go,
        ),
      ];
    }
    return [
      BigButton(
        key: const Key('echo_retry'),
        label: tr('Tekrar dinle ve söyle', 'Listen and sing again'),
        icon: Ic.rotateCcw,
        onPressed: _go,
      ),
      TextLink(
        tr('Başka ezgi', 'Another melody'),
        key: const Key('echo_other'),
        onTap: _another,
      ),
    ];
  }
}

String _retry(SessionRetryReason reason) => switch (reason) {
  SessionRetryReason.calibrationRequired => tr(
    'Ortamı yeniden dinlemem gerekiyor; tekrar dene.',
    'I need to listen to the room again; try again.',
  ),
  SessionRetryReason.permissionDenied => tr(
    'Mikrofon izni yok. Telefon ayarlarından Vocalart için mikrofonu aç.',
    'No microphone permission. Allow it for Vocalart in your phone settings.',
  ),
  SessionRetryReason.routeUnsupported => tr(
    'Bu ses çıkışı desteklenmiyor. Kablolu kulaklıkla dene.',
    'This audio output is not supported. Try wired headphones.',
  ),
  SessionRetryReason.interrupted => tr(
    'Deneme kesildi.',
    'The attempt was interrupted.',
  ),
  SessionRetryReason.captureFailed || SessionRetryReason.analysisFailed => tr(
    'Kayıt işlenemedi; tekrar dene.',
    'The recording could not be processed; try again.',
  ),
  SessionRetryReason.quality => tr(
    'Kayıt net değildi. Sessiz bir yerde, mikrofon açıldıktan sonra söyle. Bu senin hatan değil.',
    'The recording was not clear. Sing somewhere quiet, after the microphone opens. This is not your mistake.',
  ),
};

enum _Mark { correct, sharp, flat, octave, missing, unknown }

class _Verdict {
  const _Verdict(this.mark, {this.cents});
  const _Verdict.unknown() : mark = _Mark.unknown, cents = null;
  final _Mark mark;
  final double? cents;

  String get label => switch (mark) {
    _Mark.correct => tr('Tuttu', 'Matched'),
    // Past a few semitones the number stops helping; say where it went.
    _Mark.sharp =>
      cents == null || cents! >= 250
          ? tr('Çok tiz', 'Too high')
          : tr('${cents!.round()} sent tiz', '${cents!.round()} c sharp'),
    _Mark.flat =>
      cents == null || cents! >= 250
          ? tr('Çok pes', 'Too low')
          : tr('${cents!.round()} sent pes', '${cents!.round()} c flat'),
    _Mark.octave => tr('Oktav farkı', 'Octave off'),
    _Mark.missing => tr('Duyulmadı', 'Not heard'),
    _Mark.unknown => '',
  };
}

(Color, Color) _markColors(_Mark mark) => switch (mark) {
  _Mark.correct => (TC.sun, TC.limeDeep),
  _Mark.sharp || _Mark.flat => (TC.coralSoft, TC.coralDeep),
  _Mark.octave => (TC.warnSoft, TC.warn),
  _Mark.missing || _Mark.unknown => (TC.card, TC.muted),
};

/// What the melody should be and what was sung, on one graph. Each note is
/// a band in its own slot (lit while the reference plays); the live trace is
/// drawn over them while singing, stretched into the melody's length since
/// only note order and pitch are compared, never timing. On the result the
/// bands take the comparison's colours. Display only.
class _EchoGraph extends StatelessWidget {
  const _EchoGraph({
    required this.notes,
    required this.notation,
    required this.active,
    required this.revealed,
    required this.trace,
    required this.verdicts,
  });
  final List<int> notes;
  final NoteNotation notation;
  final int? active;
  final int revealed;
  final List<(int, double?)> trace;
  final List<_Verdict>? verdicts;

  @override
  Widget build(BuildContext context) => Semantics(
    label: [
      for (var i = 0; i < notes.length; i++)
        '${PitchClass.midiName(notes[i], notation)}'
            '${verdicts == null ? '' : ' ${verdicts![i].label}'}',
    ].join(', '),
    child: ExcludeSemantics(
      child: Column(
        children: [
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _EchoPainter(
                notes: notes,
                active: active,
                revealed: revealed,
                trace: trace,
                verdicts: verdicts,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < notes.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        PitchClass.midiName(notes[i], notation),
                        style: TT.small.copyWith(
                          fontWeight: FontWeight.w700,
                          color: i < revealed ? TC.ink : TC.faint,
                        ),
                      ),
                      if (verdicts != null)
                        Text(
                          verdicts![i].label,
                          key: Key('echo_verdict_$i'),
                          textAlign: TextAlign.center,
                          style: TT.small.copyWith(
                            color: _markColors(verdicts![i].mark).$2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _EchoPainter extends CustomPainter {
  _EchoPainter({
    required this.notes,
    required this.active,
    required this.revealed,
    required this.trace,
    required this.verdicts,
  });
  final List<int> notes;
  final int? active;
  final int revealed;
  final List<(int, double?)> trace;
  final List<_Verdict>? verdicts;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = notes.reduce(math.min) - 2.5, hi = notes.reduce(math.max) + 2.5;
    final span = math.max(7.0, hi - lo), mid = (lo + hi) / 2;
    final ps = size.height / span;
    double y(double m) =>
        (size.height / 2 - (m - mid) * ps).clamp(4.0, size.height - 4);
    final slot = size.width / notes.length;
    // Faint semitone grid.
    final grid = Paint()
      ..color = TC.line.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var m = (mid - span / 2).ceil(); m <= mid + span / 2; m++) {
      canvas.drawLine(
        Offset(0, y(m.toDouble())),
        Offset(size.width, y(m.toDouble())),
        grid,
      );
    }
    for (var i = 0; i < notes.length; i++) {
      if (i >= revealed) continue;
      final r = RRect.fromLTRBR(
        slot * i + slot * 0.08,
        y(notes[i] + 0.5),
        slot * (i + 1) - slot * 0.08,
        y(notes[i] - 0.5),
        Radius.circular(ps / 2),
      );
      final on = active == i;
      var (fill, border) = verdicts == null
          ? (on ? TC.koro : TC.primarySoft, TC.koro)
          : _markColors(verdicts![i].mark);
      if (on) {
        canvas.drawRRect(
          r.inflate(4),
          Paint()
            ..color = TC.koro.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      canvas.drawRRect(r, Paint()..color = fill);
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = border,
      );
    }
    final first = trace.indexWhere((p) => p.$2 != null);
    if (first < 0) return;
    final t0 = trace[first].$1;
    final length = notes.length * _slotMs;
    final shown = math.max(length, trace.last.$1 - t0);
    double x(int t) => (t - t0) / shown * size.width;
    int slotAt(double px) => (px / slot).floor().clamp(0, notes.length - 1);
    bool hit(double px, double m) => (m - notes[slotAt(px)]).abs() < 0.5;
    final glow = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 11
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = first + 1; i < trace.length; i++) {
      final a = trace[i - 1], b = trace[i];
      if (a.$2 == null || b.$2 == null) continue;
      final pa = Offset(x(a.$1), y(a.$2!)), pb = Offset(x(b.$1), y(b.$2!));
      final colour = hit(pb.dx, b.$2!) ? TC.teal : TC.koro;
      glow.color = colour.withValues(alpha: 0.35);
      line.color = colour;
      canvas.drawLine(pa, pb, glow);
      canvas.drawLine(pa, pb, line);
    }
    if (verdicts != null) return;
    final last = trace.lastIndexWhere((p) => p.$2 != null);
    final head = Offset(x(trace[last].$1), y(trace[last].$2!));
    final ok = hit(head.dx, trace[last].$2!);
    canvas.drawCircle(
      head,
      12,
      Paint()
        ..color = (ok ? TC.sun : TC.koro).withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(head, 7, Paint()..color = ok ? TC.sun : TC.koro);
    canvas.drawCircle(
      head,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = TC.ink,
    );
  }

  @override
  bool shouldRepaint(_EchoPainter old) => true;
}
