import '../application/chord_reference_session.dart';
import '../application/chord_response_attempt_coordinator.dart';
import '../application/chord_response_capture_session.dart';
import '../application/chord_response_diagnostic_analyzer.dart';
import '../domain/audio/audio_capture.dart';
import '../domain/audio/pitch_sequence_alignment.dart';
import '../domain/audio/recording_pitch_analyzer.dart';
import '../domain/models/exercise.dart';
import '../domain/models/exercise_protocol.dart';
import '../infrastructure/audio/reviewed_chord_recording_loader.dart';
import 'chord_reference_session_composer.dart';

typedef ChordCaptureBackendFactory = Future<AudioLabBackend> Function();
typedef ChordPitchWorkerFactory = RecordingPitchWorker Function();

/// Builds one fully owned, reviewed chord attempt without starting any IO.
///
/// The caller must have obtained [loaded] from the reviewed manifest/loader
/// boundary. Construction never requests permission, plays audio, opens the
/// microphone, persists a result or changes placeholder availability.
class ChordDiagnosticAttemptComposer {
  const ChordDiagnosticAttemptComposer({
    required this.createPlayer,
    required this.createBackend,
    required this.createWorker,
  });

  final ChordReferencePlayerFactory createPlayer;
  final ChordCaptureBackendFactory createBackend;
  final ChordPitchWorkerFactory createWorker;

  Future<ChordResponseAttemptCoordinator> create({
    required LoadedChordRecording loaded,
    Duration recallDelay = const Duration(milliseconds: 650),
    ExerciseMode mode = ExerciseMode.learning,
    int maxReferencePlays = 1,
    ResponseOrder responseOrder = ResponseOrder.exact,
    Duration maxResponseDuration = const Duration(seconds: 10),
    Duration calibrationDuration = const Duration(seconds: 2),
    double toleranceCents = PitchSequenceAligner.defaultToleranceCents,
    ChordRecallDelay? wait,
    DateTime Function()? clock,
  }) async {
    final bytes = loaded.bytes;
    ChordReferenceSession.validateInput(
      wavBytes: bytes,
      recallDelay: recallDelay,
      mode: mode,
      maxReferencePlays: maxReferencePlays,
    );
    if (maxResponseDuration <= Duration.zero ||
        maxResponseDuration > const Duration(seconds: 10) ||
        calibrationDuration < const Duration(milliseconds: 1500) ||
        calibrationDuration > const Duration(seconds: 5) ||
        !toleranceCents.isFinite ||
        toleranceCents < 0 ||
        toleranceCents > 100) {
      throw ArgumentError('Invalid chord diagnostic attempt configuration');
    }

    ChordReferenceSession? reference;
    AudioLabBackend? backend;
    ChordResponseCaptureSession? capture;
    try {
      reference =
          await ChordReferenceSessionComposer(
            createPlayer: createPlayer,
          ).create(
            loaded: loaded,
            recallDelay: recallDelay,
            mode: mode,
            maxReferencePlays: maxReferencePlays,
            wait: wait,
          );
      backend = await createBackend();
      if (backend is! AudioRecordingReader) {
        throw StateError('Chord capture backend cannot read owned PCM');
      }
      capture = ChordResponseCaptureSession(
        reference: reference,
        backend: backend,
        maxResponseDuration: maxResponseDuration,
        calibrationDuration: calibrationDuration,
        wait: wait,
        clock: clock,
      );
      final worker = createWorker();
      return ChordResponseAttemptCoordinator(
        session: capture,
        analyzer: ChordResponseDiagnosticAnalyzer(worker: worker, clock: clock),
        responseOrder: responseOrder,
        toleranceCents: toleranceCents,
      );
    } catch (_) {
      if (capture != null) {
        await _ignoreCleanupFailure(capture.close);
      } else {
        if (backend != null) await _ignoreCleanupFailure(backend.close);
        if (reference != null) await _ignoreCleanupFailure(reference.close);
      }
      rethrow;
    }
  }
}

Future<void> _ignoreCleanupFailure(Future<void> Function() cleanup) async {
  try {
    await cleanup();
  } catch (_) {
    // Keep the construction error as the actionable failure.
  }
}
