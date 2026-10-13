import '../models/measurement_provenance.dart';
import 'pitch_deviation.dart';
import 'recording_pitch_analyzer.dart';
import 'yin_pitch_frame_analyzer.dart';

/// A diagnostic window, not a voice event. Private DSP types stay immutable.
class SegmentationPitchFrame {
  const SegmentationPitchFrame({
    required this.startSample,
    required this.sampleCount,
    required this.status,
    this.frequencyHz,
  });
  final int startSample, sampleCount;
  final PitchFrameStatus status;
  final double? frequencyHz;
}

enum PitchSegmentationStatus { invalidInput, noCandidates, candidatesObserved }

class DiagnosticPitchSegment {
  DiagnosticPitchSegment._({
    required this.startSample,
    required this.endSample,
    required this.frequencyHz,
    required List<int> frameIndices,
  }) : frameIndices = List.unmodifiable(frameIndices);
  final int startSample, endSample;
  final double frequencyHz;
  final List<int> frameIndices;
}

/// No VAD, note identity, duration accuracy, exercise result or memory score.
/// Boundaries are window-center estimates, not measured acoustic onsets.
class PitchSegmentationEvidence {
  PitchSegmentationEvidence._({
    required this.status,
    required this.sampleRateHz,
    required this.sampleCount,
    required this.provenance,
    required List<DiagnosticPitchSegment> segments,
    required List<int> discardedFrameIndices,
    required List<int> nonPitchedFrameIndices,
  }) : segments = List.unmodifiable(segments),
       discardedFrameIndices = List.unmodifiable(discardedFrameIndices),
       nonPitchedFrameIndices = List.unmodifiable(nonPitchedFrameIndices);
  final PitchSegmentationStatus status;
  final int sampleRateHz, sampleCount;
  final MeasurementProvenance provenance;
  final List<DiagnosticPitchSegment> segments;
  final List<int> discardedFrameIndices, nonPitchedFrameIndices;
}

/// CORE-03b experimental target-independent segmentation of periodic frames.
/// No bridging through uncertain/silent windows, no octave folding, no target
/// fitting. Short runs are explicitly retained as discarded-frame evidence.
class PitchSegmenter {
  const PitchSegmenter._();
  static const version = 'pitch-segment-diagnostic-1/defaults-1';
  static const minFrames = 3;
  static const minDurationMs = 200;
  static const maxWithinRunCents = 35.0;

  static PitchSegmentationEvidence fromRecording(
    RecordingPitchEvidence evidence,
  ) {
    if (evidence.status == RecordingPitchStatus.invalidInput) {
      return _report(
        PitchSegmentationStatus.invalidInput,
        evidence.sampleRateHz,
        evidence.sampleCount,
        evidence.provenance,
        const [],
        const [],
        const [],
      );
    }
    return segment(
      frames: [
        for (final f in evidence.frames)
          SegmentationPitchFrame(
            startSample: f.startSample,
            sampleCount: f.sampleCount,
            status: f.estimate.status,
            frequencyHz: f.estimate.frequencyHz,
          ),
      ],
      sampleRateHz: evidence.sampleRateHz,
      sampleCount: evidence.sampleCount,
      provenance: evidence.provenance,
    );
  }

  static PitchSegmentationEvidence segment({
    required List<SegmentationPitchFrame> frames,
    required int sampleRateHz,
    required int sampleCount,
    required MeasurementProvenance provenance,
  }) {
    PitchSegmentationEvidence invalid() => _report(
      PitchSegmentationStatus.invalidInput,
      sampleRateHz,
      sampleCount,
      provenance,
      const [],
      const [],
      const [],
    );
    if (sampleRateHz < 8000 ||
        sampleRateHz > 48000 ||
        sampleCount < 0 ||
        sampleCount > sampleRateHz * 10 ||
        frames.length > RecordingPitchAnalyzer.maxFrames) {
      return invalid();
    }
    final centers = <int>[];
    var previousStart = -1, previousCenter = -1;
    for (final f in frames) {
      final center = f.startSample + f.sampleCount ~/ 2;
      if (f.startSample < 0 ||
          f.startSample <= previousStart ||
          f.sampleCount < 2 ||
          f.sampleCount > YinPitchFrameAnalyzer.maxFrameSamples ||
          f.startSample + f.sampleCount > sampleCount ||
          center <= previousCenter ||
          (f.status == PitchFrameStatus.pitched &&
              (f.frequencyHz == null ||
                  !f.frequencyHz!.isFinite ||
                  f.frequencyHz! < 50 ||
                  f.frequencyHz! > 2000)) ||
          (f.status != PitchFrameStatus.pitched && f.frequencyHz != null) ||
          f.status == PitchFrameStatus.invalidInput) {
        return invalid();
      }
      centers.add(center);
      previousStart = f.startSample;
      previousCenter = center;
    }
    final segments = <DiagnosticPitchSegment>[];
    final discarded = <int>[], nonPitched = <int>[], run = <int>[];
    int boundaryAfter(int index) =>
        index + 1 < centers.length &&
            frames[index + 1].startSample <=
                frames[index].startSample + frames[index].sampleCount
        ? (centers[index] + centers[index + 1]) ~/ 2
        : centers[index];
    void flush() {
      if (run.isEmpty) return;
      // Conservative endpoints: never extend beyond the final observed center.
      final first = run.first;
      final separated =
          first == 0 ||
          frames[first].startSample >
              frames[first - 1].startSample + frames[first - 1].sampleCount;
      final start = separated
          ? centers[first]
          : (centers[first - 1] + centers[first]) ~/ 2;
      final end = boundaryAfter(run.last);
      if (run.length < minFrames ||
          (end - start) * 1000 < minDurationMs * sampleRateHz) {
        discarded.addAll(run);
      } else {
        final frequencies = [for (final i in run) frames[i].frequencyHz!]
          ..sort();
        segments.add(
          DiagnosticPitchSegment._(
            startSample: start,
            endSample: end,
            frequencyHz: frequencies[(frequencies.length - 1) ~/ 2],
            frameIndices: run,
          ),
        );
      }
      run.clear();
    }

    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      // Missing window coverage is also a hard boundary, not inferred sustain.
      final gap =
          i > 0 &&
          f.startSample > frames[i - 1].startSample + frames[i - 1].sampleCount;
      if (gap) flush();
      if (f.status != PitchFrameStatus.pitched) {
        flush();
        nonPitched.add(i);
        continue;
      }
      if (run.isNotEmpty &&
          PitchDeviation(
                detectedHz: f.frequencyHz!,
                targetHz: frames[run.first].frequencyHz!,
              ).absoluteCents.abs() >
              maxWithinRunCents) {
        flush();
      }
      run.add(i);
    }
    flush();
    return _report(
      segments.isEmpty
          ? PitchSegmentationStatus.noCandidates
          : PitchSegmentationStatus.candidatesObserved,
      sampleRateHz,
      sampleCount,
      provenance,
      segments,
      discarded,
      nonPitched,
    );
  }
}

PitchSegmentationEvidence _report(
  PitchSegmentationStatus status,
  int rate,
  int count,
  MeasurementProvenance provenance,
  List<DiagnosticPitchSegment> segments,
  List<int> discarded,
  List<int> nonPitched,
) => PitchSegmentationEvidence._(
  status: status,
  sampleRateHz: rate,
  sampleCount: count,
  provenance: MeasurementProvenance(
    source: provenance.source,
    analyzerVersion: '${provenance.analyzerVersion}/${PitchSegmenter.version}',
  ),
  segments: segments,
  discardedFrameIndices: discarded,
  nonPitchedFrameIndices: nonPitched,
);
