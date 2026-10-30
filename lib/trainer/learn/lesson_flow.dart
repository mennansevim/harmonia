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
      title: node.isGate ? node.title : 'Ayırt et · ${node.title}',
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
      _Step.overview => (_overview(), node.isGate ? 'Teste başla' : 'Başla'),
      _Step.listen => (
        _intro
            ? _introPage(path.introSlides[_page])
            : node.newItems.isEmpty
            ? _comparePage()
            : _meetPage(node.newItems[_page]),
        _intro && _page == _pageCount - 1 ? 'Tamam' : 'İleri',
      ),
      _ => (_singPage(), 'Ayırt etmeye geç'),
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
                  IconButton(
                    tooltip: 'Geri',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, color: TC.body),
                  ),
                  Expanded(
                    child: Text(
                      kind.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.title,
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
              Icons.fact_check_outlined,
              'Ayırt et',
              node.kind == NodeKind.finalExam
                  ? '20 soru · %80 ile tamamlanır'
                  : '12 soru · %80 ile önceki dersler de tamamlanır',
            ),
          ]
        : [
            (
              Icons.hearing_rounded,
              'Dinle',
              node.newItems.isEmpty
                  ? 'Bildiklerini yan yana çal'
                  : 'Yeni ${kind.unitWord}: ${node.newItems.map((i) => _label(i, long: false)).join(', ')}',
            ),
            (
              Icons.mic_none_rounded,
              'Söyle',
              'Duyduğunu sesli tekrar et · ölçülmez',
            ),
            (
              Icons.fact_check_outlined,
              'Ayırt et',
              '${node.items.length} seçenekli kısa tur',
            ),
          ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(switch (node.kind) {
          NodeKind.checkpoint => 'ARA DURAK',
          NodeKind.finalExam => 'KONSER PROVASI',
          _ => 'BASAMAK $stage',
        }, style: TT.caps.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(node.title, style: TT.h2),
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
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Text('${_page + 1} / $_pageCount', style: TT.caps.copyWith(color: color)),
      const SizedBox(height: 4),
      Text(s.title, style: TT.h2),
      const SizedBox(height: 8),
      Text(s.body, style: TT.body),
      const SizedBox(height: 20),
      for (final b in s.bullets)
        BulletCard(b, color: color, highlight: s.highlight),
    ],
  );

  List<(String, String)> _facts(String item) => switch (kind) {
    TrainerKind.pitch => [
      ('Yeri', '${_label('0')}\'ya göre ${int.parse(item)} yarım ses yukarıda'),
    ],
    TrainerKind.interval => [
      ('Genişlik', '${Intervals.byId(item).semitones} yarım ses'),
      ('Solfej örneği', Intervals.byId(item).anchor),
    ],
    TrainerKind.chord => [('Ses sayısı', '${Chords.byId(item).tones.length}')],
    TrainerKind.scale => [('Nota sayısı', '${Scales.byId(item).steps.length}')],
    TrainerKind.progression => [
      ('Akor sayısı', '${Progressions.byId(item).chords.length}'),
    ],
  };

  Widget _meetPage(String item) {
    final store = TrainerScope.of(context).store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text(
          'DİNLE · ${_page + 1} / $_pageCount',
          style: TT.caps.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(_label(item), style: TT.h2),
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
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Çal'),
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
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Başka yerden'),
                ),
              ),
            ],
          ],
        ),
        if (store.part != null) ...[
          const SizedBox(height: 10),
          Text(
            '${store.part!.title} aralığında çalınıyor.',
            textAlign: TextAlign.center,
            style: TT.small,
          ),
        ],
      ],
    );
  }

  Widget _comparePage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    children: [
      Text('DİNLE · YAN YANA', style: TT.caps.copyWith(color: color)),
      const SizedBox(height: 4),
      Text(node.title.replaceFirst(RegExp(r'^\d+\. '), ''), style: TT.h2),
      const SizedBox(height: 6),
      const Text(
        'Her birini çal; aradaki farkı tek cümleyle kendine söyle.',
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
                Icon(Icons.play_circle_outline_rounded, color: color, size: 30),
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
              ? 'Hazır · referansı dinleyip söyleyebilirsin'
              : 'Önce birkaç saniye sessiz kalıp ortamı ölç',
        SingleToneSessionPhase.calibrating => 'Ortam sesi ölçülüyor…',
        SingleToneSessionPhase.preparing => 'Mikrofon hazırlanıyor…',
        SingleToneSessionPhase.referencePlaying => 'Dinle · henüz söyleme',
        SingleToneSessionPhase.waiting => 'Hazırlan…',
        SingleToneSessionPhase.responding => 'Şimdi söyle',
        SingleToneSessionPhase.assessing => 'Kayıt kalitesi kontrol ediliyor…',
        SingleToneSessionPhase.analyzing => 'Ses adayı inceleniyor…',
        SingleToneSessionPhase.finished => _singOutcomeLabel(session),
        SingleToneSessionPhase.closed => 'Oturum kapandı',
      };

  String _singOutcomeLabel(TrainerPitchSingSession session) {
    final outcome = session.diagnosticOutcome;
    if (outcome == null) return 'Yeni bir deneme yapabilirsin';
    if (outcome.needsRetry) {
      return switch (outcome.retryReason!) {
        SessionRetryReason.calibrationRequired => 'Ortam ölçümünü yenile',
        SessionRetryReason.permissionDenied =>
          'Mikrofon izni verilmedi · istersen bu adımı geç',
        SessionRetryReason.routeUnsupported =>
          'Bu ses yolu ölçüm için uygun değil · kulaklıkla tekrar dene',
        SessionRetryReason.interrupted => 'Deneme kesildi · sonuç sayılmadı',
        SessionRetryReason.captureFailed => 'Kayıt alınamadı · sonuç sayılmadı',
        SessionRetryReason.quality =>
          'Ses yeterince ayrışmadı · sonuç sayılmadı',
        SessionRetryReason.analysisFailed =>
          'Ses analizi tamamlanamadı · sonuç sayılmadı',
      };
    }
    final deviation = outcome.deviation;
    if (deviation == null) return 'Kararlı bir ses adayı bulunamadı';
    final cents = deviation.absoluteCents.round();
    final sign = cents > 0 ? '+' : '';
    return 'Tanısal fark: $sign$cents sent · puan değil';
  }

  String _sourceLabel(MeasurementSource source) => switch (source) {
    MeasurementSource.microphone => 'Mikrofon kaydı',
    MeasurementSource.mock => 'Test kaynağı',
    MeasurementSource.synthetic => 'Sentetik kaynak',
    MeasurementSource.touch => 'Dokunma',
    MeasurementSource.unverified => 'Doğrulanmamış kaynak',
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
              Icon(Icons.mic_none_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text('İsteğe bağlı ses kontrolü', style: TT.title),
              ),
              const Text('PUANSIZ', style: TT.caps),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? _singUnavailable
                      ? 'Ses kontrolü bu cihazda başlatılamadı · istersen adımı geç'
                      : 'Mikrofon yalnız sen başlatırsan açılır. Bu kontrol ders sonucunu değiştirmez.'
                : _singPhaseLabel(session),
            key: const Key('sing_diagnostic_status'),
            style: TT.small,
            semanticsLabel: session == null
                ? _singUnavailable
                      ? 'İsteğe bağlı ses kontrolü kullanılamıyor'
                      : 'İsteğe bağlı ses kontrolü hazır'
                : _singPhaseLabel(session),
          ),
          if (outcome?.evidence != null) ...[
            const SizedBox(height: 6),
            Text(
              'Kaynak: ${_sourceLabel(outcome!.evidence!.provenance.source)}',
              key: const Key('sing_diagnostic_source'),
              style: TT.small,
            ),
          ],
          const SizedBox(height: 12),
          if (active)
            OutlinedButton.icon(
              key: const Key('sing_cancel'),
              onPressed: () => session.cancel(),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Durdur'),
            )
          else if (!calibrated)
            OutlinedButton.icon(
              key: const Key('sing_calibrate'),
              onPressed: () => _calibrateSing(item),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Ortamı ölç ve hazırla'),
            )
          else
            FilledButton.icon(
              key: const Key('sing_start'),
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: () => _startSing(item),
              icon: const Icon(Icons.mic_rounded),
              label: Text(outcome == null ? 'Dinle ve söyle' : 'Tekrar dene'),
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      children: [
        Text('SÖYLE', style: TT.caps.copyWith(color: color)),
        const SizedBox(height: 4),
        const Text('Duy, sonra kendi sesinle tekrar et', style: TT.h2),
        const SizedBox(height: 6),
        Text(switch (kind) {
          TrainerKind.interval => 'İki notayı sırayla, la-la diye söyle.',
          TrainerKind.chord ||
          TrainerKind.progression => 'Akorun en pes sesini mırıldan.',
          TrainerKind.scale => 'Diziyi notaların adlarıyla yukarı çık.',
          TrainerKind.pitch => 'Notayı adıyla birlikte uzatarak söyle.',
        }, style: TT.body),
        const SizedBox(height: 18),
        for (final item in focus)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => _play(item),
              child: Row(
                children: [
                  Icon(Icons.volume_up_outlined, color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_label(item), style: TT.title)),
                  const Text('Çal', style: TT.small),
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
        const Text(
          'Bu adım puanlanmaz ve ilerlemeye yazılmaz; kulak ile ses arasında bağ kurmak içindir.',
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
            const Positioned(
              left: 0,
              bottom: 0,
              child: Text('KÖK', style: TT.caps),
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: Text('OKTAV', style: TT.caps),
            ),
          ],
        );
      },
    ),
  );
}
