import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/audio/pitch_segmenter.dart';
import '../../domain/audio/pitch_sequence_alignment.dart';
import '../../domain/audio/recording_pitch_analyzer.dart';
import '../../domain/audio/yin_pitch_frame_analyzer.dart';
import '../../domain/lang.dart';

/// How one pitched frame relates to the reference note its candidate segment
/// was aligned with. Display only: never a score, note result or success.
enum RibbonTone { withinTolerance, outsideTolerance, octaveApart, unmatched }

/// One analysis frame, reduced to what the ribbon draws.
class RibbonFrame {
  const RibbonFrame({
    required this.startSample,
    required this.sampleCount,
    required this.status,
    this.frequencyHz,
    this.rmsDb,
  });
  final int startSample, sampleCount;
  final PitchFrameStatus status;
  final double? frequencyHz, rmsDb;
}

class RibbonPoint {
  const RibbonPoint(this.seconds, this.midi, this.level, this.tone, this.cents);
  final double seconds, midi, level;
  final RibbonTone tone;

  /// Raw distance to the aligned reference, never folded into one octave.
  final double? cents;
}

/// A reference note drawn behind the candidate segment it was aligned with.
/// Its time span is the segment's window estimate, not a measured onset.
class RibbonBand {
  const RibbonBand({
    required this.startSeconds,
    required this.endSeconds,
    required this.midi,
    required this.referenceIndex,
    required this.kind,
  });
  final double startSeconds, endSeconds, midi;
  final int referenceIndex;
  final PitchSequenceStepKind kind;
}

/// "Ghost ribbon" (design 1): the aligned reference notes become ghost bands
/// with the aligner's own tolerance, and the recorded pitch frames are drawn
/// through them. Built only from existing diagnostic evidence.
class GhostRibbonData {
  const GhostRibbonData._({
    required this.runs,
    required this.bands,
    required this.toleranceCents,
    required this.durationSeconds,
    required this.lowMidi,
    required this.highMidi,
  });

  /// Continuous pitched stretches; silence and unpitched frames are gaps.
  final List<List<RibbonPoint>> runs;
  final List<RibbonBand> bands;
  final double toleranceCents, durationSeconds, lowMidi, highMidi;

  /// Same evidence rebuilt by a parent rebuild must not restart the drawing.
  bool sameShape(GhostRibbonData other) =>
      other.durationSeconds == durationSeconds &&
      other.bands.length == bands.length &&
      other.runs.length == runs.length &&
      other.count(RibbonTone.withinTolerance) ==
          count(RibbonTone.withinTolerance) &&
      other.count(RibbonTone.outsideTolerance) ==
          count(RibbonTone.outsideTolerance);

  int count(RibbonTone tone) =>
      runs.fold(0, (sum, run) => sum + run.where((p) => p.tone == tone).length);

  static GhostRibbonData? fromEvidence({
    required List<double> referenceHz,
    required RecordingPitchEvidence recording,
    required PitchSegmentationEvidence segments,
    required PitchSequenceEvidence alignment,
  }) => build(
    referenceHz: referenceHz,
    sampleRateHz: recording.sampleRateHz,
    sampleCount: recording.sampleCount,
    frames: [
      for (final f in recording.frames)
        RibbonFrame(
          startSample: f.startSample,
          sampleCount: f.sampleCount,
          status: f.estimate.status,
          frequencyHz: f.estimate.frequencyHz,
          rmsDb: f.estimate.rmsDb,
        ),
    ],
    segments: segments,
    alignment: alignment,
  );

