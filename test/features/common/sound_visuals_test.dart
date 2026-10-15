import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/app/theme/harmonia_theme.dart';
import 'package:harmonia/domain/audio/audio_capture.dart';
import 'package:harmonia/features/common/input_level_meter.dart';
import 'package:harmonia/features/common/sound/playback_visual.dart';
import 'package:harmonia/features/common/sound/waveform_playback_view.dart';
import 'package:harmonia/infrastructure/audio/click_track.dart';

class _Player implements ReferenceClipPlayer {
  Completer<void> end = Completer();
  int stops = 0;
  @override
  Future<PlaybackHandle> playWav(List<int> wavBytes) async =>
      PlaybackHandle(end.future);
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> close() async {}
}

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: HarmoniaTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  ),
);

void main() {
  final pair = renderTonePair(261.63, 293.66).encode();

  test('visual is built from the real clip; bad bytes give none', () {
    final v = PlaybackVisual.fromWav(pair)!;
    expect(v.sampleRateHz, 48000);
    expect(v.duration.inMilliseconds, inInclusiveRange(1690, 1710));
    expect(v.envelope, hasLength(PlaybackVisual.envelopeBuckets));
    // Tone, silence gap, tone: the envelope shows the gap.
    expect(v.envelope.first, greaterThan(0.1));
    expect(v.envelope[(PlaybackVisual.envelopeBuckets * .42).round()], 0);
    expect(PlaybackVisual.fromWav(const [1, 2, 3]), isNull);
  });

  test('player wrapper publishes while playing, clears after', () async {
    final inner = _Player();
    final p = VisualizingClipPlayer(inner);
    final handle = await p.playWav(pair);
    expect(p.current.value, isNotNull);
    inner.end.complete();
    await handle.completed;
    await Future<void>.delayed(Duration.zero);
    expect(p.current.value, isNull);
    inner.end = Completer();
    await p.playWav(pair);
    await p.stop();
    expect(p.current.value, isNull);
    expect(inner.stops, 1);
  });

  testWidgets('waveform animates only for the clip length, then settles', (
    tester,
  ) async {
    final v = ValueNotifier<PlaybackVisual?>(null);
    await tester.pumpWidget(_host(WaveformPlaybackView(playback: v)));
    await tester.pumpAndSettle();
    v.value = PlaybackVisual.fromWav(pair);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(find.bySemanticsLabel('Ses çalıyor'), findsOneWidget);
    // Even if completion never arrives, drawing stops after the clip.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    v.value = null;
    await tester.pump();
    expect(find.bySemanticsLabel('Dinlemek için dokun'), findsOneWidget);
  });

  testWidgets('reduced motion shows a still waveform', (tester) async {
    final v = ValueNotifier<PlaybackVisual?>(null);
    await tester.pumpWidget(
      _host(WaveformPlaybackView(playback: v), reduce: true),
    );
    await tester.pumpAndSettle();
    v.value = PlaybackVisual.fromWav(pair);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.bySemanticsLabel('Ses çalıyor'), findsOneWidget);
  });

  testWidgets('voice ribbon moves only when a level arrives', (tester) async {
    final levels = StreamController<double>();
    addTearDown(levels.close);
    await tester.pumpWidget(_host(InputLevelMeter(levels: levels.stream)));
    await tester.pumpAndSettle();
    expect(find.text('Giriş seviyesi: bekleniyor'), findsOneWidget);
    levels.add(-20);
    await tester.pump();
    await tester.pump();
    expect(find.text('Giriş seviyesi: uygun'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    levels.add(-2);
    await tester.pumpAndSettle();
    expect(find.textContaining('çok yüksek'), findsOneWidget);
    expect(
      find.text('Ses düzeyini gösterir; notanın doğru olduğunu göstermez.'),
      findsOneWidget,
    );
  });
}
