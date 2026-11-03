import '../content/rhythm_patterns.dart' show ContentReviewStatus;
import '../models/exercise_result.dart';
import '../models/attempt_assistance_evidence.dart';
import '../models/learner_profile.dart';
import 'measured_exercise.dart';
import 'rhythm_next_step.dart';

/// LEARN-01: draft skill graph from LEARNING_MODEL.md stages. Order is a
/// recommendation, not a lock; educators may change it. Not approved content.
enum SkillStage {
  voiceAndPulse,
  directionAndTonic,
  rhythmAndReading,
  melodyAndMemory,
  harmonicHearing,
  examLiteracy,
  partIndependence,
  choirMusicianship,
  transfer,
}

enum LearningRoute { core, conservatory, choir }

/// Perception and production are tracked separately (LEARNING_MODEL).
enum SkillDimension { perception, production }

/// How (and whether) this build can produce evidence for the skill.
enum MeasurementSupport {
  /// Valid in-app measurements exist (linked exercise ids).
  measuredInApp,

  /// Needs the audio engine gates (VAD/benchmark) before any score.
  awaitingEngine,

  /// Needs educator-approved exercises or recordings first.
  awaitingContent,

  /// Judged by a real educator; no automatic score.
  educatorObserved,
}

/// Ladder from LEARNING_MODEL: never "mastered for life".
enum MasteryState { notMeasured, practicing, supported, independent, retained }

class SkillNode {
  SkillNode({
    required this.id,
    required this.title,
    required this.goal,
    required this.stage,
    required this.route,
    required this.dimension,
    required this.support,
    this.prerequisites = const [],
    this.exerciseIds = const [],
    this.review = ContentReviewStatus.draftAwaitingEducator,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9-]{1,47}$').hasMatch(id)) {
      throw ArgumentError('Invalid skill id $id');
    }
    if ((support == MeasurementSupport.measuredInApp) !=
        exerciseIds.isNotEmpty) {
      throw ArgumentError('Only measured skills link exercises ($id)');
    }
  }
  final String id;
  final String title;
  final String goal;
  final SkillStage stage;
  final LearningRoute route;
  final SkillDimension dimension;
  final MeasurementSupport support;
  final List<String> prerequisites;
  final List<String> exerciseIds;
  final ContentReviewStatus review;
}

class SkillGraph {
  SkillGraph(List<SkillNode> nodes) : nodes = List.unmodifiable(nodes) {
    final byId = <String, SkillNode>{};
    for (final n in nodes) {
      if (byId.containsKey(n.id)) throw ArgumentError('Duplicate ${n.id}');
      byId[n.id] = n;
    }
    for (final n in nodes) {
      for (final p in n.prerequisites) {
        final pre = byId[p];
        if (pre == null) {
          throw ArgumentError('${n.id}: unknown prerequisite $p');
        }
        // A route skill may build on core or its own route, never the other.
        if (pre.route != LearningRoute.core && pre.route != n.route) {
          throw ArgumentError('${n.id}: cross-route prerequisite $p');
        }
      }
    }
    _byId = byId;
    order = List.unmodifiable(_topological());
  }

  final List<SkillNode> nodes;
  late final Map<String, SkillNode> _byId;

  /// Prerequisites before dependents; stable by declaration order.
  late final List<SkillNode> order;

  SkillNode operator [](String id) => _byId[id]!;

  List<SkillNode> _topological() {
    final out = <SkillNode>[];
    final state = <String, int>{}; // 1 visiting, 2 done
    void visit(SkillNode n) {
      if (state[n.id] == 2) return;
      if (state[n.id] == 1) throw ArgumentError('Cycle at ${n.id}');
      state[n.id] = 1;
      for (final p in n.prerequisites) {
        visit(_byId[p]!);
      }
      state[n.id] = 2;
      out.add(n);
    }

    for (final n in nodes) {
      visit(n);
    }
    return out;
  }

  /// Core skills plus the goal's own route (foundations: core only).
  List<SkillNode> forGoal(PracticeGoal goal) {
    final route = switch (goal) {
      PracticeGoal.conservatory => LearningRoute.conservatory,
      PracticeGoal.choir => LearningRoute.choir,
      PracticeGoal.foundations => null,
    };
    return [
      for (final n in order)
        if (n.route == LearningRoute.core || n.route == route) n,
    ];
  }
}

