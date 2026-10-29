import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../quiz/quiz.dart';
import '../quiz/quiz_view.dart';
import '../ui/kit.dart';

/// "One quick level check": ask what the learner knows per trainer, prove
/// it with a short quiz on the first checkpoint's material, and skip the
/// lessons they clear (via the checkpoint's normal completion rule).
class LevelCheck extends StatefulWidget {
  const LevelCheck({
    super.key,
    required this.onBack,
    required this.onDone,
    required this.dots,
  });
  final VoidCallback onBack;
  final VoidCallback onDone;
  final Widget dots;
  @override
  State<LevelCheck> createState() => _LevelCheckState();
}

class _LevelCheckState extends State<LevelCheck> {
  bool _asking = false;
  final Set<TrainerKind> _claimed = {};

  LessonNode _firstGate(TrainerKind k) =>
      trainerPaths[k]!.nodes.firstWhere((n) => n.kind == NodeKind.checkpoint);

  Future<void> _prove() async {
    final store = TrainerScope.of(context).store;
    final nav = Navigator.of(context);
    for (final k in _claimed) {
      final gate = _firstGate(k);
      final questions = QuizGenerator(
        QuizConfig.forNode(gate, length: 5),
      ).session();
      final summary = await nav.push<QuizSummary>(
        MaterialPageRoute(
          builder: (routeContext) => QuizView(
            title: 'Seviye: ${k.shortTitle}',
            questions: questions,
            allowRetry: false,
            onFinished: (s) => Navigator.of(routeContext).pop(s),
          ),
        ),
      );
      if (summary != null && summary.accuracy >= 0.8) {
        store.completeNode(gate, summary.accuracy);
      }
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    if (_asking) {
      return Column(
        children: [
          TopBar(
            title: 'Ne biliyorsun?',
            onBack: () => setState(() => _asking = false),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Rahatça tanıyabildiklerini seç. Her biri için birkaç dinleme sorusu soracağız.',
                  style: TT.body,
                ),
                const SizedBox(height: 16),
                for (final k in TrainerKind.values)
                  ChoiceTile(
                    key: Key('claim_${k.id}'),
                    label: '${k.title}: ${_firstGate(k).subtitle}',
                    selected: _claimed.contains(k),
                    color: TC.orange,
                    onTap: () => setState(() {
                      if (!_claimed.remove(k)) _claimed.add(k);
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BigButton(
              key: const Key('level_prove'),
              label: _claimed.isEmpty ? 'Hiçbiri, yeni başlıyorum' : 'Kanıtla',
              onPressed: _claimed.isEmpty ? widget.onDone : _prove,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackSquare(onTap: widget.onBack),
                ),
                widget.dots,
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              const Text('Kısa bir seviye kontrolü', style: TT.h1),
              const SizedBox(height: 6),
              const Text(
                'Bildiklerin konusunda dürüst ol; planın tam doğru yerden başlasın.',
                style: TT.body,
              ),
              const SizedBox(height: 22),
              for (final (icon, color, title, body) in const [
                (
                  Icons.hearing_rounded,
                  TC.orange,
                  'Ne bildiğini söyle',
                  'Beş becerinin her biri için kısa bir soru',
                ),
                (
                  Icons.checklist_rounded,
                  TC.blue,
                  'İddia ettiğini kanıtla',
                  'Birkaç dinleme sorusu, fazlası değil',
                ),
                (
                  Icons.fast_forward_rounded,
                  TC.purple,
                  'Geçtiklerini atla',
                  'Zaten bildiğin derslerin ötesinden başla',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: soft(color),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color),
                      ),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: TC.body),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yaklaşık iki dakika, en fazla beş. Baskı yok.',
                        style: TT.small,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: BigButton(
            key: const Key('level_check'),
            label: 'Seviyemi kontrol et',
            icon: Icons.play_arrow_rounded,
            onPressed: () => setState(() => _asking = true),
          ),
        ),
        TextLink('Atla, yeni başlıyorum', onTap: widget.onDone),
        const SizedBox(height: 8),
      ],
    );
  }
}
