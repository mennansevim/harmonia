import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/pitch_segmenter.dart';
import 'package:resonia/domain/audio/pitch_sequence_alignment.dart';
import 'package:resonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';
import 'package:resonia/features/melody/ghost_ribbon.dart';

const _rate = 16000, _size = 1024, _hop = 512;
const _reference = [261.63, 329.63, 392.0];

double _cents(double hz, double cents) => hz * math.pow(2, cents / 1200);

/// +10 ¢ on note 1, +80 ¢ on note 2, an octave above note 3; silence between.
List<RibbonFrame> _frames() {
  final hz = <double?>[
    for (var i = 0; i < 10; i++) _cents(_reference[0], 10),
    null,
    null,
    null,
    for (var i = 0; i < 10; i++) _cents(_reference[1], 80),
    null,
    null,
    null,
    for (var i = 0; i < 10; i++) _reference[2] * 2,
  ];
  return [
    for (var i = 0; i < hz.length; i++)
      RibbonFrame(
        startSample: i * _hop,
        sampleCount: _size,
        status: hz[i] == null
            ? PitchFrameStatus.silence
            : PitchFrameStatus.pitched,
        frequencyHz: hz[i],
        rmsDb: hz[i] == null ? null : -24,
      ),
  ];
}

({
  List<RibbonFrame> frames,
  int samples,
  PitchSegmentationEvidence segments,
  PitchSequenceEvidence alignment,
})
_evidence() {
  final frames = _frames();
  final samples = (frames.length - 1) * _hop + _size;
  final segments = PitchSegmenter.segment(
    frames: [
      for (final f in frames)
        SegmentationPitchFrame(
          startSample: f.startSample,
          sampleCount: f.sampleCount,
          status: f.status,
          frequencyHz: f.frequencyHz,
        ),
    ],
    sampleRateHz: _rate,
    sampleCount: samples,
    provenance: const MeasurementProvenance(source: MeasurementSource.mock),
  );
  List<SequencePitchEvent> events(List<double> hz) => [
    for (var i = 0; i < hz.length; i++)
      SequencePitchEvent(frequencyHz: hz[i], onsetMs: i * 800, durationMs: 600),
  ];
  final alignment = PitchSequenceAligner.align(
    reference: events(_reference),
    response: events([for (final s in segments.segments) s.frequencyHz]),
    source: MeasurementSource.mock,
  );
  return (
    frames: frames,
    samples: samples,
    segments: segments,
    alignment: alignment,
  );
}

GhostRibbonData _data() {
  final e = _evidence();
  return GhostRibbonData.build(
    referenceHz: _reference,
    sampleRateHz: _rate,
    sampleCount: e.samples,
    frames: e.frames,
    segments: e.segments,
    alignment: e.alignment,
  )!;
}

void main() {
  test('colours frames by raw cents to the aligned reference', () {
    final e = _evidence();
    expect(e.segments.segments, hasLength(3));
    final data = _data();
    expect(data.bands, hasLength(3));
    expect(data.runs, hasLength(3), reason: 'silence stays a gap');
    expect(data.count(RibbonTone.withinTolerance), 10);
    expect(data.count(RibbonTone.outsideTolerance), 10);
    // An octave apart is its own state, never folded into the band.
    expect(data.count(RibbonTone.octaveApart), 10);
    final octave = data.runs.last.first;
    expect(octave.cents, closeTo(1200, .5));
    expect(data.toleranceCents, PitchSequenceAligner.defaultToleranceCents);
  });

  test('draws nothing without aligned candidates', () {
    final e = _evidence();
    final none = PitchSequenceAligner.align(
      reference: const [
        SequencePitchEvent(frequencyHz: 220, onsetMs: 0, durationMs: 100),
      ],
      response: const [],
      source: MeasurementSource.mock,
    );
    expect(
      GhostRibbonData.build(
        referenceHz: _reference,
        sampleRateHz: _rate,
        sampleCount: e.samples,
        frames: e.frames,
        segments: e.segments,
        alignment: none,
      ),
      isNull,
    );
  });

  testWidgets('animates the trace and can redraw it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: GhostRibbonView(data: _data())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('melody_ghost_ribbon')), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('melody_ghost_replay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
