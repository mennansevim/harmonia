enum FixtureSource { synthetic, humanRecording, instrumentRecording }

enum FixturePartition { development, holdout }

enum FixtureSignal { tone, voice, instrument, silence, noise }

/// Metadata gate; the infrastructure loader separately checks file/hash/header.
/// Opaque subjectGroup identifies a speaker/session without storing their name.
class AudioFixture {
  AudioFixture({
    required this.id,
    required this.source,
    required this.partition,
    required this.signal,
    required this.sampleRateHz,
    required this.sampleCount,
    required this.sha256,
    required this.rightsReference,
    this.consentReference,
    this.subjectGroup,
    List<double> expectedFrequenciesHz = const [],
    this.a4Hz = 440,
  }) : expectedFrequenciesHz = List.unmodifiable(expectedFrequenciesHz) {
    if (id.trim().isEmpty ||
        rightsReference.trim().isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        sampleRateHz < 8000 ||
        sampleRateHz > 192000 ||
        sampleCount < 0 ||
        sampleCount > sampleRateHz * 120 ||
        !a4Hz.isFinite ||
        a4Hz <= 0 ||
        expectedFrequenciesHz.any(
          (f) => !f.isFinite || f <= 0 || f >= sampleRateHz / 2,
        )) {
      throw ArgumentError('Invalid fixture metadata');
    }
    if (source == FixtureSource.humanRecording &&
        ((consentReference?.trim().isEmpty ?? true) ||
            (subjectGroup?.trim().isEmpty ?? true))) {
      throw ArgumentError(
        'Human recordings require consent and an opaque group',
      );
    }
    if (source == FixtureSource.synthetic &&
        (partition == FixturePartition.holdout ||
            signal == FixtureSignal.voice ||
            signal == FixtureSignal.instrument)) {
      throw ArgumentError(
        'Synthetic audio cannot represent a real voice/device holdout',
      );
    }
    if (source == FixtureSource.instrumentRecording &&
        signal == FixtureSignal.voice) {
      throw ArgumentError('Instrument is not human voice');
    }
    if ((signal == FixtureSignal.silence || signal == FixtureSignal.noise) &&
        expectedFrequenciesHz.isNotEmpty) {
      throw ArgumentError('Unvoiced fixture cannot assert a pitch target');
    }
  }
  final String id, sha256, rightsReference;
  final String? consentReference, subjectGroup;
  final FixtureSource source;
  final FixturePartition partition;
  final FixtureSignal signal;
  final int sampleRateHz, sampleCount;
  final double a4Hz;
  final List<double> expectedFrequenciesHz;

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.name,
    'partition': partition.name,
    'signal': signal.name,
    'sampleRateHz': sampleRateHz,
    'sampleCount': sampleCount,
    'sha256': sha256,
    'rightsReference': rightsReference,
    'consentReference': consentReference,
    'subjectGroup': subjectGroup,
    'expectedFrequenciesHz': expectedFrequenciesHz,
    'a4Hz': a4Hz,
  };

  factory AudioFixture.fromJson(Map<String, Object?> json) {
    try {
      return AudioFixture(
        id: json['id'] as String,
        source: FixtureSource.values.byName(json['source'] as String),
        partition: FixturePartition.values.byName(json['partition'] as String),
        signal: FixtureSignal.values.byName(json['signal'] as String),
        sampleRateHz: json['sampleRateHz'] as int,
        sampleCount: json['sampleCount'] as int,
        sha256: json['sha256'] as String,
        rightsReference: json['rightsReference'] as String,
        consentReference: json['consentReference'] as String?,
        subjectGroup: json['subjectGroup'] as String?,
        expectedFrequenciesHz: (json['expectedFrequenciesHz'] as List)
            .map((f) => (f as num).toDouble())
            .toList(),
        a4Hz: (json['a4Hz'] as num).toDouble(),
      );
    } on TypeError {
      throw const FormatException('Malformed fixture fields');
    } on ArgumentError {
      throw const FormatException('Invalid fixture metadata');
    }
  }

  static void validateManifest(List<AudioFixture> fixtures) {
    final ids = <String>{};
    final hashes = <String>{};
    final groups = <String, FixturePartition>{};
    for (final fixture in fixtures) {
      if (!ids.add(fixture.id) || !hashes.add(fixture.sha256)) {
        throw ArgumentError('Duplicate fixture identity/content');
      }
      final group = fixture.subjectGroup;
      if (group == null) continue;
      final previous = groups[group];
      if (previous != null && previous != fixture.partition) {
        throw ArgumentError('Subject leaks across development and holdout');
      }
      groups[group] = fixture.partition;
    }
  }
}
