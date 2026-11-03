import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/pitch_sequence_alignment.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/features/melody/melody_candidate_comparison_card.dart';

void main() {
  testWidgets('explains every candidate kind without a score claim', (
    tester,
  ) async {
    PitchSequenceEvidence evidence(double responseHz) =>
        PitchSequenceAligner.align(
          reference: const [
            SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
          ],
          response: [
            SequencePitchEvent(
              frequencyHz: responseHz,
              onsetMs: 0,
              durationMs: 100,
            ),
          ],
          source: MeasurementSource.mock,
        );
    final extra = PitchSequenceAligner.align(
      reference: const [
        SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
      ],
      response: const [
        SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
        SequencePitchEvent(frequencyHz: 330, onsetMs: 100, durationMs: 100),
      ],
      source: MeasurementSource.mock,
    );
    final missing = PitchSequenceAligner.align(
      reference: const [
        SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
        SequencePitchEvent(frequencyHz: 330, onsetMs: 100, durationMs: 100),
      ],
      response: const [
        SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
      ],
      source: MeasurementSource.mock,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                MelodyCandidateComparisonCard(evidence: evidence(220)),
                MelodyCandidateComparisonCard(evidence: evidence(440)),
                MelodyCandidateComparisonCard(evidence: evidence(300)),
                MelodyCandidateComparisonCard(evidence: extra),
                MelodyCandidateComparisonCard(evidence: missing),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Aday karşılaştırması'), findsNWidgets(5));
    expect(find.textContaining('tolerans içinde yakın'), findsWidgets);
    expect(find.textContaining('oktav farkı adayı'), findsOneWidget);
    expect(find.textContaining('farklı perde adayı'), findsOneWidget);
    expect(find.textContaining('eşleşen referans adayı'), findsOneWidget);
    expect(find.textContaining('eşleşen frekans bölümü'), findsOneWidget);
    expect(
      find.textContaining('ezgi hafızası puanı değildir'),
      findsNWidgets(5),
    );
    expect(find.textContaining('geçmişe, başarıya'), findsNWidgets(5));
    expect(find.textContaining('Başarılı'), findsNothing);
    expect(find.textContaining('puan: '), findsNothing);
  });

  testWidgets('no-response evidence stays explicitly unscored', (tester) async {
    final evidence = PitchSequenceAligner.align(
      reference: const [
        SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
      ],
      response: const [],
      source: MeasurementSource.mock,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MelodyCandidateComparisonCard(evidence: evidence)),
      ),
    );

    expect(find.textContaining('güvenle karşılaştırılamadı'), findsOneWidget);
    expect(find.textContaining('sıfır puan değildir'), findsOneWidget);
    expect(find.byKey(const Key('melody_candidate_step_0')), findsNothing);
  });
}
