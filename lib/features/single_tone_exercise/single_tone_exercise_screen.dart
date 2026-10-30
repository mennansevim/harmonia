import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/audio/pitch_analyzer.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/score_metric.dart';
import '../../domain/scoring/pitch_exercise_scorer.dart';
import '../../infrastructure/audio/mock/mock_pitch_analyzer.dart';
import '../common/ui/resonia_ui.dart';

/// Developer-only result gallery: [MockPitchScenario] exercises deterministic
/// feedback without opening a microphone, playing a reference or saving history.
/// The separate real capture session remains unscored until its evidence gates
/// pass; this gallery does not validate that pipeline.
///
/// Feedback copy reuses the deterministic fallback strings from
/// AI_COACH.md § Fallback: they are rule-based, not AI-generated, so
/// showing them here does not connect the AI Coach to the live app.
class SingleToneExerciseScreen extends StatefulWidget {
  SingleToneExerciseScreen({
    super.key,
    Exercise? exercise,
    PitchAnalyzer? pitchAnalyzer,
    PitchExerciseScorer? scorer,
    String? sessionId,
  }) : exercise = exercise ?? _defaultExercise,
       pitchAnalyzer = pitchAnalyzer ?? MockPitchAnalyzer(),
       scorer = scorer ?? const PitchExerciseScorer(),
       sessionId = sessionId ?? 'local-session';

  final Exercise exercise;
  final PitchAnalyzer pitchAnalyzer;
  final PitchExerciseScorer scorer;
  final String sessionId;

  static const _defaultExercise = Exercise(
    id: 'single-tone-c4',
    skill: Skill.pitch,
    title: 'Tek Ses: Do (C4)',
    difficulty: 1,
    targetNote: TargetNote(note: 'C4', frequencyHz: 261.63),
    description: 'Referans notayı dinle ve aynı notayı söyle.',
  );

  @override
  State<SingleToneExerciseScreen> createState() =>
      _SingleToneExerciseScreenState();
}

class _SingleToneExerciseScreenState extends State<SingleToneExerciseScreen> {
  ExerciseResult? _lastResult;
  bool _isAnalyzing = false;
  String? _error;