  /// Null when there is nothing honest to draw: no aligned candidates, no
  /// pitched frame, or frames that do not belong to [segments].
  static GhostRibbonData? build({
    required List<double> referenceHz,
    required int sampleRateHz,
    required int sampleCount,
    required List<RibbonFrame> frames,
    required PitchSegmentationEvidence segments,
    required PitchSequenceEvidence alignment,
  }) {
    if (alignment.status != PitchSequenceStatus.aligned ||
        segments.status != PitchSegmentationStatus.candidatesObserved ||
        sampleRateHz <= 0 ||
        sampleCount <= 0 ||
        referenceHz.isEmpty) {
      return null;
    }
    double secondsAt(int sample) => sample / sampleRateHz;

    final stepForSegment = <int, PitchSequenceStep>{};
    for (final step in alignment.steps) {
      final r = step.referenceIndex, s = step.responseIndex;
      if (r != null && s != null && r < referenceHz.length) {
        stepForSegment[s] = step;
      }
    }
    final segmentOfFrame = <int, int>{};
    for (var s = 0; s < segments.segments.length; s++) {
      for (final i in segments.segments[s].frameIndices) {
        if (i < 0 || i >= frames.length) return null;
        segmentOfFrame[i] = s;
      }
    }

    final bands = <RibbonBand>[
      for (final MapEntry(key: s, value: step) in stepForSegment.entries)
        if (s < segments.segments.length)
          RibbonBand(
            startSeconds: secondsAt(segments.segments[s].startSample),
            endSeconds: secondsAt(segments.segments[s].endSample),
            midi: _midi(referenceHz[step.referenceIndex!]),
            referenceIndex: step.referenceIndex!,
            kind: step.kind,
          ),
    ]..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));

    final runs = <List<RibbonPoint>>[];
    var run = <RibbonPoint>[];
    double? lastSeconds;
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      final hz = f.frequencyHz;
      final seconds = secondsAt(f.startSample + f.sampleCount ~/ 2);
      final gap =
          lastSeconds != null &&
          seconds - lastSeconds > 2.5 * f.sampleCount / sampleRateHz;
      if (f.status != PitchFrameStatus.pitched ||
          hz == null ||
          !hz.isFinite ||
          hz <= 0 ||
          gap) {
        if (run.isNotEmpty) runs.add(run);
        run = <RibbonPoint>[];
        if (f.status != PitchFrameStatus.pitched || hz == null) continue;
        if (!hz.isFinite || hz <= 0) continue;
      }
      final step = stepForSegment[segmentOfFrame[i]];
      final refHz = step == null ? null : referenceHz[step.referenceIndex!];
      final cents = refHz == null ? null : 1200 * _log2(hz / refHz);
      final tone = switch (step?.kind) {
        null ||
        PitchSequenceStepKind.missing ||
        PitchSequenceStepKind.extra => RibbonTone.unmatched,
        PitchSequenceStepKind.wrongOctave => RibbonTone.octaveApart,
        _ when cents!.abs() <= alignment.toleranceCents =>
          RibbonTone.withinTolerance,
        _ => RibbonTone.outsideTolerance,
      };
      final db = f.rmsDb;
      final level = db == null || !db.isFinite
          ? .5
          : ((db + 60) / 50).clamp(0.0, 1.0);
      run.add(RibbonPoint(seconds, _midi(hz), level, tone, cents));
      lastSeconds = seconds;
    }
    if (run.isNotEmpty) runs.add(run);
    if (runs.isEmpty) return null;

    final refMidi = referenceHz.map(_midi);
    final refLow = refMidi.reduce(math.min), refHigh = refMidi.reduce(math.max);
    var low = refLow - 2, high = refHigh + 2;
    for (final p in runs.expand((r) => r)) {
      low = math.min(low, p.midi - 1);
      high = math.max(high, p.midi + 1);
    }
    // Wildly off frames (octave candidates, glitches) are clipped at the edge
    // instead of squashing every reference row into a thin strip.
    low = math.max(low, refLow - 7);
    high = math.min(high, refHigh + 7);
    return GhostRibbonData._(
      runs: List.unmodifiable(runs.map(List<RibbonPoint>.unmodifiable)),
      bands: List.unmodifiable(bands),
      toleranceCents: alignment.toleranceCents,
      durationSeconds: secondsAt(sampleCount),
      lowMidi: low.floorToDouble(),
      highMidi: high.ceilToDouble(),
    );
  }
}

