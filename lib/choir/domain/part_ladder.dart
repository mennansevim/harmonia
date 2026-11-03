/// Accompanied part learning in fading steps: the singer first hears the
/// full texture, then sings with their own part in front, and the support is
/// taken away until they hold the part against the others alone (a
/// "part-missing" mix). This follows the common learning-track routine
/// (full mix → part-dominant → own part → part-missing) and the fading of
/// scaffolding; it is a practice order, not a measurement, and nothing here
/// is scored.
enum PartStep {
  /// Every part balanced; follow your line without singing.
  listen(ownGain: 0.8, othersGain: 0.8, tempo: 100, sing: false),

  /// Own part in front, slower, on a neutral vowel.
  lead(ownGain: 1, othersGain: 0.25, tempo: 80, sing: true),

  /// Own part still clearly there, full tempo, with the words.
  together(ownGain: 0.9, othersGain: 0.55, tempo: 100, sing: true),

  /// Own part faint: the singer carries it.
  carry(ownGain: 0.25, othersGain: 0.8, tempo: 100, sing: true),

  /// Own part gone: hold it against the other voices.
  alone(ownGain: 0, othersGain: 0.8, tempo: 100, sing: true);

  const PartStep({
    required this.ownGain,
    required this.othersGain,
    required this.tempo,
    required this.sing,
  });
  final double ownGain;
  final double othersGain;

  /// Percent of the written tempo.
  final int tempo;

  /// False for the listening step.
  final bool sing;

  PartStep? get next =>
      index + 1 < PartStep.values.length ? PartStep.values[index + 1] : null;

  /// The step a mix corresponds to, or null for a hand-made mix.
  static PartStep? matching(double ownGain, double othersGain, int tempo) {
    for (final s in PartStep.values) {
      if ((s.ownGain - ownGain).abs() < 0.01 &&
          (s.othersGain - othersGain).abs() < 0.01 &&
          s.tempo == tempo) {
        return s;
      }
    }
    return null;
  }
}
