import '../../domain/learning/measured_exercise.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/learning/rhythm_next_step.dart';
import '../../domain/learning/today_planner.dart';
import '../../domain/lang.dart';

/// (title, reason, action label) for one recommended next step.
(String, String, String) nextStepText(NextStep step) {
  final name = step.pattern?.title ?? '';
  return switch (step.kind) {
    NextStepKind.start => (
      tr('Ritimle başla: $name', 'Start with rhythm: $name'),
      tr(
        'Henüz ölçülmüş ritim denemen yok. Kısa bir desenle başlayalım.',
        'You have no measured rhythm attempt yet. Let us start with a short pattern.',
      ),
      tr('Başla', 'Start'),
    ),
    NextStepKind.retryUnmeasured => (
      tr('Yeniden dene: $name', 'Try again: $name'),
      tr(
        'Son deneme ölçülemedi (yeterli vuruş yoktu). Dinleyip tüm vuruşları tekrar et.',
        'The last attempt could not be measured (not enough taps). Listen and repeat every beat.',
      ),
      tr('Yeniden dene', 'Try again'),
    ),
    NextStepKind.repeat => (
      tr('Aynı deseni tekrar et: $name', 'Repeat the same pattern: $name'),
      switch (step.focus) {
        RhythmErrorFocus.missed => tr(
          'Son denemede ${step.focusCount} vuruş eksikti. Dinlerken vuruşları say, sonra hepsini tekrar et.',
          '${step.focusCount} beats were missing last time. Count the beats as you listen, then repeat them all.',
        ),
        RhythmErrorFocus.extra => tr(
          'Son denemede ${step.focusCount} fazla vuruş vardı. Vuruş sayısına dikkat et.',
          'There were ${step.focusCount} extra taps last time. Watch the number of beats.',
        ),
        RhythmErrorFocus.late => tr(
          'Son denemede ${step.focusCount} vuruş geç geldi. Aralıkları biraz daha kısa tut.',
          '${step.focusCount} taps came late last time. Keep the gaps a little shorter.',
        ),
        RhythmErrorFocus.early => tr(
          'Son denemede ${step.focusCount} vuruş erken geldi. Aralıkları biraz daha uzun tut.',
          '${step.focusCount} taps came early last time. Keep the gaps a little longer.',
        ),
        RhythmErrorFocus.none => tr(
          'Ölçüt için art arda iki temiz deneme gerekiyor.',
          'The criterion needs two clean attempts in a row.',
        ),
      },
      tr('Tekrar et', 'Repeat'),
    ),
    NextStepKind.nextPattern => (
      tr('Yeni desen: $name', 'New pattern: $name'),
      tr(
        'Önceki deseni taslak ölçüte göre tamamladın (art arda iki temiz deneme). Şimdi yeni bir desen.',
        'You completed the last pattern by the draft criterion (two clean attempts in a row). Now a new pattern.',
      ),
      tr('Yeni desene geç', 'On to the new pattern'),
    ),
    NextStepKind.delayedCheck => (
      tr('Kalıcılık kontrolü: $name', 'Retention check: $name'),
      tr(
        'Bu deseni daha önceki bir gün tamamlamıştın. Bugün tek dinlemeyle tekrar et; öğrenmenin kalıcı olup olmadığını böyle kontrol ederiz.',
        'You completed this pattern on an earlier day. Repeat it today after a single listen; that is how we check the learning has stuck.',
      ),
      tr('Kontrol et', 'Check'),
    ),
    NextStepKind.allDone => (
      tr('Taslak desenlerin hepsi tamam', 'All draft patterns done'),
      tr(
        'Yeni ritim içerikleri eğitimci onayından sonra eklenecek. Bu arada diğer çalışmalara bakabilirsin.',
        'New rhythm content will be added after educator approval. Meanwhile, try the other exercises.',
      ),
      '',
    ),
  };
}

String get draftCriterionNote => tr(
  'Taslak ölçüt: art arda iki deneme eksik/fazla vuruşsuz ve ortalama sapma ≤ 60 ms. Eğitimci onayı bekliyor.',
  'Draft criterion: two attempts in a row with no missing or extra taps and a mean offset ≤ 60 ms. Awaiting educator approval.',
);

