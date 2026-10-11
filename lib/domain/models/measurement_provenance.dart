/// `touch` = on-screen pointer timestamps (rhythm taps), never audio.
enum MeasurementSource { unverified, mock, synthetic, microphone, touch }

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

  /// Unknown sources are rejected, never upgraded to microphone.
  factory MeasurementProvenance.fromJson(Map<String, Object?> json) {
    final source = MeasurementSource.values.where(
      (s) => s.name == json['source'],
    );
    final version = json['analyzerVersion'];
    if (source.length != 1 || version is! String || version.isEmpty) {
      throw const FormatException('Invalid provenance');
    }
    return MeasurementProvenance(
      source: source.single,
      analyzerVersion: version,
    );
  }
}
