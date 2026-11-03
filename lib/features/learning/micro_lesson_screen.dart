import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/learning/micro_lesson.dart';
import '../../domain/learning/skill_graph.dart';
import '../common/ui/resonia_ui.dart';
import '../../domain/lang.dart';

/// Text draft reader only. No recorder/player, completion marker or history.
class MicroLessonScreen extends StatelessWidget {
  const MicroLessonScreen({super.key, required this.lesson});
  final MicroLesson lesson;

  @override
  Widget build(BuildContext context) => LessonScaffold(
    progress: null,
    counter: tr('Taslak', 'Draft'),
    closeLabel: tr('Mikroders okumasını kapat', 'Close the micro-lesson'),
    top: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusPill(
          tr(
            'Metin taslağı • Eğitimci onayı bekliyor',
            'Draft text • Awaiting educator approval',
          ),
          key: Key('lesson_review_notice'),
        ),
      ),
      const SizedBox(height: ResoniaSpacing.md),
      Semantics(
        header: true,
        child: Text(
          lesson.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      const SizedBox(height: ResoniaSpacing.sm),
      Text(
        lesson.dimension == SkillDimension.perception
            ? tr('Hedef boyutu: Algı', 'Target dimension: Perception')
            : tr('Hedef boyutu: Üretim', 'Target dimension: Production'),
      ),
      const SizedBox(height: ResoniaSpacing.sm),
      Text(lesson.objective),
      const SizedBox(height: ResoniaSpacing.sm),
      Text(
        tr(
          'Yalnız metin okuma. Ses, mikrofon, puan ve ilerleme kaydı yok. Okumak, öğrenme kanıtı değildir.',
          'Reading only. No sound, microphone, score or progress record. Reading is not proof of learning.',
        ),
        key: Key('lesson_no_mastery_notice'),
      ),
      ExpansionTile(
        key: const Key('lesson_content_info'),
        tilePadding: EdgeInsets.zero,
        title: Text(tr('Ders bilgisi', 'Lesson info')),
        children: [
          Text(
            tr(
              'İçerik sürümü: ${lesson.contentVersion}',
              'Content version: ${lesson.contentVersion}',
            ),
          ),
          Text(
            tr(
              'Ses örnekleri ve eğitimci onayı doğrulanmadan çalışmalar açılmaz. Bu metin bir sınav veya tamamlanmış ders değildir.',
              'Exercises stay closed until sound examples and educator approval are verified. This text is not an exam or a completed lesson.',
            ),
          ),
        ],
      ),
      const SizedBox(height: ResoniaSpacing.md),
      for (final step in lesson.steps)
        Card(
          key: Key('lesson_phase_${step.phase.name}'),
          child: Padding(
            padding: const EdgeInsets.all(ResoniaSpacing.md),
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
                const SizedBox(height: ResoniaSpacing.xs),
                Text(step.instruction),
                if (step.phase != LessonPhase.explanation) ...[
                  const SizedBox(height: ResoniaSpacing.sm),
                  Text(
                    step.awaitsExamples
                        ? tr(
                            'Ses örnekleri henüz eklenmedi.',
                            'Sound examples have not been added yet.',
                          )
                        : tr(
                            'Örnek kimlikleri tanımlı; sesler ve eğitimci onayı doğrulanmadı.',
                            'Example IDs are defined; the sounds and educator approval are not verified.',
                          ),
                  ),
                  ChunkyButton(
                    key: Key('lesson_practice_${step.phase.name}'),
                    onPressed: null,
                    tone: ChunkyTone.neutral,
                    label: tr(
                      'Çalışma henüz açılamıyor',
                      'The exercise cannot open yet',
                    ),
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
        label: tr('Geri dön', 'Go back'),
        tone: ChunkyTone.neutral,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ],
  );
}

String _phaseTitle(LessonPhase phase) => switch (phase) {
  LessonPhase.explanation => tr('Kavramı anla', 'Understand the idea'),
  LessonPhase.contrast => tr('Örnekleri karşılaştır', 'Compare examples'),
  LessonPhase.guidedPractice => tr('Destekli çalış', 'Practise with support'),
  LessonPhase.independentCheck => tr(
    'Yeni örnekle kontrol et',
    'Check with a new example',
  ),
  LessonPhase.delayedCheck => tr(
    'Daha sonra yeniden kontrol et',
    'Check again later',
  ),
};