/// (title, reason, action) for the home recommendation across skills.
(String, String, String) todayStepText(TodayStep step) {
  final e = step.exercise;
  final name = e == null ? '' : '${step.node!.title} — ${e.title}';
  String repeatReason() => lastResultReason(step.lastResult);

  return switch (step.kind) {
    NextStepKind.start => (
      tr('Başla: $name', 'Start: $name'),
      tr(
        'Henüz ölçülmüş çalışman yok. Rotandaki ilk ölçülebilir beceriyle başlayalım.',
        'You have no measured practice yet. Let us start with the first measurable skill on your route.',
      ),
      tr('Başla', 'Start'),
    ),
    NextStepKind.retryUnmeasured => (
      tr('Yeniden dene: $name', 'Try again: $name'),
      tr(
        'Son deneme ölçülemedi (tamamlanmadı). Baştan tekrar et.',
        'The last attempt could not be measured (not finished). Repeat it from the start.',
      ),
      tr('Yeniden dene', 'Try again'),
    ),
    NextStepKind.repeat => (
      tr('Tekrar et: $name', 'Repeat: $name'),
      repeatReason(),
      tr('Tekrar et', 'Repeat'),
    ),
    NextStepKind.nextPattern => (
      tr('Sıradaki: $name', 'Next: $name'),
      tr(
        'Önceki çalışmayı taslak ölçüte göre tamamladın; rotadaki sıradaki ölçülebilir çalışma bu.',
        'You completed the last exercise by the draft criterion; this is the next measurable one on your route.',
      ),
      tr('Başla', 'Start'),
    ),
    NextStepKind.delayedCheck => (
      tr('Kalıcılık kontrolü: $name', 'Retention check: $name'),
      tr(
        'Bunu daha önceki bir gün tamamlamıştın. Bugün tek dinlemeyle tekrar et; öğrenmenin kalıcı olup olmadığını böyle kontrol ederiz.',
        'You completed this on an earlier day. Repeat it today after a single listen; that is how we check the learning has stuck.',
      ),
      tr('Kontrol et', 'Check'),
    ),
    NextStepKind.allDone => (
      tr(
        'Şimdilik ölçülebilen her şey tamam',
        'Everything measurable is done for now',
      ),
      tr(
        'Yeni içerikler eğitimci onayından sonra eklenecek. Beceri haritasında sıradaki becerileri görebilirsin.',
        'New content will be added after educator approval. You can see the next skills on the skill map.',
      ),
      '',
    ),
  };
}

/// Evidence-citing reason for repeating an exercise, from its last valid
/// comparable result (null: nothing measured yet).
String lastResultReason(ExerciseResult? last) {
  if (last == null) {
    return tr(
      'Ölçüt için art arda iki temiz deneme gerekiyor.',
      'The criterion needs two clean attempts in a row.',
    );
  }
  if (last.measurements['dimension'] == 'perception') {
    return tr(
      'Son turda ${last.measurements['total']} sorudan ${last.measurements['correct']} doğru. Ölçüt: art arda iki turda en az ${PerceptionCriterion.minCorrect}.',
      '${last.measurements['correct']} of ${last.measurements['total']} right last round. Criterion: at least ${PerceptionCriterion.minCorrect} in two rounds in a row.',
    );
  }
  int n(String k) => last.measurements[k] as int? ?? 0;
  if (n('missed') > 0) {
    return tr(
      'Son denemede ${n('missed')} vuruş eksikti. Dinlerken vuruşları say.',
      '${n('missed')} beats were missing last time. Count the beats as you listen.',
    );
  }
  if (n('extra') > 0) {
    return tr(
      'Son denemede ${n('extra')} fazla vuruş vardı. Vuruş sayısına dikkat et.',
      'There were ${n('extra')} extra taps last time. Watch the number of beats.',
    );
  }
  if (n('late') > 0) {
    return tr(
      'Son denemede ${n('late')} vuruş geç geldi.',
      '${n('late')} taps came late last time.',
    );
  }
  if (n('early') > 0) {
    return tr(
      'Son denemede ${n('early')} vuruş erken geldi.',
      '${n('early')} taps came early last time.',
    );
  }
  return tr(
    'Ölçüt için art arda iki temiz deneme gerekiyor.',
    'The criterion needs two clean attempts in a row.',
  );
}
