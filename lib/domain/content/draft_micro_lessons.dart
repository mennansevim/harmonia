import '../learning/micro_lesson.dart';
import '../learning/skill_graph.dart';

/// Two developer text drafts, not the promised 12 approved micro-units.
/// No recorded examples, runnable checks or lesson completion evidence yet.
final draftMicroLessons = MicroLessonCatalog(
  graph: draftSkillGraph,
  lessons: [
    MicroLesson(
      id: 'lesson-high-low',
      contentVersion: 'draft-1',
      skillId: 'pitch-high-low',
      title: 'Tiz ve pes: sesin yönünü dinle',
      objective: 'Ses yüksekliğini (tiz/pes) ses şiddetinden ayrı düşünmek.',
      route: LearningRoute.core,
      dimension: SkillDimension.perception,
      steps: [
        LessonStep(
          phase: LessonPhase.explanation,
          instruction:
              'Tiz/pes, sesin daha ince veya daha kalın duyulmasıdır. Daha yüksek şiddette çalmak, sesi kendiliğinden daha tiz yapmaz. Bu ders dinleme içindir; söyleme başarısını ölçmez.',
        ),
        LessonStep(
          phase: LessonPhase.contrast,
          instruction:
              'Aynı şiddette iki sesin yükselen ve alçalan örneklerini karşılaştır. Eğitimci kontrolünden geçmiş örnekler henüz eklenmedi.',
        ),
        LessonStep(
          phase: LessonPhase.guidedPractice,
          instruction:
              'İki sesi dinle, ikinci sesin daha tiz mi pes mi olduğunu seç. Açıklamayı gördükten sonra tekrar dinleyebilirsin. Dersin örnek bankası bekleniyor.',
        ),
        LessonStep(
          phase: LessonPhase.independentCheck,
          instruction:
              'Çalışmada duyulmamış yeni bir çiftle, ipucu olmadan yönü seç. Eğitim örneğini tekrar kullanmak yeni soruda başarı kanıtı değildir. Kontrol seti bekleniyor.',
        ),
        LessonStep(
          phase: LessonPhase.delayedCheck,
          instruction:
              'Başka bir gün, farklı bir örnekle yeniden kontrol et. Bu adımı okumak hatırlama başarısı değildir; takvim ve yeni kontrol seti henüz bağlı değil.',
        ),
      ],
    ),
    MicroLesson(
      id: 'lesson-pulse',
      contentVersion: 'draft-1',
      skillId: 'pulse-tap',
      title: 'Puls: eşit aralığı koru',
      objective: 'Düzenli vuruş aralıklarını duyup dokunarak tekrar etmek.',
      route: LearningRoute.core,
      dimension: SkillDimension.production,
      steps: [
        LessonStep(
          phase: LessonPhase.explanation,
          instruction:
              'Puls, müzikte düzenli hissedilen vuruştur. Burada amacın dokunuşların arasını düzenli tutmak; daha çok dokunmak daha iyi sonuç demek değildir.',
        ),
        LessonStep(
          phase: LessonPhase.contrast,
          instruction:
              'Düzenli ve aralıkları değişen iki vuruş örneğini karşılaştır. Onaylı karşılaştırma sesleri bekleniyor.',
        ),
        LessonStep(
          phase: LessonPhase.guidedPractice,
          instruction:
              'Kısa düzenli örneği dinle, sonra dokunarak tekrar et. Mevcut taklit motorunda ilk dokunuş çapa olur ve ilk giriş zamanı ölçülmez. Ders örnekleri henüz bağlı değil.',
        ),
        LessonStep(
          phase: LessonPhase.independentCheck,
          instruction:
              'Daha önce çalışılmamış bir ritmi ipucu olmadan tekrar et. Referans sayısı ve eksik/fazla dokunuşlar ayrı kanıttır. Yeni kontrol bankası bekleniyor.',
        ),
        LessonStep(
          phase: LessonPhase.delayedCheck,
          instruction:
              'Sonraki gün farklı bir örnekle tekrar kontrol et. Okuma tamamlandı bilgisi ritim becerisi veya kalıcılık kanıtı değildir; ders takvimi henüz bağlı değil.',
        ),
      ],
    ),
  ],
);
