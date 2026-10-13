import 'dart:convert';

import 'micro_lesson.dart';
import 'skill_graph.dart';

/// Versioned draft interchange only; no IO, approval or runnable assessment.
abstract final class MicroLessonCodec {
  static const schemaVersion = 1;
  static const maxEncodedBytes = 1024 * 1024;

  static Map<String, Object?> toJson(MicroLessonCatalog catalog) => {
    'schemaVersion': schemaVersion,
    'kind': 'draft_micro_lessons',
    'lessons': [
      for (final lesson in catalog.lessons)
        {
          'id': lesson.id,
          'contentVersion': lesson.contentVersion,
          'skillId': lesson.skillId,
          'title': lesson.title,
          'objective': lesson.objective,
          'route': lesson.route.name,
          'dimension': lesson.dimension.name,
          'review': 'draft_awaiting_educator',
          'steps': [
            for (final step in lesson.steps)
              {
                'phase': step.phase.name,
                'instruction': step.instruction,
                'exampleIds': [...step.exampleIds],
              },
          ],
        },
    ],
  };

  static String encode(MicroLessonCatalog catalog) {
    final text = jsonEncode(toJson(catalog));
    _budget(text);
    return text;
  }

  static MicroLessonCatalog decode(String text, {required SkillGraph graph}) {
    _budget(text);
    try {
      return fromJson(jsonDecode(text), graph: graph);
    } on FormatException {
      // JSON parser errors otherwise retain the original input as source.
      _invalid();
    }
  }

  static MicroLessonCatalog fromJson(
    Object? value, {
    required SkillGraph graph,
  }) {
    try {
      final root = _object(value, {'schemaVersion', 'kind', 'lessons'});
      if (root['schemaVersion'] is! int ||
          root['schemaVersion'] != schemaVersion ||
          root['kind'] != 'draft_micro_lessons') {
        _invalid();
      }
      final lessons = _list(root['lessons'], 128);
      return MicroLessonCatalog(
        graph: graph,
        lessons: [for (final item in lessons) _lesson(item)],
      );
    } on ArgumentError {
      // No partially accepted prefix and no private text in the error.
      _invalid();
    }
  }

  static MicroLesson _lesson(Object? item) {
    final data = _object(item, {
      'id',
      'contentVersion',
      'skillId',
      'title',
      'objective',
      'route',
      'dimension',
      'review',
      'steps',
    });
    if (data['review'] != 'draft_awaiting_educator') {
      _invalid();
    }
    final steps = _list(data['steps'], LessonPhase.values.length);
    return MicroLesson(
      id: _string(data['id'], 64),
      contentVersion: _string(data['contentVersion'], 64),
      skillId: _string(data['skillId'], 64),
      title: _string(data['title'], 160),
      objective: _string(data['objective'], 500),
      route: _enum(data['route'], LearningRoute.values),
      dimension: _enum(data['dimension'], SkillDimension.values),
      steps: [for (final item in steps) _step(item)],
    );
  }

  static LessonStep _step(Object? item) {
    final data = _object(item, {'phase', 'instruction', 'exampleIds'});
    return LessonStep(
      phase: _enum(data['phase'], LessonPhase.values),
      instruction: _string(data['instruction'], 1200),
      exampleIds: [
        for (final id in _list(data['exampleIds'], 24)) _string(id, 64),
      ],
    );
  }

  static void _budget(String text) {
    if (text.length > maxEncodedBytes ||
        utf8.encode(text).length > maxEncodedBytes) {
      _invalid();
    }
  }

  static Map<String, Object?> _object(Object? value, Set<String> keys) {
    if (value is! Map ||
        value.length != keys.length ||
        !value.keys.every((key) => key is String && keys.contains(key))) {
      _invalid();
    }
    return Map<String, Object?>.from(value);
  }

  static List<dynamic> _list(Object? value, int max) {
    if (value is! List || value.length > max) {
      _invalid();
    }
    return value;
  }

  static String _string(Object? value, int max) {
    if (value is! String || value.trim().isEmpty || value.length > max) {
      _invalid();
    }
    return value;
  }

  static T _enum<T extends Enum>(Object? value, List<T> values) {
    final matches = values.where((entry) => entry.name == value);
    if (matches.length != 1) {
      _invalid();
    }
    return matches.single;
  }

  static Never _invalid() =>
      throw const FormatException('Invalid draft lesson catalog');
}
