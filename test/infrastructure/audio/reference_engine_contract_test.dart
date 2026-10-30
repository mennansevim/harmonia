import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harmonia/domain/audio/audio_fixture.dart';
import 'package:harmonia/domain/audio/audio_fixture_manifest.dart';
import 'package:harmonia/domain/audio/pitch_deviation.dart';
import 'package:harmonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:harmonia/infrastructure/audio/audio_fixture_loader.dart';
import 'package:harmonia/infrastructure/audio/pcm16_wav.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('harmonia-audio-01-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<AudioFixtureEntry> writeFixture({
    required String id,
    required Pcm16Wav wav,
    required List<double> expectedFrequenciesHz,
  }) async {
    final bytes = wav.encode();
    final relativePath = '$id.wav';
    await File('${root.path}/$relativePath').writeAsBytes(bytes, flush: true);
    return AudioFixtureEntry(
      relativePath: relativePath,
      fixture: AudioFixture(
        id: id,
        source: FixtureSource.synthetic,
        partition: FixturePartition.development,
        signal: FixtureSignal.tone,
        sampleRateHz: wav.sampleRateHz,
        sampleCount: wav.samples.length,
        sha256: sha256.convert(bytes).toString(),
        rightsReference: 'generated-test-only',
        expectedFrequenciesHz: expectedFrequenciesHz,
      ),
    );
  }

  test(
    'short fixture passes file gates but cannot manufacture a pitch',
    () async {
      const rate = 16000;
      final entry = await writeFixture(
        id: 'short-a4',
        wav: Pcm16Wav(
          sampleRateHz: rate,
          samples: List.generate(
            256,
            (i) => 0.2 * math.sin(2 * math.pi * 440 * i / rate),
          ),
        ),
        expectedFrequenciesHz: const [440],
      );
      final manifest = AudioFixtureManifest([entry]);
      final loaded = await AudioFixtureLoader(
        root: root,
      ).loadManifest(manifest).single;

      expect(loaded.wav.sampleRateHz, rate);
      expect(loaded.wav.samples, hasLength(256));
      final estimate = YinPitchFrameAnalyzer().analyze(
        loaded.wav.samples,
        sampleRateHz: loaded.wav.sampleRateHz,
      );
      expect(estimate.status, PitchFrameStatus.insufficientData);
      expect(estimate.frequencyHz, isNull);
    },
  );

  test(
    'fixture clock keeps the same pitch class in separate octaves',
    () async {
      const rate = 16000;
      const c4 = 261.625565;
      const c5 = 523.251131;
      final entries = [
        await writeFixture(
          id: 'c4',
          wav: Pcm16Wav.tone(
            frequencyHz: c4,
            sampleRateHz: rate,
            durationSeconds: 0.4,
          ),
          expectedFrequenciesHz: const [c4],
        ),
        await writeFixture(
          id: 'c5',
          wav: Pcm16Wav.tone(
            frequencyHz: c5,
            sampleRateHz: rate,
            durationSeconds: 0.4,
          ),
          expectedFrequenciesHz: const [c5],
        ),
      ];
      final loaded = await AudioFixtureLoader(
        root: root,
      ).loadManifest(AudioFixtureManifest(entries)).toList();
      final analyzer = YinPitchFrameAnalyzer();
      final observed = <double>[];
      for (final fixture in loaded) {
        final frameLength = analyzer.recommendedFrameSamples(
          fixture.wav.sampleRateHz,
        );
        final estimate = analyzer.analyze(
          fixture.wav.samples.sublist(500, 500 + frameLength),
          sampleRateHz: fixture.wav.sampleRateHz,
        );
        expect(estimate.status, PitchFrameStatus.pitched);
        observed.add(estimate.frequencyHz!);
      }

      expect(
        PitchDeviation(
          detectedHz: observed[0],
          targetHz: c4,
        ).absoluteCents.abs(),
        lessThan(5),
      );
      expect(
        PitchDeviation(
          detectedHz: observed[1],
          targetHz: c5,
        ).absoluteCents.abs(),
        lessThan(5),
      );
      final octave = PitchDeviation(detectedHz: observed[1], targetHz: c4);
      expect(octave.octaveOffset, 1);
      expect(octave.absoluteCents, closeTo(1200, 5));
    },
  );
}
