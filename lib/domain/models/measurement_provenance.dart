enum MeasurementSource { unverified, mock, synthetic, microphone }

/// Origin is not a claim of accuracy, consent, or device validation.
class MeasurementProvenance {
  const MeasurementProvenance({
    this.source = MeasurementSource.unverified,
    this.analyzerVersion = 'unknown',
  });
  final MeasurementSource source;
  final String analyzerVersion;
  Map<String, Object?> toJson() => {
    'source': source.name,
    'analyzerVersion': analyzerVersion,
  };
}
