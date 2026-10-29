/// Reviewed metadata for prerecorded 2/3/4-note piano references.
///
/// This contract does not validate the file bytes, musical labels, ownership,
/// or teaching suitability. It only prevents unreviewed placeholder metadata
/// from silently becoming a playable catalog.
class ReviewedChordRecording {
  ReviewedChordRecording({
    required this.id,
    required this.voiceCount,
    required this.relativePath,
    required List<int> targetMidiNotes,
    required this.sha256,
    required this.sampleRateHz,
    required this.channels,
    required this.sampleFrames,
    required this.a4Hz,
    required this.rightsReference,
    required this.labelReviewReference,
  }) : targetMidiNotes = List.unmodifiable(targetMidiNotes) {
    final expectedPrefix = '$voiceCount-notes/';
    final parts = relativePath.split('/');
    final durationMs = sampleFrames * 1000 / sampleRateHz;
    if (!_idPattern.hasMatch(id) ||
        voiceCount < 2 ||
        voiceCount > 4 ||
        targetMidiNotes.length != voiceCount ||
        targetMidiNotes.toSet().length != targetMidiNotes.length ||
        targetMidiNotes.any((note) => note < 21 || note > 108) ||
        !_strictlyAscending(targetMidiNotes) ||
        !relativePath.startsWith(expectedPrefix) ||
        !relativePath.endsWith('.wav') ||
        parts.length != 2 ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              !_pathPartPattern.hasMatch(part),
        ) ||
        !_shaPattern.hasMatch(sha256) ||
        sampleRateHz < 8000 ||
        sampleRateHz > 48000 ||
        (channels != 1 && channels != 2) ||
        sampleFrames < 1 ||
        durationMs < 100 ||
        durationMs > 10000 ||
        !a4Hz.isFinite ||
        a4Hz < 400 ||
        a4Hz > 480 ||
        !_referencePattern.hasMatch(rightsReference) ||
        !_referencePattern.hasMatch(labelReviewReference)) {
      throw ArgumentError('Invalid reviewed chord recording metadata');
    }
  }

  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
  static final _pathPartPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$');
  static final _shaPattern = RegExp(r'^[a-f0-9]{64}$');
  static final _referencePattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,255}$',
  );

  final String id;
  final int voiceCount;
  final String relativePath;
  final List<int> targetMidiNotes;
  final String sha256;
  final int sampleRateHz;
  final int channels;
  final int sampleFrames;
  final double a4Hz;
  final String rightsReference;
  final String labelReviewReference;

  double get durationMs => sampleFrames * 1000 / sampleRateHz;

  Map<String, Object?> toJson() => {
    'id': id,
    'voiceCount': voiceCount,
    'path': relativePath,
    'targetMidiNotes': targetMidiNotes,
    'sha256': sha256,
    'sampleRateHz': sampleRateHz,
    'channels': channels,
    'sampleFrames': sampleFrames,
    'a4Hz': a4Hz,
    'rightsReference': rightsReference,
    'labelReviewReference': labelReviewReference,
  };

  factory ReviewedChordRecording.fromJson(Map<String, Object?> json) {
    if (!_sameKeys(json, _entryKeys)) {
      throw const FormatException('Unexpected chord recording fields');
    }
    try {
      final notes = (json['targetMidiNotes'] as List).cast<int>();
      return ReviewedChordRecording(
        id: json['id'] as String,
        voiceCount: json['voiceCount'] as int,
        relativePath: json['path'] as String,
        targetMidiNotes: notes,
        sha256: json['sha256'] as String,
        sampleRateHz: json['sampleRateHz'] as int,
        channels: json['channels'] as int,
        sampleFrames: json['sampleFrames'] as int,
        a4Hz: (json['a4Hz'] as num).toDouble(),
        rightsReference: json['rightsReference'] as String,
        labelReviewReference: json['labelReviewReference'] as String,
      );
    } on TypeError {
      throw const FormatException('Malformed chord recording fields');
    } on ArgumentError {
      throw const FormatException('Invalid chord recording metadata');
    }
  }
}

class ReviewedChordRecordingManifest {
  ReviewedChordRecordingManifest(List<ReviewedChordRecording> recordings)
    : recordings = List.unmodifiable(recordings) {
    if (recordings.isEmpty || recordings.length > 256) {
      throw ArgumentError('Manifest requires 1–256 recordings');
    }
    final ids = <String>{};
    final paths = <String>{};
    final hashes = <String>{};
    for (final recording in recordings) {
      if (!ids.add(recording.id) ||
          !paths.add(recording.relativePath.toLowerCase()) ||
          !hashes.add(recording.sha256)) {
        throw ArgumentError('Duplicate chord recording identity/content');
      }
    }
  }

  final List<ReviewedChordRecording> recordings;

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'kind': 'reviewed_prerecorded_piano_chords',
    'codec': 'pcm_s16le_wav',
    'source': 'user_recorded_piano',
    'recordings': recordings.map((recording) => recording.toJson()).toList(),
  };

  factory ReviewedChordRecordingManifest.fromJson(Map<String, Object?> json) {
    if (!_sameKeys(json, _manifestKeys) ||
        json['schemaVersion'] is! int ||
        json['schemaVersion'] != 1 ||
        json['kind'] != 'reviewed_prerecorded_piano_chords' ||
        json['codec'] != 'pcm_s16le_wav' ||
        json['source'] != 'user_recorded_piano') {
      throw const FormatException('Unsupported reviewed chord manifest');
    }
    try {
      final raw = json['recordings'] as List;
      if (raw.isEmpty || raw.length > 256) {
        throw const FormatException('Manifest requires 1–256 recordings');
      }
      return ReviewedChordRecordingManifest([
        for (final entry in raw)
          ReviewedChordRecording.fromJson(
            (entry as Map).cast<String, Object?>(),
          ),
      ]);
    } on TypeError {
      throw const FormatException('Malformed reviewed chord manifest');
    } on ArgumentError {
      throw const FormatException('Invalid reviewed chord manifest');
    }
  }
}

const _entryKeys = {
  'id',
  'voiceCount',
  'path',
  'targetMidiNotes',
  'sha256',
  'sampleRateHz',
  'channels',
  'sampleFrames',
  'a4Hz',
  'rightsReference',
  'labelReviewReference',
};

const _manifestKeys = {
  'schemaVersion',
  'kind',
  'codec',
  'source',
  'recordings',
};

bool _sameKeys(Map<String, Object?> json, Set<String> expected) =>
    json.length == expected.length && json.keys.toSet().containsAll(expected);

bool _strictlyAscending(List<int> values) {
  for (var i = 1; i < values.length; i++) {
    if (values[i] <= values[i - 1]) return false;
  }
  return true;
}
