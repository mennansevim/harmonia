import 'dart:math' as math;

import '../../../domain/audio/pitch_analyzer.dart';
import '../../../domain/models/measurement_provenance.dart';

const _mockProvenance = MeasurementProvenance(
  source: MeasurementSource.mock,
  analyzerVersion: 'mock-pitch-1',
);

/// Scenarios the mock pitch engine can simulate.
///
/// These map directly to the states PRODUCT_SPEC.md and AI_COACH.md call
/// out as the ones the first single-tone exercise screen must show:
/// success, wrong note, wrong octave (up/down) and noise, plus two extra
/// states (`unstable`, `silence`) that the real DSP engine will also need
/// to distinguish later.
enum MockPitchScenario {
  correct,
  wrongNote,
  wrongOctaveDown,
  wrongOctaveUp,
  unstable,
  noisy,
  silence,
}

/// A stand-in for the real DSP pitch engine (ARCHITECTURE.md § Pitch
/// motoru), used until microphone capture and autocorrelation/YIN analysis
/// are implemented.
///
/// It ignores the actual audio samples in [PitchAnalysisRequest] — there is
/// no real signal yet — and instead returns a canned, deterministic
/// [PitchAnalysisResult] for whichever [MockPitchScenario] is currently
/// selected. This lets exercise screens, scoring and feedback UI be built
/// and tested against every measurement outcome before the real audio
/// engine exists.
///
/// Replace this with a real [PitchAnalyzer] implementation in Faz 1/2 once
/// microphone capture and DSP land; nothing outside this class should need
/// to change since it only depends on the [PitchAnalyzer] interface.
class MockPitchAnalyzer implements PitchAnalyzer {
  MockPitchAnalyzer({
    MockPitchScenario initialScenario = MockPitchScenario.correct,
    this.simulatedLatency = const Duration(milliseconds: 150),
  }) : _scenario = initialScenario;

  MockPitchScenario _scenario;
  final Duration simulatedLatency;

  MockPitchScenario get scenario => _scenario;

  void setScenario(MockPitchScenario scenario) => _scenario = scenario;

  @override
  Future<PitchAnalysisResult> analyze(PitchAnalysisRequest request) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }
    return _buildResult(_scenario, request.targetFrequencyHz);
  }

  PitchAnalysisResult _buildResult(
    MockPitchScenario scenario,
    double targetFrequencyHz,
  ) {
    double atCents(double cents) =>
        targetFrequencyHz * math.pow(2, cents / 1200);

    switch (scenario) {
      case MockPitchScenario.correct:
        return PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: atCents(6),
          centsDifference: 6,
          octaveOffset: 0,
          voicedRatio: 0.95,
          stabilityCents: 8,
          isNoisy: false,
        );

      case MockPitchScenario.wrongNote:
        // A full tone flat (~-200 cents), same octave: recognizably a
        // different note, not a tuning slip.
        return PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: atCents(-200),
          centsDifference: -200,
          octaveOffset: 0,
          voicedRatio: 0.9,
          stabilityCents: 10,
          isNoisy: false,
        );

      case MockPitchScenario.wrongOctaveDown:
        // Same pitch class, one octave below — must still be an error
        // (ADR-006), never a pass.
        return PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: atCents(-1200 + 4),
          centsDifference: 4,
          octaveOffset: -1,
          voicedRatio: 0.92,
          stabilityCents: 9,
          isNoisy: false,
        );

      case MockPitchScenario.wrongOctaveUp:
        return PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: atCents(1200 - 3),
          centsDifference: -3,
          octaveOffset: 1,
          voicedRatio: 0.92,
          stabilityCents: 9,
          isNoisy: false,
        );

      case MockPitchScenario.unstable:
        // Correct note on average, but wavering pitch (e.g. uncontrolled
        // vibrato) beyond the stability tolerance.
        return PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: atCents(10),
          centsDifference: 10,
          octaveOffset: 0,
          voicedRatio: 0.85,
          stabilityCents: 45,
          isNoisy: false,
        );

      case MockPitchScenario.noisy:
        // Signal present but unreliable: low voiced ratio, engine flags it
        // as noise-dominated rather than trusting the pitch estimate.
        return PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: atCents(-30),
          centsDifference: -30,
          octaveOffset: 0,
          voicedRatio: 0.3,
          stabilityCents: 60,
          isNoisy: true,
        );

      case MockPitchScenario.silence:
        // No usable voiced signal at all (e.g. user didn't sing, mic
        // muted).
        return const PitchAnalysisResult(
          provenance: _mockProvenance,
          detectedFrequencyHz: null,
          centsDifference: null,
          octaveOffset: 0,
          voicedRatio: 0.02,
          stabilityCents: 0,
          isNoisy: false,
        );
    }
  }
}
