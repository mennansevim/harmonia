import '../../domain/learning/measured_exercise.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../../domain/learning/today_planner.dart';

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

/// (title, reason, action) for the home recommendation across skills.
(String, String, String) todayStepText(TodayStep step) {
  final e = step.exercise;
  final name = e == null ? '' : '${step.node!.title} — ${e.title}';
  String repeatReason() => lastResultReason(step.lastResult);

  return switch (step.kind) {
    NextStepKind.start => (
      'Başla: $name',
      'Henüz ölçülmüş çalışman yok. Rotandaki ilk ölçülebilir beceriyle başlayalım.',
      'Başla',
    ),
    NextStepKind.retryUnmeasured => (
      'Yeniden dene: $name',
      'Son deneme ölçülemedi (tamamlanmadı). Baştan tekrar et.',
      'Yeniden dene',
    ),
    NextStepKind.repeat => ('Tekrar et: $name', repeatReason(), 'Tekrar et'),
    NextStepKind.nextPattern => (
      'Sıradaki: $name',
      'Önceki çalışmayı taslak ölçüte göre tamamladın; rotadaki sıradaki ölçülebilir çalışma bu.',
      'Başla',
    ),
    NextStepKind.delayedCheck => (
      'Kalıcılık kontrolü: $name',
      'Bunu daha önceki bir gün tamamlamıştın. Bugün tek dinlemeyle tekrar et; öğrenmenin kalıcı olup olmadığını böyle kontrol ederiz.',
      'Kontrol et',
    ),
    NextStepKind.allDone => (
      'Şimdilik ölçülebilen her şey tamam',
      'Yeni içerikler eğitimci onayından sonra eklenecek. Beceri haritasında sıradaki becerileri görebilirsin.',
      '',
    ),
  };
}

/// Evidence-citing reason for repeating an exercise, from its last valid
/// comparable result (null: nothing measured yet).
String lastResultReason(ExerciseResult? last) {
  if (last == null) return 'Ölçüt için art arda iki temiz deneme gerekiyor.';
  if (last.measurements['dimension'] == 'perception') {
    return 'Son turda ${last.measurements['total']} sorudan ${last.measurements['correct']} doğru. Ölçüt: art arda iki turda en az ${PerceptionCriterion.minCorrect}.';
  }
  int n(String k) => last.measurements[k] as int? ?? 0;
  if (n('missed') > 0) {
    return 'Son denemede ${n('missed')} vuruş eksikti. Dinlerken vuruşları say.';
  }
  if (n('extra') > 0) {
    return 'Son denemede ${n('extra')} fazla vuruş vardı. Vuruş sayısına dikkat et.';
  }
  if (n('late') > 0) return 'Son denemede ${n('late')} vuruş geç geldi.';
  if (n('early') > 0) return 'Son denemede ${n('early')} vuruş erken geldi.';
  return 'Ölçüt için art arda iki temiz deneme gerekiyor.';
}
