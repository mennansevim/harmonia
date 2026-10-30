import 'dart:collection';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/capture_quality.dart';
import 'package:resonia/domain/audio/latency_estimator.dart';
import 'package:resonia/domain/models/measurement_provenance.dart';

const route = AudioRouteSnapshot(
  input: AudioRouteKind.builtIn,
  output: AudioRouteKind.wired,
);
final stamp = CalibrationStamp(
  route: route,
  sampleRateHz: 48000,
  measuredAt: DateTime.utc(2026, 10, 11),
);
LatencyTrial trial(
  int index,
  double offset, {
  String referenceClock = 'test_clock',
  String responseClock = 'test_clock',
  String? signature,
  int rate = 48000,
  int baseUs = 0,
}) => LatencyTrial(
  referenceTimestampUs: baseUs + index * 1000000,
  responseTimestampUs: baseUs + index * 1000000 + (offset * 1000).round(),
  referenceClockId: referenceClock,
  responseClockId: responseClock,
  routeSignature: signature ?? route.signature,
  sampleRateHz: rate,
);
List<LatencyTrial> trials(List<double> offsets) => [
  for (var i = 0; i < offsets.length; i++) trial(i, offsets[i]),
];
LatencyEstimate estimate(
  List<LatencyTrial> input, {
  CalibrationStamp? binding,
  LatencyMethod method = LatencyMethod.loopback,
  MeasurementSource source = MeasurementSource.synthetic,
  LatencyClockBasis basis = LatencyClockBasis.observedSharedClock,
}) => LatencyEstimator.estimate(
  trials: input,
  stamp: binding ?? stamp,
  method: method,
  source: source,
  clockBasis: basis,
);

class OversizeTrials extends ListBase<LatencyTrial> {
  @override
  int get length => 65;
  @override
  set length(int value) => throw StateError('Must not resize');
  @override
  LatencyTrial operator [](int index) => throw StateError('Must not traverse');
  @override
  void operator []=(int index, LatencyTrial value) =>
      throw StateError('Must not write');
}

