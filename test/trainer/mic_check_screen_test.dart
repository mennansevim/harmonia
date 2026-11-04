import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/mic_check_session.dart';
import 'package:resonia/application/microphone_permission_recovery.dart';
import 'package:resonia/domain/audio/audio_capture.dart';
import 'package:resonia/domain/audio/mic_check.dart';
import 'package:resonia/trainer/app/scope.dart';
import 'package:resonia/trainer/audio/trainer_audio.dart';
import 'package:resonia/trainer/prepare/mic_check_screen.dart';
import 'package:resonia/trainer/state/trainer_store.dart';
import 'package:resonia/trainer/ui/kit.dart';

import '../support/fake_audio_lab_backend.dart';
import '../support/visible_text_contrast.dart';

const _rate = 16000;

List<double> _noise(double seconds, {double rms = 0.001}) {
  var state = 29;
  final amp = rms * math.sqrt(3);
  return List.generate((seconds * _rate).round(), (_) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return amp * (state / 0x7fffffff * 2 - 1);
  });
}

List<double> _voice(double amplitude, {double seconds = 1.5}) => [
  ..._noise(0.3),
  ...List.generate(
    (_rate * seconds).round(),
    (i) =>
        (amplitude * math.sin(2 * math.pi * 220 * i / _rate)).clamp(-1.0, 1.0),
  ),
];

/// Serves one queued clip per recording (silence first, then the voice).
class _QueuedBackend extends FakeRoutedAudioLabBackend {
  _QueuedBackend(this.clips);
  final List<List<double>> clips;

  @override
  Future<CapturedAudio> stopCapture() {
    if (clips.isNotEmpty) nextClip(clips.removeAt(0));
    return super.stopCapture();
  }
}

class _Recovery implements MicrophonePermissionRecovery {
  int opens = 0;
  @override
  Future<bool> openAppSettings() async {
    opens++;
    return true;
  }
}

class _Host extends StatelessWidget {
  const _Host({required this.screen});
  final MicCheckScreen screen;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        key: const Key('open'),
        onPressed: () async {
          final status = await Navigator.of(
            context,
          ).push<MicCheckStatus?>(MaterialPageRoute(builder: (_) => screen));
          popped.add(status);
        },
        child: const Text('open'),
      ),
    ),
  );
}

final popped = <MicCheckStatus?>[];

