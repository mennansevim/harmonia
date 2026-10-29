import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/kit.dart';
import 'session_end.dart';

/// Runs one node of a trainer path end to end and pops with `true` when the
/// node was completed.
class LessonFlow extends StatefulWidget {
  const LessonFlow({super.key, required this.node, this.random});
  final LessonNode node;
  final math.Random? random;

  @override
  State<LessonFlow> createState() => _LessonFlowState();
}

enum _Step { start, slides, quickCheck, lockedIn, complete, practice, result }

class _LessonFlowState extends State<LessonFlow> {
  late final math.Random _random = widget.random ?? math.Random();
  late final QuizGenerator _gen = QuizGenerator(
    QuizConfig.forNode(
      widget.node,
      voice: TrainerScope.read(context).store.part,
    ),
    random: _random,
  );
  _Step _step = _Step.start;
  int _slide = 0;
  late final List<Widget Function()> _slides = _buildSlides();
  late final List<QuizQuestion> _check;
  QuizSummary? _summary;
  bool _passed = false;

  LessonNode get node => widget.node;
  TrainerKind get kind => node.trainer;
  Color get color => trainerColor(kind);
  TrainerPath get path => trainerPaths[kind]!;

  @override
  void initState() {
    super.initState();
    final focus = node.newItems.isEmpty ? node.items : node.newItems;
    _check = focus.isEmpty
        ? const []
        : [
            for (var i = 0; i < (kind == TrainerKind.scale ? 4 : 3); i++)
              kind == TrainerKind.scale
                  ? _gen.find(target: focus[i % focus.length], choices: 2)
                  : _gen.yesNo(target: focus[i % focus.length]),
          ];
    if (node.kind == NodeKind.intro) _step = _Step.slides;
  }

  void _finishNode(double accuracy) {
    final store = TrainerScope.of(context).store;
    _passed = store.completeNode(node, accuracy);
    // Reading the intro slides alone is not a finished practice session.
    if (node.kind != NodeKind.intro) store.recordSession();
  }

  // ---------------- slides ----------------

  List<Widget Function()> _buildSlides() {
    if (node.kind == NodeKind.intro) {
      return [
        for (final s in path.introSlides)
          () => _infoSlide(s.title, s.body, s.bullets, s.highlight),
        () => _readySlide('Hazırsın', switch (kind) {
          TrainerKind.interval =>
            'Sıçramayı dinle, karışımı dinle ve şarkı kancalarına yaslan. Aralıklarla tek tek tanışma zamanı.',
          TrainerKind.scale =>
            'Merdiveni duy, evle karşılaştır ve renk notasını ara. Dizilerle tek tek tanışma zamanı.',
          _ => 'Dinle, karşılaştır, hatırla. Şimdi ilk derse geçme zamanı.',
        }),
      ];
    }
    final focus = node.newItems;
    if (focus.isEmpty) {
      return [() => _compareSlide()];
    }
    return [
      for (final item in focus) ...[
        () => _conceptSlide(item),
        () => _hearSlide(item),
        if (kind == TrainerKind.interval) () => _hookSlide(item),
      ],
    ];
  }

