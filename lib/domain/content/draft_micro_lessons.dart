import '../learning/micro_lesson.dart';
import '../learning/skill_graph.dart';
import '../lang.dart';

/// Two developer text drafts, not the promised 12 approved micro-units.
/// No recorded examples, runnable checks or lesson completion evidence yet.
/// Built once per wording language: lesson text is part of the catalog.
final _lessonsByLang = <bool, MicroLessonCatalog>{};

MicroLessonCatalog get draftMicroLessons =>
    _lessonsByLang[Lang.en] ??= _buildLessons();

MicroLessonCatalog _buildLessons() => MicroLessonCatalog(
  graph: draftSkillGraph,
  lessons: [
    MicroLesson(
      id: 'lesson-high-low',
      contentVersion: 'draft-1',
      skillId: 'pitch-high-low',
      title: tr(
        'Tiz ve pes: sesin yönünü dinle',
        'High and low: hear which way the sound goes',
      ),
      objective: tr(
        'Ses yüksekliğini (tiz/pes) ses şiddetinden ayrı düşünmek.',
        'Thinking of pitch (high/low) apart from loudness.',
      ),
      route: LearningRoute.core,
      dimension: SkillDimension.perception,
      steps: [
        LessonStep(
          phase: LessonPhase.explanation,
          instruction: tr(
            'Tiz/pes, sesin daha ince veya daha kalın duyulmasıdır. Daha yüksek şiddette çalmak, sesi kendiliğinden daha tiz yapmaz. Bu ders dinleme içindir; söyleme başarısını ölçmez.',
            'High or low is whether a sound seems thinner or thicker. Playing louder does not make a sound higher by itself. This lesson is for listening; it does not measure singing success.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.contrast,
          instruction: tr(
            'Aynı şiddette iki sesin yükselen ve alçalan örneklerini karşılaştır. Eğitimci kontrolünden geçmiş örnekler henüz eklenmedi.',
            'Compare rising and falling examples of two sounds at the same loudness. Educator-checked examples have not been added yet.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.guidedPractice,
          instruction: tr(
            'İki sesi dinle, ikinci sesin daha tiz mi pes mi olduğunu seç. Açıklamayı gördükten sonra tekrar dinleyebilirsin. Dersin örnek bankası bekleniyor.',
            'Hear two sounds and choose whether the second is higher or lower. You can listen again after seeing the explanation. The lesson example bank is pending.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.independentCheck,
          instruction: tr(
            'Çalışmada duyulmamış yeni bir çiftle, ipucu olmadan yönü seç. Eğitim örneğini tekrar kullanmak yeni soruda başarı kanıtı değildir. Kontrol seti bekleniyor.',
            'With a new pair not heard in practice, choose the direction without hints. Reusing a training example is not proof of success on a new question. The check set is pending.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.delayedCheck,
          instruction: tr(
            'Başka bir gün, farklı bir örnekle yeniden kontrol et. Bu adımı okumak hatırlama başarısı değildir; takvim ve yeni kontrol seti henüz bağlı değil.',
            'Check again on another day with a different example. Reading this step is not proof of recall; the schedule and new check set are not connected yet.',
          ),
        ),
      ],
    ),
    MicroLesson(
      id: 'lesson-pulse',
      contentVersion: 'draft-1',
      skillId: 'pulse-tap',
      title: tr('Puls: eşit aralığı koru', 'Pulse: keep the gaps even'),
      objective: tr(
        'Düzenli vuruş aralıklarını duyup dokunarak tekrar etmek.',
        'Hearing evenly spaced beats and tapping them back.',
      ),
      route: LearningRoute.core,
      dimension: SkillDimension.production,
      steps: [
        LessonStep(
          phase: LessonPhase.explanation,
          instruction: tr(
            'Puls, müzikte düzenli hissedilen vuruştur. Burada amacın dokunuşların arasını düzenli tutmak; daha çok dokunmak daha iyi sonuç demek değildir.',
            'The pulse is the steady beat you feel in music. Here the aim is to keep your taps evenly spaced; more taps do not mean a better result.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.contrast,
          instruction: tr(
            'Düzenli ve aralıkları değişen iki vuruş örneğini karşılaştır. Onaylı karşılaştırma sesleri bekleniyor.',
            'Compare a steady beat with one whose gaps change. Approved comparison sounds are pending.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.guidedPractice,
          instruction: tr(
            'Kısa düzenli örneği dinle, sonra dokunarak tekrar et. Mevcut taklit motorunda ilk dokunuş çapa olur ve ilk giriş zamanı ölçülmez. Ders örnekleri henüz bağlı değil.',
            'Hear the short steady example, then tap it back. In the current echo engine the first tap is the anchor and the first entry time is not measured. Lesson examples are not connected yet.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.independentCheck,
          instruction: tr(
            'Daha önce çalışılmamış bir ritmi ipucu olmadan tekrar et. Referans sayısı ve eksik/fazla dokunuşlar ayrı kanıttır. Yeni kontrol bankası bekleniyor.',
            'Repeat a rhythm you have not practised, without hints. Reference plays and missing or extra taps are separate evidence. The new check bank is pending.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.delayedCheck,
          instruction: tr(
            'Sonraki gün farklı bir örnekle tekrar kontrol et. Okuma tamamlandı bilgisi ritim becerisi veya kalıcılık kanıtı değildir; ders takvimi henüz bağlı değil.',
            'Check again the next day with a different example. Having read it is not proof of rhythm skill or retention; the lesson schedule is not connected yet.',
          ),
        ),
      ],
    ),
    MicroLesson(
      id: 'lesson-tonic-degree',
      contentVersion: 'draft-1',
      skillId: 'tonic-degree',
      title: tr(
        'Tonik ve derece: önce do’yu yerleştir',
        'Tonic and degree: place do first',
      ),
      objective: tr(
        'Hedef sesi mutlak nota adıyla değil, duyulan tonal merkeze göre derece olarak düşünmek.',
        'Thinking of the target note as a degree against the tonal centre you hear, not as an absolute note name.',
      ),
      route: LearningRoute.core,
      dimension: SkillDimension.perception,
      steps: [
        LessonStep(
          phase: LessonPhase.explanation,
          instruction: tr(
            'Hareketli do yaklaşımında do, o sorunun tonal merkezidir. Aynı hece her soruda aynı mutlak frekans olmak zorunda değildir. Önce do’yu zihninde sabitle, sonra hedef sesin do’ya göre uzaklığını dinle.',
            'In movable do, do is the tonal centre of that question. The same syllable need not be the same absolute frequency each time. First fix do in your mind, then hear how far the target is from it.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.contrast,
          instruction: tr(
            'Do–re, do–mi ve do–sol ilişkilerini yan yana karşılaştır. Yalnız hedef sesin ince veya kalın olmasına değil, do’dan kaç basamak uzaklaştığına odaklan. Eğitimci onaylı karşılaştırma örnekleri bekleniyor.',
            'Compare do–re, do–mi and do–sol side by side. Focus not on whether the target is high or low, but on how many steps it is from do. Educator-approved comparison examples are pending.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.guidedPractice,
          instruction: tr(
            'Tonik bağlamını dinledikten sonra do’yu içinden tekrar et ve hedefe adım adım git. Bu strateji bir ipucudur; mevcut ders ses bankası henüz bağlı değildir.',
            'After hearing the tonic context, repeat do in your head and step towards the target. This strategy is a hint; the lesson sound bank is not connected yet.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.independentCheck,
          instruction: tr(
            'Farklı bir tonikte, ipucu olmadan hedef dereceyi seç. Daha önceki sorunun mutlak sesini ezberlemek yeni soruda derece duyma kanıtı değildir. Kontrol seti bekleniyor.',
            'In a different key, choose the target degree without hints. Memorising the absolute pitch of an earlier question is not proof of hearing degrees. The check set is pending.',
          ),
        ),
        LessonStep(
          phase: LessonPhase.delayedCheck,
          instruction: tr(
            'Başka bir gün ve farklı bir tonik bağlamında yeniden kontrol et. Bu metni okumak kalıcılık veya sınava hazırlık kanıtı değildir.',
            'Check again on another day in a different tonic context. Reading this text is not proof of retention or exam readiness.',
          ),
        ),
      ],
    ),
  ],
);