Future<_QueuedBackend> _open(
  WidgetTester tester,
  List<List<double>> clips, {
  bool permission = true,
  _Recovery? recovery,
}) async {
  final backend = _QueuedBackend(clips)..permission = permission;
  final store = TrainerStore(MemoryTrainerPersistence());
  await store.load();
  await tester.pumpWidget(
    TrainerScope(
      store: store,
      audio: TrainerAudio.silent(),
      liveAudio: false,
      child: MaterialApp(
        home: _Host(
          screen: MicCheckScreen(
            recovery: recovery,
            controllerFactory: () => MicCheckController(
              backend: backend,
              silenceDuration: const Duration(milliseconds: 5),
              getReadyDuration: const Duration(milliseconds: 5),
              voiceDuration: const Duration(milliseconds: 5),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  return backend;
}

Future<void> _run(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('mic_check_start')));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

String _status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('mic_check_status'))).data!;

void main() {
  setUp(popped.clear);

  testWidgets('quiet room and clear voice is ready, unscored', (tester) async {
    final backend = await _open(tester, [_noise(2), _voice(0.2)]);
    expect(backend.calls, isEmpty, reason: 'microphone opens only on tap');
    expect(_status(tester), 'Hazır olduğunda başlat');

    await _run(tester);
    expect(find.byKey(const Key('mic_check_result_ready')), findsOneWidget);
    expect(_status(tester), 'Hazır');
    expect(find.byKey(const Key('mic_check_not_counted')), findsNothing);
    expect(find.byKey(const Key('mic_check_details')), findsOneWidget);
    expect(find.textContaining('ayrışma:'), findsOneWidget);
    expect(find.textContaining('Puan değil'), findsOneWidget);
    // Two recordings, each read once and discarded (ADR-003).
    expect(backend.calls.where((c) => c == 'start').length, 2);
    expect(backend.calls.where((c) => c == 'read').length, 2);
    expect(backend.calls.where((c) => c == 'discard').length, 2);
    expect(backend.capturing, isFalse);

    await tester.tap(find.byKey(const Key('mic_check_done')));
    await tester.pumpAndSettle();
    expect(popped, [MicCheckStatus.ready]);
    await tester.pump();
    expect(backend.calls, contains('close'));
  });

  testWidgets('a noisy room stops after the silence step', (tester) async {
    final backend = await _open(tester, [_noise(2, rms: 0.02), _voice(0.2)]);
    await _run(tester);
    expect(find.byKey(const Key('mic_check_result_noisyRoom')), findsOneWidget);
    expect(_status(tester), 'Ortam gürültülü');
    expect(find.text('Sayılmadı · puan değil'), findsOneWidget);
    expect(find.textContaining('sessiz bir odaya'), findsOneWidget);
    expect(backend.calls.where((c) => c == 'start').length, 1);
    expect(find.byKey(const Key('mic_check_start')), findsOneWidget);
  });

  testWidgets('a weak voice is too quiet, not a failure', (tester) async {
    await _open(tester, [_noise(2), _voice(0.006)]);
    await _run(tester);
    expect(find.byKey(const Key('mic_check_result_tooQuiet')), findsOneWidget);
    expect(_status(tester), 'Ses çok kısık');
    expect(find.text('Sayılmadı · puan değil'), findsOneWidget);
    expect(find.textContaining('yaklaştır'), findsOneWidget);
  });

  testWidgets('a clipping voice is reported as too loud', (tester) async {
    await _open(tester, [_noise(2), _voice(4)]);
    await _run(tester);
    expect(find.byKey(const Key('mic_check_result_tooLoud')), findsOneWidget);
    expect(_status(tester), 'Ses çok yüksek · kırpılıyor');
    expect(find.textContaining('uzaklaştır'), findsOneWidget);
  });

  testWidgets('talking during the silence is not measured', (tester) async {
    await _open(tester, [
      [..._noise(1.5), ..._voice(0.2, seconds: 0.5)],
    ]);
    await _run(tester);
    expect(
      find.byKey(const Key('mic_check_result_notMeasured')),
      findsOneWidget,
    );
    expect(find.textContaining('Sessiz kalma sırasında'), findsOneWidget);
    expect(find.text('Sayılmadı · puan değil'), findsOneWidget);
  });

  testWidgets('denied permission is neutral and skippable', (tester) async {
    final recovery = _Recovery();
    final backend = await _open(
      tester,
      [_noise(2)],
      permission: false,
      recovery: recovery,
    );
    await _run(tester);
    expect(
      find.byKey(const Key('mic_check_result_permissionDenied')),
      findsOneWidget,
    );
    expect(_status(tester), 'Mikrofon izni yok');
    expect(backend.calls, ['permission']);
    expect(find.byKey(const Key('mic_check_details')), findsNothing);

    await tester.tap(find.byKey(const Key('mic_check_settings')));
    await tester.pumpAndSettle();
    expect(recovery.opens, 1);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(popped, [MicCheckStatus.permissionDenied]);
  });

  testWidgets('a recorder failure is not measured, never ready', (
    tester,
  ) async {
    final backend = await _open(tester, [_noise(2)]);
    backend.stopFailure = StateError('device detail');
    await _run(tester);
    expect(
      find.byKey(const Key('mic_check_result_notMeasured')),
      findsOneWidget,
    );
    expect(find.textContaining('Kayıt alınamadı'), findsOneWidget);
    expect(find.textContaining('device detail'), findsNothing);
  });

  testWidgets('stopping mid-check deletes the capture and shows no result', (
    tester,
  ) async {
    final backend = _QueuedBackend([_noise(2), _voice(0.2)]);
    final store = TrainerStore(MemoryTrainerPersistence());
    await store.load();
    await tester.pumpWidget(
      TrainerScope(
        store: store,
        audio: TrainerAudio.silent(),
        liveAudio: false,
        child: MaterialApp(
          home: MicCheckScreen(
            controllerFactory: () => MicCheckController(
              backend: backend,
              silenceDuration: const Duration(seconds: 3),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('mic_check_start')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_status(tester), 'Birkaç saniye sessiz kal');
    expect(backend.capturing, isTrue);
    await tester.tap(find.byKey(const Key('mic_check_cancel')));
    await tester.pump(const Duration(seconds: 4));
    expect(backend.capturing, isFalse);
    expect(backend.calls, contains('discard'));
    expect(find.byKey(const Key('mic_check_start')), findsOneWidget);
    expect(find.byKey(const Key('mic_check_not_counted')), findsNothing);
    expect(find.byKey(const Key('mic_check_result_ready')), findsNothing);
  });

  testWidgets('without live audio the check is unavailable, not failed', (
    tester,
  ) async {
    final store = TrainerStore(MemoryTrainerPersistence());
    await store.load();
    await tester.pumpWidget(
      TrainerScope(
        store: store,
        audio: TrainerAudio.silent(),
        liveAudio: false,
        child: const MaterialApp(home: MicCheckScreen()),
      ),
    );
    await tester.tap(find.byKey(const Key('mic_check_start')));
    await tester.pumpAndSettle();
    expect(_status(tester), 'Bu cihazda başlatılamadı');
    final start = tester.widget<BigButton>(
      find.byKey(const Key('mic_check_start')),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('every result state meets tap, label and contrast rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final cases = <String, (List<List<double>>, bool)>{
      'idle': (<List<double>>[], true),
      'ready': ([_noise(2), _voice(0.2)], true),
      'noisyRoom': ([_noise(2, rms: 0.02)], true),
      'tooQuiet': ([_noise(2), _voice(0.006)], true),
      'tooLoud': ([_noise(2), _voice(4)], true),
      'notMeasured': (
        [
          [..._noise(1.5), ..._voice(0.2)],
        ],
        true,
      ),
      'permissionDenied': (<List<double>>[], false),
    };
    final failed = <String>[];
    for (final MapEntry(key: name, value: (clips, allowed)) in cases.entries) {
      // A fresh navigator per state; the previous check closes on dispose.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await _open(tester, clips, permission: allowed);
      if (name != 'idle') {
        await _run(tester);
        expect(find.byKey(Key('mic_check_result_$name')), findsOneWidget);
      }
      // The shared kit TopBar back button is 44 pt (iOS minimum); the
      // Android 48 dp rule is a separate kit-wide follow-up.
      for (final (label, g) in [
        ('iostap', iOSTapTargetGuideline),
        ('label', labeledTapTargetGuideline),
        ('contrast', const VisibleTextContrastGuideline()),
      ]) {
        final e = await g.evaluate(tester);
        if (!e.passed) failed.add('$name $label: ${e.reason}');
      }
    }
    expect(failed, isEmpty);
    semantics.dispose();
  });
}