double _log2(double x) => math.log(x) / math.ln2;
double _midi(double hz) => 69 + 12 * _log2(hz / 440);

String ribbonNoteName(double midi) {
  final m = midi.round(), pc = m % 12, octave = m ~/ 12 - 1;
  const solfege = [
    'Do',
    'Do♯',
    'Re',
    'Re♯',
    'Mi',
    'Fa',
    'Fa♯',
    'Sol',
    'Sol♯',
    'La',
    'La♯',
    'Si',
  ];
  const en = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
  return '${tr(solfege[pc], en[pc])}$octave';
}

/// The ribbon's own stage colours: a fixed dark scope, so the bright trace
/// reads the same in light and dark themes.
abstract final class RibbonColors {
  static const stage = Color(0xFF1C1330);
  static const row = Color(0x08FFFFFF);
  static const rowLabel = Color(0x8AFFFFFF);
  static const reference = Color(0xFFB9A6FF);
  static const within = Color(0xFFD9F574);
  static const outside = Color(0xFFFF6259);
  static const octave = Color(0xFFFFC861);
  static const unmatched = Color(0x99FFFFFF);

  static Color of(RibbonTone tone) => switch (tone) {
    RibbonTone.withinTolerance => within,
    RibbonTone.outsideTolerance => outside,
    RibbonTone.octaveApart => octave,
    RibbonTone.unmatched => unmatched,
  };
}

class GhostRibbonView extends StatefulWidget {
  const GhostRibbonView({required this.data, super.key});
  final GhostRibbonData data;
  @override
  State<GhostRibbonView> createState() => _GhostRibbonViewState();
}

