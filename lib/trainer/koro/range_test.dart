import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/microphone_permission_recovery.dart';
import '../../domain/audio/audio_capture.dart';
import '../../domain/audio/live_pitch_tracker.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../domain/audio/yin_pitch_frame_analyzer.dart';
import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../../infrastructure/permissions/permission_handler_microphone_recovery.dart';
import '../app/scope.dart';
import '../domain/music.dart';
import '../ui/audio_reactive_orb.dart';
import '../ui/kit.dart';
import 'range_ladder.dart';
import 'range_visuals.dart';
import 'pulse_chain.dart';
import 'voice_waves.dart';
import '../../domain/lang.dart';

/// One sung take reduced to a single representative pitch, or a reason why
/// no pitch is reported. Never a score.
class RangeTake {
  const RangeTake.pitch(double this.hz) : failure = null;
  const RangeTake.failed(String this.failure) : hz = null;
  final double? hz;
  final String? failure;
}

abstract interface class RangeProbe {
  Future<bool> requestPermission();
  Stream<double> get levelDb;
  Future<RangeTake> record(Duration duration);
  Future<void> close();
}

/// A probe that can also show the pitch while a take runs. Display only:
/// the take is still judged on the whole recording by [record].
abstract interface class LivePitchProbe {
  /// Hz every ~20 ms during a take, null when no clear pitch is heard.
  Stream<double?> get livePitchHz;
}

/// Quality gate on the shared Resonia pitch core. Thresholds are draft
/// hypotheses (no human benchmark yet): a take must be mostly periodic and
/// steady, otherwise it is reported as unmeasured, never guessed.
///
/// Silence before the voice starts and after it stops is not held against
/// the take: continuity is judged from the first to the last periodic frame.
/// The voice must still last [minVoicedSeconds], the same amount the old
/// whole-take rule asked for (35% of a 2 s take).
const minVoicedSeconds = 0.7;
const minVoicedContinuity = 0.35;

RangeTake evaluateRangeEvidence(RecordingPitchEvidence evidence) {
  if (evidence.status == RecordingPitchStatus.invalidInput ||
      evidence.status == RecordingPitchStatus.insufficientData) {
    return RangeTake.failed(
      tr(
        'Kayıt çok kısa ya da okunamadı.',
        'The recording was too short or could not be read.',
      ),
    );
  }
  if (evidence.status != RecordingPitchStatus.periodicSignalObserved ||
      evidence.representativeFrequencyHz == null) {
    return RangeTake.failed(
      tr(
        'Net bir ses duyulamadı. Biraz daha yüksek sesle, sabit tut.',
        'No clear voice was heard. A little louder, and hold it steady.',
      ),
    );
  }
  final frames = evidence.frames;
  final first = frames.indexWhere(
    (f) => f.estimate.status == PitchFrameStatus.pitched,
  );
  final last = frames.lastIndexWhere(
    (f) => f.estimate.status == PitchFrameStatus.pitched,
  );
  final pitched = frames
      .where((f) => f.estimate.status == PitchFrameStatus.pitched)
      .length;
  final voicedSeconds = first < 0
      ? 0.0
      : (frames[last].startSample +
                frames[last].sampleCount -
                frames[first].startSample) /
            evidence.sampleRateHz;
  final continuity = first < 0 ? 0.0 : pitched / (last - first + 1);
  if (voicedSeconds < minVoicedSeconds) {
    return RangeTake.failed(
      tr(
        'Ses çok kısa duyuldu. Notayı en az bir saniye tut.',
        'Your voice was too short. Hold the note for at least a second.',
      ),
    );
  }
  if (continuity < minVoicedContinuity) {
    return RangeTake.failed(
      tr(
        'Ses sık sık kesildi. Notayı tek nefeste, kesmeden tut.',
        'Your voice kept dropping out. Hold the note in one breath.',
      ),
    );
  }
  final spread = evidence.pitchDispersionCents;
  if (spread == null || spread > 80) {
    return RangeTake.failed(
      tr(
        'Ses fazla dalgalandı. Tek bir notada sabit kal.',
        'The pitch wavered too much. Stay steady on one note.',
      ),
    );
  }
  return RangeTake.pitch(evidence.representativeFrequencyHz!);
}

