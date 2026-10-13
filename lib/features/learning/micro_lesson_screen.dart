import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../domain/learning/micro_lesson.dart';
import '../../domain/learning/skill_graph.dart';

/// Text draft reader only. No recorder/player, completion marker or history.
class MicroLessonScreen extends StatelessWidget {
  const MicroLessonScreen({super.key, required this.lesson});
  final MicroLesson lesson;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mikroders taslağı')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(HarmoniaSpacing.lg),
        children: [
          Semantics(
            header: true,
            child: Text(
              lesson.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: HarmoniaSpacing.sm),
          const Text(
            'Metin taslağı • Eğitimci onayı bekliyor',
            key: Key('lesson_review_notice'),
          ),
          Text(
            lesson.dimension == SkillDimension.perception
                ? 'Hedef boyutu: Algı'
                : 'Hedef boyutu: Üretim',
          ),
          Text('İçerik sürümü: ${lesson.contentVersion}'),
          const SizedBox(height: HarmoniaSpacing.sm),
          Text(lesson.objective),
          const SizedBox(height: HarmoniaSpacing.sm),
          const Text(
            'Bu ekran yalnız metin okuma içindir. Ses çalmaz, mikrofon açmaz, puan veya beceri ilerlemesi kaydetmez. Okumak, beceriyi öğrendiğin anlamına gelmez.',
            key: Key('lesson_no_mastery_notice'),
          ),
          const SizedBox(height: HarmoniaSpacing.md),
          for (final step in lesson.steps)
            Card(
              key: Key('lesson_phase_${step.phase.name}'),
              child: Padding(
                padding: const EdgeInsets.all(HarmoniaSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        '${step.phase.index + 1}. ${_phaseTitle(step.phase)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: HarmoniaSpacing.xs),
                    Text(step.instruction),
                    if (step.phase != LessonPhase.explanation) ...[
                      const SizedBox(height: HarmoniaSpacing.sm),
                      Text(
                        step.awaitsExamples
                            ? 'Ses örnekleri henüz eklenmedi.'
                            : 'Örnek kimlikleri tanımlı; sesler ve eğitimci onayı doğrulanmadı.',
                      ),
                      OutlinedButton(
                        key: Key('lesson_practice_${step.phase.name}'),
                        onPressed: null,
                        child: const Text('Çalışma henüz açılamıyor'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

String _phaseTitle(LessonPhase phase) => switch (phase) {
  LessonPhase.explanation => 'Kavramı anla',
  LessonPhase.contrast => 'Örnekleri karşılaştır',
  LessonPhase.guidedPractice => 'Destekli çalış',
  LessonPhase.independentCheck => 'Yeni örnekle kontrol et',
  LessonPhase.delayedCheck => 'Daha sonra yeniden kontrol et',
};
