import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/application/melody_practice.dart';
import 'package:resonia/application/melody_session.dart';
import 'package:resonia/domain/audio/pitch_deviation.dart';
import 'package:resonia/domain/audio/yin_pitch_frame_analyzer.dart';
import 'package:resonia/infrastructure/audio/pcm16_wav.dart';
import 'package:resonia/infrastructure/audio/synthetic_melody_backend.dart';

DiagnosticMelodyReference reference(List<double> frequencies) =>
    DiagnosticMelodyReference(
      id: 'synthetic-practice',
      contentVersion: 'test-1',
      frequenciesHz: frequencies,
    );

void main() {
  test('selection stays bound to original identity and raw note order', () {
    final original = [220.0, 440.0, 330.0, 660.0, 220.0];
    final r = reference(original);
    final practice = DiagnosticMelodyPractice(
      reference: r,
      startIndex: 1,
      endIndexExclusive: 4,
      repetitions: 2,
    );
    original[1] = 880;
    expect(practice.reference, same(r));
    expect(practice.reference.id, 'synthetic-practice');
    expect(practice.frequenciesHz, [440, 330, 660]);
    expect(practice.noteCount, 3);
    expect(() => practice.frequenciesHz[0] = 880, throwsUnsupportedError);
  });

  test('invalid range is rejected instead of clamped or reordered', () {
    final r = reference([220, 440, 330]);
    for (final range in [(-1, 2), (0, 0), (2, 1), (0, 4), (3, 4)]) {
      expect(
        () => DiagnosticMelodyPractice(
          reference: r,
          startIndex: range.$1,
          endIndexExclusive: range.$2,
        ),
        throwsArgumentError,
      );
    }
  });

  test('repetitions are explicitly bounded to one through three', () {
    final r = reference([220, 440, 330]);
    for (final count in [-1, 0, 4, 1000000]) {
      expect(
        () => DiagnosticMelodyPractice(
          reference: r,
          startIndex: 0,
          endIndexExclusive: 3,
          repetitions: count,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'one-note and last-note selection are valid practice, not assessment',
    () {
      final practice = DiagnosticMelodyPractice(
        reference: reference([220, 440, 330]),
        startIndex: 2,
        endIndexExclusive: 3,
      );
      expect(practice.frequenciesHz, [330]);
      expect(practice.durationMs, 1000);
      final wav = renderDiagnosticMelodyPractice(practice, sampleRateHz: 8000);
      expect(wav.samples.length, 8000);
      expect(wav.samples.skip(4800), everyElement(0));
    },
  );

  test('full selection preserves original diagnostic WAV exactly', () {
    for (final count in [3, 4, 5]) {
      final r = reference(
        <double>[220, 440, 330, 660, 220].take(count).toList(),
      );
      final practice = DiagnosticMelodyPractice(
        reference: r,
        startIndex: 0,
        endIndexExclusive: count,
      );
      final expected = <double>[];
      for (var i = 0; i < count; i++) {
        expected.addAll(
          Pcm16Wav.tone(
            frequencyHz: r.frequenciesHz[i],
            sampleRateHz: 8000,
            durationSeconds: 0.6,
          ).samples,
        );
        expected.addAll(List.filled(i == count - 1 ? 3200 : 1600, 0.0));
      }
      expect(
        renderDiagnosticMelodyPractice(practice, sampleRateHz: 8000).samples,
        orderedEquals(expected),
      );
      expect(
        renderDiagnosticMelody(r, sampleRateHz: 8000).samples,
        orderedEquals(expected),
      );
    }
  });

  test(
    'repeated excerpt preserves frequency, octave, order and exact rests',
    () {
      final practice = DiagnosticMelodyPractice(
        reference: reference([220, 440, 330, 660, 220]),
        startIndex: 1,
        endIndexExclusive: 4,
        repetitions: 3,
      );
      for (final rate in [8000, 16000, 48000]) {
        final decoded = Pcm16Wav.decode(
          renderDiagnosticMelodyPractice(practice, sampleRateHz: rate).encode(),
        );
        expect(decoded.samples.length, practice.durationMs * rate ~/ 1000);
        final detector = YinPitchFrameAnalyzer();
        final window = detector.recommendedFrameSamples(rate);
        var onsetMs = 0;
        for (var repeat = 0; repeat < 3; repeat++) {
          for (var note = 0; note < 3; note++) {
            final start = (onsetMs + 100) * rate ~/ 1000;
            final pitch = detector.analyze(
              decoded.samples.sublist(start, start + window),
              sampleRateHz: rate,
            );
            expect(pitch.status, PitchFrameStatus.pitched);
            expect(
              PitchDeviation(
                detectedHz: pitch.frequencyHz!,
                targetHz: practice.frequenciesHz[note],
              ).absoluteCents,
              lessThan(15),
            );
            final gapMs = note < 2
                ? 200
                : repeat < 2
                ? 1000
                : 400;
            final gapStart = (onsetMs + 600) * rate ~/ 1000;
            final gapEnd = (onsetMs + 600 + gapMs) * rate ~/ 1000;
            expect(decoded.samples.sublist(gapStart, gapEnd), everyElement(0));
            onsetMs += 600 + gapMs;
          }
        }
        expect(onsetMs, practice.durationMs);
        expect(
          decoded.samples.every((s) => s.isFinite && s.abs() <= 0.25),
          isTrue,
        );
      }
    },
  );

  test('maximum five-note three-repeat PCM is bounded and deterministic', () {
    final practice = DiagnosticMelodyPractice(
      reference: reference([220, 440, 330, 660, 220]),
      startIndex: 0,
      endIndexExclusive: 5,
      repetitions: 3,
    );
    expect(practice.durationMs, 13800);
    final wav = renderDiagnosticMelodyPractice(practice);
    expect(wav.samples.length, 662400);
    expect(
      wav.encode(),
      orderedEquals(renderDiagnosticMelodyPractice(practice).encode()),
    );
  });

  test('unsupported sample rate is rejected without hidden resampling', () {
    final practice = DiagnosticMelodyPractice(
      reference: reference([220, 440, 330]),
      startIndex: 0,
      endIndexExclusive: 2,
    );
    for (final rate in [0, 7999, 48001, 192000]) {
      expect(
        () => renderDiagnosticMelodyPractice(practice, sampleRateHz: rate),
        throwsArgumentError,
      );
    }
  });
}
