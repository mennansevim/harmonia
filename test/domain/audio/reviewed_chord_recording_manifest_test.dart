import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonia/domain/audio/reviewed_chord_recording_manifest.dart';

ReviewedChordRecording recording({
  String id = 'c4-g4',
  int voiceCount = 2,
  String path = '2-notes/c4-g4.wav',
  List<int> notes = const [60, 67],
  String hashChar = 'a',
  int sampleRateHz = 48000,
  int channels = 1,
  int sampleFrames = 72000,
  double a4Hz = 440,
  String rights = 'rights/self-recorded-v1',
  String review = 'review/piano-labels-v1',
}) => ReviewedChordRecording(
  id: id,
  voiceCount: voiceCount,
  relativePath: path,
  targetMidiNotes: notes,
  sha256: hashChar * 64,
  sampleRateHz: sampleRateHz,
  channels: channels,
  sampleFrames: sampleFrames,
  a4Hz: a4Hz,
  rightsReference: rights,
  labelReviewReference: review,
);

Map<String, Object?> manifestJson() =>
    ReviewedChordRecordingManifest([recording()]).toJson();

void main() {
  test(
    'reviewed manifest round trips without enabling playback or scoring',
    () {
      final manifest = ReviewedChordRecordingManifest([
        recording(),
        recording(
          id: 'c4-e4-g4',
          voiceCount: 3,
          path: '3-notes/c4-e4-g4.wav',
          notes: [60, 64, 67],
          hashChar: 'b',
          channels: 2,
        ),
      ]);
      final restored = ReviewedChordRecordingManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, Object?>,
      );
      expect(restored.toJson(), manifest.toJson());
      expect(restored.recordings.first.durationMs, 1500);
    },
  );

  test('entries and note lists are immutable snapshots', () {
    final notes = [60, 67];
    final entries = [recording(notes: notes)];
    final manifest = ReviewedChordRecordingManifest(entries);
    notes.clear();
    entries.clear();
    expect(manifest.recordings.single.targetMidiNotes, [60, 67]);
    expect(() => manifest.recordings.clear(), throwsUnsupportedError);
    expect(
      () => manifest.recordings.single.targetMidiNotes.add(72),
      throwsUnsupportedError,
    );
  });

  test('target count, keyboard range and low-to-high order are strict', () {
    for (final notes in <List<int>>[
      [60],
      [60, 60],
      [67, 60],
      [20, 60],
      [60, 109],
      [60, 64, 67],
    ]) {
      expect(
        () => recording(notes: notes),
        throwsArgumentError,
        reason: '$notes',
      );
    }
    expect(
      () => recording(
        voiceCount: 4,
        path: '4-notes/c4-e4-g4-b4.wav',
        notes: [60, 64, 67, 71],
      ),
      returnsNormally,
    );
  });

  test('paths stay in the exact voice-count folder', () {
    for (final path in [
      '../2-notes/c4-g4.wav',
      '/2-notes/c4-g4.wav',
      '3-notes/c4-g4.wav',
      '2-notes/a/c4-g4.wav',
      '2-notes/../c4-g4.wav',
      r'2-notes\c4-g4.wav',
      '2-notes/c4-g4.mp3',
      '2-notes/%2e%2e.wav',
    ]) {
      expect(() => recording(path: path), throwsArgumentError, reason: path);
    }
  });

  test('hash, rights and independent label review references are required', () {
    for (final candidate in [
      () => recording(hashChar: 'A'),
      () => recording(rights: ''),
      () => recording(rights: 'contains spaces'),
      () => recording(review: ''),
      () => recording(review: '../review'),
    ]) {
      expect(candidate, throwsArgumentError);
    }
  });

  test('audio metadata is bounded but not treated as acoustic proof', () {
    for (final candidate in [
      () => recording(sampleRateHz: 7999),
      () => recording(sampleRateHz: 48001),
      () => recording(channels: 0),
      () => recording(channels: 3),
      () => recording(sampleFrames: 4799),
      () => recording(sampleFrames: 480001),
      () => recording(a4Hz: 399),
      () => recording(a4Hz: 481),
      () => recording(a4Hz: double.nan),
    ]) {
      expect(candidate, throwsArgumentError);
    }
  });

  test('duplicate id path or content hash is rejected case-insensitively', () {
    final base = recording();
    for (final duplicate in [
      recording(path: '2-notes/d4-a4.wav', hashChar: 'b'),
      recording(id: 'other', path: '2-notes/C4-G4.wav', hashChar: 'b'),
      recording(id: 'other', path: '2-notes/d4-a4.wav'),
    ]) {
      expect(
        () => ReviewedChordRecordingManifest([base, duplicate]),
        throwsArgumentError,
      );
    }
  });

  test('manifest version codec source and exact fields fail closed', () {
    final json = manifestJson();
    for (final override in <Map<String, Object?>>[
      {'schemaVersion': 2},
      {'schemaVersion': 1.0},
      {'kind': 'placeholder'},
      {'codec': 'aac'},
      {'source': 'generated'},
      {'extra': true},
    ]) {
      expect(
        () => ReviewedChordRecordingManifest.fromJson({...json, ...override}),
        throwsFormatException,
      );
    }
  });

  test('entry fields are exact and numeric types are not coerced', () {
    final json = manifestJson();
    final entry = (json['recordings'] as List).single as Map<String, Object?>;
    for (final override in <Map<String, Object?>>[
      {'voiceCount': 2.0},
      {
        'targetMidiNotes': ['60', 67],
      },
      {'sampleRateHz': 48000.0},
      {'channels': '1'},
      {'sampleFrames': 72000.0},
      {'a4Hz': '440'},
      {'extra': true},
    ]) {
      expect(
        () => ReviewedChordRecordingManifest.fromJson({
          ...json,
          'recordings': [
            {...entry, ...override},
          ],
        }),
        throwsFormatException,
      );
    }
  });

  test('empty and oversized manifests cannot claim reviewed content', () {
    expect(() => ReviewedChordRecordingManifest([]), throwsArgumentError);
    expect(
      () => ReviewedChordRecordingManifest(List.filled(257, recording())),
      throwsArgumentError,
    );
    expect(
      () => ReviewedChordRecordingManifest.fromJson({
        ...manifestJson(),
        'recordings': const [],
      }),
      throwsFormatException,
    );
  });
}
