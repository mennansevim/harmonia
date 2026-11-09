import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/placement.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/kit.dart';
import '../../domain/lang.dart';

/// Placement test on one path (PLACE-01): the path's own gates, asked with
/// early stop, starting where the stated level suggests. A passed gate is
/// recorded through the store's normal gate rule. Pops `true` when the
/// learner wants to start the next lesson right away.
class PlacementFlow extends StatefulWidget {
  const PlacementFlow({super.key, required this.trainer, required this.level});
  final TrainerKind trainer;
  final ExperienceLevel level;

  @override
  State<PlacementFlow> createState() => _PlacementFlowState();
}

enum _Phase { intro, quiz, between, done }

class _PlacementFlowState extends State<PlacementFlow> {
  late final PlacementRun _run = PlacementRun(
    trainerPaths[widget.trainer]!,
    widget.level,
  );
  _Phase _phase = _Phase.intro;
  LessonNode? _lastGate;
  bool _lastPassed = false;
  int _round = 0;

  QuizConfig _config(LessonNode gate) =>
      QuizConfig.forNode(gate, voice: TrainerScope.read(context).store.part);

  void _finishGate(LessonNode gate, GateStop stop, QuizSummary summary) {
    final correct = summary.correct;
    final wrong = summary.total - correct;
    final passed = stop.verdict(correct, wrong) ?? false;
    final store = TrainerScope.read(context).store;
    store.completeNode(
      gate,
      stop.accuracy(correct),
      correct: correct,
      total: summary.total,
    );
    _run.record(passed);
    _lastGate = gate;
    _lastPassed = passed;
    _save();
    setState(() => _phase = _run.done ? _Phase.done : _Phase.between);
  }

  void _stopHere() {
    _run.stop();
    _save();
    setState(() => _phase = _Phase.done);
  }

  void _save() {
    final store = TrainerScope.read(context).store;
    final placed = Map<String, Object?>.from(
      (store.answers['placed'] as Map?) ?? const {},
    );
    placed[widget.trainer.id] = _run.placed?.id ?? '';
    store.answers['placed'] = placed;
    store.lastTrainer = widget.trainer.id;
    store.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.quiz) {
      final gate = _run.current!;
      final config = _config(gate);
      final stop = GateStop(config.length);
      return QuizView(
        key: ValueKey('placement_${gate.id}_$_round'),
        title: tr('Seviye testi · ${gate.title}', 'Placement · ${gate.title}'),
        color: trainerColor(widget.trainer),
        questions: QuizGenerator(config).session(),
        showCounter: true,
        stopWhen: (records) {
          final correct = records.where((r) => r.correct).length;
          return stop.verdict(correct, records.length - correct) != null;
        },
        onExit: _stopHere,
        onFinished: (summary) => _finishGate(gate, stop, summary),
      );
    }
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BackSquare(
                  icon: Ic.x,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_phase) {
                    _Phase.intro => _intro(),
                    _Phase.between => _between(),
                    _ => _done(),
                  },
                ),
              ),
              ..._buttons(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buttons() => switch (_phase) {
    _Phase.intro => [
      BigButton(
        key: const Key('placement_start'),
        label: tr('Teste başla', 'Start the test'),
        icon: Ic.play,
        onPressed: () => setState(() => _phase = _Phase.quiz),
      ),
      Center(
        child: TextLink(
          tr('Şimdi değil', 'Not now'),
          onTap: () => Navigator.of(context).pop(false),
        ),
      ),
    ],
    _Phase.between => [
      BigButton(
        key: const Key('placement_continue'),
        label: tr('Devam et', 'Continue'),
        icon: Ic.arrowRight,
        onPressed: () => setState(() {
          _round++;
          _phase = _Phase.quiz;
        }),
      ),
      Center(
        child: TextLink(
          tr('Burada durayım', 'Stop here'),
          key: const Key('placement_stop'),
          onTap: _stopHere,
        ),
      ),
    ],
    _ => [
      BigButton(
        key: const Key('placement_begin'),
        label: tr('Derse başla', 'Start the lesson'),
        icon: Ic.play,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      Center(
        child: TextLink(
          tr('Ana sayfaya git', 'Go to home'),
          onTap: () => Navigator.of(context).pop(false),
        ),
      ),
    ],
  };

  Widget _intro() {
    final first = _run.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('SEVİYE TESTİ', 'PLACEMENT'), style: TT.caps),
        const SizedBox(height: 4),
        Text(
          tr('Bildiklerini atlayalım', 'Let\'s skip what you know'),
          style: TT.h1,
        ),
        const SizedBox(height: 12),
        Text(
          tr(
            '${widget.trainer.title} yolunun ara duraklarından kısa turlar. '
                '${first?.title ?? ''} ile başlıyoruz.',
            'Short rounds from the checkpoints of ${widget.trainer.title}. '
                'We start with ${first?.title ?? ''}.',
          ),
          style: TT.body,
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bullet(
                tr(
                  'Geçme kuralı derstekiyle aynı: %80.',
                  'The pass mark is the same as in lessons: 80%.',
                ),
              ),
              _bullet(
                tr(
                  'Sonuç belli olunca tur erken biter; kalan sorular sorulmaz.',
                  'A round ends as soon as the result is settled.',
                ),
              ),
              _bullet(
                tr(
                  'Her turdan sonra durabilirsin.',
                  'You can stop after any round.',
                ),
              ),
              _bullet(
                tr(
                  'Sonuç yaklaşıktır; dersleri istediğin zaman elle açabilirsin.',
                  'The result is approximate; you can open any lesson yourself.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _between() {
    final gate = _lastGate!;
    final next = _run.current!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _lastPassed ? Ic.circleCheck : Ic.rotateCcw,
          color: TC.primary,
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          _lastPassed
              ? tr('${gate.title} geçildi', '${gate.title} passed')
              : tr(
                  '${gate.title} bu sefer olmadı',
                  '${gate.title} not this time',
                ),
          key: const Key('placement_verdict'),
          style: TT.h1,
        ),
        const SizedBox(height: 8),
        Text(
          _lastPassed
              ? tr(
                  'Bir üst durağı deneyelim: ${next.title}.',
                  'Let\'s try the next one: ${next.title}.',
                )
              : tr(
                  'Bir alt durağı deneyelim: ${next.title}.',
                  'Let\'s try the one below: ${next.title}.',
                ),
          style: TT.body,
        ),
      ],
    );
  }

  Widget _done() {
    final store = TrainerScope.of(context).store;
    final next = store.nextNodeAfterIntro(widget.trainer);
    final placed = _run.placed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('SONUÇ', 'RESULT'), style: TT.caps),
        const SizedBox(height: 4),
        Text(
          placed == null
              ? tr('En baştan başlıyoruz', 'Starting from the beginning')
              : tr('${placed.title} geçildi', '${placed.title} passed'),
          key: const Key('placement_result'),
          style: TT.h1,
        ),
        const SizedBox(height: 12),
        if (next != null)
          Text(
            tr(
              'Başlangıç noktan: ${next.title}',
              'Your starting point: ${next.title}',
            ),
            key: const Key('placement_next'),
            style: TT.title,
          ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Bu yaklaşık bir yerleştirme. Kolay gelirse ilerideki bir ara '
                'durağı dene; zor gelirse önceki dersleri elle açabilirsin.',
            'This is an approximate placement. If it feels easy, try a later '
                'checkpoint; if it feels hard, open earlier lessons yourself.',
          ),
          style: TT.small,
        ),
      ],
    );
  }

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Ic.check, color: TC.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TT.small)),
      ],
    ),
  );
}
