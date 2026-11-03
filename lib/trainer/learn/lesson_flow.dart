import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/single_tone_session.dart';
import '../../domain/models/measurement_provenance.dart';
import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../sing/trainer_pitch_sing_mobile.dart';
import '../sing/trainer_pitch_sing_session.dart';
import '../ui/kit.dart';
import 'session_end.dart';
import '../../domain/lang.dart';

/// Resonia lesson: Dinle (meet each new sound) → Söyle (sing it back,
/// self-paced and unmeasured) → Ayırt et (scored listening practice).
/// Gates skip straight to the scored part; the intro only reads.
class LessonFlow extends StatefulWidget {
  const LessonFlow({
    super.key,
    required this.node,
    this.random,
    this.pitchSingSessionFactory,
  });
  final LessonNode node;
  final math.Random? random;
  final TrainerPitchSingSession Function(TrainerPitchSingTarget target)?
  pitchSingSessionFactory;

  @override
  State<LessonFlow> createState() => _LessonFlowState();
}

enum _Step { overview, listen, sing, practice, result }

class _LessonFlowState extends State<LessonFlow> with WidgetsBindingObserver {
  late final math.Random _random = widget.random ?? math.Random();
  late final QuizGenerator _gen = QuizGenerator(
    QuizConfig.forNode(
      widget.node,
      voice: TrainerScope.read(context).store.part,
    ),
    random: _random,
  );
  _Step _step = _Step.overview;
  int _page = 0;
  int _root = 0;
  QuizSummary? _summary;
  bool _passed = false;
  TrainerPitchSingSession? _singSession;
  String? _singItem;
  int _singGeneration = 0;
  bool _singUnavailable = false;

  LessonNode get node => widget.node;
  TrainerKind get kind => node.trainer;
  Color get color => trainerColor(kind);
  TrainerPath get path => trainerPaths[kind]!;
  bool get _intro => node.kind == NodeKind.intro;

