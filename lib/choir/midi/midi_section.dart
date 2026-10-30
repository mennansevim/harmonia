import '../domain/choir.dart';
import 'smf_reader.dart';

/// Which track is which part. Only a suggestion from the track's name, in the
/// languages choirs commonly label scores with: the conductor confirms it
/// (MIDI-02). Names that say nothing stay unmapped.
Map<int, ChoirPart> suggestTrackParts(MidiFile file) {
  final found = <int, ChoirPart>{};
  for (final track in file.tracks) {
    if (track.notes.isEmpty) continue;
    final part = _partFromName(track.name);
    if (part != null) found[track.index] = part;
  }
  return found;
}

ChoirPart? _partFromName(String? name) {
  if (name == null) return null;
  final words = name
      .toLowerCase()
      .split(RegExp(r'[^a-zçğıöşüéèàáäñ]+'))
      .where((w) => w.isNotEmpty);
  for (final word in words) {
    final part = _partWords[word];
    if (part != null) return part;
  }
  return null;
}

const _partWords = {
  's': ChoirPart.soprano,
  'sop': ChoirPart.soprano,
  'sopr': ChoirPart.soprano,
  'soprano': ChoirPart.soprano,
  'sopran': ChoirPart.soprano,
  'sopranos': ChoirPart.soprano,
  'a': ChoirPart.alto,
  'alt': ChoirPart.alto,
  'alto': ChoirPart.alto,
  'altos': ChoirPart.alto,
  'contralto': ChoirPart.alto,
  't': ChoirPart.tenor,
  'ten': ChoirPart.tenor,
  'tenor': ChoirPart.tenor,
  'tenors': ChoirPart.tenor,
  'ténor': ChoirPart.tenor,
  'tenore': ChoirPart.tenor,
  'b': ChoirPart.bass,
  'bs': ChoirPart.bass,
  'bas': ChoirPart.bass,
  'bass': ChoirPart.bass,
  'basses': ChoirPart.bass,
  'basse': ChoirPart.bass,
  'basso': ChoirPart.bass,
  'bajo': ChoirPart.bass,
};

/// The stretch of a file to play: whole measures, half-open in ticks.
class MidiSection {
  const MidiSection({
    required this.startTick,
    required this.endTick,
    required this.fromMeasure,
    required this.toMeasure,
  });

  final int startTick;
  final int endTick;
  final int fromMeasure;
  final int toMeasure;

  /// Measures [from]..[to] (1-based, both included), or the whole file when
  /// they are null. Ends past the last measure are pulled in; a range wholly
  /// outside the file throws [RangeError], since it would play silence.
  factory MidiSection.of(MidiFile file, {int? from, int? to}) {
    final starts = file.measureStarts();
    final first = from ?? 1;
    final last = to ?? starts.length;
    if (first < 1 || first > starts.length || last < first) {
      throw RangeError('Measures $first–$last are not in this file');
    }
    final end = last < starts.length ? last : starts.length;
    return MidiSection(
      startTick: starts[first - 1],
      endTick: end < starts.length ? starts[end] : file.lengthTicks,
      fromMeasure: first,
      toMeasure: end,
    );
  }
}
