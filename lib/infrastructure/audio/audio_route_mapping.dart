// audio_session marks AudioDeviceType experimental; the mapping is pinned by
// tests and must be re-checked on every audio_session upgrade.
// ignore_for_file: experimental_member_use

import 'package:audio_session/audio_session.dart';

import '../../domain/audio/capture_quality.dart';

AudioRouteKind audioRouteKindOf(AudioDeviceType type) => switch (type) {
  AudioDeviceType.builtInEarpiece ||
  AudioDeviceType.builtInSpeaker ||
  AudioDeviceType.builtInSpeakerSafe ||
  AudioDeviceType.builtInMic => AudioRouteKind.builtIn,
  AudioDeviceType.wiredHeadset ||
  AudioDeviceType.wiredHeadphones ||
  AudioDeviceType.headsetMic ||
  AudioDeviceType.lineAnalog => AudioRouteKind.wired,
  AudioDeviceType.bluetoothSco ||
  AudioDeviceType.bluetoothA2dp ||
  AudioDeviceType.bluetoothLe ||
  AudioDeviceType.hearingAid => AudioRouteKind.bluetooth,
  AudioDeviceType.usbAudio => AudioRouteKind.usb,
  AudioDeviceType.airPlay => AudioRouteKind.airPlay,
  _ => AudioRouteKind.unknown,
};

/// iOS `currentRoute` lists the active ports (`activeRouteReported`), Android
/// only the available ones, so Android snapshots are always `inferred`.
/// Several external kinds on one side are ambiguous and map to unknown.
AudioRouteSnapshot routeFromDevices(
  Iterable<AudioDevice> devices, {
  required bool activeRouteReported,
}) {
  AudioRouteKind pick(Iterable<AudioDevice> side) {
    // Android lists system ports (telephony, remote submix, bus…); they are
    // ignored rather than poisoning the route, but never chosen either.
    final kinds = {for (final d in side) audioRouteKindOf(d.type)}
      ..remove(AudioRouteKind.unknown);
    if (kinds.isEmpty) return AudioRouteKind.unknown;
    final external = kinds.difference({AudioRouteKind.builtIn});
    if (external.length > 1) return AudioRouteKind.unknown;
    return external.isEmpty ? AudioRouteKind.builtIn : external.single;
  }

  final input = pick(devices.where((d) => d.isInput));
  final output = pick(devices.where((d) => d.isOutput));
  if (input == AudioRouteKind.unknown && output == AudioRouteKind.unknown) {
    return const AudioRouteSnapshot.unknown();
  }
  return AudioRouteSnapshot(
    input: input,
    output: output,
    certainty: activeRouteReported
        ? RouteCertainty.reported
        : RouteCertainty.inferred,
  );
}
