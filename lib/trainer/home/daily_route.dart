/// Today's route, sized by the learner's chosen daily minutes. Deterministic
/// and content-free: it only decides which route steps appear.
///
/// - up to 3 minutes: the ear lesson alone;
/// - up to 5 minutes: a 1-minute breathing guide, then the lesson;
/// - longer: a 2-minute breathing guide, the lesson, then one choir step.
class DailyRoute {
  const DailyRoute({required this.breathSeconds, required this.choirStep});

  factory DailyRoute.forMinutes(int minutes) => minutes <= 3
      ? const DailyRoute(breathSeconds: 0, choirStep: false)
      : minutes <= 5
      ? const DailyRoute(breathSeconds: 60, choirStep: false)
      : const DailyRoute(breathSeconds: 120, choirStep: true);

  /// Length of the unmeasured "Hazırla" breathing guide; 0 = no such step.
  final int breathSeconds;

  /// Whether the choir workshop step closes the route.
  final bool choirStep;

  bool get breath => breathSeconds > 0;
  int get stepCount => 1 + (breath ? 1 : 0) + (choirStep ? 1 : 0);
}
