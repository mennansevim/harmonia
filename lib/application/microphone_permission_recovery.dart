/// Opens the operating-system settings page where the user can recover a
/// microphone permission that can no longer be requested in-app.
abstract interface class MicrophonePermissionRecovery {
  Future<bool> openAppSettings();
}
