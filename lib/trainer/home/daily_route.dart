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

  /// The goal's ear-lesson track, in order (PLACE-01). Today's lesson is
  /// the first unfinished path on it; any path can still be opened by hand.
  /// Empty = no ready lesson for this goal yet (never another goal's).
  /// Draft order: not educator-approved. Echo/rhythm/part-singing modules
  /// are lab exercises outside the track until their device gates close.
  List<TrainerKind> get track => switch (this) {
    PracticeGoal.beginner => const [
      TrainerKind.pitch,
      TrainerKind.interval,
      TrainerKind.chord,
    ],
    PracticeGoal.ear => const [
      TrainerKind.interval,
      TrainerKind.chord,
      TrainerKind.scale,
      TrainerKind.progression,
    ],
    PracticeGoal.exam => const [
      TrainerKind.interval,
      TrainerKind.pitch,
      TrainerKind.chord,
      TrainerKind.scale,
      TrainerKind.progression,
    ],
    PracticeGoal.choir => const [
      TrainerKind.interval,
      TrainerKind.pitch,
      TrainerKind.chord,
    ],
    PracticeGoal.voice => const [TrainerKind.pitch, TrainerKind.interval],
    PracticeGoal.stage => const [],
  };

  /// The path that opens the track; null = no ready lesson for this goal.
  TrainerKind? get lesson => track.firstOrNull;

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
      'Porte okuma, deşifre ve dikte içerikleri henüz hazır değil. '
          'Makam melodileri, solfej ve dikte henüz hazır değil; 2/3/4 sesli '
          'tekrar kayıt bekliyor.',
      'Staff reading, sight-reading and dictation content is not ready yet. '
          'Makam melodies, solfège and dictation are not ready; 2/3/4-voice '
          'repetition is waiting for recordings.',
    ),
    PracticeGoal.voice => tr(
      'Eğitimci onaylı ses ısınma rutinleri henüz hazır değil.',
      'Educator-approved vocal warm-up routines are not ready yet.',
    ),
    _ => null,
  };
}

/// A lab "echo" exercise an exam route adds (P4): the way conservatory
/// ear tests are answered is repetition (sing back, clap back), not choosing.
/// Practice only: it never feeds XP, streak, mastery or history.
enum EchoStep { melody, clap }

extension EchoStepInfo on EchoStep {
  String get id => name;

  static EchoStep? fromId(Object? id) =>
      id is String ? EchoStep.values.asNameMap()[id] : null;

  /// The other kind: echo steps alternate day by day.
  EchoStep get other =>
      this == EchoStep.melody ? EchoStep.clap : EchoStep.melody;
}

/// Longest daily time (minutes) with no echo step; longer adds one.
const echoStepMinMinutes = 5;

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
    this.echoStep,
  });

  factory DailyRoute.forMinutes(int minutes) => minutes <= 3
      ? const DailyRoute(breathSeconds: 0, voiceStep: false)
      : minutes <= 5
      ? const DailyRoute(breathSeconds: 60, voiceStep: false)
      : const DailyRoute(breathSeconds: 120, voiceStep: true);

  /// The route for a goal; null keeps the legacy minutes-only route.
  ///
  /// [lastEcho] is the echo kind practised last ([echoDoneToday]: it was
  /// today). An exam route longer than [echoStepMinMinutes] adds one echo
  /// step: today's kind if already done today, else the opposite of the last
  /// one (melody when none yet). No other goal gets an echo step.
  factory DailyRoute.plan({
    PracticeGoal? goal,
    required int minutes,
    EchoStep? lastEcho,
    bool echoDoneToday = false,
  }) {
    if (goal == null) return DailyRoute.forMinutes(minutes);
    final short = minutes <= 5;
    final echo = goal == PracticeGoal.exam && minutes > echoStepMinMinutes
        ? (lastEcho == null
              ? EchoStep.melody
              : (echoDoneToday ? lastEcho : lastEcho.other))
        : null;
    return switch (goal) {
      // Listening goals: breath only when there is time, no microphone step.
      PracticeGoal.beginner ||
      PracticeGoal.ear ||
      PracticeGoal.exam => DailyRoute(
        breathSeconds: minutes <= 3 ? 0 : (short ? 60 : 120),
        voiceStep: false,
        goal: goal,
        echoStep: echo,
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

  /// The echo exercise of an exam route longer than 5 minutes; else null.
  final EchoStep? echoStep;

  bool get breath => breathSeconds > 0;
  int get stepCount =>
      (lesson ? 1 : 0) +
      (breath ? 1 : 0) +
      (voiceStep ? 1 : 0) +
      (echoStep != null ? 1 : 0);
}

/// Daily minutes offered in onboarding and Settings.
const dailyMinuteChoices = [3, 5, 10, 15, 20];

/// Today's route for the stored goal and minutes.
DailyRoute routeFor(
  Map<String, Object?> answers,
  int minutes, {
  EchoStep? lastEcho,
  bool echoDoneToday = false,
}) => DailyRoute.plan(
  goal: PracticeGoalInfo.fromId(answers['goal']),
  minutes: minutes,
  lastEcho: lastEcho,
  echoDoneToday: echoDoneToday,
);
