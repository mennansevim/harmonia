import 'package:flutter/widgets.dart';

import '../../application/result_history.dart';
import '../../domain/learning/measured_exercise.dart';
import '../interval/interval_screen.dart';
import '../pitch_comparison/pitch_comparison_screen.dart';
import '../rhythm_imitation/rhythm_imitation_screen.dart';

/// Screen that runs one measured exercise; shared by the home
/// recommendation and the daily plan (LEARN-03).
Widget measuredExerciseScreen(
  MeasuredExercise? e, {
  required ResultHistoryRepository? history,
  required bool retentionCheck,
}) => switch (e) {
  IntervalMeasuredExercise() => IntervalScreen(
    history: history,
    initialLevelId: e.exerciseId,
    retentionCheck: retentionCheck,
  ),
  PitchComparisonMeasuredExercise() => PitchComparisonScreen(
    history: history,
    initialLevelId: e.exerciseId,
    retentionCheck: retentionCheck,
  ),
  _ => RhythmImitationScreen(
    history: history,
    initialPatternId: e?.exerciseId,
    retentionCheck: retentionCheck,
  ),
};
