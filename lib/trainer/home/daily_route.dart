import '../../domain/lang.dart';
import '../domain/trainers.dart';

/// Why the learner opened Vocalart (WIDE-01). One goal picks today's route;
/// it never derives a voice type, a tolerance or an "easy mode", and it is
/// independent of age and of choir membership.
enum PracticeGoal { beginner, ear, voice, choir, stage, exam }

extension PracticeGoalInfo on PracticeGoal {
  String get id => name;

  static PracticeGoal? fromId(Object? id) =>
      id is String ? PracticeGoal.values.asNameMap()[id] : null;

  String get title => switch (this) {
    PracticeGoal.beginner => tr('Müziğe yeni başlıyorum', 'I am new to music'),
    PracticeGoal.ear => tr('Kulağımı geliştirmek', 'Train my ear'),
    PracticeGoal.voice => tr('Sesimi hazırlamak', 'Prepare my voice'),
    PracticeGoal.choir => tr(
      'Koro provasına hazırlanmak',
      'Get ready for choir rehearsal',
    ),
    PracticeGoal.stage => tr(
      'Konuşma ve sahne hazırlığı',
      'Speech and stage preparation',
    ),
    PracticeGoal.exam => tr(
      'Konservatuvar sınavına çalışmak',
      'Study for a conservatory exam',
    ),
  };

  String get subtitle => switch (this) {
    PracticeGoal.beginner => tr(
      'Nota adlarıyla başla; ön bilgi gerekmez',
      'Start with note names; no prior knowledge needed',
    ),
    PracticeGoal.ear => tr(
      'Aralık, akor ve dizileri kulaktan tanı',
      'Recognise intervals, chords and scales by ear',
    ),
    PracticeGoal.voice => tr(
      'Nefes, nota dersi ve isteğe bağlı ses adımı',
      'Breath, a note lesson and an optional voice step',
    ),
    PracticeGoal.choir => tr(
      'Nefes, aralık dersi ve isteğe bağlı ses adımı',
      'Breath, an interval lesson and an optional voice step',
    ),
    PracticeGoal.stage => tr(
      'Şimdilik nefes rehberi; metin içerikleri hazırlanıyor',
      'Breath guide for now; text content is in preparation',
    ),
    PracticeGoal.exam => tr(
      'Aralık dersiyle başla; porte ve dikte hazırlanıyor',
      'Start with intervals; staff and dictation are in preparation',
    ),
  };

  /// The ear lesson path that opens the route; null = no ready lesson for
  /// this goal yet (the route never falls back to another goal's lesson).
  TrainerKind? get lesson => switch (this) {
    PracticeGoal.beginner || PracticeGoal.voice => TrainerKind.pitch,
    PracticeGoal.ear ||
    PracticeGoal.choir ||
    PracticeGoal.exam => TrainerKind.interval,
    PracticeGoal.stage => null,
  };

  /// Content this goal needs that is not ready (educator approval or
  /// recordings missing). Shown as such, never offered as a route step.
  String? get pendingContent => switch (this) {
    PracticeGoal.stage => tr(
      'Artikülasyon, vurgu/durak ve metin provası içerikleri eğitimci onayı '
          'bekliyor. Hazır olana kadar rotada yalnız nefes rehberi var.',
      'Articulation, stress/pause and text rehearsal content is awaiting '
          'educator approval. Until it is ready the route has the breath '
          'guide only.',
    ),
    PracticeGoal.exam => tr(
      'Porte okuma, deşifre ve dikte içerikleri henüz hazır değil.',
      'Staff reading, sight-reading and dictation content is not ready yet.',
    ),
    PracticeGoal.voice => tr(
      'Eğitimci onaylı ses ısınma rutinleri henüz hazır değil.',
      'Educator-approved vocal warm-up routines are not ready yet.',
    ),
    _ => null,
  };
}

/// Today's route. Deterministic and content-free: it only decides which
/// route steps appear, and only from content that already ships.
///
/// Without a goal (saves from before WIDE-01) the route is sized by minutes
/// alone, exactly as before:
/// - up to 3 minutes: the ear lesson alone;
/// - up to 5 minutes: a 1-minute breathing guide, then the lesson;
/// - longer: a 2-minute breathing guide, the lesson, then one voice step.
class DailyRoute {
  const DailyRoute({
    required this.breathSeconds,
    required this.voiceStep,
    this.lesson = true,
    this.goal,
  });

  factory DailyRoute.forMinutes(int minutes) => minutes <= 3
      ? const DailyRoute(breathSeconds: 0, voiceStep: false)
      : minutes <= 5
      ? const DailyRoute(breathSeconds: 60, voiceStep: false)
      : const DailyRoute(breathSeconds: 120, voiceStep: true);

  /// The route for a goal; null keeps the legacy minutes-only route.
  factory DailyRoute.plan({PracticeGoal? goal, required int minutes}) {
    if (goal == null) return DailyRoute.forMinutes(minutes);
    final short = minutes <= 5;
    return switch (goal) {
      // Listening goals: breath only when there is time, no microphone step.
      PracticeGoal.beginner ||
      PracticeGoal.ear ||
      PracticeGoal.exam => DailyRoute(
        breathSeconds: minutes <= 3 ? 0 : (short ? 60 : 120),
        voiceStep: false,
        goal: goal,
      ),
      // Voice goals always start with breath; the optional voice step joins
      // from 5 minutes.
      PracticeGoal.voice || PracticeGoal.choir => DailyRoute(
        breathSeconds: short ? 60 : 120,
        voiceStep: minutes > 3,
        goal: goal,
      ),
      PracticeGoal.stage => DailyRoute(
        breathSeconds: short ? 60 : 120,
        voiceStep: false,
        lesson: false,
        goal: goal,
      ),
    };
  }

  /// Length of the unmeasured "Hazırla" breathing guide; 0 = no such step.
  final int breathSeconds;

  /// Whether a voice workshop step (range test / voice count) closes the
  /// route.
  final bool voiceStep;

  /// Whether an ear lesson is part of the route.
  final bool lesson;

  /// The goal the route was planned for; null = legacy minutes-only route.
  final PracticeGoal? goal;

  bool get breath => breathSeconds > 0;
  int get stepCount =>
      (lesson ? 1 : 0) + (breath ? 1 : 0) + (voiceStep ? 1 : 0);
}

/// Daily minutes offered in onboarding and Settings.
const dailyMinuteChoices = [3, 5, 10, 15, 20];

/// Today's route for the stored goal and minutes.
DailyRoute routeFor(Map<String, Object?> answers, int minutes) =>
    DailyRoute.plan(
      goal: PracticeGoalInfo.fromId(answers['goal']),
      minutes: minutes,
    );