class MicRangeProbe implements RangeProbe, LivePitchProbe {
  MicRangeProbe() {
    _samples = _backend.liveSamples.listen(
      (chunk) => _tracker.add(chunk, 48000),
    );
  }
  final _backend = PluginAudioLabBackend(livePcm: true);
  final _worker = IsolateRecordingPitchWorker();
  final _pitch = StreamController<double?>.broadcast();
  late final _tracker = LivePitchTracker(
    onPitch: (hz) {
      if (!_pitch.isClosed) _pitch.add(hz);
    },
  );
  late final StreamSubscription<List<double>> _samples;

  @override
  Stream<double?> get livePitchHz => _pitch.stream;

  @override
  Stream<double> get levelDb => _backend.inputLevelDb;

  @override
  Future<bool> requestPermission() => _backend.requestMicrophonePermission();

  @override
  Future<RangeTake> record(Duration duration) async {
    _tracker.reset();
    await _backend.startCapture();
    await Future<void>.delayed(duration);
    await _backend.stopCapture();
    final CapturedAudioSamples samples = await _backend.readRecording();
    try {
      final evidence = await _worker.analyze(
        samples: samples.samples,
        sampleRateHz: samples.sampleRateHz,
        source: samples.source,
      );
      return evaluateRangeEvidence(evidence);
    } finally {
      await _backend.discardCapture();
    }
  }

  @override
  Future<void> close() async {
    await _samples.cancel();
    await _pitch.close();
    await _backend.close();
  }
}

VoicePart? suggestPart(int low, int high) {
  if (high - low < 5) return null;
  VoicePart? best;
  var bestScore = -1.0;
  for (final p in VoicePart.values) {
    final overlap =
        (high < p.high ? high : p.high) - (low > p.low ? low : p.low);
    final centre = ((low + high) / 2 - (p.low + p.high) / 2).abs();
    final score = overlap - centre * 0.1;
    if (overlap > 0 && score > bestScore) {
      bestScore = score;
      best = p;
    }
  }
  return best;
}

enum _Stage {
  intro,
  denied,
  comfort,
  comfortListening,
  comfortFailed,
  playing,
  listening,
  feedback,
  turn,
  result,
}

/// Separate voice-detection screen: play-and-listen range ladder (the
/// author's Agora method). Each piano note is played first, then the singer
/// repeats it; no gender or voice-group question is asked.
class RangeTestScreen extends StatefulWidget {
  const RangeTestScreen({
    super.key,
    this.probe,
    this.recovery,
    this.playNote,
    this.pause = const Duration(milliseconds: 900),
  });
  final RangeProbe? probe;
  final MicrophonePermissionRecovery? recovery;

  /// Plays one reference note and completes when it is over; defaults to
  /// the shared trainer audio (recorded piano when cleared, else synth).
  final Future<void> Function(int midi)? playNote;

  /// How long feedback stays before the next note.
  final Duration pause;
  @override
  State<RangeTestScreen> createState() => _RangeTestScreenState();
}

/// Long enough for the microphone to open and the singer to react after
/// the piano; leading silence is trimmed by [evaluateRangeEvidence].
const _takeLength = Duration(seconds: 3);

