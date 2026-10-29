import 'dart:math' as math;

import '../models/exercise.dart';
import '../models/exercise_protocol.dart';

/// Known piano stimulus labels, NOT a chord detector or student score.
/// Initial keyboard range is MIDI 21–108, 12-TET. Enharmonics share one key.
class PianoChordReference {
  PianoChordReference({
    required List<int> midiNotes,
    this.a4Hz = 440,
    this.durationMs = 1500,
    this.settleSilenceMs = 250,
    this.mode = ExerciseMode.learning,
    this.responseOrder = ResponseOrder.exact,
    this.recallDelayMs = 0,
    this.maxReferencePlays = 1,
  }) : midiNotes = _snapshotKeys(midiNotes) {
    if (midiNotes.length < 2 ||
        midiNotes.length > 4 ||
        midiNotes.toSet().length != midiNotes.length ||
        midiNotes.any((n) => n < 21 || n > 108) ||
        !a4Hz.isFinite ||
        a4Hz < 400 ||
        a4Hz > 480 ||
        durationMs < 100 ||
        durationMs > 5000 ||
        settleSilenceMs < 0 ||
        settleSilenceMs > 2000 ||
        recallDelayMs < 0 ||
        recallDelayMs > 10000 ||
        maxReferencePlays < 1 ||
        maxReferencePlays > 10 ||
        (mode == ExerciseMode.recallExam && maxReferencePlays != 1) ||
        (mode != ExerciseMode.learning && mode != ExerciseMode.recallExam)) {
      throw ArgumentError('Invalid 2/3/4-note piano reference');
    }
  }

  final List<int> midiNotes;
  final double a4Hz;
  final int durationMs, settleSilenceMs, recallDelayMs, maxReferencePlays;
  final ExerciseMode mode;
  final ResponseOrder responseOrder;

  static List<int> _snapshotKeys(List<int> keys) {
    if (keys.length < 2 ||
        keys.length > 4 ||
        keys.toSet().length != keys.length ||
        keys.any((n) => n < 21 || n > 108)) {
      throw ArgumentError('Supply 2/3/4 distinct piano keys');
    }
    return List.unmodifiable([...keys]..sort());
  }

  /// Exact response defaults to low→high, independent of bank/input ordering.
  /// anyOrder permits a later set matcher, NOT multiple simultaneous singers.
  List<TargetNote> get targetNotes => List.unmodifiable([
    for (final midi in midiNotes)
      TargetNote(
        note: '${_names[midi % 12]}${midi ~/ 12 - 1}',
        frequencyHz: a4Hz * math.pow(2, (midi - 69) / 12),
      ),
  ]);

  static const _names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  ConfiguredExercise configure({
    required String id,
    required String title,
    required int difficulty,
    required String contentVersion,
  }) => ConfiguredExercise(
    exercise: Exercise(
      id: id,
      skill: Skill.chord,
      title: title,
      difficulty: difficulty,
      mode: mode,
      contentVersion: contentVersion,
    ),
    protocol: ExerciseProtocol(
      mode: mode,
      notes: [
        for (final note in targetNotes)
          NoteEvent(
            note: note,
            onsetBeats: 0,
            durationBeats: durationMs / 1000,
          ),
      ],
      presentation: ReferencePresentation.simultaneous,
      responseOrder: responseOrder,
      a4Hz: a4Hz,
      recallDelayMs: recallDelayMs,
      maxReferencePlays: maxReferencePlays,
    ),
  );
}
