import 'package:flutter/material.dart';

import '../../../app/theme/resonia_theme.dart';
import 'resonia_ui.dart';

/// Read-only round evidence, not a claim about what the learner perceived.
/// Closed initially so the summary remains short; no playback or writes.
class AnswerComparisonCard extends StatelessWidget {
  const AnswerComparisonCard({
    super.key,
    required this.questionNumber,
    required this.reference,
    required this.selected,
    required this.correct,
    this.keyPrefix,
    this.onPlayReference,
    this.onPlaySelected,
    this.referenceLoading = false,
    this.referencePlaying = false,
    this.selectedLoading = false,
    this.selectedPlaying = false,
    this.playbackFailed = false,
  });

  final int questionNumber;
  final String reference;
  final String? selected;
  final String correct;
  final String? keyPrefix;
  final Future<void> Function()? onPlayReference;
  final Future<void> Function()? onPlaySelected;
  final bool referenceLoading;
  final bool referencePlaying;
  final bool selectedLoading;
  final bool selectedPlaying;
  final bool playbackFailed;

  @override
  Widget build(BuildContext context) {
    final status = selected == null
        ? 'Cevap yok'
        : selected == correct
        ? 'Doğru'
        : 'Farklı seçim';
    Widget field(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataLabel(label),
        const SizedBox(height: ResoniaSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
    Widget listenButton({
      required String id,
      required String idleLabel,
      required Future<void> Function()? onPlay,
      required bool loading,
      required bool playing,
    }) => OutlinedButton.icon(
      key: keyPrefix == null ? null : Key('${keyPrefix}_$id'),
      onPressed: onPlay == null ? null : () => onPlay(),
      icon: Icon(playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded),
      label: Text(
        loading
            ? 'Hazırlanıyor… · Durdur'
            : playing
            ? 'Durdur'
            : idleLabel,
      ),
    );
    return Card(
      child: ExpansionTile(
        title: Text('Soru $questionNumber · $status'),
        childrenPadding: const EdgeInsets.all(ResoniaSpacing.md),
        children: [
          field('Çalınan örnek', reference),
          if (onPlayReference != null || referenceLoading || referencePlaying)
            Padding(
              padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
              child: listenButton(
                id: 'reference',
                idleLabel: 'Örneği dinle',
                onPlay: onPlayReference,
                loading: referenceLoading,
                playing: referencePlaying,
              ),
            ),
          const SizedBox(height: ResoniaSpacing.md),
          // Wrap supports the lesson shell's intrinsic sizing. LayoutBuilder
          // here would fail when the expanded card is measured intrinsically.
          if (MediaQuery.textScalerOf(context).scale(16) > 24) ...[
            field('Senin seçimin', selected ?? 'Cevap yok'),
            const SizedBox(height: ResoniaSpacing.md),
            field('Doğru cevap', correct),
          ] else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: ResoniaSpacing.md,
                runSpacing: ResoniaSpacing.md,
                children: [
                  SizedBox(
                    width: 240,
                    child: field('Senin seçimin', selected ?? 'Cevap yok'),
                  ),
                  SizedBox(width: 240, child: field('Doğru cevap', correct)),
                ],
              ),
            ),
          if (onPlaySelected != null || selectedLoading || selectedPlaying)
            Padding(
              padding: const EdgeInsets.only(top: ResoniaSpacing.md),
              child: listenButton(
                id: 'selected',
                idleLabel: 'Seçtiğini dinle',
                onPlay: onPlaySelected,
                loading: selectedLoading,
                playing: selectedPlaying,
              ),
            ),
          if (playbackFailed)
            const Padding(
              padding: EdgeInsets.only(top: ResoniaSpacing.sm),
              child: Text(
                'Ses çalınamadı. Sonucun değişmedi; yeniden deneyebilirsin.',
              ),
            ),
        ],
      ),
    );
  }
}
