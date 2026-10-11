import 'dart:math' as math;

import '../../domain/audio/piano_chord_reference.dart';
import 'pcm16_wav.dart';

enum PianoSampleOrigin { recordedPiano, syntheticTest }

/// Caller-declared labels/rights reference; neither tuning nor rights are
/// verified merely by constructing this object. No audio assets bundled here.
class PianoNoteSample {
  PianoNoteSample({
    required this.midiNote,
    required this.a4Hz,
    required this.wav,
    required this.assetId,
    required this.rightsReference,
    required this.origin,
  }) {
    if (midiNote < 21 ||
        midiNote > 108 ||
        !a4Hz.isFinite ||
        a4Hz < 400 ||
        a4Hz > 480 ||
        assetId.trim().isEmpty ||
        rightsReference.trim().isEmpty ||
        wav.sampleRateHz > 48000 ||
        a4Hz * math.pow(2, (midiNote - 69) / 12) >= wav.sampleRateHz / 2 ||
        wav.samples.isEmpty ||
        wav.samples.length > wav.sampleRateHz * 5) {
      throw ArgumentError('Invalid piano sample metadata/PCM budget');
    }
  }
  final int midiNote;
  final double a4Hz;
  final Pcm16Wav wav;
  final String assetId, rightsReference;
  final PianoSampleOrigin origin;
}

class RenderedPianoChord {
  RenderedPianoChord._({
    required this.wav,
    required this.audibleSampleCount,
    required this.settleSampleCount,
    required List<PianoNoteSample> sources,
  }) : sources = List.unmodifiable(sources);
  final Pcm16Wav wav;
  final int audibleSampleCount, settleSampleCount;
  final List<PianoNoteSample> sources;
  bool get isSyntheticTest =>
      sources.first.origin == PianoSampleOrigin.syntheticTest;
}

/// Preparation-only mix: one PCM/WAV clock, all notes start at sample zero.
/// No per-note players, resampling/pitch shifting or sine fallback.
/// Run off the UI isolate when preparing production assets.
class PianoChordRenderer {
  RenderedPianoChord render({
    required PianoChordReference reference,
    required List<PianoNoteSample> samples,
  }) {
    if (samples.length != reference.midiNotes.length ||
        samples.map((s) => s.midiNote).toSet().length != samples.length ||
        samples.any((s) => !reference.midiNotes.contains(s.midiNote))) {
      throw ArgumentError('Supply exactly one sample per target piano key');
    }
    final rate = samples.first.wav.sampleRateHz;
    final origin = samples.first.origin;
    if (samples.any(
      (s) =>
          s.wav.sampleRateHz != rate ||
          s.origin != origin ||
          (s.a4Hz - reference.a4Hz).abs() > 1e-6,
    )) {
      throw ArgumentError(
        'Piano samples must share actual Hz, tuning and origin',
      );
    }
    final count = (reference.durationMs * rate / 1000).round();
    final settle = (reference.settleSilenceMs * rate / 1000).round();
    // Reject too-short/silent sources, rather than hiding a missing note in the
    // chord. Frequency labels and piano timbre still require human/fixture QA.
    if (samples.any(
      (s) =>
          s.wav.samples.length < count ||
          !s.wav.samples.take(count).any((v) => v != 0),
    )) {
      throw ArgumentError(
        'Sample is too short or silent for reference duration',
      );
    }
    final ordered = [
      for (final midi in reference.midiNotes)
        samples.singleWhere((s) => s.midiNote == midi),
    ];
    final output = List<double>.filled(count + settle, 0);
    // Worst-case coherent peaks remain <=0.8 without clipping/peak-dependent
    // normalization. Preserve relative sample levels; bank balancing is QA.
    final gain = 0.8 / ordered.length;
    final fadeIn = math.max(1, (0.002 * rate).round());
    final fadeOut = math.max(1, (0.012 * rate).round());
    for (var i = 0; i < count; i++) {
      var sum = 0.0;
      for (final sample in ordered) {
        sum += sample.wav.samples[i];
      }
      final envelope = math.min(
        1.0,
        math.min(i / fadeIn, (count - 1 - i) / fadeOut),
      );
      output[i] = sum * gain * envelope;
    }
    return RenderedPianoChord._(
      wav: Pcm16Wav(sampleRateHz: rate, samples: output),
      audibleSampleCount: count,
      settleSampleCount: settle,
      sources: ordered,
    );
  }
}
