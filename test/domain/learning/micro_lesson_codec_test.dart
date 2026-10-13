import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/content/draft_micro_lessons.dart';
import 'package:harmonia/domain/learning/micro_lesson_codec.dart';
import 'package:harmonia/domain/learning/skill_graph.dart';

Map<String, dynamic> _json() =>
    jsonDecode(MicroLessonCodec.encode(draftMicroLessons))
        as Map<String, dynamic>;
Map<String, dynamic> _lesson(Map<String, dynamic> data) =>
    (data['lessons'] as List).first as Map<String, dynamic>;
Map<String, dynamic> _step(Map<String, dynamic> data, int index) =>
    (_lesson(data)['steps'] as List)[index] as Map<String, dynamic>;
void _reject(Object? value) => expect(
  () => MicroLessonCodec.fromJson(value, graph: draftSkillGraph),
  throwsFormatException,
);

void main() {
  test('malformed JSON errors do not expose catalog text', () {
    try {
      MicroLessonCodec.decode('{"private-note":', graph: draftSkillGraph);
      fail('Must reject malformed JSON');
    } on FormatException catch (error) {
      expect(error.source, isNull);
      expect(error.toString(), isNot(contains('private-note')));
    }
  });
  test(
    'draft round-trip deterministic with gates and pending slots preserved',
    () {
      final text = MicroLessonCodec.encode(draftMicroLessons);
      final restored = MicroLessonCodec.decode(text, graph: draftSkillGraph);
      expect(MicroLessonCodec.encode(restored), text);
      for (final lesson in restored.lessons) {
        expect(lesson.educatorApproved, isFalse);
        expect(lesson.assessmentEnabled, isFalse);
        expect(lesson.awaitsExamples, isTrue);
      }
    },
  );
  test('schema kind and version must be exact, no coercion', () {
    for (final version in [null, true, '1', 1.0, 0, 2]) {
      _reject(_json()..['schemaVersion'] = version);
    }
    _reject(_json()..['kind'] = 'approved_lessons');
    _reject(null);
    _reject([]);
  });
  test('unknown or missing fields rejected at every object depth', () {
    _reject(_json()..['assessmentEnabled'] = true);
    _reject(_json()..remove('kind'));
    final a = _json();
    _lesson(a)['educatorApproved'] = true;
    _reject(a);
    final b = _json();
    _lesson(b).remove('review');
    _reject(b);
    final c = _json();
    _step(c, 0)['score'] = 100;
    _reject(c);
    final d = _json();
    _step(d, 0).remove('exampleIds');
    _reject(d);
  });
  test('approval cannot be imported, even when examples exist', () {
    for (final review in [null, true, 'educator_approved', 'draft']) {
      final data = _json();
      _lesson(data)['review'] = review;
      _reject(data);
    }
  });
  test('invalid enums, types, strings and references rejected', () {
    for (final field in [
      'id',
      'title',
      'objective',
      'contentVersion',
      'skillId',
    ]) {
      final data = _json();
      _lesson(data)[field] = 10;
      _reject(data);
    }
    for (final field in ['route', 'dimension']) {
      final data = _json();
      _lesson(data)[field] = 'unknown';
      _reject(data);
    }
    final a = _json();
    _step(a, 0)['phase'] = 0;
    _reject(a);
    final b = _json();
    _step(b, 1)['exampleIds'] = [false];
    _reject(b);
    final c = _json();
    _step(c, 2)['exampleIds'] = ['../private'];
    _reject(c);
    final d = _json();
    _step(d, 0)['instruction'] = ' ';
    _reject(d);
  });
  test('graph binding and duplicate lesson ids revalidated', () {
    final a = _json();
    _lesson(a)['skillId'] = 'missing-skill';
    _reject(a);
    final b = _json();
    _lesson(b)['dimension'] = 'production';
    _reject(b);
    final c = _json();
    _lesson(c)['route'] = 'choir';
    _reject(c);
    final d = _json();
    (d['lessons'] as List).add(_lesson(d));
    _reject(d);
  });
  test(
    'bad late lesson rejects entire catalog rather than accepting prefix',
    () {
      final data = _json();
      (data['lessons'] as List).last['skillId'] = 'missing-skill';
      _reject(data);
    },
  );
  test('phase sequence and held-out partition guards retained on import', () {
    final a = _json();
    (_lesson(a)['steps'] as List).removeLast();
    _reject(a);
    final b = _json();
    _step(b, 2)['phase'] = 'contrast';
    _reject(b);
    final c = _json();
    _step(c, 1)['exampleIds'] = ['sample-aa', 'sample-bb'];
    _step(c, 3)['exampleIds'] = ['sample-aa'];
    _reject(c);
  });
  test('budgets checked before list item traversal and UTF8 before decode', () {
    _reject(_json()..['lessons'] = List.filled(129, null));
    final a = _json();
    _lesson(a)['steps'] = List.filled(6, null);
    _reject(a);
    final b = _json();
    _step(b, 2)['exampleIds'] = List.filled(25, null);
    _reject(b);
    final c = _json();
    _step(c, 0)['instruction'] = 'x' * 1201;
    _reject(c);
    expect(
      () => MicroLessonCodec.decode(
        'x' * (MicroLessonCodec.maxEncodedBytes + 1),
        graph: draftSkillGraph,
      ),
      throwsFormatException,
    );
    expect(
      () => MicroLessonCodec.decode('ğ' * 600000, graph: draftSkillGraph),
      throwsFormatException,
    );
  });
  test('input and exported maps cannot mutate immutable restored lessons', () {
    final data = _json();
    final restored = MicroLessonCodec.fromJson(data, graph: draftSkillGraph);
    _lesson(data)['title'] = 'Changed';
    _step(data, 0)['instruction'] = 'Changed';
    final exported = MicroLessonCodec.toJson(restored);
    (exported['lessons'] as List).clear();
    expect(restored.lessons.first.title, draftMicroLessons.lessons.first.title);
    expect(
      restored.lessons.first.steps.first.instruction,
      draftMicroLessons.lessons.first.steps.first.instruction,
    );
  });
}
