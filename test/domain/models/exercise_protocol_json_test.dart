import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/models/exercise.dart';
import 'package:harmonia/domain/models/exercise_protocol.dart';

Map<String, Object?> _json() =>
    jsonDecode(
          jsonEncode(
            ExerciseProtocol(
              mode: ExerciseMode.learning,
              notes: [
                NoteEvent(
                  note: const TargetNote(note: 'C4', frequencyHz: 261.63),
                  onsetBeats: 0,
                  durationBeats: 1,
                ),
              ],
            ).toJson(),
          ),
        )
        as Map<String, Object?>;
Map<String, dynamic> _event(Map<String, Object?> data) =>
    (data['notes'] as List).first as Map<String, dynamic>;
void _reject(Map<String, Object?> data) =>
    expect(() => ExerciseProtocol.fromJson(data), throwsFormatException);

void main() {
  test('round-trip retains all v1 fields and aids', () {
    final data = _json()
      ..['allowPitchHint'] = true
      ..['maxReferencePlays'] = 3;
    final restored = ExerciseProtocol.fromJson(data);
    expect(restored.toJson(), data);
    expect(restored.allowPitchHint, isTrue);
  });
  test('integer schema cannot coerce double string bool', () {
    for (final value in [1.0, '1', true, null, 2]) {
      _reject(_json()..['schemaVersion'] = value);
    }
  });
  test('exact fields required at root tuning event and note', () {
    _reject(_json()..['unexpected'] = 'private-text');
    _reject(_json()..remove('allowPitchHint'));
    final a = _json();
    (a['tuning'] as Map)['approved'] = true;
    _reject(a);
    final b = _json();
    _event(b)['voiceScore'] = 100;
    _reject(b);
    final c = _json();
    (_event(c)['note'] as Map)['rights'] = 'claimed';
    _reject(c);
    final d = _json();
    (_event(d)['note'] as Map).remove('frequency');
    _reject(d);
  });
  test('flags require bool, integer policy fields require int', () {
    for (final key in [
      'allowPitchHint',
      'allowTransposition',
      'allowAccompaniment',
    ]) {
      for (final value in [1, 'false', null]) {
        _reject(_json()..[key] = value);
      }
    }
    for (final key in [
      'meterNumerator',
      'meterDenominator',
      'recallDelayMs',
      'maxReferencePlays',
    ]) {
      _reject(_json()..[key] = 1.0);
    }
  });
  test('unknown enum or mode gives safe format failure', () {
    for (final key in ['mode', 'presentation', 'responseOrder']) {
      _reject(_json()..[key] = 'not-a-supported-value');
      _reject(_json()..[key] = null);
    }
  });
  test('numeric types and nonfinite values rejected', () {
    for (final value in ['60', true, null, double.nan, double.infinity]) {
      _reject(_json()..['tempoBpm'] = value);
      final a = _json();
      _event(a)['durationBeats'] = value;
      _reject(a);
      final b = _json();
      (_event(b)['note'] as Map)['frequency'] = value;
      _reject(b);
    }
  });
  test('both event budgets preflight before traversing malformed prefix', () {
    _reject(_json()..['notes'] = List.filled(257, null));
    _reject(_json()..['rhythmOnsetsBeats'] = List.filled(257, null));
    _reject(_json()..['notes'] = 'not-a-list');
    _reject(_json()..['rhythmOnsetsBeats'] = null);
  });
  test(
    'bad late event rejects whole protocol; semantic tuning guard unchanged',
    () {
      final a = _json();
      (a['notes'] as List).add(null);
      _reject(a);
      final b = _json();
      (_event(b)['note'] as Map)['frequency'] = 523.25;
      expect(() => ExerciseProtocol.fromJson(b), throwsArgumentError);
      final c = _json()
        ..['mode'] = 'recall_exam'
        ..['allowPitchHint'] = true;
      expect(() => ExerciseProtocol.fromJson(c), throwsArgumentError);
    },
  );
  test('exported/imported collections do not mutate restored protocol', () {
    final data = _json();
    final restored = ExerciseProtocol.fromJson(data);
    (data['notes'] as List).clear();
    (restored.toJson()['notes'] as List).clear();
    expect(restored.notes.length, 1);
    expect(() => restored.notes.clear(), throwsUnsupportedError);
  });
  test('malformed field errors do not echo private values', () {
    try {
      ExerciseProtocol.fromJson(_json()..['mode'] = 'private-student-note');
      fail('Must reject');
    } on FormatException catch (error) {
      expect(error.source, isNull);
      expect(error.toString(), isNot(contains('private-student-note')));
    }
  });
}
