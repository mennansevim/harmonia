import 'exercise.dart';
import '../audio/target_note_tuning.dart';

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
  static const maxReferencePlaysLimit = 256;
  static const maxRecallDelayMs = 600000;

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
        recallDelayMs > maxRecallDelayMs ||
        maxReferencePlays < 1 ||
        maxReferencePlays > maxReferencePlaysLimit ||
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
      TargetNoteTuning.validate(notes[i].note, a4Hz: a4Hz);
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
    final root = _protocolObject(json, {
      'schemaVersion',
      'mode',
      'notes',
      'rhythmOnsetsBeats',
      'presentation',
      'responseOrder',
      'tuning',
      'tempoBpm',
      'meterNumerator',
      'meterDenominator',
      'recallDelayMs',
      'maxReferencePlays',
      'allowPitchHint',
      'allowTransposition',
      'allowAccompaniment',
    });
    if (root['schemaVersion'] is! int || root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported protocol version');
    }
    final tuning = _protocolObject(root['tuning'], {'system', 'a4Hz'});
    if (tuning['system'] != '12tet') {
      throw const FormatException('Unsupported tuning');
    }
    // Preflight both counts before walking even the first event.
    final notes = _protocolList(root['notes']);
    final rhythms = _protocolList(root['rhythmOnsetsBeats']);
    return ExerciseProtocol(
      mode: _protocolMode(root['mode']),
      notes: notes.map((raw) {
        final event = _protocolObject(raw, {
          'note',
          'onsetBeats',
          'durationBeats',
        });
        final note = _protocolObject(event['note'], {'note', 'frequency'});
        return NoteEvent(
          note: TargetNote(
            note: _protocolString(note['note']),
            frequencyHz: _protocolNumber(note['frequency']),
          ),
          onsetBeats: _protocolNumber(event['onsetBeats']),
          durationBeats: _protocolNumber(event['durationBeats']),
        );
      }).toList(),
      rhythmOnsetsBeats: rhythms.map(_protocolNumber).toList(),
      presentation: _protocolEnum(
        root['presentation'],
        ReferencePresentation.values,
      ),
      responseOrder: _protocolEnum(root['responseOrder'], ResponseOrder.values),
      a4Hz: _protocolNumber(tuning['a4Hz']),
      tempoBpm: _protocolNumber(root['tempoBpm']),
      meterNumerator: _protocolInt(root['meterNumerator']),
      meterDenominator: _protocolInt(root['meterDenominator']),
      recallDelayMs: _protocolInt(root['recallDelayMs']),
      maxReferencePlays: _protocolInt(root['maxReferencePlays']),
      allowPitchHint: _protocolBool(root['allowPitchHint']),
      allowTransposition: _protocolBool(root['allowTransposition']),
      allowAccompaniment: _protocolBool(root['allowAccompaniment']),
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

Map<String, Object?> _protocolObject(Object? value, Set<String> keys) {
  if (value is! Map ||
      value.length != keys.length ||
      !value.keys.every((key) => key is String && keys.contains(key))) {
    throw const FormatException('Invalid protocol fields');
  }
  return Map<String, Object?>.from(value);
}

List<dynamic> _protocolList(Object? value) {
  if (value is! List || value.length > 256) {
    throw const FormatException('Invalid protocol event budget');
  }
  return value;
}

String _protocolString(Object? value) {
  if (value is! String || value.isEmpty || value.length > 8) {
    throw const FormatException('Invalid protocol note label');
  }
  return value;
}

double _protocolNumber(Object? value) {
  if (value is! num || !value.isFinite || !value.toDouble().isFinite) {
    throw const FormatException('Invalid protocol number');
  }
  return value.toDouble();
}

int _protocolInt(Object? value) {
  if (value is! int) throw const FormatException('Invalid protocol integer');
  return value;
}

bool _protocolBool(Object? value) {
  if (value is! bool) throw const FormatException('Invalid protocol flag');
  return value;
}

T _protocolEnum<T extends Enum>(Object? value, List<T> values) {
  final found = values.where((entry) => entry.name == value);
  if (found.length != 1) throw const FormatException('Unknown protocol enum');
  return found.single;
}

ExerciseMode _protocolMode(Object? value) {
  final found = ExerciseMode.values.where((mode) => mode.wireValue == value);
  if (found.length != 1) throw const FormatException('Unknown protocol mode');
  return found.single;
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
