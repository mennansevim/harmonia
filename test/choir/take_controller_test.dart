import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/choir/audio/take_controller.dart';
import 'package:resonia/choir/audio/take_engine.dart';
import 'package:resonia/choir/audio/wav_io.dart';
import 'package:resonia/choir/domain/submission.dart';
import 'package:resonia/choir/midi/part_renderer.dart';
import 'package:resonia/domain/audio/capture_quality.dart';

class FakeCapture implements TakeCapture {
  final events = StreamController<TakeInterruption>.broadcast();
  final levels = StreamController<double>.broadcast();
  var lagMs = 100;
  var stopped = 0, cancelled = 0;
  String? vocalPath, accompanimentPath;
  Object? failStart;

  /// What the mic "heard", written on stop like a real recorder.
  Int16List recorded = Int16List(0);

  @override
  Stream<TakeInterruption> get interruptions => events.stream;
  @override
  Stream<double> get levelsDb => levels.stream;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<AudioRouteSnapshot> route() async =>
      const AudioRouteSnapshot.unknown();
  @override
  Future<int> start({
    required String vocalPath,
    String? accompanimentPath,
  }) async {
    if (failStart != null) throw failStart!;
    this.vocalPath = vocalPath;
    this.accompanimentPath = accompanimentPath;
    return lagMs;
  }

  @override
  Future<void> stop() async {
    stopped++;
    await File(vocalPath!).writeAsBytes(encodeWav(recorded, 1000));
  }

  @override
  Future<void> cancel() async => cancelled++;
  @override
  Future<void> close() async {}
}

void main() {
  late Directory dir;
  late FakeCapture capture;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('take-');
    capture = FakeCapture();
  });
  tearDown(() => dir.delete(recursive: true));

  RenderedPart part() => RenderedPart(
    samples: Int16List(3000),
    sampleRateHz: 1000,
    countInSamples: 1000,
  );

  TakeController controller({bool accompanied = true}) => TakeController(
    capture: capture,
    workDirectory: dir,
    maxSeconds: 600,
    render: accompanied ? () async => part() : null,
  );

  test('an accompanied take plays the render and joins the voice', () async {
    final take = controller();
    await take.begin();
    expect(take.phase, TakePhase.recording);
    expect(capture.accompanimentPath, isNotNull);
    expect(await File(capture.accompanimentPath!).exists(), isTrue);
    expect(take.countIn, const Duration(seconds: 1));

    capture.recorded = Int16List(3200)..[1500] = 9000;
    await take.finish();
    expect(take.phase, TakePhase.review);
    expect(take.kind, TakeKind.accompaniedMix);
    expect(capture.stopped, 1);
    final mixed = readWav(await File(take.resultPath).readAsBytes());
    expect(mixed.samples.length, 2000);
    expect(mixed.samples.indexWhere((s) => s != 0), 400);
    take.dispose();
  });

  test('alignment moves the voice and re-mixes', () async {
    final take = controller();
    await take.begin();
    capture.recorded = Int16List(3200)..[1500] = 9000;
    await take.finish();
    await take.setAlignment(150);
    expect(take.phase, TakePhase.review);
    final mixed = readWav(await File(take.resultPath).readAsBytes());
    expect(mixed.samples.indexWhere((s) => s != 0), 550);
    await take.setAlignment(9999);
    expect(take.alignmentMs, TakeController.alignmentRangeMs);
    take.dispose();
  });

  test('with no accompaniment the take is the voice itself', () async {
    final take = controller(accompanied: false);
    await take.begin();
    expect(capture.accompanimentPath, isNull);
    capture.recorded = Int16List(500)..[10] = 1;
    await take.finish();
    expect(take.kind, TakeKind.unaccompanied);
    expect(take.resultDurationMs, 500);
    take.dispose();
  });

  test('an interruption discards the take and nothing resumes', () async {
    final take = controller();
    await take.begin();
    capture.events.add(TakeInterruption.routeChanged);
    await pumpEventQueue();
    expect(take.phase, TakePhase.interrupted);
    expect(take.interruption, TakeInterruption.routeChanged);
    expect(capture.cancelled, 1);
    await take.finish();
    expect(capture.stopped, 0);
    await take.begin();
    expect(take.phase, TakePhase.recording);
    take.dispose();
  });

  test(
    'stopping before the first note is a failure, not a silent file',
    () async {
      final take = controller();
      await take.begin();
      capture.recorded = Int16List(500);
      await take.finish();
      expect(take.phase, TakePhase.failed);
      take.dispose();
    },
  );

  test('a capture that cannot start reports failure', () async {
    capture.failStart = StateError('no mic');
    final take = controller();
    await take.begin();
    expect(take.phase, TakePhase.failed);
    take.dispose();
  });

  test('leaving mid-take cancels the recorder', () async {
    final take = controller();
    await take.begin();
    take.dispose();
    await pumpEventQueue();
    expect(capture.cancelled, 1);
  });

  test('the piece ending stops the take', () async {
    late void Function() fire;
    Duration? limit;
    final take = TakeController(
      capture: capture,
      workDirectory: dir,
      maxSeconds: 600,
      render: () async => part(),
      timer: (d, f) {
        limit = d;
        fire = f;
        return Timer(const Duration(days: 1), () {});
      },
    );
    await take.begin();
    expect(limit, const Duration(seconds: 3));
    capture.recorded = Int16List(3200);
    fire();
    await pumpEventQueue(times: 200);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(take.phase, TakePhase.review);
    take.dispose();
  });
}
