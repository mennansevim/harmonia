import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/chord_recording_catalog.dart';

Map<String, dynamic> pendingCatalog() => {
  'schemaVersion': 1,
  'kind': 'prerecorded_piano_chords',
  'slots': [
    for (final count in [4, 2, 3])
      {
        'id': 'piano-$count-voices',
        'voiceCount': count,
        'assetDirectory': 'assets/audio/piano/chords/$count-notes/',
        'status': 'awaiting_recording',
        'assetPath': null,
        'targetMidiNotes': null,
        'rightsReference': null,
      },
  ],
};

void main() {
  test(
    '2/3/4 folders are sorted immutable placeholders without invented notes',
    () {
      final json = pendingCatalog();
      final catalog = ChordRecordingCatalog.fromJson(json);
      expect(catalog.slots.map((s) => s.voiceCount), [2, 3, 4]);
      expect(
        catalog.slots.first.assetDirectory,
        'assets/audio/piano/chords/2-notes/',
      );
      (json['slots'] as List).clear();
      expect(catalog.slots.length, 3);
      expect(() => catalog.slots.clear(), throwsUnsupportedError);
    },
  );
  test('schema/cardinality/source are explicit', () {
    for (final field in {
      'schemaVersion': 2,
      'kind': 'live_piano',
      'slots': <Object>[],
    }.entries) {
      final json = pendingCatalog()..[field.key] = field.value;
      expect(() => ChordRecordingCatalog.fromJson(json), throwsFormatException);
    }
    expect(
      () => ChordRecordingCatalog.fromJson({'schemaVersion': 1.0}),
      throwsFormatException,
    );
  });
  test('a supplied path/status/label cannot silently unlock playback', () {
    for (final field in {
      'assetPath': 'example.wav',
      'status': 'ready',
      'targetMidiNotes': [60, 64],
      'rightsReference': 'unreviewed',
    }.entries) {
      final json = pendingCatalog();
      (json['slots'] as List).first[field.key] = field.value;
      expect(() => ChordRecordingCatalog.fromJson(json), throwsFormatException);
    }
  });
  test(
    'missing null markers, wrong path/count, duplicates and malformed slots fail',
    () {
      for (final field in ['assetPath', 'targetMidiNotes', 'rightsReference']) {
        final json = pendingCatalog();
        ((json['slots'] as List).first as Map).remove(field);
        expect(
          () => ChordRecordingCatalog.fromJson(json),
          throwsFormatException,
        );
      }
      for (final field in {
        'voiceCount': 5,
        'assetDirectory': '../sounds/',
        'id': '../id',
      }.entries) {
        final json = pendingCatalog();
        (json['slots'] as List).first[field.key] = field.value;
        expect(
          () => ChordRecordingCatalog.fromJson(json),
          throwsFormatException,
        );
      }
      final duplicate = pendingCatalog();
      (duplicate['slots'] as List)[1] = (duplicate['slots'] as List)[0];
      expect(
        () => ChordRecordingCatalog.fromJson(duplicate),
        throwsFormatException,
      );
      final malformed = pendingCatalog();
      malformed['slots'] = <Object?>[
        null,
        ...(malformed['slots'] as List).skip(1),
      ];
      expect(
        () => ChordRecordingCatalog.fromJson(malformed),
        throwsFormatException,
      );
    },
  );
}
