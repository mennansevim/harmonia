import '../../infrastructure/audio/isolate_recording_pitch_worker.dart';
import '../../infrastructure/audio/just_audio_clip_player.dart';
import '../../infrastructure/audio/plugin_audio_lab_backend.dart';
import 'trainer_pitch_sing_session.dart';

/// Production composition only. Construction does not request permission,
/// start playback or open the microphone; those remain explicit UI actions.
TrainerPitchSingSession createMobileTrainerPitchSingSession(
  TrainerPitchSingTarget target,
) => TrainerPitchSingSession(
  target: target,
  capture: PluginAudioLabBackend(),
  referencePlayer: JustAudioClipPlayer(),
  worker: IsolateRecordingPitchWorker(),
);
