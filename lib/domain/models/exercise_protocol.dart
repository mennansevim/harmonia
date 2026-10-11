import 'exercise.dart';

enum ReferencePresentation { sequential, simultaneous }

enum ResponseOrder { exact, anyOrder }

/// Beat positions use the stated meter denominator as the beat unit.
class NoteEvent {
  NoteEvent({
    required this.note,
    required this.onsetBeats,
    required this.durationBeats,
  }) {
    if (note.note.trim().isEmpty ||
        !note.frequencyHz.isFinite ||
        note.frequencyHz <= 0 ||
        !onsetBeats.isFinite ||
        onsetBeats < 0 ||
        !durationBeats.isFinite ||
        durationBeats <= 0) {
      throw ArgumentError('Invalid note event');
    }
  }
  final TargetNote note;
  final double onsetBeats;
  final double durationBeats;
  Map<String, Object?> toJson() => {
    'note': note.toJson(),
    'onsetBeats': onsetBeats,
    'durationBeats': durationBeats,
  };
}

/// Validated content contract. The legacy demo Exercise remains supported.
/// This defines stimulus and response rules, not a pitch/sequence analyzer.
class ExerciseProtocol {
  ExerciseProtocol({
    required this.mode,
    required List<NoteEvent> notes,
    List<double> rhythmOnsetsBeats = const [],
    this.presentation = ReferencePresentation.sequential,
    this.responseOrder = ResponseOrder.exact,
    this.a4Hz = 440,
    this.tempoBpm = 60,
    this.meterNumerator = 4,
    this.meterDenominator = 4,
    this.recallDelayMs = 0,
    this.maxReferencePlays = 1,
    this.allowPitchHint = false,
    this.allowTransposition = false,
    this.allowAccompaniment = false,
  }) : notes = List.unmodifiable(notes),
       rhythmOnsetsBeats = List.unmodifiable(rhythmOnsetsBeats) {
    if (!a4Hz.isFinite ||
        a4Hz <= 0 ||
        !tempoBpm.isFinite ||
        tempoBpm <= 0 ||
        meterNumerator < 1 ||
        ![1, 2, 4, 8, 16, 32].contains(meterDenominator) ||
        recallDelayMs < 0 ||
        maxReferencePlays < 1 ||
        (notes.isEmpty && rhythmOnsetsBeats.isEmpty) ||
        notes.length > 256 ||
        rhythmOnsetsBeats.length > 256) {
      throw ArgumentError('Invalid exercise protocol');
    }
    double previous = -1;
    for (final onset in rhythmOnsetsBeats) {
      if (!onset.isFinite || onset < 0 || onset <= previous) {
        throw ArgumentError('Rhythm onsets must increase');
      }
      previous = onset;
    }
    for (var i = 0; i < notes.length; i++) {
      if (presentation == ReferencePresentation.simultaneous &&
          notes[i].onsetBeats != 0) {
        throw ArgumentError('Simultaneous notes must share onset zero');
      }
      if (presentation == ReferencePresentation.sequential &&
          i > 0 &&
          notes[i].onsetBeats <
              notes[i - 1].onsetBeats + notes[i - 1].durationBeats) {
        throw ArgumentError('Sequential notes must not overlap');
      }
    }
    if (mode == ExerciseMode.recallExam &&
        (allowPitchHint || allowTransposition || allowAccompaniment)) {
      throw ArgumentError('Recall exams cannot use learning aids');
    }
    if (allowAccompaniment && mode != ExerciseMode.choirPractice) {
      throw ArgumentError('Accompaniment is reserved for choir practice');
    }
  }
  final ExerciseMode mode;
  final List<NoteEvent> notes;
  final List<double> rhythmOnsetsBeats;
  final ReferencePresentation presentation;
  final ResponseOrder responseOrder;

