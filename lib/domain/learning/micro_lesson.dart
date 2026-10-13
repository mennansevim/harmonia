import 'skill_graph.dart';

enum LessonPhase {
  explanation,
  contrast,
  guidedPractice,
  independentCheck,
  delayedCheck,
}

/// Identifier binding only. No waveform, license, label or playback approval.
class LessonStep {
  LessonStep({
    required this.phase,
    required this.instruction,
    List<String> exampleIds = const [],
  }) : exampleIds = List.unmodifiable(exampleIds) {
    if (instruction.trim().isEmpty ||
        instruction.length > 1200 ||
        exampleIds.length > 24 ||
        exampleIds.any((id) => !_id(id)) ||
        exampleIds.toSet().length != exampleIds.length ||
        (phase == LessonPhase.explanation && exampleIds.isNotEmpty) ||
        (phase == LessonPhase.contrast && exampleIds.length == 1)) {
      throw ArgumentError('Invalid lesson step');
    }
  }
  final LessonPhase phase;
  final String instruction;
  final List<String> exampleIds;
  bool get awaitsExamples =>
      phase != LessonPhase.explanation && exampleIds.isEmpty;
}

/// LEARN-02a draft-only lesson contract. Reading/completion has no conversion
/// to ExerciseResult, mastery or an educator approval. Publication is a
/// separate reviewed-content gate; identifiers cannot prove acoustic novelty.
class MicroLesson {
  MicroLesson({
    required this.id,
    required this.contentVersion,
    required this.skillId,
    required this.title,
    required this.objective,
    required this.route,
    required this.dimension,
    required List<LessonStep> steps,
  }) : steps = List.unmodifiable(steps) {
    if (!_id(id) ||
        !_id(contentVersion) ||
        !_id(skillId) ||
        title.trim().isEmpty ||
        title.length > 160 ||
        objective.trim().isEmpty ||
        objective.length > 500 ||
        steps.length != LessonPhase.values.length) {
      throw ArgumentError('Invalid micro lesson');
    }
    for (var i = 0; i < steps.length; i++) {
      if (steps[i].phase != LessonPhase.values[i]) {
        throw ArgumentError('Lesson phases must be complete and ordered');
      }
    }
    final training = <String>{
      ...steps[LessonPhase.contrast.index].exampleIds,
      ...steps[LessonPhase.guidedPractice.index].exampleIds,
    };
    final independent = steps[LessonPhase.independentCheck.index].exampleIds
        .toSet();
    final delayed = steps[LessonPhase.delayedCheck.index].exampleIds.toSet();
    if (training.intersection(independent).isNotEmpty ||
        training.intersection(delayed).isNotEmpty ||
        independent.intersection(delayed).isNotEmpty) {
      throw ArgumentError('Training and unseen checks must use distinct ids');
    }
  }
  final String id, contentVersion, skillId, title, objective;
  final LearningRoute route;
  final SkillDimension dimension;
  final List<LessonStep> steps;

  /// These draft types cannot open an exam or certify educator delivery.
  bool get educatorApproved => false;
  bool get assessmentEnabled => false;
  bool get awaitsExamples => steps.any((step) => step.awaitsExamples);
}

class MicroLessonCatalog {
  MicroLessonCatalog({
    required SkillGraph graph,
    required List<MicroLesson> lessons,
  }) : lessons = List.unmodifiable(lessons) {
    if (lessons.length > 128) throw ArgumentError('Lesson catalog budget');
    final ids = <String>{};
    for (final lesson in lessons) {
      if (!ids.add(lesson.id)) throw ArgumentError('Duplicate lesson id');
      final skills = graph.nodes.where((node) => node.id == lesson.skillId);
      if (skills.length != 1) throw ArgumentError('Unknown lesson skill');
      final skill = skills.single;
      if (lesson.route != skill.route || lesson.dimension != skill.dimension) {
        throw ArgumentError('Lesson route/dimension must match bound skill');
      }
    }
  }
  final List<MicroLesson> lessons;
  List<MicroLesson> forSkill(String skillId) =>
      List.unmodifiable(lessons.where((lesson) => lesson.skillId == skillId));
}

bool _id(String value) => RegExp(r'^[a-z][a-z0-9-]{1,63}$').hasMatch(value);