  Future<void> _runScenario(MockPitchScenario scenario) async {
    if (_isAnalyzing || !mounted) return;
    setState(() {
      _isAnalyzing = true;
      _lastResult = null;
      _error = null;
    });
    try {
      final analyzer = widget.pitchAnalyzer;
      if (analyzer is MockPitchAnalyzer) {
        analyzer.setScenario(scenario);
      }

      final pitchResult = await widget.pitchAnalyzer.analyze(
        PitchAnalysisRequest(
          samples: const [],
          sampleRateHz: 44100,
          targetFrequencyHz: widget.exercise.targetNote!.frequencyHz,
        ),
      );

      if (!mounted) return;
      final result = widget.scorer.score(
        exercise: widget.exercise,
        sessionId: widget.sessionId,
        pitch: pitchResult,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _lastResult = result;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Örnek sonuç oluşturulamadı. Yeniden deneyebilirsin.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return LessonScaffold(
      progress: null,
      counter: 'Simülasyon',
      closeLabel: 'Tek ses sonuç örneklerini kapat',
      top: [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill('Mikrofon kapalı'),
        ),
        const SizedBox(height: ResoniaSpacing.md),
        Text(exercise.title, style: Theme.of(context).textTheme.headlineSmall),
        const Text('Mikrofon girişi henüz simüle ediliyor'),
        const Text(
          'Bunlar hazır sonuç örnekleridir; senin başarını ölçmez, geçmişine veya gelişimine eklenmez.',
        ),
        const SizedBox(height: ResoniaSpacing.md),
        _TargetNoteCard(exercise: exercise),
        if (_isAnalyzing)
          Semantics(
            liveRegion: true,
            child: const Text(
              'Örnek sonuç hazırlanıyor…',
              key: Key('demo_pending'),
            ),
          )
        else if (_lastResult != null)
          Semantics(
            liveRegion: true,
            child: _FeedbackCard(result: _lastResult!),
          ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: Text(_error!, key: const Key('demo_error')),
          ),
      ],
      bottom: [
        Text(
          'Bir sonuç örneği seç',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ResoniaSpacing.sm),
        _ScenarioButtons(isBusy: _isAnalyzing, onSelected: _runScenario),
        const SizedBox(height: ResoniaSpacing.md),
        const ExpansionTile(
          key: Key('demo_help'),
          tilePadding: EdgeInsets.zero,
          title: Text('Bu örnekler neyi gösterir?'),
          children: [
            Text(
              'Doğru nota, yanlış oktav ve geçersiz ölçüm gibi durumlarda açıklamanın nasıl görüneceğini gösterir. Sayılar simülasyona aittir; mikrofon açılmaz, referans ses çalınmaz ve ses kaydı alınmaz. Gerçek dinle-söyle oturumu ayrı bir modüldür; bu ekran onu doğrulamaz.',
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetNoteCard extends StatelessWidget {
  const _TargetNoteCard({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final target = exercise.targetNote!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          children: [
            Text(
              'Örnek hedef nota',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(target.note, style: Theme.of(context).textTheme.displayMedium),
            DataLabel('${target.frequencyHz.toStringAsFixed(2)} Hz'),
            if (exercise.description != null) ...[
              const SizedBox(height: 12),
              Text(
                'Örnek yönerge: ${exercise.description!}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScenarioButtons extends StatelessWidget {
  const _ScenarioButtons({required this.isBusy, required this.onSelected});

  final bool isBusy;
  final ValueChanged<MockPitchScenario> onSelected;

  static const _labels = {
    MockPitchScenario.correct: 'Doğru ses örneği',
    MockPitchScenario.wrongNote: 'Yanlış Nota',
    MockPitchScenario.wrongOctaveDown: 'Yanlış Oktav (Aşağı)',
    MockPitchScenario.wrongOctaveUp: 'Yanlış Oktav (Yukarı)',
    MockPitchScenario.unstable: 'Kararsız Ses',
    MockPitchScenario.noisy: 'Gürültülü Ortam',
    MockPitchScenario.silence: 'Sessizlik',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final entry in _labels.entries)
          ChunkyButton(
            key: Key('scenario_${entry.key.name}'),
            onPressed: isBusy ? null : () => onSelected(entry.key),
            tone: ChunkyTone.neutral,
            expand: false,
            label: entry.value,
          ),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.result});

  final ExerciseResult result;

  /// Deterministic, rule-based copy — matches AI_COACH.md § Fallback so the
  /// same wording is used whether the AI Coach is reachable or not.
  static const _errorMessages = {
    ExerciseErrorType.wrongOctave:
        'Bir oktav fark var. Aynı notayı hedef oktavda tekrar dene.',
    ExerciseErrorType.unstable:
        'Sesin hedefe yaklaştı fakat sabit kalmadı. Daha uzun ve rahat söyle.',
    ExerciseErrorType.noise:
        'Ortam sesi sonucu etkiliyor. Kulaklık ve sessiz ortam dene.',
    ExerciseErrorType.wrongNote:
        'Farklı bir nota söyledin. Hedef notayı tekrar dinle.',
    ExerciseErrorType.missingVoice:
        'Ses algılanmadı. Mikrofonu kontrol et ve tekrar dene.',
    ExerciseErrorType.late_: 'Doğru söyledin; başlangıç biraz geç geldi.',
    ExerciseErrorType.early: 'Doğru söyledin; başlangıç biraz erken geldi.',
    ExerciseErrorType.invalidSignal:
        'Ölçüm geçerli değil. Mikrofonu kontrol edip tekrar dene.',
  };

  @override
  Widget build(BuildContext context) {
    if (result.isSuccess) {
      return _StatusCard(
        key: const Key('feedback_success'),
        color: context.resultColors.correct,
        icon: Icons.check_circle,
        title: 'Doğru!',
        message:
            'Bu örnekte nota doğru ve kararlı. Bu, senin sesinden alınmış bir sonuç değildir.',
        scores: result.scores,
      );
    }

    // PRODUCT_SPEC.md § Animasyon ilkeleri: errors are shown as an
    // explanatory amber state, not a punitive red one.
    final primaryError = result.errors.isEmpty
        ? const ExerciseError(
            type: ExerciseErrorType.invalidSignal,
            severity: ExerciseErrorSeverity.high,
          )
        : result.errors.reduce(
            (a, b) => a.severity.index >= b.severity.index ? a : b,
          );

    return _StatusCard(
      key: Key('feedback_${primaryError.type.wireValue}'),
      color: !result.isValid
          ? context.resultColors.notMeasured
          : primaryError.type == ExerciseErrorType.wrongOctave
          ? context.resultColors.wrongOctave
          : context.resultColors.nearMiss,
      icon: Icons.info_outline,
      title: !result.isValid
          ? 'Ölçüm Alınamadı'
          : switch (primaryError.type) {
              ExerciseErrorType.wrongOctave => 'Yanlış Oktav',
              ExerciseErrorType.wrongNote => 'Yanlış Nota',
              ExerciseErrorType.unstable => 'Kararsız Ses',
              ExerciseErrorType.noise => 'Gürültü Algılandı',
              ExerciseErrorType.missingVoice => 'Ses Algılanmadı',
              ExerciseErrorType.late_ => 'Geç Kaldın',
              ExerciseErrorType.early => 'Erken Başladın',
              ExerciseErrorType.invalidSignal => 'Ölçüm Alınamadı',
            },
      message: 'Örnek açıklama: ${_errorMessages[primaryError.type]!}',
      scores: result.scores,
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.scores,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final ExerciseScores scores;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill('Simülasyon sonucu'),
            const SizedBox(height: ResoniaSpacing.sm),
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            if (!scores.hasMeasurements)
              const Text(
                'Bu örnek puanlanmadı; gelişim ortalamana eklenmez.',
                key: Key('measurement_not_scored'),
              )
            else ...[
              const Text('Örnek puanlar • kişisel sonuç değildir'),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _ScoreChip(label: 'Genel', value: scores.overall),
                  _ScoreChip(label: 'Doğruluk', value: scores.accuracy),
                  _ScoreChip(label: 'Sabitlik', value: scores.stability),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});

  final String label;
  final ScoreMetric value;

  @override
  Widget build(BuildContext context) {
    final text = switch (value.status) {
      ScoreMetricStatus.measured => '${value.value!.round()}',
      ScoreMetricStatus.notMeasured => 'Ölçülmedi',
      ScoreMetricStatus.notApplicable => 'Uygulanmaz',
    };
    return Chip(label: Text('$label: $text'));
  }
}