/// Evidence-based state per skill from local history. Only measuredInApp
/// skills can leave notMeasured; everything else stays "unknown" honestly.
class SkillStatusEvaluator {
  const SkillStatusEvaluator._();

  static MasteryState stateOf(
    SkillNode node,
    List<ExerciseResult> results, {
    List<MeasuredExercise>? catalog,
  }) {
    if (node.support != MeasurementSupport.measuredInApp) {
      return MasteryState.notMeasured;
    }
    final known = catalog ?? defaultMeasuredCatalog();
    final states = <MasteryState>[];
    for (final id in node.exerciseIds) {
      final e = known.where((e) => e.exerciseId == id);
      states.add(
        e.isEmpty ? MasteryState.notMeasured : exerciseState(e.single, results),
      );
    }
    if (states.every((s) => s == MasteryState.notMeasured)) {
      return MasteryState.notMeasured;
    }
    // Unattempted exercises cap the skill at "practicing".
    final capped = [
      for (final s in states)
        s == MasteryState.notMeasured ? MasteryState.practicing : s,
    ];
    return capped.reduce((a, b) => a.index <= b.index ? a : b);
  }

  static MasteryState exerciseState(
    MeasuredExercise e,
    List<ExerciseResult> results,
  ) {
    final valid = comparableResults(
      results,
      e,
    ).where((r) => r.isValid).toList();
    if (valid.isEmpty) return MasteryState.notMeasured;
    const k = RhythmNextStepPolicy.masteryStreak;
    if (valid.length < k || !valid.sublist(valid.length - k).every(e.isClean)) {
      return MasteryState.practicing;
    }
    final streak = valid.sublist(valid.length - k);
    final retained = valid.any(
      (r) =>
          r.measurements['retentionCheck'] == true &&
          e.isClean(r) &&
          valid.any(
            (earlier) =>
                e.isClean(earlier) &&
                RhythmNextStepPolicy.laterDay(earlier.createdAt, r.createdAt),
          ),
    );
    if (retained) return MasteryState.retained;
    final unaided = streak.every(
      (r) => AttemptAssistanceEvidence.claimsIndependent(r.measurements),
    );
    return unaided ? MasteryState.independent : MasteryState.supported;
  }
}

SkillNode _n(
  String id,
  String title,
  String goal,
  SkillStage stage,
  SkillDimension dimension,
  MeasurementSupport support, {
  LearningRoute route = LearningRoute.core,
  List<String> pre = const [],
  List<String> exercises = const [],
}) => SkillNode(
  id: id,
  title: title,
  goal: goal,
  stage: stage,
  route: route,
  dimension: dimension,
  support: support,
  prerequisites: pre,
  exerciseIds: exercises,
);

