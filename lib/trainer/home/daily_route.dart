/// Today's route, sized by the learner's chosen daily minutes. Deterministic
/// and content-free: it only decides which route steps appear.
///
/// - up to 3 minutes: the ear lesson alone;
/// - up to 5 minutes: a 1-minute breathing guide, then the lesson;
/// - longer: a 2-minute breathing guide, the lesson, then one voice step.
class DailyRoute {
  const DailyRoute({required this.breathSeconds, required this.voiceStep});

  factory DailyRoute.forMinutes(int minutes) => minutes <= 3
      ? const DailyRoute(breathSeconds: 0, voiceStep: false)
      : minutes <= 5
      ? const DailyRoute(breathSeconds: 60, voiceStep: false)
      : const DailyRoute(breathSeconds: 120, voiceStep: true);

  /// Length of the unmeasured "Hazırla" breathing guide; 0 = no such step.
  final int breathSeconds;

  /// Whether a voice workshop step (range test / voice count) closes the
  /// route.
  final bool voiceStep;

  bool get breath => breathSeconds > 0;
  int get stepCount => 1 + (breath ? 1 : 0) + (voiceStep ? 1 : 0);
}
