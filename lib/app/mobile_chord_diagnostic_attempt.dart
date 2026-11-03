import '../application/chord_response_attempt_coordinator.dart';
import '../domain/models/exercise.dart';
import '../domain/models/exercise_protocol.dart';
import '../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../infrastructure/audio/just_audio_clip_player.dart';
import '../infrastructure/audio/plugin_audio_lab_backend.dart';
import '../infrastructure/audio/reviewed_chord_recording_loader.dart';
import 'chord_diagnostic_attempt_composer.dart';

/// Mobile production composition for an already reviewed and loaded piano WAV.
///
/// Merely creating this object performs no playback, permission request,
/// capture or analysis. Product routing remains responsible for exposing only
/// manifest-reviewed recordings.
Future<ChordResponseAttemptCoordinator> createMobileChordDiagnosticAttempt({
  required LoadedChordRecording loaded,
  ExerciseMode mode = ExerciseMode.learning,
  int maxReferencePlays = 1,
  ResponseOrder responseOrder = ResponseOrder.exact,
}) =>
    ChordDiagnosticAttemptComposer(
      createPlayer: () async => JustAudioClipPlayer(),
      createBackend: () async => PluginAudioLabBackend(),
      createWorker: IsolateRecordingPitchWorker.new,
    ).create(
      loaded: loaded,
      mode: mode,
      maxReferencePlays: maxReferencePlays,
      responseOrder: responseOrder,
    );