/// Draft graph (developer proposal from LEARNING_MODEL; educator review
/// pending). Measured links: rhythm imitation, tone-pair perception and
/// movable-do degree hearing.
final SkillGraph draftSkillGraph = SkillGraph([
  _n(
    'pitch-high-low',
    'Tiz / pes ayırt etme',
    'İki sesten hangisinin daha tiz olduğunu duymak.',
    SkillStage.voiceAndPulse,
    SkillDimension.perception,
    MeasurementSupport.measuredInApp,
    exercises: ['draft-perc-highlow-200', 'draft-perc-highlow-100'],
  ),
  _n(
    'pitch-match',
    'Tek ses eşleme',
    'Duyduğun notayı doğru oktavda, rahatça söylemek.',
    SkillStage.voiceAndPulse,
    SkillDimension.production,
    MeasurementSupport.awaitingEngine,
  ),
  _n(
    'pulse-tap',
    'Düzenli puls',
    'Eşit aralıklı vuruşları dinleyip aynı düzenle tekrar etmek.',
    SkillStage.voiceAndPulse,
    SkillDimension.production,
    MeasurementSupport.measuredInApp,
    exercises: ['draft-rhythm-quarters'],
  ),
  _n(
    'interval-direction',
    'Aralık yönü ve mesafe',
    'İki sesin yukarı/aşağı ilişkisini ve uzaklığını duymak.',
    SkillStage.directionAndTonic,
    SkillDimension.perception,
    MeasurementSupport.awaitingContent,
    pre: ['pitch-high-low'],
  ),
  _n(
    'tonic-degree',
    'Tonik ve dereceler',
    'Tonal merkezi duyup bir sesin derecesini bulmak.',
    SkillStage.directionAndTonic,
    SkillDimension.perception,
    MeasurementSupport.measuredInApp,
    exercises: ['draft-int-do-re-mi-sol', 'draft-int-do-to-la'],
    pre: ['interval-direction'],
  ),
  _n(
    'rhythm-imitation',
    'Ritim tekrarı',
    'Kısa ritimleri dinleyip eksik/fazla vuruş olmadan tekrar etmek.',
    SkillStage.rhythmAndReading,
    SkillDimension.production,
    MeasurementSupport.measuredInApp,
    pre: ['pulse-tap'],
    exercises: ['draft-rhythm-eighths', 'draft-rhythm-syncopation'],
  ),
  _n(
    'rhythm-reading',
    'Ritim okuma',
    'Notadaki süre ve susları okuyup çalmak.',
    SkillStage.rhythmAndReading,
    SkillDimension.perception,
    MeasurementSupport.awaitingContent,
    pre: ['rhythm-imitation'],
  ),
  _n(
    'melody-short',
    'Kısa ezgi (3–5 nota)',
    'Kısa ezgiyi doğru sıra ve oktavla söylemek.',
    SkillStage.melodyAndMemory,
    SkillDimension.production,
    MeasurementSupport.awaitingEngine,
    pre: ['pitch-match', 'interval-direction'],
  ),
  _n(
    'melody-delayed',
    'Gecikmeli ezgi hatırlama',
    'Ezgiyi bir süre sonra ipucusuz hatırlamak.',
    SkillStage.melodyAndMemory,
    SkillDimension.production,
    MeasurementSupport.awaitingEngine,
    pre: ['melody-short'],
  ),
  _n(
    'harmonic-voices',
    '2 / 3 / 4 ses ayırt etme',
    'Birlikte çalınan sesleri duyup tek tek söylemek.',
    SkillStage.harmonicHearing,
    SkillDimension.production,
    MeasurementSupport.awaitingContent,
    route: LearningRoute.conservatory,
    pre: ['melody-short'],
  ),
  _n(
    'dictation-sight-reading',
    'Dikte ve deşifre',
    'Görülmemiş kısa parçayı yazmak ve okumak.',
    SkillStage.examLiteracy,
    SkillDimension.perception,
    MeasurementSupport.awaitingContent,
    route: LearningRoute.conservatory,
    pre: ['harmonic-voices', 'rhythm-reading'],
  ),
  _n(
    'part-independence',
    'Parti bağımsızlığı',
    'Diğer partiler çalarken kendi hattını sürdürmek.',
    SkillStage.partIndependence,
    SkillDimension.production,
    MeasurementSupport.awaitingEngine,
    route: LearningRoute.choir,
    pre: ['melody-short'],
  ),
  _n(
    'entries-cutoffs',
    'Giriş ve bitişler',
    'Sus sonrası doğru giriş ve bitiş zamanlaması.',
    SkillStage.choirMusicianship,
    SkillDimension.production,
    MeasurementSupport.awaitingEngine,
    route: LearningRoute.choir,
    pre: ['part-independence', 'rhythm-imitation'],
  ),
  _n(
    'transfer-conservatory',
    'Sınav denemesine aktarım',
    'Becerileri süreli, ipucusuz denemede kullanmak; eğitimci yorumu.',
    SkillStage.transfer,
    SkillDimension.production,
    MeasurementSupport.educatorObserved,
    route: LearningRoute.conservatory,
    pre: ['dictation-sight-reading'],
  ),
  _n(
    'transfer-choir',
    'Provaya aktarım',
    'Kısa repertuvarda kendi partini gerçek provada söylemek; eğitimci gözlemi.',
    SkillStage.transfer,
    SkillDimension.production,
    MeasurementSupport.educatorObserved,
    route: LearningRoute.choir,
    pre: ['entries-cutoffs'],
  ),
]);
