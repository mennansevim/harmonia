import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';
import '../../domain/learning/micro_lesson.dart';
import '../../domain/learning/skill_graph.dart';
import '../common/ui/harmonia_ui.dart';

/// Text draft reader only. No recorder/player, completion marker or history.
class MicroLessonScreen extends StatelessWidget {
  const MicroLessonScreen({super.key, required this.lesson});
  final MicroLesson lesson;

  @override
  Widget build(BuildContext context) => LessonScaffold(
    progress: null,
    counter: 'Taslak',
    closeLabel: 'Mikroders okumasını kapat',
    top: [
      const Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusPill(
          'Metin taslağı • Eğitimci onayı bekliyor',
          key: Key('lesson_review_notice'),
        ),
      ),
      const SizedBox(height: HarmoniaSpacing.md),
      Semantics(
        header: true,
        child: Text(
          lesson.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: HarmoniaSpacing.sm),
      Text(
        lesson.dimension == SkillDimension.perception
            ? 'Hedef boyutu: Algı'
            : 'Hedef boyutu: Üretim',
      ),
      const SizedBox(height: HarmoniaSpacing.sm),
      Text(lesson.objective),
      const SizedBox(height: HarmoniaSpacing.sm),
      const Text(
        'Yalnız metin okuma. Ses, mikrofon, puan ve ilerleme kaydı yok. Okumak, öğrenme kanıtı değildir.',
        key: Key('lesson_no_mastery_notice'),
      ),
      ExpansionTile(
        key: const Key('lesson_content_info'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Ders bilgisi'),
        children: [
          Text('İçerik sürümü: ${lesson.contentVersion}'),
          const Text(
            'Ses örnekleri ve eğitimci onayı doğrulanmadan çalışmalar açılmaz. Bu metin bir sınav veya tamamlanmış ders değildir.',
          ),
        ],
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
                  ChunkyButton(
                    key: Key('lesson_practice_${step.phase.name}'),
                    onPressed: null,
                    tone: ChunkyTone.neutral,
                    label: 'Çalışma henüz açılamıyor',
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
    bottom: [
      ChunkyButton(
        key: const Key('lesson_reader_back'),
        label: 'Geri dön',
        tone: ChunkyTone.neutral,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}

String _phaseTitle(LessonPhase phase) => switch (phase) {
  LessonPhase.explanation => 'Kavramı anla',
  LessonPhase.contrast => 'Örnekleri karşılaştır',
  LessonPhase.guidedPractice => 'Destekli çalış',
  LessonPhase.independentCheck => 'Yeni örnekle kontrol et',
  LessonPhase.delayedCheck => 'Daha sonra yeniden kontrol et',
};