  /// Initial contract supports 12-tone equal temperament only.
  final double a4Hz;
  final double tempoBpm;
  final int meterNumerator, meterDenominator, recallDelayMs, maxReferencePlays;
  final bool allowPitchHint, allowTransposition, allowAccompaniment;
  bool get targetVisibleDuringResponse => mode != ExerciseMode.recallExam;
  factory ExerciseProtocol.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported protocol version');
    }
    final tuning = json['tuning'] as Map<String, dynamic>;
    if (tuning['system'] != '12tet') {
      throw const FormatException('Unsupported tuning');
    }
    return ExerciseProtocol(
      mode: ExerciseMode.values.singleWhere((m) => m.wireValue == json['mode']),
      notes: (json['notes'] as List).map((raw) {
        final event = raw as Map;
        final note = event['note'] as Map;
        return NoteEvent(
          note: TargetNote(
            note: note['note'] as String,
            frequencyHz: (note['frequency'] as num).toDouble(),
          ),
          onsetBeats: (event['onsetBeats'] as num).toDouble(),
          durationBeats: (event['durationBeats'] as num).toDouble(),
        );
      }).toList(),
      rhythmOnsetsBeats: (json['rhythmOnsetsBeats'] as List)
          .map((n) => (n as num).toDouble())
          .toList(),
      presentation: ReferencePresentation.values.byName(
        json['presentation'] as String,
      ),
      responseOrder: ResponseOrder.values.byName(
        json['responseOrder'] as String,
      ),
      a4Hz: (tuning['a4Hz'] as num).toDouble(),
      tempoBpm: (json['tempoBpm'] as num).toDouble(),
      meterNumerator: json['meterNumerator'] as int,
      meterDenominator: json['meterDenominator'] as int,
      recallDelayMs: json['recallDelayMs'] as int,
      maxReferencePlays: json['maxReferencePlays'] as int,
      allowPitchHint: json['allowPitchHint'] as bool,
      allowTransposition: json['allowTransposition'] as bool,
      allowAccompaniment: json['allowAccompaniment'] as bool,
    );
  }
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'mode': mode.wireValue,
    'notes': notes.map((n) => n.toJson()).toList(),
    'rhythmOnsetsBeats': rhythmOnsetsBeats,
    'presentation': presentation.name,
    'responseOrder': responseOrder.name,
    'tuning': {'system': '12tet', 'a4Hz': a4Hz},
    'tempoBpm': tempoBpm,
    'meterNumerator': meterNumerator,
    'meterDenominator': meterDenominator,
    'recallDelayMs': recallDelayMs,
    'maxReferencePlays': maxReferencePlays,
    'allowPitchHint': allowPitchHint,
    'allowTransposition': allowTransposition,
    'allowAccompaniment': allowAccompaniment,
  };
}

/// New catalog entries bind the validated protocol to a legacy exercise.
class ConfiguredExercise {
  ConfiguredExercise({required this.exercise, required this.protocol}) {
    if (exercise.id.trim().isEmpty ||
        exercise.contentVersion.trim().isEmpty ||
        exercise.difficulty < 1 ||
        exercise.mode != protocol.mode) {
      throw ArgumentError('Exercise metadata and protocol must agree');
    }
    final count = protocol.notes.length;
    final valid = switch (exercise.skill) {
      Skill.pitch || Skill.range => count == 1,
      Skill.interval => count == 2,
      Skill.chord =>
        count >= 2 &&
            count <= 4 &&
            protocol.presentation == ReferencePresentation.simultaneous,
      Skill.melody =>
        count >= 2 &&
            protocol.presentation == ReferencePresentation.sequential &&
            protocol.responseOrder == ResponseOrder.exact,
      Skill.rhythm => count == 0 && protocol.rhythmOnsetsBeats.isNotEmpty,
    };
    if (!valid) throw ArgumentError('Protocol does not match skill');
    if (exercise.targetNote != null &&
        (count != 1 || exercise.targetNote != protocol.notes.first.note)) {
      throw ArgumentError('Legacy target conflicts with sequence');
    }
  }
  final Exercise exercise;
  final ExerciseProtocol protocol;
}
