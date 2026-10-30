// ignore_for_file: experimental_member_use
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/infrastructure/audio/audio_route_mapping.dart';

AudioDevice _d(
  AudioDeviceType type, {
  bool input = false,
  bool output = false,
}) => AudioDevice(
  id: '${type.name}-$input-$output',
  name: type.name,
  isInput: input,
  isOutput: output,
  type: type,
);

void main() {
  test('iOS active built-in route is reported speaker + mic', () {
    final r = routeFromDevices([
      _d(AudioDeviceType.builtInMic, input: true),
      _d(AudioDeviceType.builtInSpeaker, output: true),
    ], activeRouteReported: true);
    expect(r.input, AudioRouteKind.builtIn);
    expect(r.output, AudioRouteKind.builtIn);
    expect(r.certainty, RouteCertainty.reported);
    expect(
      RoutePolicy.assess(r, CapturePurpose.pitchResponse),
      RouteDecision.sequentialOnly,
    );
  });

  test('external output wins over built-in; Android is only inferred', () {
    final r = routeFromDevices([
      _d(AudioDeviceType.builtInMic, input: true),
      _d(AudioDeviceType.builtInSpeaker, output: true),
      _d(AudioDeviceType.wiredHeadphones, output: true),
      _d(AudioDeviceType.telephony, output: true),
    ], activeRouteReported: false);
    expect(r.output, AudioRouteKind.wired);
    expect(r.certainty, RouteCertainty.inferred);
    expect(
      RoutePolicy.assess(r, CapturePurpose.pitchResponse),
      RouteDecision.unverified,
    );
  });

  test('two external outputs are ambiguous; empty list is unknown', () {
    final r = routeFromDevices([
      _d(AudioDeviceType.builtInMic, input: true),
      _d(AudioDeviceType.wiredHeadphones, output: true),
      _d(AudioDeviceType.bluetoothA2dp, output: true),
    ], activeRouteReported: true);
    expect(r.output, AudioRouteKind.unknown);
    expect(
      routeFromDevices(const [], activeRouteReported: true).certainty,
      RouteCertainty.unknown,
    );
  });

  test('device type mapping covers bluetooth, usb and airplay', () {
    expect(
      audioRouteKindOf(AudioDeviceType.bluetoothSco),
      AudioRouteKind.bluetooth,
    );
    expect(
      audioRouteKindOf(AudioDeviceType.bluetoothLe),
      AudioRouteKind.bluetooth,
    );
    expect(audioRouteKindOf(AudioDeviceType.usbAudio), AudioRouteKind.usb);
    expect(audioRouteKindOf(AudioDeviceType.airPlay), AudioRouteKind.airPlay);
    expect(audioRouteKindOf(AudioDeviceType.hdmi), AudioRouteKind.unknown);
  });
}