class _GhostRibbonViewState extends State<GhostRibbonView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (widget.data.durationSeconds * 400)
          .clamp(1200, 3200)
          .round(),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = 1;
    } else if (_draw.value == 0 && !_draw.isAnimating) {
      _draw.forward();
    }
  }

  @override
  void didUpdateWidget(GhostRibbonView old) {
    super.didUpdateWidget(old);
    if (!old.data.sameShape(widget.data)) _replay();
  }

  void _replay() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _draw.value = 1;
    } else {
      _draw.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final text = Theme.of(context).textTheme;
    final tol = d.toleranceCents.toStringAsFixed(0);
    final within = d.count(RibbonTone.withinTolerance),
        outside = d.count(RibbonTone.outsideTolerance),
        octave = d.count(RibbonTone.octaveApart);
    return Card(
      key: const Key('melody_ghost_ribbon'),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Perde izi', 'Pitch trace'), style: text.titleMedium),
            Text(
              tr(
                'Hayalet bantlar, eşleşen aday bölümün arkasındaki referans sesidir (±$tol sent). Deneysel; puan değil.',
                'Ghost bands are the reference note behind each matched candidate segment (±$tol cents). Experimental; not a score.',
              ),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            Semantics(
              label: tr(
                'Perde izi: ${d.bands.length} referans bandı; bant içinde $within, dışında $outside, oktav farkında $octave analiz karesi.',
                'Pitch trace: ${d.bands.length} reference bands; $within analysis frames inside the band, $outside outside, $octave an octave apart.',
              ),
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 196,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _draw,
                    builder: (context, _) => CustomPaint(
                      painter: GhostRibbonPainter(
                        data: d,
                        progress: Curves.easeOutCubic.transform(_draw.value),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            Wrap(
              spacing: ResoniaSpacing.md,
              runSpacing: ResoniaSpacing.xs,
              children: [
                _Swatch(RibbonColors.within, tr('Bant içinde', 'In band')),
                _Swatch(RibbonColors.outside, tr('Bant dışında', 'Off band')),
                if (octave > 0)
                  _Swatch(
                    RibbonColors.octave,
                    tr('Oktav farkı', 'Octave apart'),
                  ),
                _Swatch(RibbonColors.unmatched, tr('Eşleşmedi', 'Unmatched')),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('melody_ghost_replay'),
                onPressed: _replay,
                icon: const Icon(Icons.replay_rounded),
                label: Text(tr('İzi yeniden çiz', 'Redraw the trace')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: RibbonColors.stage.withValues(alpha: .4)),
        ),
      ),
      const SizedBox(width: ResoniaSpacing.xs),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

class GhostRibbonPainter extends CustomPainter {
  GhostRibbonPainter({required this.data, required this.progress});
  final GhostRibbonData data;

  /// 0 → 1: bands fade in first, then the trace draws left to right.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = RibbonColors.stage);
    const left = 44.0, right = 12.0, top = 12.0, bottom = 12.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    final span = data.highMidi - data.lowMidi;
    final semi = h / span;
    double x(double s) => left + s / data.durationSeconds * w;
    double y(double m) =>
        top + (data.highMidi - m.clamp(data.lowMidi, data.highMidi)) * semi;

    final rowPaint = Paint()..color = RibbonColors.row;
    for (var m = data.lowMidi.ceil(); m <= data.highMidi.floor(); m++) {
      if (m.isEven) {
        canvas.drawRect(Rect.fromLTWH(left, y(m + .5), w, semi), rowPaint);
      }
    }
    final labelled = <int>{};
    for (final band in data.bands) {
      if (!labelled.add(band.midi.round())) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: ribbonNoteName(band.midi),
          style: const TextStyle(
            color: RibbonColors.rowLabel,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 6);
      tp.paint(
        canvas,
        Offset(left - 6 - tp.width, y(band.midi) - tp.height / 2),
      );
    }

    final bandIn = (progress / .25).clamp(0.0, 1.0);
    final tolSemis = data.toleranceCents / 100;
    for (final band in data.bands) {
      final rect = Rect.fromLTRB(
        x(band.startSeconds),
        y(band.midi + tolSemis),
        math.max(x(band.endSeconds), x(band.startSeconds) + 2),
        y(band.midi - tolSemis),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = RibbonColors.within.withValues(alpha: .10 * bandIn),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = RibbonColors.reference.withValues(alpha: .55 * bandIn),
      );
      canvas.drawLine(
        Offset(rect.left, y(band.midi)),
        Offset(rect.right, y(band.midi)),
        Paint()
          ..strokeWidth = 1
          ..color = RibbonColors.reference.withValues(alpha: .35 * bandIn),
      );
    }

    final drawn = ((progress - .2) / .8).clamp(0.0, 1.0);
    final until = drawn * data.durationSeconds;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    RibbonPoint? head;
    for (final run in data.runs) {
      for (var i = 1; i < run.length; i++) {
        final a = run[i - 1], b = run[i];
        if (b.seconds > until) break;
        line
          ..color = RibbonColors.of(b.tone)
          ..strokeWidth = 1.5 + b.level * 3.5;
        canvas.drawLine(
          Offset(x(a.seconds), y(a.midi)),
          Offset(x(b.seconds), y(b.midi)),
          line,
        );
        head = b;
      }
      if (run.length == 1 && run.first.seconds <= until) {
        canvas.drawCircle(
          Offset(x(run.first.seconds), y(run.first.midi)),
          2,
          Paint()..color = RibbonColors.of(run.first.tone),
        );
      }
    }
    if (head != null && drawn < 1) {
      final c = Offset(x(head.seconds), y(head.midi));
      final color = RibbonColors.of(head.tone);
      canvas
        ..drawCircle(c, 9, Paint()..color = color.withValues(alpha: .25))
        ..drawCircle(c, 4.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(GhostRibbonPainter old) =>
      old.progress != progress || !identical(old.data, data);
}
