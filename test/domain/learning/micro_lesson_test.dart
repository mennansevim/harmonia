import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/content/draft_micro_lessons.dart';
import 'package:resonia/domain/learning/micro_lesson.dart';
import 'package:resonia/domain/learning/skill_graph.dart';

List<LessonStep> _steps({
  List<String> training = const ['sample-aa', 'sample-bb'],
  List<String> independent = const ['sample-cc'],
  List<String> delayed = const ['sample-dd'],
}) => [
  for (final p in LessonPhase.values)
    LessonStep(
      phase: p,
      instruction: 'Taslak açıklama',
      exampleIds: switch (p) {
        LessonPhase.contrast => training,
        LessonPhase.independentCheck => independent,
        LessonPhase.delayedCheck => delayed,
        _ => [],
      },
    ),
];
MicroLesson _lesson({
  List<LessonStep>? steps,
  String id = 'lesson-test',
  String skillId = 'pitch-high-low',
  LearningRoute route = LearningRoute.core,
  SkillDimension dimension = SkillDimension.perception,
}) => MicroLesson(
  id: id,
  contentVersion: 'draft-1',
  skillId: skillId,
  title: 'Taslak ders',
  objective: 'Tek beceri hedefi',
  route: route,
  dimension: dimension,
  steps: steps ?? _steps(),
);

void main() {
  test('drafts align with skill graph and do not enable assessment', () {
    expect(draftMicroLessons.lessons.length, 3);
    for (final lesson in draftMicroLessons.lessons) {
      expect(lesson.educatorApproved, isFalse);
      expect(lesson.assessmentEnabled, isFalse);
      expect(lesson.awaitsExamples, isTrue);
      expect(lesson.dimension, draftSkillGraph[lesson.skillId].dimension);
      expect(lesson.steps.map((s) => s.phase), LessonPhase.values);
    }
  });
  test('steps and example ids defensive immutable snapshots', () {
    final ids = ['sample-aa', 'sample-bb'];
    final steps = _steps(training: ids);
    final lesson = _lesson(steps: steps);
    ids.clear();
    steps.clear();
    expect(lesson.steps.length, 5);
    expect(lesson.steps[1].exampleIds.length, 2);
    expect(() => lesson.steps.clear(), throwsUnsupportedError);
    expect(() => lesson.steps[1].exampleIds.clear(), throwsUnsupportedError);
  });
  test('missing, duplicate or shuffled phase rejected', () {
    expect(() => _lesson(steps: _steps()..removeLast()), throwsArgumentError);
    final steps = _steps();
    steps[2] = steps[1];
    expect(() => _lesson(steps: steps), throwsArgumentError);
    expect(
      () => _lesson(steps: _steps().reversed.toList()),
      throwsArgumentError,
    );
  });
  test('training and independent/delayed check ids cannot leak', () {
    expect(
      () => _lesson(steps: _steps(independent: ['sample-aa'])),
      throwsArgumentError,
    );
    expect(
      () => _lesson(steps: _steps(delayed: ['sample-bb'])),
      throwsArgumentError,
    );
    expect(
      () => _lesson(steps: _steps(delayed: ['sample-cc'])),
      throwsArgumentError,
    );
  });
  test('guided examples are also excluded from held-out controls', () {
    final steps = _steps();
    steps[2] = LessonStep(
      phase: LessonPhase.guidedPractice,
      instruction: 'Çalış',
      exampleIds: ['sample-cc'],
    );
    expect(() => _lesson(steps: steps), throwsArgumentError);
  });
  test(
    'invalid reference, duplicate, oversized and malformed step rejected',
    () {
      for (final ids in <List<String>>[
        ['../private'],
        ['sample-aa', 'sample-aa'],
        List.generate(25, (i) => 'sample-$i'),
      ]) {
        expect(
          () => LessonStep(
            phase: LessonPhase.guidedPractice,
            instruction: 'Çalış',
            exampleIds: ids,
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => LessonStep(
          phase: LessonPhase.contrast,
          instruction: 'Çalış',
          exampleIds: ['sample-aa'],
        ),
        throwsArgumentError,
      );
      expect(
        () => LessonStep(
          phase: LessonPhase.explanation,
          instruction: 'Çalış',
          exampleIds: ['sample-aa'],
        ),
        throwsArgumentError,
      );
      expect(
        () => LessonStep(phase: LessonPhase.explanation, instruction: ' '),
        throwsArgumentError,
      );
      expect(
        () =>
            LessonStep(phase: LessonPhase.explanation, instruction: 'x' * 1201),
        throwsArgumentError,
      );
    },
  );
  test('unknown skill or mismatched route/dimension fails closed', () {
    for (final lesson in [
      _lesson(skillId: 'unknown-skill'),
      _lesson(route: LearningRoute.choir),
      _lesson(dimension: SkillDimension.production),
    ]) {
      expect(
        () => MicroLessonCatalog(graph: draftSkillGraph, lessons: [lesson]),
        throwsArgumentError,
      );
    }
  });
  test('catalog snapshot, duplicate and budget guard', () {
    final lessons = [_lesson()];
    final catalog = MicroLessonCatalog(
      graph: draftSkillGraph,
      lessons: lessons,
    );
    lessons.clear();
    expect(catalog.lessons.length, 1);
    expect(catalog.forSkill('unknown-skill'), isEmpty);
    expect(
      () => catalog.forSkill('pitch-high-low').clear(),
      throwsUnsupportedError,
    );
    expect(
      () => MicroLessonCatalog(
        graph: draftSkillGraph,
        lessons: [_lesson(), _lesson()],
      ),
      throwsArgumentError,
    );
    expect(
      () => MicroLessonCatalog(
        graph: draftSkillGraph,
        lessons: List.generate(129, (i) => _lesson(id: 'lesson-$i')),
      ),
      throwsArgumentError,
    );
  });
  test('empty sample slots stay pending, bound ids still not approved', () {
    final lesson = _lesson();
    expect(lesson.awaitsExamples, isTrue); // guided slot is intentionally empty
    final steps = _steps();
    steps[2] = LessonStep(
      phase: LessonPhase.guidedPractice,
      instruction: 'Çalış',
      exampleIds: ['sample-aa'],
    );
    final bound = _lesson(steps: steps);
    expect(bound.awaitsExamples, isFalse);
    expect(bound.assessmentEnabled, isFalse);
    expect(bound.educatorApproved, isFalse);
  });
}