  Widget _iconBox(IconData icon) => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: soft(color),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color),
  );

  Widget _infoSlide(
    String title,
    String body,
    List<String> bullets,
    List<String>? highlight,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
    children: [
      Text(title, textAlign: TextAlign.center, style: TT.h3),
      const SizedBox(height: 10),
      Text(body, textAlign: TextAlign.center, style: TT.body),
      const SizedBox(height: 22),
      Center(child: _iconBox(Icons.explore_outlined)),
      const SizedBox(height: 22),
      for (final b in bullets)
        BulletCard(b, color: color, highlight: highlight),
    ],
  );

  Widget _readySlide(String title, String body) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBox(Icons.check_rounded),
        const SizedBox(height: 18),
        Text(title, style: TT.h3),
        const SizedBox(height: 10),
        Text(body, textAlign: TextAlign.center, style: TT.body),
      ],
    ),
  );

  String _label(String id, {bool long = true}) {
    final store = TrainerScope.of(context).store;
    return itemLabel(kind, id, notation: store.notation, long: long);
  }

  List<String> _bullets(String item) => switch (kind) {
    TrainerKind.pitch => [
      '${_label(item)} notasını içinden söyle; rengini ezberle.',
      'Ayırt ederken hesap yapma, hisse güven.',
      'Yeni nota eklendikçe öncekilerle karşılaştır.',
    ],
    TrainerKind.interval => [
      '${Intervals.byId(item).semitones} yarım ses genişliğinde.',
      Intervals.byId(item).feel,
      'Kanca: ${Intervals.byId(item).hook}.',
    ],
    TrainerKind.chord => [
      Chords.byId(item).feel,
      '${Chords.byId(item).tones.length} sesli bir akor.',
      'Önce bütün hissi dinle, sonra notaları.',
    ],
    TrainerKind.scale => [
      Scales.byId(item).feel,
      '${Scales.byId(item).steps.length} notalı bir dizi.',
      if (Scales.byId(item).color != null)
        'Renk notası merdivende vurgulanır.'
      else
        'Tüm dereceler eşit derecede önemli.',
    ],
    TrainerKind.progression => [
      Progressions.byId(item).feel,
      'Bas notanın yolunu takip et.',
      '${Progressions.byId(item).chords.length} akorlu kalıp.',
    ],
  };

  Widget _conceptSlide(String item) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
    children: [
      Text(_label(item), textAlign: TextAlign.center, style: TT.h3),
      const SizedBox(height: 10),
      Text(itemFeel(kind, item), textAlign: TextAlign.center, style: TT.body),
      const SizedBox(height: 22),
      Center(child: _iconBox(Icons.track_changes_rounded)),
      const SizedBox(height: 22),
      for (final b in _bullets(item)) BulletCard(b, color: color),
    ],
  );

  int _root = 0;

  SoundSpec _demo(String item, {bool learn = true}) {
    final f = SoundFactory(_random);
    final r = Register.medium.rootC + _root;
    return switch (kind) {
      TrainerKind.pitch => f.note(Register.medium.rootC + int.parse(item)),
      TrainerKind.interval => f.interval(item, rootMidi: r, learn: learn),
      TrainerKind.chord => f.chord(item, rootMidi: r, arpeggiate: learn),
      TrainerKind.scale => f.scale(item, root: r),
      TrainerKind.progression => f.progression(item, keyRoot: r - 12),
    };
  }

  Widget _hearSlide(String item) {
    final audio = TrainerScope.of(context).audio;
    final store = TrainerScope.of(context).store;
    return StatefulBuilder(
      builder: (context, setLocal) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        children: [
          Text(
            '${_label(item)} sesini duy',
            textAlign: TextAlign.center,
            style: TT.h3,
          ),
          const SizedBox(height: 10),
          Text(
            switch (kind) {
              TrainerKind.interval =>
                'Pes nota, tiz nota, sonra ikisi birlikte. İki notanın nasıl kaynaştığına dikkat et.',
              TrainerKind.scale =>
                'Merdivenin ev notasının üzerinden tırmanışını dinle.',
              TrainerKind.chord => 'Önce notalar tek tek, sonra akor birlikte.',
              _ => 'Dinle ve sesin rengini aklında tut.',
            },
            textAlign: TextAlign.center,
            style: TT.body,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: soft(color).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_label(item), style: TT.title),
                          const SizedBox(height: 4),
                          Text(
                            switch (kind) {
                              TrainerKind.interval =>
                                '${item.toUpperCase()} · ${Intervals.byId(item).semitones} YARIM SES',
                              TrainerKind.scale =>
                                '${Scales.byId(item).steps.length} NOTA',
                              TrainerKind.chord =>
                                '${Chords.byId(item).tones.length} SES',
                              _ => 'DİNLE',
                            },
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('lesson_play'),
                      tooltip: 'Çal',
                      style: IconButton.styleFrom(
                        backgroundColor: color,
                        fixedSize: const Size(52, 52),
                      ),
                      onPressed: () => audio.play(_demo(item)),
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                  ],
                ),
                if (kind == TrainerKind.scale) ...[
                  const SizedBox(height: 16),
                  ScaleLadder(scale: Scales.byId(item), color: color),
                ],
              ],
            ),
          ),
          if (kind != TrainerKind.pitch) ...[
            const SizedBox(height: 20),
            const Text(
              'HERHANGİ BİR NOTADAN DİNLE',
              textAlign: TextAlign.center,
              style: TT.caps,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final pc in PitchClass.whiteKeys)
                  ChoiceChip(
                    label: Text(
                      PitchClass.name(pc, store.notation).toUpperCase(),
                    ),
                    selected: _root == pc,
                    showCheckmark: false,
                    selectedColor: color,
                    labelStyle: TextStyle(
                      color: _root == pc ? Colors.white : color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                    backgroundColor: soft(color),
                    shape: const StadiumBorder(),
                    onSelected: (_) {
                      setLocal(() => _root = pc);
                      audio.play(_demo(item));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Aynı kalıp, farklı başlangıç notası. Birkaçına dokun, tanıdık gelince devam et.',
              textAlign: TextAlign.center,
              style: TT.small,
            ),
          ],
        ],
      ),
    );
  }

  Widget _hookSlide(String item) {
    final iv = Intervals.byId(item);
    final audio = TrainerScope.of(context).audio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Text(
          '${iv.name} için bir kanca: ${iv.hook}.',
          textAlign: TextAlign.center,
          style: TT.body.copyWith(color: TC.ink),
        ),
        const SizedBox(height: 22),
        AppCard(
          color: const Color(0xFFF7F7FC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BÖYLE HATIRLA', style: TT.caps),
              const SizedBox(height: 4),
              Text(iv.hook, style: TT.title),
              const SizedBox(height: 18),
              SizedBox(
                height: 110,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _LeapPainter(iv.semitones, color),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => audio.play(
                    SoundFactory(_random).interval(item, rootMidi: 60),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('ÇAL'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compareSlide() {
    final audio = TrainerScope.of(context).audio;
    final items = node.items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        Text(
          node.title.replaceFirst(RegExp(r'^\d+\. '), ''),
          textAlign: TextAlign.center,
          style: TT.h3,
        ),
        const SizedBox(height: 10),
        Text(
          'Her birini çal, sonra farkı dinle. ${node.subtitle}',
          textAlign: TextAlign.center,
          style: TT.body,
        ),
        const SizedBox(height: 22),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => audio.play(_demo(item, learn: false)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label(item), style: TT.title),
                        const SizedBox(height: 2),
                        Text(itemFeel(kind, item), style: TT.small),
                      ],
                    ),
                  ),
                  Icon(Icons.play_circle_fill_rounded, color: color, size: 36),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---------------- navigation ----------------

  void _nextSlide() {
    if (_slide < _slides.length - 1) {
      setState(() => _slide++);
      return;
    }
    if (node.kind == NodeKind.intro) {
      _finishNode(1);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _step = _Step.quickCheck);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.start => _startScreen(),
      _Step.slides => _slidesScreen(),
      _Step.quickCheck => QuizView(
        key: const ValueKey('quick'),
        title: node.title,
        color: color,
        questions: _check,
        record: false,
        forceHints: true,
        showCounter: false,
        quickCheckLabel: 'KISA YOKLAMA',
        onExit: () => Navigator.of(context).pop(false),
        onFinished: (_) => setState(() => _step = _Step.lockedIn),
      ),
      _Step.lockedIn => _lockedIn(),
      _Step.complete => _lessonComplete(),
      _Step.practice => QuizView(
        key: const ValueKey('practice'),
        title: node.isGate ? node.title : 'Pratik',
        color: node.isGate ? color : TC.magenta,
        questions: node.isGate ? _gen.session() : _gen.lessonPractice(node),
        showCounter: node.isGate,
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
        onDone: () => Navigator.of(context).pop(_passed),
      ),
    };
  }

  Widget _startScreen() {
    final gate = node.isGate;
    final unit =
        path.nodes
            .where(
              (n) => n.isGate && path.indexOf(n.id) < path.indexOf(node.id),
            )
            .length +
        1;
    final lessonsInUnit = _unitSize(unit);
    final indexInUnit = _indexInUnit();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: gate ? node.title : 'Öğren',
              shadow: true,
              onBack: () => Navigator.of(context).pop(false),
            ),
            if (!gate) _stepper(learn: true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Tag(switch (node.kind) {
                      NodeKind.checkpoint => 'KONTROL NOKTASI',
                      NodeKind.finalExam => 'FİNAL SINAVI',
                      _ when node.newItems.isEmpty => 'YENİ KARŞILAŞTIRMA',
                      _ => 'YENİ ${kind.unitWord.toUpperCase()}',
                    }, color: TC.primary),
                    const SizedBox(height: 16),
                    TrainerBadge(
                      color: gate ? color : TC.primary,
                      icon: gate ? Icons.flag_rounded : trainerIcon(kind),
                      size: 72,
                    ),
                    const SizedBox(height: 18),
                    Text(node.title, textAlign: TextAlign.center, style: TT.h2),
                    const SizedBox(height: 8),
                    Text(
                      node.subtitle,
                      textAlign: TextAlign.center,
                      style: TT.body,
                    ),
                    if (gate) ...[
                      const SizedBox(height: 16),
                      Text(
                        node.kind == NodeKind.finalExam
                            ? '20 soru · %80 ile geçersin'
                            : '12 soru · %80 ile geçersin; geçersen önceki dersleri atlarsın',
                        textAlign: TextAlign.center,
                        style: TT.small,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Text(
                        'Ünite $unit · Ders $indexInUnit / $lessonsInUnit',
                        style: TT.small,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: BigButton(
                label: gate ? 'Teste başla' : 'Derse başla',
                chevron: true,
                color: gate ? color : TC.primary,
                onPressed: () => setState(
                  () => _step = gate ? _Step.practice : _Step.slides,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _unitSize(int unit) {
    var u = 1;
    var count = 0;
    for (final n in path.nodes) {
      if (n.kind == NodeKind.intro) continue;
      if (n.isGate) {
        if (u == unit) return count;
        u++;
        count = 0;
      } else {
        count++;
      }
    }
    return count;
  }

  int _indexInUnit() {
    var count = 0;
    for (final n in path.nodes) {
      if (n.kind == NodeKind.intro) continue;
      if (n.isGate) {
        count = 0;
        continue;
      }
      count++;
      if (n.id == node.id) return count;
    }
    return count;
  }

  Widget _stepper({required bool learn}) => Padding(
    padding: const EdgeInsets.fromLTRB(40, 4, 40, 8),
    child: Row(
      children: [
        _dot('Öğren', true),
        Expanded(child: Container(height: 2, color: TC.line)),
        _dot('Pratik', !learn),
      ],
    ),
  );

  Widget _dot(String label, bool active) => Column(
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Colors.white : const Color(0xFFE4E3EF),
          border: Border.all(
            color: active ? TC.primary : const Color(0xFFE4E3EF),
            width: 4,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: active ? TC.primary : TC.muted,
        ),
      ),
    ],
  );

  Widget _slidesScreen() {
    final isIntro = node.kind == NodeKind.intro;
    final last = _slide == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: node.title,
              progress: (_slide + 1) / (_slides.length + (isIntro ? 0 : 3)),
              progressColor: color,
              onBack: () {
                if (_slide > 0) {
                  setState(() => _slide--);
                } else {
                  Navigator.of(context).pop(false);
                }
              },
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: KeyedSubtree(
                  key: ValueKey(_slide),
                  child: _slides[_slide](),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: BigButton(
                key: const Key('lesson_next'),
                label: isIntro && last ? 'Tamam' : 'İleri',
                color: kind == TrainerKind.pitch ? TC.primary : color,
                onPressed: _nextSlide,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedIn() => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          TopBar(title: node.title, progress: 0.92, progressColor: color),
          Expanded(
            child: _readySlide(
              'Yerine oturdu',
              node.newItems.isEmpty
                  ? 'Farkı duydun. Şimdi pratikte pekiştirelim.'
                  : '${node.newItems.map((i) => _label(i)).join(', ')} artık kulağında. Bu senin yeni işaret noktan.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BigButton(
              label: 'Devam',
              color: kind == TrainerKind.pitch ? TC.primary : color,
              onPressed: () => setState(() => _step = _Step.complete),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _lessonComplete() => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          TopBar(
            title: 'Öğren',
            shadow: true,
            onBack: () => Navigator.of(context).pop(false),
          ),
          _stepper(learn: false),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Tag('DERS TAMAMLANDI', color: TC.primary),
                const SizedBox(height: 16),
                TrainerBadge(color: color, icon: trainerIcon(kind), size: 76),
                const SizedBox(height: 18),
                Text(kind.title, style: TT.h2),
                const SizedBox(height: 6),
                Text(node.title, style: TT.small),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BigButton(
              label: 'Devam et',
              chevron: true,
              color: color,
              onPressed: () => setState(() => _step = _Step.practice),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LeapPainter extends CustomPainter {
  _LeapPainter(this.semitones, this.color);
  final int semitones;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final y1 = size.height * 0.75;
    final y2 = size.height * (0.75 - 0.55 * semitones / 12);
    final a = Offset(size.width * 0.28, y1);
    final b = Offset(size.width * 0.68, y2);
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 4,
    );
    for (final p in [a, b]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 70, height: 30),
          const Radius.circular(15),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LeapPainter old) => old.semitones != semitones;
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
            for (var i = 0; i <= 12; i++)
              Positioned(
                left: i * step - (i == 12 ? 1 : 0),
                top: 6,
                child: Container(
                  width: 1,
                  height: 12,
                  color: color.withValues(alpha: 0.3),
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
              right: 0,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
