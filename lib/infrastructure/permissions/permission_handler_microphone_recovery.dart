import 'package:permission_handler/permission_handler.dart' as permissions;

import '../../application/microphone_permission_recovery.dart';

/// Production boundary for the explicit, user-initiated settings redirect.
///
/// Permission requests remain owned by the recording backend. This adapter
/// never requests microphone access and therefore cannot show an OS prompt.
final class PermissionHandlerMicrophoneRecovery
    implements MicrophonePermissionRecovery {
  const PermissionHandlerMicrophoneRecovery();

  @override
  Future<bool> openAppSettings() => permissions.openAppSettings();
}
