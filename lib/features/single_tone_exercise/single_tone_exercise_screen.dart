import 'package:flutter/material.dart';

import '../../domain/audio/pitch_analyzer.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_result.dart';
import '../../domain/models/score_metric.dart';
import '../../domain/scoring/pitch_exercise_scorer.dart';
import '../../infrastructure/audio/mock/mock_pitch_analyzer.dart';
import '../audio_lab/audio_lab_screen.dart';
import '../chord_exercise/chord_placeholder_screen.dart';

/// The first user-facing exercise screen (PRODUCT_SPEC.md § Egzersiz
/// türleri: "Tek ses" / "Dinle ve söyle").
///
/// There is no real microphone capture yet (that lands with the real
/// [PitchAnalyzer] implementation), so this screen lets a developer/tester
/// pick which [MockPitchScenario] the mock engine should simulate — the
/// scoring and feedback code paths below are otherwise exactly what the
/// real microphone flow will drive.
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

  Future<void> _runScenario(MockPitchScenario scenario) async {
    final analyzer = widget.pitchAnalyzer;
    if (analyzer is MockPitchAnalyzer) {
      analyzer.setScenario(scenario);
    }

    setState(() => _isAnalyzing = true);

    final pitchResult = await widget.pitchAnalyzer.analyze(
      PitchAnalysisRequest(
        samples: const [],
        sampleRateHz: 44100,
        targetFrequencyHz: widget.exercise.targetNote!.frequencyHz,
      ),
    );

    final result = widget.scorer.score(
      exercise: widget.exercise,
      sessionId: widget.sessionId,
      pitch: pitchResult,
      createdAt: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.title),
        actions: [
          IconButton(
            key: const Key('open_chord_placeholders'),
            tooltip: '2 / 3 / 4 sesli örnekler',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChordPlaceholderScreen(),
              ),
            ),
          ),
          IconButton(
            key: const Key('open_audio_lab'),
            tooltip: 'Gerçek kayıt laboratuvarı',
            icon: const Icon(Icons.mic_none),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AudioLabScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TargetNoteCard(exercise: exercise),
              const SizedBox(height: 24),
              Text(
                'Mikrofon girişi henüz simüle ediliyor',
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              _ScenarioButtons(isBusy: _isAnalyzing, onSelected: _runScenario),
              const SizedBox(height: 24),
              if (_isAnalyzing)
                const Center(child: CircularProgressIndicator())
              else if (_lastResult != null)
                _FeedbackCard(result: _lastResult!),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Hedef Nota', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(target.note, style: Theme.of(context).textTheme.displayMedium),
            Text('${target.frequencyHz.toStringAsFixed(2)} Hz'),
            if (exercise.description != null) ...[
              const SizedBox(height: 12),
              Text(
                exercise.description!,
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
    MockPitchScenario.correct: 'Doğru Söyle',
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
          OutlinedButton(
            key: Key('scenario_${entry.key.name}'),
            onPressed: isBusy ? null : () => onSelected(entry.key),
            child: Text(entry.value),
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
        color: Colors.green,
        icon: Icons.check_circle,
        title: 'Doğru!',
        message: 'Notayı doğru ve kararlı söyledin.',
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
      color: Colors.amber.shade800,
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
      message: _errorMessages[primaryError.type]!,
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
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                'Bu kayıt puanlanmadı; gelişim ortalamana eklenmez.',
                key: Key('measurement_not_scored'),
              )
            else
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