void main() {
  test(
    'stable synthetic distribution retains source, median and no correction',
    () {
      final result = estimate(trials([99, 100, 101, 102, 98, 100, 99, 101]));
      expect(result.status, LatencyEstimateStatus.stableEstimate);
      expect(result.rawMedianMs, 100);
      expect(result.retainedMedianMs, 100);
      expect(result.rawMadMs, 1);
      expect(result.source, MeasurementSource.synthetic);
      expect(result.toJson()['correctionEnabled'], isFalse);
      expect(
        jsonDecode(jsonEncode(result.toJson()))['status'],
        'stableEstimate',
      );
    },
  );
  test('deterministic evidence for repeated input', () {
    final input = trials(List.filled(10, 120));
    expect(estimate(input).toJson(), estimate(input).toJson());
  });
  test('empty and seven trials have no estimate', () {
    for (final count in [0, 7]) {
      final result = estimate(trials(List.filled(count, 100)));
      expect(result.status, LatencyEstimateStatus.insufficientTrials);
      expect(result.retainedMedianMs, isNull);
      expect(result.retainedTrialCount, isNull);
    }
  });
  test('eight retained trials minimum after rejection', () {
    final result = estimate(trials([100, 100, 100, 100, 100, 100, 100, 150]));
    expect(result.status, LatencyEstimateStatus.unstable);
    expect(result.rejectedTrialIndices, [7]);
    expect(result.retainedMedianMs, isNull);
  });
  test('isolated outlier identified without hiding raw statistics', () {
    final result = estimate(trials([...List.filled(15, 100), 130]));
    expect(result.status, LatencyEstimateStatus.stableEstimate);
    expect(result.rejectedTrialIndices, [15]);
    expect(result.retainedTrialCount, 15);
    expect(result.rawMedianMs, 100);
  });
  test('many outliers cannot become clean calibration after trimming', () {
    final result = estimate(
      trials([...List.filled(8, 100), ...List.filled(4, 140)]),
    );
    expect(result.status, LatencyEstimateStatus.unstable);
    expect(result.rejectedTrialIndices.length, 4);
    expect(result.rawCentralSpreadMs, 40);
    expect(result.retainedMedianMs, isNull);
  });
  test('bimodal route latency is unstable', () {
    final result = estimate(
      trials([...List.filled(8, 80), ...List.filled(8, 120)]),
    );
    expect(result.status, LatencyEstimateStatus.unstable);
    expect(result.rawMadMs, 20);
  });
  test('drift is not corrected by shifting or fitting answers', () {
    final result = estimate(
      trials([for (var i = 0; i < 16; i++) 80.0 + i * 3]),
    );
    expect(result.status, LatencyEstimateStatus.unstable);
  });
  test('scheduled and unknown clocks never produce an estimate', () {
    for (final basis in [
      LatencyClockBasis.scheduledPlayback,
      LatencyClockBasis.unknown,
    ]) {
      final result = estimate(trials(List.filled(8, 100)), basis: basis);
      expect(result.status, LatencyEstimateStatus.unsupportedClock);
      expect(result.rawMedianMs, isNull);
    }
  });
  test('different clock origins are rejected', () {
    final input = [
      for (var i = 0; i < 8; i++) trial(i, 100, responseClock: 'other'),
    ];
    expect(estimate(input).status, LatencyEstimateStatus.unsupportedClock);
  });
  test('clock reset within batch is rejected', () {
    final input = trials(List.filled(8, 100))
      ..[7] = trial(7, 100, referenceClock: 'new', responseClock: 'new');
    expect(estimate(input).status, LatencyEstimateStatus.unsupportedClock);
  });
  test('empty, whitespace and oversized clock tokens rejected', () {
    for (final id in ['', 'bad clock', List.filled(65, 'x').join()]) {
      expect(
        estimate([
          for (var i = 0; i < 8; i++)
            trial(i, 100, referenceClock: id, responseClock: id),
        ]).status,
        LatencyEstimateStatus.unsupportedClock,
      );
    }
  });
  test('changed route or sample rate rejects entire batch', () {
    for (final changed in [
      trial(7, 100, signature: 'other'),
      trial(7, 100, rate: 44100),
    ]) {
      final input = trials(List.filled(8, 100))..[7] = changed;
      expect(estimate(input).status, LatencyEstimateStatus.bindingMismatch);
    }
  });
  test('unknown and inferred routes are not accepted as measured', () {
    for (final r in [
      const AudioRouteSnapshot.unknown(),
      const AudioRouteSnapshot(
        input: AudioRouteKind.builtIn,
        output: AudioRouteKind.wired,
        certainty: RouteCertainty.inferred,
      ),
    ]) {
      final result = estimate(
        trials(List.filled(8, 100)),
        binding: CalibrationStamp(
          route: r,
          sampleRateHz: 48000,
          measuredAt: stamp.measuredAt,
        ),
      );
      expect(result.status, LatencyEstimateStatus.unverifiedRoute);
    }
  });
  test('negative or over-budget late offset invalidates clean prefix', () {
    for (final offset in [-0.001, 500.001]) {
      expect(
        estimate(trials([...List.filled(8, 100), offset])).status,
        LatencyEstimateStatus.invalidInput,
      );
    }
  });
  test('zero and 500 ms are actual estimates, never missing defaults', () {
    for (final value in [0.0, 500.0]) {
      final result = estimate(trials(List.filled(8, value)));
      expect(result.status, LatencyEstimateStatus.stableEstimate);
      expect(result.retainedMedianMs, value);
      expect(result.toJson()['correctionEnabled'], isFalse);
    }
  });
  test('timestamp duplicates, reverse order and negative values rejected', () {
    final input = trials(List.filled(8, 100));
    expect(
      estimate([...input, input.last]).status,
      LatencyEstimateStatus.invalidInput,
    );
    expect(
      estimate(input.reversed.toList()).status,
      LatencyEstimateStatus.invalidInput,
    );
    expect(
      estimate([trial(-1, 100), ...input]).status,
      LatencyEstimateStatus.invalidInput,
    );
  });
  test(
    'timestamp bound prevents precision loss while large origin remains valid',
    () {
      final valid = [
        for (var i = 0; i < 8; i++) trial(i, 100, baseUs: 8000000000000000),
      ];
      expect(estimate(valid).retainedMedianMs, 100);
      expect(
        estimate([
          for (var i = 0; i < 8; i++)
            trial(i, 100, baseUs: LatencyEstimator.maxTimestampUs),
        ]).status,
        LatencyEstimateStatus.invalidInput,
      );
    },
  );
  test('budget rejected before traversing oversized list', () {
    expect(
      estimate(OversizeTrials()).status,
      LatencyEstimateStatus.invalidInput,
    );
    expect(
      estimate(trials(List.filled(64, 100))).status,
      LatencyEstimateStatus.stableEstimate,
    );
  });
  test(
    'evidence cannot be mutated through caller input or exported indices',
    () {
      final input = trials([...List.filled(15, 100), 130]);
      final result = estimate(input);
      input.clear();
      expect(result.trialCount, 16);
      expect(result.rejectedTrialIndices, [15]);
      expect(() => result.rejectedTrialIndices.add(0), throwsUnsupportedError);
    },
  );
  test(
    'tap alignment remains motor-bias diagnostic, not hardware correction',
    () {
      final result = estimate(
        trials(List.filled(8, 180)),
        method: LatencyMethod.tapAlignment,
        source: MeasurementSource.touch,
      );
      expect(result.method, LatencyMethod.tapAlignment);
      expect(result.source, MeasurementSource.touch);
      expect(result.toJson()['correctionEnabled'], isFalse);
      expect(result.retainedMedianMs, 180);
    },
  );
}
