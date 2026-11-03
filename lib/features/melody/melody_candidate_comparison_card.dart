import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/audio/pitch_sequence_alignment.dart';
import '../../domain/lang.dart';

/// Explains symbolic melody alignment without turning candidate frequencies
/// into a learner score, a verified note result or melody-memory evidence.
class MelodyCandidateComparisonCard extends StatelessWidget {
  const MelodyCandidateComparisonCard({required this.evidence, super.key});

  final PitchSequenceEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final steps = evidence.steps;
    return Card(
      key: const Key('melody_candidate_comparison'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Aday karşılaştırması', 'Candidate comparison'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              evidence.status == PitchSequenceStatus.aligned
                  ? tr(
                      'Referans sırası ile bulunan frekans bölümleri sembolik olarak yan yana getirildi. Bu, nota doğruluğu veya ezgi hafızası puanı değildir.',
                      'The reference order and the frequency segments found are set side by side symbolically. This is not a note accuracy or melody memory score.',
                    )
                  : tr(
                      'Frekans bölümleri güvenle karşılaştırılamadı. Bu, öğrenci hatası veya sıfır puan değildir.',
                      'The frequency segments could not be compared reliably. This is not a student mistake or a zero score.',
                    ),
            ),
            if (evidence.status == PitchSequenceStatus.aligned) ...[
              const SizedBox(height: ResoniaSpacing.sm),
              Text(
                tr(
                  '${steps.length} karşılaştırma adımı · ±${evidence.toleranceCents.toStringAsFixed(0)} sent aday toleransı',
                  '${steps.length} comparison steps · ±${evidence.toleranceCents.toStringAsFixed(0)} cent candidate tolerance',
                ),
              ),
              const SizedBox(height: ResoniaSpacing.sm),
              for (var index = 0; index < steps.length; index++)
                _CandidateStepRow(index: index, step: steps[index]),
            ],
            const SizedBox(height: ResoniaSpacing.sm),
            Text(
              tr(
                'Bölümleme ve insan sesi doğrulaması bekliyor; bu bilgi geçmişe, başarıya veya sıralamaya yazılmaz.',
                'Segmentation and human voice validation are pending; this is not written to history, success or ranking.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateStepRow extends StatelessWidget {
  const _CandidateStepRow({required this.index, required this.step});

  final int index;
  final PitchSequenceStep step;

  @override
  Widget build(BuildContext context) {
    final description = _description(step);
    return Semantics(
      label: tr(
        '${index + 1}. aday karşılaştırma adımı: $description',
        'Candidate comparison step ${index + 1}: $description',
      ),
      child: Padding(
        key: Key('melody_candidate_step_$index'),
        padding: const EdgeInsets.symmetric(vertical: ResoniaSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon(step.kind), size: 20),
            const SizedBox(width: ResoniaSpacing.sm),
            Expanded(child: Text('${index + 1}. $description')),
          ],
        ),
      ),
    );
  }
}

String _description(PitchSequenceStep step) {
  final reference = step.referenceIndex == null
      ? null
      : tr(
          '${step.referenceIndex! + 1}. referans',
          'reference ${step.referenceIndex! + 1}',
        );
  final response = step.responseIndex == null
      ? null
      : tr(
          '${step.responseIndex! + 1}. aday bölüm',
          'candidate segment ${step.responseIndex! + 1}',
        );
  return switch (step.kind) {
    PitchSequenceStepKind.correct => tr(
      '$reference ile $response tolerans içinde yakın görünüyor.',
      '$reference and $response look close, within tolerance.',
    ),
    PitchSequenceStepKind.wrongPitch => tr(
      '$reference ile $response arasında farklı perde adayı görüldü.',
      'A different pitch candidate was seen between $reference and $response.',
    ),
    PitchSequenceStepKind.wrongOctave => tr(
      '$reference ile $response arasında oktav farkı adayı görüldü.',
      'An octave difference candidate was seen between $reference and $response.',
    ),
    PitchSequenceStepKind.missing => tr(
      '$reference için eşleşen frekans bölümü adayı bulunamadı.',
      'No matching frequency segment candidate was found for $reference.',
    ),
    PitchSequenceStepKind.extra => tr(
      '$response için eşleşen referans adayı bulunamadı.',
      'No matching reference candidate was found for $response.',
    ),
  };
}

IconData _icon(PitchSequenceStepKind kind) => switch (kind) {
  PitchSequenceStepKind.correct => Icons.radio_button_checked_rounded,
  PitchSequenceStepKind.wrongPitch => Icons.multiline_chart_rounded,
  PitchSequenceStepKind.wrongOctave => Icons.swap_vert_rounded,
  PitchSequenceStepKind.missing => Icons.remove_circle_outline_rounded,
  PitchSequenceStepKind.extra => Icons.add_circle_outline_rounded,
};