class _RangeTestScreenState extends State<RangeTestScreen>
    with SingleTickerProviderStateMixin {
  RangeProbe? _probe;
  _Stage _stage = _Stage.intro;
  RangeLadder? _ladder;
  RangeAttempt? _last;
  String? _failure;
  double _level = -60;
  StreamSubscription<double>? _levels;
  StreamSubscription<double?>? _pitches;

  /// Live display trace of the current take (MIDI, null = unpitched).
  final List<double?> _trace = [];
  late final AnimationController _flash;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  bool _skip = false;
  int _run = 0;
  bool _saved = false;

  @override
  void dispose() {
    _run++;
    _levels?.cancel();
    _pitches?.cancel();
    _flash.dispose();
    _probe?.close();
    super.dispose();
  }

  RangeProbe _ensureProbe() => _probe ??= widget.probe ?? MicRangeProbe();

  Future<void> _play(int midi) =>
      (widget.playNote ?? TrainerScope.read(context).audio.playNote)(midi);

  Future<void> _start() async {
    final probe = _ensureProbe();
    bool granted;
    try {
      granted = await probe.requestPermission();
    } catch (_) {
      granted = false;
    }
    if (!mounted) return;
    if (!granted) {
      setState(() => _stage = _Stage.denied);
      return;
    }
    _levels ??= probe.levelDb.listen((db) {
      if (mounted) setState(() => _level = db);
    });
    if (probe is LivePitchProbe) {
      _pitches ??= (probe as LivePitchProbe).livePitchHz.listen((hz) {
        if (!mounted || _stage != _Stage.listening) return;
        if (_trace.length >= rangeTracePoints) return;
        setState(() => _trace.add(hz == null ? null : hzToMidi(hz)));
      });
    }
    setState(() => _stage = _Stage.comfort);
  }

  Future<RangeTake> _take() async {
    try {
      return await _ensureProbe().record(_takeLength);
    } catch (_) {
      return RangeTake.failed(
        tr(
          'Kayıt başlatılamadı. Mikrofonu başka bir uygulama kullanıyor olabilir.',
          'Recording could not start. Another app may be using the microphone.',
        ),
      );
    }
  }

  /// A comfortable "aa" sets the first note, instead of asking for a voice
  /// group or gender.
  Future<void> _comfort() async {
    setState(() => _stage = _Stage.comfortListening);
    final take = await _take();
    if (!mounted) return;
    if (take.hz == null) {
      setState(() {
        _failure = take.failure;
        _stage = _Stage.comfortFailed;
      });
      return;
    }
    _begin(startFromComfort(take.hz));
  }

  void _begin(int startMidi) {
    _ladder = RangeLadder.start(startMidi);
    _last = null;
    _saved = false;
    _loop(++_run);
  }

  bool _live(int run) => mounted && run == _run;

  Future<void> _loop(int run) async {
    while (_live(run) && !_ladder!.done) {
      if (_consumeSkip()) {
        if (_ladder!.done) break;
        await _turn(run);
        continue;
      }
      setState(() => _stage = _Stage.playing);
      await _play(_ladder!.currentMidi);
      if (!_live(run)) return;
      if (_consumeSkip()) {
        if (_ladder!.done) break;
        await _turn(run);
        continue;
      }
      setState(() {
        _trace.clear();
        _stage = _Stage.listening;
      });
      final take = await _take();
      if (!_live(run)) return;
      if (_consumeSkip()) {
        if (_ladder!.done) break;
        await _turn(run);
        continue;
      }
      final before = _ladder!.direction;
      setState(() {
        _ladder = _ladder!.record(take.hz);
        _last = _ladder!.log.last;
        _failure = take.failure;
        _stage = _Stage.feedback;
      });
      if (_last!.judgement.match == RangeMatch.matched) {
        _flash.forward(from: 0);
      }
      await Future<void>.delayed(widget.pause);
      if (!_live(run)) return;
      if (!_ladder!.done && _ladder!.direction != before) await _turn(run);
    }
    if (_live(run)) _finish();
  }

  Future<void> _turn(int run) async {
    setState(() => _stage = _Stage.turn);
    await Future<void>.delayed(widget.pause * 2);
  }

  bool _consumeSkip() {
    if (!_skip) return false;
    _skip = false;
    _ladder = _ladder!.skipDirection();
    return true;
  }

  void _finish() {
    final bounds = _ladder!.bounds;
    if (bounds != null && !_saved) {
      _saved = true;
      final store = TrainerScope.of(context).store;
      store.koroRange = '${bounds.lowMidi}-${bounds.highMidi}';
      // The measured range picks the practice register; nobody is asked
      // for a voice group. Settings can still change it.
      final part = suggestPart(bounds.lowMidi, bounds.highMidi);
      if (part != null) store.voicePart = part.name;
      store.save();
    }
    setState(() => _stage = _Stage.result);
  }

  void _restart() {
    _run++;
    setState(() {
      _ladder = null;
      _last = null;
      _stage = _Stage.comfort;
    });
  }

  double get _progress => switch (_stage) {
    _Stage.intro || _Stage.denied => 0.05,
    _Stage.comfort || _Stage.comfortListening || _Stage.comfortFailed => 0.15,
    _Stage.result => 1,
    _ => _ladder?.direction == RangeDirection.down ? 0.66 : 0.4,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TC.canvas,
    body: SafeArea(
      child: Column(
        children: [
          TopBar(
            title: tr('Ses aralığı', 'Vocal range'),
            progress: _progress,
            progressColor: TC.koro,
          ),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Future<void> _openSettings() async {
    try {
      await (widget.recovery ?? const PermissionHandlerMicrophoneRecovery())
          .openAppSettings();
    } catch (_) {
      // The page already spells out the manual path to the setting.
    }
  }

  Widget _body() {
    final notation = TrainerScope.of(context).store.notation;
    String name(int midi) => PitchClass.midiName(midi, notation);
    switch (_stage) {
      case _Stage.intro:
        return _Page(
          icon: Ic.mic,
          title: tr('Ses aralığını bul', 'Find your range'),
          body: tr(
            'Piyano bir nota çalar, sen aynı notayı "aa" ile 3 saniye tekrar edersin. Önce tize, sonra pese doğru nota nota ilerleriz; iki denemede tutturamadığın yerde o yön biter.\n\nYanlış oktavda söylenen nota ulaşılmış sayılmaz. Kayıtlar cihazdan çıkmaz ve analizden sonra silinir. Sonuç ses tipi değildir; onu eğitmen ya da koro şefi belirler.',
            'The piano plays a note and you repeat it on "aa" for 3 seconds. We climb note by note, then go down; a direction ends where two attempts miss.\n\nA note sung in the wrong octave does not count as reached. Recordings stay on the device and are deleted after analysis. The result is not a voice type; a teacher or conductor decides that.',
          ),
          button: tr('Başla', 'Start'),
          onPressed: _start,
          secondary: tr('Şimdi değil', 'Not now'),
          onSecondary: () => Navigator.maybePop(context),
        );
      case _Stage.denied:
        return _Page(
          icon: Ic.lock,
          title: tr('Mikrofon izni gerekli', 'Microphone permission needed'),
          body: tr(
            'Ses aralığını ölçmek için mikrofon izni ver. iOS Ayarlar > Vocalart > Mikrofon\'dan açabilirsin.',
            'Allow the microphone to measure your range. You can turn it on in iOS Settings > Vocalart > Microphone.',
          ),
          // A denied prompt never reappears on iOS: retrying alone is a dead end.
          button: tr('Ayarları aç', 'Open Settings'),
          onPressed: _openSettings,
          secondary: tr('Tekrar dene', 'Try again'),
          onSecondary: _start,
        );
      case _Stage.comfort:
        return _Page(
          icon: Ic.speech,
          title: tr('Önce rahat bir ses', 'First, a comfortable note'),
          body: tr(
            'Konuşur gibi, zorlamadan bir "aa" söyle. Testin başlangıç notasını bundan seçeriz; ses grubunu sormayız.',
            'Sing an easy "aa", like speaking. We pick the starting note from it; we do not ask for your voice group.',
          ),
          button: tr('Söyle (3 sn)', 'Sing (3 s)'),
          onPressed: _comfort,
          secondary: tr(
            '${name(neutralStartMidi)} notasından başla',
            'Start from ${name(neutralStartMidi)}',
          ),
          onSecondary: () => _begin(neutralStartMidi),
          hero: AudioReactiveOrb(
            key: const Key('range_orb'),
            phase: OrbPhase.idle,
            onTap: _comfort,
            semanticLabel: tr('Söyle (3 sn)', 'Sing (3 s)'),
          ),
          footer: _LevelBar(db: _level),
        );
      case _Stage.comfortListening:
        return _Page(
          icon: Ic.audioLines,
          hero: AudioReactiveOrb(
            key: const Key('range_orb'),
            phase: OrbPhase.listening,
            levelDb: _level,
          ),
          title: tr('Dinliyorum…', 'Listening…'),
          body: tr('Rahat bir "aa".', 'An easy "aa".'),
          footer: _LevelBar(db: _level),
        );
      case _Stage.comfortFailed:
        return _Page(
          icon: Ic.circleHelp,
          title: tr('Ölçülemedi', 'Not measured'),
          body: _failure ?? '',
          button: tr('Tekrar söyle', 'Sing again'),
          onPressed: _comfort,
          secondary: tr(
            '${name(neutralStartMidi)} notasından başla',
            'Start from ${name(neutralStartMidi)}',
          ),
          onSecondary: () => _begin(neutralStartMidi),
        );
      case _Stage.playing:
      case _Stage.listening:
      case _Stage.feedback:
      case _Stage.turn:
        return _LadderView(
          ladder: _ladder!,
          stage: _stage,
          last: _last,
          failure: _failure,
          level: _level,
          trace: _trace,
          flash: _flash,
          notation: notation,
          onSkip: _stage == _Stage.playing || _stage == _Stage.listening
              ? () => setState(() => _skip = true)
              : null,
          skipping: _skip,
        );
      case _Stage.result:
        final bounds = _ladder?.bounds;
        if (bounds == null) {
          return _Page(
            icon: Ic.moveVertical,
            title: tr('Aralık çıkmadı', 'No range yet'),
            body: tr(
              'En az iki notayı aynı oktavda tutturmak gerekiyor. Bu deneme kaydedilmedi. Sessiz bir yerde, telefonu yüz hizasında tutup tekrar dene.',
              'At least two notes must be matched in the same octave. This attempt was not saved. Try again somewhere quiet, phone at face height.',
            ),
            button: tr('Tekrar dene', 'Try again'),
            onPressed: _restart,
            secondary: tr('Kapat', 'Close'),
            onSecondary: () => Navigator.maybePop(context),
          );
        }
        final store = TrainerScope.of(context).store;
        final low = bounds.lowMidi;
        final high = bounds.highMidi;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: _IconTile(Ic.music2)),
            const SizedBox(height: 8),
            Text(
              '${name(low)} – ${name(high)}',
              key: const Key('range_result'),
              textAlign: TextAlign.center,
              style: TT.h1,
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                '${bounds.semitones} yarım ses · yaklaşık ${bounds.octaves.toStringAsFixed(1)} oktav · ${_ladder!.reached.length} nota tutturuldu',
                '${bounds.semitones} semitones · about ${bounds.octaves.toStringAsFixed(1)} octaves · ${_ladder!.reached.length} notes matched',
              ),
              textAlign: TextAlign.center,
              style: TT.body,
            ),
            const SizedBox(height: 20),
            KeyboardMap(
              low: (low - 3).clamp(rangeLadderNotes.first, low),
              high: (high + 3).clamp(high, rangeLadderNotes.last),
              reached: _ladder!.reached.toSet(),
              notation: notation,
              bracket: true,
            ),
            const SizedBox(height: 20),
            _RangeChart(low: low, high: high, notation: notation),
            const SizedBox(height: 20),
            AppCard(
              color: const Color(0xFFEEEBFF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('ÇALIŞMA ARALIĞI', 'PRACTICE RANGE'), style: TT.caps),
                  const SizedBox(height: 4),
                  Text(
                    store.part?.title ?? tr('Belirsiz', 'Unclear'),
                    style: TT.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Dersler bu aralıkta çalar; Ayarlar\'dan değiştirebilirsin. Bu bir ses tipi kararı değildir: ses rengi, geçiş bölgeleri ve rahat tessitura ölçülmedi.',
                      'Lessons play in this range; you can change it in Settings. This is not a voice type: timbre, passaggi and comfortable tessitura were not measured.',
                    ),
                    style: TT.small,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BigButton(
              label: tr('Bitti', 'Done'),
              onPressed: () => Navigator.pop(context),
            ),
            TextLink(tr('Testi tekrarla', 'Repeat the test'), onTap: _restart),
          ],
        );
    }
  }
}

/// The running ladder: what to do now, the note, and the staircase.
class _LadderView extends StatelessWidget {
  const _LadderView({
    required this.ladder,
    required this.stage,
    required this.last,
    required this.failure,
    required this.level,
    required this.trace,
    required this.flash,
    required this.notation,
    required this.onSkip,
    required this.skipping,
  });
  final RangeLadder ladder;
  final _Stage stage;
  final RangeAttempt? last;
  final String? failure;
  final double level;
  final List<double?> trace;
  final Animation<double> flash;
  final NoteNotation notation;
  final VoidCallback? onSkip;
  final bool skipping;

  String _feedback() {
    final a = last;
    if (a == null) return '';
    final j = a.judgement;
    final retry =
        a.attempt < rangeAttemptsPerNote && ladder.currentMidi == a.targetMidi;
    final again = retry ? tr(' Bir kez daha.', ' One more try.') : '';
    return switch (j.match) {
      RangeMatch.matched => tr(
        'Tuttu · %${j.closeness!.round()} yakın',
        'Matched · ${j.closeness!.round()}% close',
      ),
      RangeMatch.octaveOff => tr(
        'Doğru nota, ama ${j.octave.abs()} oktav ${j.octave < 0 ? 'pes' : 'tiz'}. Sayılmadı.$again',
        'Right note, but ${j.octave.abs()} octave${j.octave.abs() > 1 ? 's' : ''} ${j.octave < 0 ? 'low' : 'high'}. Not counted.$again',
      ),
      RangeMatch.missed => tr(
        '${j.cents! > 0 ? 'Tiz' : 'Pes'} kaldı (${j.cents!.abs().round()} sent).$again',
        'Too ${j.cents! > 0 ? 'high' : 'low'} (${j.cents!.abs().round()} cents).$again',
      ),
      RangeMatch.unmeasured =>
        '${failure ?? tr('Ölçülemedi.', 'Not measured.')}$again',
    };
  }

  @override
  Widget build(BuildContext context) {
    final up = ladder.direction == RangeDirection.up;
    final (icon, title) = switch (stage) {
      _Stage.playing => (Ic.volume2, tr('Dinle', 'Listen')),
      _Stage.listening => (Ic.mic, tr('Şimdi sen söyle', 'Now you sing')),
      _Stage.turn => (Ic.arrowDown, tr('Şimdi pese doğru', 'Now going down')),
      _ => (
        last?.judgement.match == RangeMatch.matched ? Ic.check : Ic.circleHelp,
        _feedback(),
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Tag(
            up
                ? tr(
                    'TİZE DOĞRU · ${ladder.reached.length} NOTA',
                    'GOING UP · ${ladder.reached.length} NOTES',
                  )
                : tr(
                    'PESE DOĞRU · ${ladder.reached.length} NOTA',
                    'GOING DOWN · ${ladder.reached.length} NOTES',
                  ),
            color: TC.koro,
          ),
          Expanded(
            child: FitOrScroll(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    PitchClass.midiName(ladder.currentMidi, notation),
                    key: const Key('range_note'),
                    style: TT.display,
                  ),
                  Text(
                    tr(
                      '${ladder.attempt}. deneme',
                      'Attempt ${ladder.attempt}',
                    ),
                    style: TT.small,
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 22, color: TC.ink),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            key: const Key('range_title'),
                            textAlign: TextAlign.center,
                            style: TT.h3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: flash,
                    builder: (context, _) {
                      final f = Curves.easeOut.transform(
                        1 - (flash.value - 0.15).abs().clamp(0.0, 1.0),
                      );
                      final shown = flash.isAnimating ? f : 0.0;
                      // During feedback the ladder has already moved on:
                      // keep the judged note in view until the next one.
                      final judged = stage == _Stage.feedback && last != null
                          ? last!.targetMidi
                          : ladder.currentMidi;
                      return Column(
                        children: [
                          VoiceWaves(
                            target: judged,
                            notation: notation,
                            pitchMidi: stage == _Stage.listening
                                ? trace.lastOrNull
                                : null,
                            levelDb: level,
                            listening: stage == _Stage.listening,
                            reference: stage == _Stage.playing,
                            flash: shown,
                          ),
                          const SizedBox(height: 14),
                          _LadderChain(
                            ladder: ladder,
                            stage: stage,
                            last: last,
                            target: judged,
                            notation: notation,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const Key('range_skip'),
            onPressed: skipping ? null : onSkip,
            icon: const Icon(Ic.skipForward),
            label: Text(
              up
                  ? tr('Tizde sınırım bu, pese geç', 'My top is here, go down')
                  : tr('Peste sınırım bu, bitir', 'My bottom is here, finish'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The run as a pulse chain: reached notes lit, misses marked, the target
/// timed, and the direction shown by light running towards it.
class _LadderChain extends StatelessWidget {
  const _LadderChain({
    required this.ladder,
    required this.stage,
    required this.last,
    required this.target,
    required this.notation,
  });
  final RangeLadder ladder;
  final _Stage stage;
  final RangeAttempt? last;
  final int target;
  final NoteNotation notation;
  @override
  Widget build(BuildContext context) {
    final touched = {
      ...ladder.reached,
      for (final a in ladder.log) a.targetMidi,
      ladder.currentMidi,
      ladder.startMidi,
    };
    var lo = touched.reduce(math.min) - 2, hi = touched.reduce(math.max) + 2;
    // At least an octave and a bit, so a short run still reads as a range.
    while (hi - lo < 14) {
      lo--;
      hi++;
    }
    final judged = last?.judgement.match;
    return PulseChain(
      low: lo,
      high: hi,
      start: ladder.startMidi,
      marks: chainMarks(ladder.log),
      attempts: ladder.log.length,
      notation: notation,
      target: stage == _Stage.turn ? null : target,
      up: ladder.direction == RangeDirection.up,
      phase: switch (stage) {
        _Stage.playing => ChainPhase.piano,
        _Stage.listening => ChainPhase.listening,
        _Stage.turn => ChainPhase.turn,
        _ => ChainPhase.feedback,
      },
      result: switch (judged) {
        null => null,
        RangeMatch.matched => ChainMark.matched,
        RangeMatch.octaveOff => ChainMark.octave,
        _ => ChainMark.missed,
      },
      listenFor: _takeLength,
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    this.button,
    this.onPressed,
    this.footer,
    this.secondary,
    this.onSecondary,
    this.hero,
  });
  final IconData icon;

  /// Replaces the icon tile, e.g. with the listening orb.
  final Widget? hero;
  final String title;
  final String body;
  final String? button;
  final VoidCallback? onPressed;
  final Widget? footer;
  final String? secondary;
  final VoidCallback? onSecondary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Column(
      children: [
        Expanded(
          child: FitOrScroll(
            // A hero sits at a fixed top slot so the orb does not jump
            // when the text or the buttons under it change between pages.
            child: Column(
              mainAxisAlignment: hero == null
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (hero != null) const SizedBox(height: 28),
                hero ?? _IconTile(icon),
                SizedBox(height: hero == null ? 18 : 6),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    title,
                    key: const Key('range_title'),
                    textAlign: TextAlign.center,
                    style: TT.display,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TT.body.copyWith(color: TC.muted, fontSize: 14),
                ),
                if (footer != null) ...[const SizedBox(height: 26), footer!],
              ],
            ),
          ),
        ),
        if (button != null) BigButton(label: button!, onPressed: onPressed),
        if (secondary != null) TextLink(secondary!, onTap: onSecondary!),
      ],
    ),
  );
}

/// The lime tile the choir screens use for a page's one picture.
class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);
  final IconData icon;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 72,
      height: 86,
      decoration: BoxDecoration(
        color: TC.sun,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Icon(icon, color: TC.ink, size: 34),
    ),
  );
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.db});
  final double db;
  @override
  Widget build(BuildContext context) {
    final v = ((db + 60) / 60).clamp(0.0, 1.0);
    return Column(
      children: [
        Text(tr('GİRİŞ SEVİYESİ', 'INPUT LEVEL'), style: TT.caps),
        const SizedBox(height: 8),
        ProgressBar(value: v, color: v > 0.92 ? TC.red : TC.koro, height: 10),
        const SizedBox(height: 6),
        Text(
          tr(
            'Yalnız gösterge; ses kalitesi ölçümü değildir.',
            'An indicator only; not a measure of voice quality.',
          ),
          style: TT.small,
        ),
      ],
    );
  }
}

class _RangeChart extends StatelessWidget {
  const _RangeChart({
    required this.low,
    required this.high,
    required this.notation,
  });
  final int low;
  final int high;
  final NoteNotation notation;
  @override
  Widget build(BuildContext context) {
    const min = 36;
    const max = 86;
    double x(int midi, double w) => w * (midi - min) / (max - min);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Column(
          children: [
            for (final p in VoicePart.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Text(p.name, style: TT.small)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c2) => SizedBox(
                          height: 14,
                          child: Stack(
                            children: [
                              Positioned(
                                left: x(p.low, c2.maxWidth),
                                width:
                                    x(p.high, c2.maxWidth) -
                                    x(p.low, c2.maxWidth),
                                top: 3,
                                height: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4E3EF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(tr('Sen', 'You'), style: TT.title),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c2) => SizedBox(
                      height: 18,
                      child: Stack(
                        children: [
                          Positioned(
                            left: x(low.clamp(min, max), c2.maxWidth),
                            width:
                                (x(high.clamp(min, max), c2.maxWidth) -
                                        x(low.clamp(min, max), c2.maxWidth))
                                    .clamp(4.0, w),
                            top: 2,
                            height: 14,
                            child: Container(
                              decoration: BoxDecoration(
                                color: TC.koro,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