  /// Listen pages: intro slides, one page per new item, or one comparison.
  int get _pageCount => _intro
      ? path.introSlides.length
      : node.newItems.isEmpty
      ? 1
      : node.newItems.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_intro) _step = _Step.listen;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final session = _singSession;
      if (session != null) unawaited(session.cancel());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final session = _singSession;
    session?.removeListener(_singChanged);
    if (session != null) unawaited(_closeAndDispose(session));
    super.dispose();
  }

  void _finishNode(double accuracy) {
    final store = TrainerScope.of(context).store;
    _passed = store.completeNode(node, accuracy);
    // Reading the intro alone is not a finished practice session.
    if (!_intro) store.recordSession();
  }

  void _forward() {
    switch (_step) {
      case _Step.overview:
        setState(() => _step = node.isGate ? _Step.practice : _Step.listen);
      case _Step.listen:
        if (_page < _pageCount - 1) {
          setState(() => _page++);
        } else if (_intro) {
          _finishNode(1);
          Navigator.of(context).pop(true);
        } else {
          setState(() => _step = _Step.sing);
        }
      case _Step.sing:
        _releaseSingSession();
        setState(() => _step = _Step.practice);
      case _Step.practice || _Step.result:
        break;
    }
  }

  String _label(String id, {bool long = true}) {
    final store = TrainerScope.of(context).store;
    return itemLabel(kind, id, notation: store.notation, long: long);
  }

  SoundSpec _demo(String item) {
    final f = SoundFactory(_random);
    final requested = node.registers.first;
    final base =
        (TrainerScope.of(context).store.part?.fit(requested) ?? requested)
            .rootC;
    final r = base + _root;
    return switch (kind) {
      TrainerKind.pitch => f.note(base + int.parse(item)),
      TrainerKind.interval => f.interval(item, rootMidi: r, learn: true),
      TrainerKind.chord => f.chord(item, rootMidi: r, arpeggiate: true),
      TrainerKind.scale => f.scale(item, root: r),
      TrainerKind.progression => f.progression(item, keyRoot: r - 12),
    };
  }

  void _play(String item) => TrainerScope.of(context).audio.play(_demo(item));

  void _singChanged() {
    if (mounted) setState(() {});
  }

  TrainerPitchSingTarget _singTarget(String item) {
    final store = TrainerScope.read(context).store;
    return TrainerPitchSingTarget.forNode(
      node: node,
      itemId: item,
      register: node.registers.first,
      voice: store.part,
      timbre: store.timbre,
    );
  }

  Future<TrainerPitchSingSession?> _sessionFor(String item) async {
    final current = _singSession;
    if (current != null && _singItem == item) return current;
    final generation = ++_singGeneration;
    current?.removeListener(_singChanged);
    if (mounted) {
      setState(() {
        _singSession = null;
        _singItem = item;
        _singUnavailable = false;
      });
    }
    if (current != null) await _closeAndDispose(current);
    if (!mounted || generation != _singGeneration) return null;
    final factory =
        widget.pitchSingSessionFactory ?? createMobileTrainerPitchSingSession;
    late final TrainerPitchSingSession session;
    try {
      session = factory(_singTarget(item));
    } catch (_) {
      if (mounted && generation == _singGeneration) {
        setState(() => _singUnavailable = true);
      }
      return null;
    }
    session.addListener(_singChanged);
    setState(() => _singSession = session);
    return session;
  }

  Future<void> _calibrateSing(String item) async {
    final session = await _sessionFor(item);
    if (session != null) await session.calibrate();
  }

  Future<void> _startSing(String item) async {
    final session = await _sessionFor(item);
    if (session != null) await session.startAttempt();
  }

  void _releaseSingSession() {
    ++_singGeneration;
    final session = _singSession;
    session?.removeListener(_singChanged);
    _singSession = null;
    _singItem = null;
    _singUnavailable = false;
    if (session != null) unawaited(_closeAndDispose(session));
  }

  Future<void> _closeAndDispose(TrainerPitchSingSession session) async {
    try {
      await session.close();
    } finally {
      session.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => switch (_step) {
    _Step.practice => QuizView(
      key: const ValueKey('practice'),
      title: node.isGate
          ? node.title
          : tr('Ayırt et · ${node.title}', 'Tell apart · ${node.title}'),
      color: color,
      questions: node.isGate ? _gen.session() : _gen.lessonPractice(node),
      showCounter: true,
      forceHints: !node.isGate,
      onExit: () => Navigator.of(context).pop(false),
      onFinished: (summary) {
        _summary = summary;
        _finishNode(summary.accuracy);
        setState(() => _step = _Step.result);
      },
    ),
    _Step.result => SessionEnd(
      node: node,
      summary: _summary!,
      passed: _passed,
      retryConfig: _gen.config,
      onDone: () => Navigator.of(context).pop(_passed),
    ),
    _ => _frame(),
  };

  Widget _frame() {
    final (body, button) = switch (_step) {
      _Step.overview => (
        _overview(),
        node.isGate
            ? tr('Teste başla', 'Start the test')
            : tr('Başla', 'Start'),
      ),
      _Step.listen => (
        _intro
            ? _introPage(path.introSlides[_page])
            : node.newItems.isEmpty
            ? _comparePage()
            : _meetPage(node.newItems[_page]),
        _intro && _page == _pageCount - 1
            ? tr('Tamam', 'OK')
            : tr('İleri', 'Next'),
      ),
      _ => (_singPage(), tr('Ayırt etmeye geç', 'On to telling apart')),
    };
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  BackSquare(
                    icon: Ic.x,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  Expanded(
                    child: Text(
                      trCaps(kind.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.crumb,
                    ),
                  ),
                  if (!_intro && !node.isGate) _phaseDots(),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey('$_step-$_page'),
                  child: body,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
              child: BigButton(
                key: const Key('lesson_next'),
                label: button,
                color: color,
                onPressed: _forward,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dinle · Söyle · Ayırt et, current phase highlighted.
  Widget _phaseDots() {
    final active = switch (_step) {
      _Step.overview => -1,
      _Step.listen => 0,
      _Step.sing => 1,
      _ => 2,
    };
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(left: 4),
            width: i == active ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= active ? color : TC.line,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _overview() {
    final stage =
        path.nodes
            .where(
              (n) =>
                  n.kind == NodeKind.checkpoint &&
                  path.indexOf(n.id) < path.indexOf(node.id),
            )
            .length +
        1;
    final steps = node.isGate
        ? [
            (
              Ic.clipboardCheck,
              tr('Ayırt et', 'Tell apart'),
              node.kind == NodeKind.finalExam
                  ? tr(
                      '20 soru · %80 ile tamamlanır',
                      '20 questions · complete with 80%',
                    )
                  : tr(
                      '12 soru · %80 ile önceki dersler de tamamlanır',
                      '12 questions · 80% also completes the lessons before',
                    ),
            ),
          ]
        : [
            (
              Ic.ear,
              tr('Dinle', 'Listen'),
              node.newItems.isEmpty
                  ? tr(
                      'Bildiklerini yan yana çal',
                      'Play what you know side by side',
                    )
                  : tr(
                      'Yeni ${kind.unitWord}: ${node.newItems.map((i) => _label(i, long: false)).join(', ')}',
                      'New ${kind.unitWord}: ${node.newItems.map((i) => _label(i, long: false)).join(', ')}',
                    ),
            ),
            (
              Ic.mic,
              tr('Söyle', 'Sing'),
              tr(
                'Duyduğunu sesli tekrar et · ölçülmez',
                'Sing back what you heard · not measured',
              ),
            ),
            (
              Ic.clipboardCheck,
              tr('Ayırt et', 'Tell apart'),
              tr(
                '${node.items.length} seçenekli kısa tur',
                'A short round with ${node.items.length} choices',
              ),
            ),
          ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      children: [
        Text(switch (node.kind) {
          NodeKind.checkpoint => tr('ARA DURAK', 'CHECKPOINT'),
          NodeKind.finalExam => tr('KONSER PROVASI', 'DRESS REHEARSAL'),
          _ => tr('BASAMAK $stage', 'STAGE $stage'),
        }, style: TT.caps.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(node.title, style: TT.h1),
        const SizedBox(height: 6),
        Text(node.subtitle, style: TT.body),
        const SizedBox(height: 24),
        for (final (icon, title, body) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TT.title),
                        Text(body, style: TT.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _introPage(IntroSlide s) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
    children: [
      Text('${_page + 1} / $_pageCount', style: TT.caps.copyWith(color: color)),
      const SizedBox(height: 4),
      Text(s.title, style: TT.h1),
      const SizedBox(height: 8),
      Text(s.body, style: TT.body),
      const SizedBox(height: 20),
      for (final b in s.bullets)
        BulletCard(b, color: color, highlight: s.highlight),
    ],
  );

  List<(String, String)> _facts(String item) => switch (kind) {
    TrainerKind.pitch => [
      (
        tr('Yeri', 'Place'),
        tr(
          '${_label('0')}\'ya göre ${int.parse(item)} yarım ses yukarıda',
          '${int.parse(item)} semitones above ${_label('0')}',
        ),
      ),
    ],
    TrainerKind.interval => [
      (
        tr('Genişlik', 'Size'),
        tr(
          '${Intervals.byId(item).semitones} yarım ses',
          '${Intervals.byId(item).semitones} semitones',
        ),
      ),
      (tr('Solfej örneği', 'Example'), Intervals.byId(item).anchor),
    ],
    TrainerKind.chord => [
      (tr('Ses sayısı', 'Notes'), '${Chords.byId(item).tones.length}'),
    ],
    TrainerKind.scale => [
      (tr('Nota sayısı', 'Notes'), '${Scales.byId(item).steps.length}'),
    ],
    TrainerKind.progression => [
      (tr('Akor sayısı', 'Chords'), '${Progressions.byId(item).chords.length}'),
    ],
  };

  Widget _meetPage(String item) {
    final store = TrainerScope.of(context).store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      children: [
        Text(
          tr(
            'DİNLE · ${_page + 1} / $_pageCount',
            'LISTEN · ${_page + 1} / $_pageCount',
          ),
          style: TT.caps.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(_label(item), style: TT.h1),
        const SizedBox(height: 6),
        Text(itemFeel(kind, item), style: TT.body),
        const SizedBox(height: 18),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (k, v) in _facts(item))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 110, child: Text(k, style: TT.small)),
                      Expanded(child: Text(v, style: TT.title)),
                    ],
                  ),
                ),
              if (kind == TrainerKind.scale) ...[
                const SizedBox(height: 6),
                ScaleLadder(scale: Scales.byId(item), color: color),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('lesson_play'),
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _play(item),
                icon: const Icon(Ic.play),
                label: Text(tr('Çal', 'Play')),
              ),
            ),
            if (kind != TrainerKind.pitch) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    minimumSize: const Size.fromHeight(50),
                    side: BorderSide(color: color),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _root = _random.nextInt(12) - 5);
                    _play(item);
                  },
                  icon: const Icon(Ic.shuffle),
                  label: Text(tr('Başka yerden', 'From elsewhere')),
                ),
              ),
            ],
          ],
        ),
        if (store.part != null) ...[
          const SizedBox(height: 10),
          Text(
            tr(
              '${store.part!.title} aralığında çalınıyor.',
              'Playing in the ${store.part!.title.toLowerCase()} range.',
            ),
            textAlign: TextAlign.center,
            style: TT.small,
          ),
        ],
      ],
    );
  }

  Widget _comparePage() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
    children: [
      Text(
        tr('DİNLE · YAN YANA', 'LISTEN · SIDE BY SIDE'),
        style: TT.caps.copyWith(color: color),
      ),
      const SizedBox(height: 4),
      Text(node.title.replaceFirst(RegExp(r'^\d+\. '), ''), style: TT.h1),
      const SizedBox(height: 6),
      Text(
        tr(
          'Her birini çal; aradaki farkı tek cümleyle kendine söyle.',
          'Play each one; tell yourself the difference in one sentence.',
        ),
        style: TT.body,
      ),
      const SizedBox(height: 18),
      for (final item in node.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => _play(item),
            child: Row(
              children: [
                Icon(Ic.circlePlay, color: color, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label(item), style: TT.title),
                      Text(itemFeel(kind, item), style: TT.small),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  String _singPhaseLabel(TrainerPitchSingSession session) =>
      switch (session.phase) {
        SingleToneSessionPhase.idle =>
          session.calibration?.isUsable == true
              ? tr(
                  'Hazır · referansı dinleyip söyleyebilirsin',
                  'Ready · listen to the reference, then sing',
                )
              : tr(
                  'Önce birkaç saniye sessiz kalıp ortamı ölç',
                  'First stay quiet for a few seconds to measure the room',
                ),
        SingleToneSessionPhase.calibrating => tr(
          'Ortam sesi ölçülüyor…',
          'Measuring the room…',
        ),
        SingleToneSessionPhase.preparing => tr(
          'Mikrofon hazırlanıyor…',
          'Preparing the microphone…',
        ),
        SingleToneSessionPhase.referencePlaying => tr(
          'Dinle · henüz söyleme',
          'Listen · do not sing yet',
        ),
        SingleToneSessionPhase.waiting => tr('Hazırlan…', 'Get ready…'),
        SingleToneSessionPhase.responding => tr('Şimdi söyle', 'Sing now'),
        SingleToneSessionPhase.assessing => tr(
          'Kayıt kalitesi kontrol ediliyor…',
          'Checking the recording quality…',
        ),
        SingleToneSessionPhase.analyzing => tr(
          'Ses adayı inceleniyor…',
          'Examining the pitch candidate…',
        ),
        SingleToneSessionPhase.finished => _singOutcomeLabel(session),
        SingleToneSessionPhase.closed => tr('Oturum kapandı', 'Session closed'),
      };

  String _singOutcomeLabel(TrainerPitchSingSession session) {
    final outcome = session.diagnosticOutcome;
    if (outcome == null) {
      return tr('Yeni bir deneme yapabilirsin', 'You can try again');
    }
    if (outcome.needsRetry) {
      return switch (outcome.retryReason!) {
        SessionRetryReason.calibrationRequired => tr(
          'Ortam ölçümünü yenile',
          'Measure the room again',
        ),
        SessionRetryReason.permissionDenied => tr(
          'Mikrofon izni verilmedi · istersen bu adımı geç',
          'Microphone permission not given · skip this step if you like',
        ),
        SessionRetryReason.routeUnsupported => tr(
          'Bu ses yolu ölçüm için uygun değil · kulaklıkla tekrar dene',
          'This audio route cannot be measured · try again with headphones',
        ),
        SessionRetryReason.interrupted => tr(
          'Deneme kesildi · sonuç sayılmadı',
          'The attempt was interrupted · not counted',
        ),
        SessionRetryReason.captureFailed => tr(
          'Kayıt alınamadı · sonuç sayılmadı',
          'Nothing was recorded · not counted',
        ),
        SessionRetryReason.quality => tr(
          'Ses yeterince ayrışmadı · sonuç sayılmadı',
          'The voice was not clear enough · not counted',
        ),
        SessionRetryReason.analysisFailed => tr(
          'Ses analizi tamamlanamadı · sonuç sayılmadı',
          'The analysis could not finish · not counted',
        ),
      };
    }
    final deviation = outcome.deviation;
    if (deviation == null) {
      return tr(
        'Kararlı bir ses adayı bulunamadı',
        'No steady pitch candidate was found',
      );
    }
    final cents = deviation.absoluteCents.round();
    final sign = cents > 0 ? '+' : '';
    return tr(
      'Tanısal fark: $sign$cents sent · puan değil',
      'Diagnostic difference: $sign$cents cents · not a score',
    );
  }

  String _sourceLabel(MeasurementSource source) => switch (source) {
    MeasurementSource.microphone => tr(
      'Mikrofon kaydı',
      'Microphone recording',
    ),
    MeasurementSource.mock => tr('Test kaynağı', 'Test source'),
    MeasurementSource.synthetic => tr('Sentetik kaynak', 'Synthetic source'),
    MeasurementSource.touch => tr('Dokunma', 'Touch'),
    MeasurementSource.unverified => tr(
      'Doğrulanmamış kaynak',
      'Unverified source',
    ),
  };

  bool _singActive(TrainerPitchSingSession session) => const {
    SingleToneSessionPhase.calibrating,
    SingleToneSessionPhase.preparing,
    SingleToneSessionPhase.referencePlaying,
    SingleToneSessionPhase.waiting,
    SingleToneSessionPhase.responding,
    SingleToneSessionPhase.assessing,
    SingleToneSessionPhase.analyzing,
  }.contains(session.phase);

  Widget _pitchDiagnostic(String item) {
    final session = _singItem == item ? _singSession : null;
    final active = session != null && _singActive(session);
    final calibrated = session?.calibration?.isUsable == true;
    final outcome = session?.diagnosticOutcome;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Ic.mic, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('İsteğe bağlı ses kontrolü', 'Optional voice check'),
                  style: TT.title,
                ),
              ),
              Text(tr('PUANSIZ', 'UNSCORED'), style: TT.caps),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? _singUnavailable
                      ? tr(
                          'Ses kontrolü bu cihazda başlatılamadı · istersen adımı geç',
                          'The voice check could not start on this device · skip the step if you like',
                        )
                      : tr(
                          'Mikrofon yalnız sen başlatırsan açılır. Bu kontrol ders sonucunu değiştirmez.',
                          'The microphone opens only if you start it. This check does not change the lesson result.',
                        )
                : _singPhaseLabel(session),
            key: const Key('sing_diagnostic_status'),
            style: TT.small,
            semanticsLabel: session == null
                ? _singUnavailable
                      ? tr(
                          'İsteğe bağlı ses kontrolü kullanılamıyor',
                          'Optional voice check unavailable',
                        )
                      : tr(
                          'İsteğe bağlı ses kontrolü hazır',
                          'Optional voice check ready',
                        )
                : _singPhaseLabel(session),
          ),
          if (outcome?.evidence != null) ...[
            const SizedBox(height: 6),
            Text(
              tr(
                'Kaynak: ${_sourceLabel(outcome!.evidence!.provenance.source)}',
                'Source: ${_sourceLabel(outcome.evidence!.provenance.source)}',
              ),
              key: const Key('sing_diagnostic_source'),
              style: TT.small,
            ),
          ],
          const SizedBox(height: 12),
          if (active)
            OutlinedButton.icon(
              key: const Key('sing_cancel'),
              onPressed: () => session.cancel(),
              icon: const Icon(Ic.circleStop),
              label: Text(tr('Durdur', 'Stop')),
            )
          else if (!calibrated)
            OutlinedButton.icon(
              key: const Key('sing_calibrate'),
              onPressed: () => _calibrateSing(item),
              icon: const Icon(Ic.settings2),
              label: Text(
                tr('Ortamı ölç ve hazırla', 'Measure the room and get ready'),
              ),
            )
          else
            FilledButton.icon(
              key: const Key('sing_start'),
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => _startSing(item),
              icon: const Icon(Ic.mic),
              label: Text(
                outcome == null
                    ? tr('Dinle ve söyle', 'Listen and sing')
                    : tr('Tekrar dene', 'Try again'),
              ),
            ),
        ],
      ),
    );
  }

  /// Singing back stays optional and unscored. Only pitch lessons may expose
  /// the calibrated diagnostic; every other trainer remains self-guided.
  Widget _singPage() {
    final focus = node.newItems.isEmpty ? node.items : node.newItems;
    final diagnosticItem = _singItem ?? focus.first;
    final diagnosticAvailable =
        kind == TrainerKind.pitch && TrainerScope.of(context).liveAudio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      children: [
        Text(tr('SÖYLE', 'SING'), style: TT.caps.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(
          tr(
            'Duy, sonra kendi sesinle tekrar et',
            'Hear it, then sing it back',
          ),
          style: TT.h1,
        ),
        const SizedBox(height: 6),
        Text(switch (kind) {
          TrainerKind.interval => tr(
            'İki notayı sırayla, la-la diye söyle.',
            'Sing the two notes in turn, on la-la.',
          ),
          TrainerKind.chord || TrainerKind.progression => tr(
            'Akorun en pes sesini mırıldan.',
            'Hum the lowest note of the chord.',
          ),
          TrainerKind.scale => tr(
            'Diziyi notaların adlarıyla yukarı çık.',
            'Sing up the scale with the note names.',
          ),
          TrainerKind.pitch => tr(
            'Notayı adıyla birlikte uzatarak söyle.',
            'Hold the note while singing its name.',
          ),
        }, style: TT.body),
        const SizedBox(height: 18),
        for (final item in focus)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => _play(item),
              child: Row(
                children: [
                  Icon(Ic.volume2, color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_label(item), style: TT.title)),
                  Text(tr('Çal', 'Play'), style: TT.small),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (diagnosticAvailable) ...[
          if (focus.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in focus)
                  ChoiceChip(
                    key: Key('sing_item_$item'),
                    selected: diagnosticItem == item,
                    label: Text(_label(item, long: false)),
                    onSelected: (_) {
                      if (item == diagnosticItem) return;
                      _releaseSingSession();
                      setState(() => _singItem = item);
                    },
                  ),
              ],
            ),
          if (focus.length > 1) const SizedBox(height: 12),
          _pitchDiagnostic(diagnosticItem),
          const SizedBox(height: 12),
        ],
        Text(
          tr(
            'Bu adım puanlanmaz ve ilerlemeye yazılmaz; kulak ile ses arasında bağ kurmak içindir.',
            'This step is not scored or added to progress; it links your ear and your voice.',
          ),
          style: TT.small,
        ),
      ],
    );
  }
}

/// Dots on a 12-step ladder; the colour note is highlighted.
class ScaleLadder extends StatelessWidget {
  const ScaleLadder({super.key, required this.scale, required this.color});
  final ScaleType scale;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: LayoutBuilder(
      builder: (context, c) {
        final step = c.maxWidth / 12;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 12,
              child: Container(
                height: 1.5,
                color: color.withValues(alpha: 0.4),
              ),
            ),
            for (var i = 0; i < scale.steps.length; i++)
              Positioned(
                left: scale.steps[i] * step - (scale.color == i ? 7 : 4),
                top: scale.color == i ? 5 : 8,
                child: Container(
                  width: scale.color == i ? 14 : 8,
                  height: scale.color == i ? 14 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scale.color == i ? TC.magenta : color,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(tr('KÖK', 'ROOT'), style: TT.caps),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Text(tr('OKTAV', 'OCTAVE'), style: TT.caps),
            ),
          ],
        );
      },
    ),
  );
}
