/// Reserved prerecorded-piano folders. No file or target note is invented.
class ChordRecordingSlot {
  const ChordRecordingSlot._({required this.id, required this.voiceCount});
  final String id;
  final int voiceCount;
  String get assetDirectory => 'assets/audio/piano/chords/$voiceCount-notes/';
}

class ChordRecordingCatalog {
  ChordRecordingCatalog._(List<ChordRecordingSlot> slots)
    : slots = List.unmodifiable(slots);
  final List<ChordRecordingSlot> slots;

  /// Placeholder-only schema. A ready file needs a later reviewed asset/target
  /// manifest; setting "ready" here must NOT silently enable playback/scoring.
  factory ChordRecordingCatalog.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] is! int ||
        json['schemaVersion'] != 1 ||
        json['kind'] != 'prerecorded_piano_chords' ||
        json['slots'] is! List) {
      throw const FormatException('Unsupported chord placeholder catalog');
    }
    final rawSlots = json['slots'] as List;
    if (rawSlots.length != 3) {
      throw const FormatException('Reserve exactly 2/3/4-note folders');
    }
    final slots = <ChordRecordingSlot>[];
    final ids = <String>{};
    final counts = <int>{};
    for (final raw in rawSlots) {
      if (raw is! Map ||
          raw['id'] is! String ||
          raw['voiceCount'] is! int ||
          raw['status'] != 'awaiting_recording' ||
          !raw.containsKey('assetPath') ||
          raw['assetPath'] != null ||
          !raw.containsKey('targetMidiNotes') ||
          raw['targetMidiNotes'] != null ||
          !raw.containsKey('rightsReference') ||
          raw['rightsReference'] != null) {
        throw const FormatException('Unreviewed audio cannot be marked ready');
      }
      final id = raw['id'] as String;
      final count = raw['voiceCount'] as int;
      if (!RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(id) ||
          ![2, 3, 4].contains(count) ||
          !ids.add(id) ||
          !counts.add(count)) {
        throw const FormatException('Invalid or duplicate chord slot');
      }
      final slot = ChordRecordingSlot._(id: id, voiceCount: count);
      if (raw['assetDirectory'] != slot.assetDirectory) {
        throw const FormatException('Unexpected chord asset directory');
      }
      slots.add(slot);
    }
    slots.sort((a, b) => a.voiceCount.compareTo(b.voiceCount));
    return ChordRecordingCatalog._(slots);
  }
}

abstract class ChordRecordingCatalogRepository {
  Future<ChordRecordingCatalog> load();
}
