import '../../domain/learning/rhythm_next_step.dart';

/// (title, reason, action label) for one recommended next step.
(String, String, String) nextStepText(NextStep step) {
  final name = step.pattern?.title ?? '';
  return switch (step.kind) {
    NextStepKind.start => (
      'Ritimle başla: $name',
      'Henüz ölçülmüş ritim denemen yok. Kısa bir desenle başlayalım.',
      'Başla',
    ),
    NextStepKind.retryUnmeasured => (
      'Yeniden dene: $name',
      'Son deneme ölçülemedi (yeterli vuruş yoktu). Dinleyip tüm vuruşları tekrar et.',
      'Yeniden dene',
    ),
    NextStepKind.repeat => (
      'Aynı deseni tekrar et: $name',
      switch (step.focus) {
        RhythmErrorFocus.missed =>
          'Son denemede ${step.focusCount} vuruş eksikti. Dinlerken vuruşları say, sonra hepsini tekrar et.',
        RhythmErrorFocus.extra =>
          'Son denemede ${step.focusCount} fazla vuruş vardı. Vuruş sayısına dikkat et.',
        RhythmErrorFocus.late =>
          'Son denemede ${step.focusCount} vuruş geç geldi. Aralıkları biraz daha kısa tut.',
        RhythmErrorFocus.early =>
          'Son denemede ${step.focusCount} vuruş erken geldi. Aralıkları biraz daha uzun tut.',
        RhythmErrorFocus.none =>
          'Ölçüt için art arda iki temiz deneme gerekiyor.',
      },
      'Tekrar et',
    ),
    NextStepKind.nextPattern => (
      'Yeni desen: $name',
      'Önceki deseni taslak ölçüte göre tamamladın (art arda iki temiz deneme). Şimdi yeni bir desen.',
      'Yeni desene geç',
    ),
    NextStepKind.delayedCheck => (
      'Kalıcılık kontrolü: $name',
      'Bu deseni daha önceki bir gün tamamlamıştın. Bugün tek dinlemeyle tekrar et; öğrenmenin kalıcı olup olmadığını böyle kontrol ederiz.',
      'Kontrol et',
    ),
    NextStepKind.allDone => (
      'Taslak desenlerin hepsi tamam',
      'Yeni ritim içerikleri eğitimci onayından sonra eklenecek. Bu arada diğer çalışmalara bakabilirsin.',
      '',
    ),
  };
}

const draftCriterionNote =
    'Taslak ölçüt: art arda iki deneme eksik/fazla vuruşsuz ve ortalama sapma ≤ 60 ms. Eğitimci onayı bekliyor.';
