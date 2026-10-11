/// Evidence, absent measurement, and inapplicability are distinct states.
enum ScoreMetricStatus { measured, notMeasured, notApplicable }

extension ScoreMetricStatusJson on ScoreMetricStatus {
  String get wireValue => switch (this) {
    ScoreMetricStatus.measured => 'measured',
    ScoreMetricStatus.notMeasured => 'not_measured',
    ScoreMetricStatus.notApplicable => 'not_applicable',
  };
}

class ScoreMetric {
  const ScoreMetric._(this.status, this.value);

  factory ScoreMetric.measured(double value) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw ArgumentError.value(
        value,
        'value',
        'Expected a finite 0–100 score',
      );
    }
    return ScoreMetric._(ScoreMetricStatus.measured, value);
  }

  const ScoreMetric.notMeasured() : this._(ScoreMetricStatus.notMeasured, null);
  const ScoreMetric.notApplicable()
    : this._(ScoreMetricStatus.notApplicable, null);

  final ScoreMetricStatus status;
  final double? value;
  bool get isMeasured => status == ScoreMetricStatus.measured;

  Map<String, Object?> toJson() => {'status': status.wireValue, 'value': value};
}
