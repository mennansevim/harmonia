import 'dart:math' as math;

import '../../domain/lang.dart';
import '../domain/music.dart';

/// One short echo melody as semitone steps from its first-degree tonic.
class EchoMelody {
  const EchoMelody(this.id, this.steps, this._name, this._nameEn);
  final String id;
  final List<int> steps;
  final String _name, _nameEn;
  String get name => tr(_name, _nameEn);
  int get lowest => steps.reduce(math.min);
  int get highest => steps.reduce(math.max);
}

class EchoLevel {
  const EchoLevel(this._title, this._titleEn, this.melodies);
  final String _title, _titleEn;
  final List<EchoMelody> melodies;
  String get title => tr(_title, _titleEn);
}

/// Easy to hard: note count first, then leap size and colour. Every melody
/// keeps the 3–5 note limit of the diagnostic reference and spans at most an
/// octave so it fits any measured practice range.
const echoLevels = <EchoLevel>[
  EchoLevel('Üç ses, adım adım', 'Three notes, step by step', [
    EchoMelody('l1-up', [0, 2, 4], 'Çıkış', 'Rising'),
    EchoMelody('l1-down', [4, 2, 0], 'İniş', 'Falling'),
    EchoMelody('l1-turn', [0, 2, 0], 'Komşu ses', 'Neighbour note'),
    EchoMelody('l1-upper', [4, 5, 4], 'Üst komşu', 'Upper neighbour'),
    EchoMelody('l1-valley', [2, 0, 2], 'Vadi', 'Valley'),
  ]),
  EchoLevel('Üç ses, küçük atlama', 'Three notes, small leaps', [
    EchoMelody('l2-arp-up', [0, 4, 7], 'Çıkan arpej', 'Rising arpeggio'),
    EchoMelody('l2-arp-down', [7, 4, 0], 'İnen arpej', 'Falling arpeggio'),
    EchoMelody('l2-fourth', [0, 5, 4], 'Dörtlü ve dönüş', 'Fourth and back'),
    EchoMelody('l2-minor', [0, 3, 5], 'Minör renk', 'Minor colour'),
    EchoMelody('l2-fall', [7, 5, 0], 'Yukarıdan düşüş', 'Drop from above'),
  ]),
  EchoLevel('Dört ses, adım adım', 'Four notes, step by step', [
    EchoMelody('l3-climb', [0, 2, 4, 5], 'Merdiven', 'Staircase'),
    EchoMelody(
      'l3-descent',
      [5, 4, 2, 0],
      'Merdivenden iniş',
      'Down the stairs',
    ),
    EchoMelody('l3-wave', [0, 2, 4, 2], 'Dalga', 'Wave'),
    EchoMelody('l3-leading', [0, -1, 0, 2], 'Yeden ses', 'Leading tone'),
    EchoMelody('l3-minor', [2, 3, 5, 3], 'Minör dalga', 'Minor wave'),
  ]),
  EchoLevel('Dört ses, atlamalı', 'Four notes with leaps', [
    EchoMelody('l4-arch', [0, 4, 7, 4], 'Kemer', 'Arch'),
    EchoMelody('l4-fifth', [0, 7, 5, 4], 'Beşli ve iniş', 'Fifth and down'),
    EchoMelody('l4-skip', [7, 0, 4, 2], 'Uzak atlama', 'Wide skip'),
    EchoMelody('l4-minor', [0, 3, 7, 5], 'Minör arpej', 'Minor arpeggio'),
    EchoMelody('l4-sixth', [0, 5, 9, 7], 'Altılı', 'Sixth'),
  ]),
  EchoLevel('Beş ses, akan ezgi', 'Five notes, flowing', [
    EchoMelody('l5-scale', [0, 2, 4, 5, 7], 'Beşli dizi', 'Five-note scale'),
    EchoMelody('l5-back', [7, 5, 4, 2, 0], 'Diziden iniş', 'Scale down'),
    EchoMelody('l5-hill', [0, 2, 4, 2, 0], 'Tepe', 'Hill'),
    EchoMelody('l5-zigzag', [0, 4, 2, 5, 4], 'Zikzak', 'Zigzag'),
    EchoMelody('l5-minor', [0, 2, 3, 5, 7], 'Minör dizi', 'Minor scale'),
  ]),
  EchoLevel('Beş ses, geniş ve renkli', 'Five notes, wide and colourful', [
    EchoMelody('l6-leaps', [0, 7, 5, 9, 7], 'Geniş atlamalar', 'Wide leaps'),
    EchoMelody('l6-aug', [0, 1, 4, 5, 4], 'Artık ikili', 'Augmented second'),
    EchoMelody('l6-octave', [0, 4, 7, 12, 7], 'Oktav tepesi', 'Octave peak'),
    EchoMelody(
      'l6-fall',
      [12, 7, 4, 5, 0],
      'Oktavdan iniş',
      'Down from the octave',
    ),
    EchoMelody('l6-seventh', [0, 3, 7, 10, 7], 'Minör yedili', 'Minor seventh'),
  ]),
];

/// The sung notes of [melody] placed inside [low]..[high] (MIDI), with the
/// tonic nudged by [shift] semitones when the range allows it, so a repeated
/// shape comes back in another key. Kept within 82–1047 Hz (E2–C6).
List<int> placeMelody(EchoMelody melody, int low, int high, {int shift = 0}) {
  final lo = math.max(40, low + 2), hi = math.min(84, high - 2);
  final minTonic = lo - melody.lowest, maxTonic = hi - melody.highest;
  final centre = ((lo + hi) / 2 - (melody.lowest + melody.highest) / 2).round();
  final tonic = minTonic > maxTonic
      ? centre
      : (centre + shift).clamp(minTonic, maxTonic);
  return [for (final s in melody.steps) tonic + s];
}

/// The learner's practice range: the measured range test if any, else the
/// chosen choir part, else a neutral middle range.
(int, int) echoRange(String? koroRange, VoicePart? part) {
  final r = koroRange?.split('-').map(int.tryParse).toList();
  if (r != null && r.length == 2 && r[0] != null && r[1] != null) {
    if (r[1]! - r[0]! >= 9) return (r[0]!, r[1]!);
  }
  if (part != null) return (part.low, part.high);
  return (53, 69);
}

/// A melody of [level], never the same id twice in a row.
EchoMelody pickEchoMelody(math.Random random, int level, {String? after}) {
  final pool = echoLevels[level.clamp(0, echoLevels.length - 1)].melodies
      .where((m) => m.id != after)
      .toList();
  return pool[random.nextInt(pool.length)];
}
