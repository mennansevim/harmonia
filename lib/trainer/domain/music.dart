import 'dart:math' as math;

/// Pure music-theory vocabulary for the ear trainer. No audio, no IO.

enum NoteNotation { letter, solfege }

/// Twelve pitch classes, 0 = C/Do.
abstract final class PitchClass {
  static const letters = [
    'C',
    'C♯',
    'D',
    'E♭',
    'E',
    'F',
    'F♯',
    'G',
    'A♭',
    'A',
    'B♭',
    'B',
  ];
  static const solfege = [
    'Do',
    'Re♭',
    'Re',
    'Mi♭',
    'Mi',
    'Fa',
    'Fa♯',
    'Sol',
    'La♭',
    'La',
    'Si♭',
    'Si',
  ];
  static const whiteKeys = [0, 2, 4, 5, 7, 9, 11];
  static const blackKeys = [1, 3, 6, 8, 10];

  static String name(int pc, NoteNotation notation) {
    final i = pc % 12;
    return notation == NoteNotation.letter ? letters[i] : solfege[i];
  }

  /// "Do4"/"C4" style label for a MIDI number (C4 = 60).
  static String midiName(int midi, NoteNotation notation) =>
      '${name(midi % 12, notation)}${midi ~/ 12 - 1}';
}

double midiToHz(num midi) => 440.0 * math.pow(2, (midi - 69) / 12).toDouble();

double hzToMidi(double hz) => 69 + 12 * math.log(hz / 440) / math.ln2;

enum Register { low, medium, high }

extension RegisterOctave on Register {
  /// MIDI of the C that roots this register.
  int get rootC => switch (this) {
    Register.low => 48,
    Register.medium => 60,
    Register.high => 72,
  };
  String get label => switch (this) {
    Register.low => 'Pes',
    Register.medium => 'Orta',
    Register.high => 'Tiz',
  };
}

/// SATB choir parts with their usual spans (MIDI). Lessons are played where
/// the learner sings: lower parts hear every register one octave down.
enum VoicePart {
  soprano('Soprano', 60, 81),
  alto('Alto', 53, 74),
  tenor('Tenor', 48, 69),
  bass('Bas', 40, 64);

  const VoicePart(this.title, this.low, this.high);
  final String title;
  final int low;
  final int high;

  bool get lower => this == tenor || this == bass;

  Register fit(Register r) => !lower
      ? r
      : switch (r) {
          Register.high => Register.medium,
          _ => Register.low,
        };
}

/// [anchor] is a solfège example, [feel] a factual description.
class IntervalType {
  const IntervalType(
    this.id,
    this.semitones,
    this.name,
    this.feel,
    this.anchor,
  );
  final String id;
  final int semitones;
  final String name;
  final String feel;
  final String anchor;
}

abstract final class Intervals {
  static const all = [
    IntervalType(
      'm2',
      1,
      'Küçük 2\'li',
      'Bir yarım ses; iki komşu tuş.',
      'Mi → Fa',
    ),
    IntervalType(
      'M2',
      2,
      'Büyük 2\'li',
      'Bir tam ses; dizinin olağan adımı.',
      'Do → Re',
    ),
    IntervalType(
      'm3',
      3,
      'Küçük 3\'lü',
      'Üç yarım ses; minör akorun alt aralığı.',
      'La → Do',
    ),
    IntervalType(
      'M3',
      4,
      'Büyük 3\'lü',
      'Dört yarım ses; majör akorun alt aralığı.',
      'Do → Mi',
    ),
    IntervalType(
      'P4',
      5,
      'Tam 4\'lü',
      'Beş yarım ses; dominantdan tonik\'e çıkış.',
      'Sol → Do',
    ),
    IntervalType(
      'A4',
      6,
      'Artık 4\'lü',
      'Altı yarım ses; oktavı tam ikiye böler.',
      'Fa → Si',
    ),
    IntervalType(
      'P5',
      7,
      'Tam 5\'li',
      'Yedi yarım ses; akort ederken duyulan boşluk.',
      'Do → Sol',
    ),
    IntervalType(
      'm6',
      8,
      'Küçük 6\'lı',
      'Sekiz yarım ses; büyük 3\'lünün çevrimi.',
      'Mi → Do',
    ),
    IntervalType(
      'M6',
      9,
      'Büyük 6\'lı',
      'Dokuz yarım ses; küçük 3\'lünün çevrimi.',
      'Do → La',
    ),
    IntervalType(
      'm7',
      10,
      'Küçük 7\'li',
      'On yarım ses; dominant 7\'li akorun dış sesleri.',
      'Sol → Fa',
    ),
    IntervalType(
      'M7',
      11,
      'Büyük 7\'li',
      'On bir yarım ses; oktavın bir yarım ses altı.',
      'Do → Si',
    ),
    IntervalType(
      'P8',
      12,
      'Oktav',
      'On iki yarım ses; aynı notanın üst kopyası.',
      'Do → Do',
    ),
  ];
  static IntervalType byId(String id) => all.firstWhere((i) => i.id == id);
}

class ChordQuality {
  const ChordQuality(this.id, this.label, this.name, this.feel, this.tones);
  final String id;
  final String label;
  final String name;
  final String feel;

  /// Semitones above the root.
  final List<int> tones;
}

abstract final class Chords {
  static const all = [
    ChordQuality(
      'maj',
      'maj',
      'Majör üçlü',
      'Kök, büyük 3\'lü, tam 5\'li (Do-Mi-Sol).',
      [0, 4, 7],
    ),
    ChordQuality(
      'min',
      'min',
      'Minör üçlü',
      'Kök, küçük 3\'lü, tam 5\'li (La-Do-Mi).',
      [0, 3, 7],
    ),
    ChordQuality(
      'dim',
      'dim',
      'Eksik üçlü',
      'Üst üste iki küçük 3\'lü (Si-Re-Fa).',
      [0, 3, 6],
    ),
    ChordQuality(
      'aug',
      'aug',
      'Artık üçlü',
      'Üst üste iki büyük 3\'lü (Do-Mi-Sol♯).',
      [0, 4, 8],
    ),
    ChordQuality(
      'maj7',
      'maj7',
      'Majör 7\'li',
      'Majör üçlü ve büyük 7\'li (Do-Mi-Sol-Si).',
      [0, 4, 7, 11],
    ),
    ChordQuality(
      'min7',
      'min7',
      'Minör 7\'li',
      'Minör üçlü ve küçük 7\'li (Re-Fa-La-Do).',
      [0, 3, 7, 10],
    ),
    ChordQuality(
      'dom7',
      'dom7',
      'Dominant 7\'li',
      'Majör üçlü ve küçük 7\'li (Sol-Si-Re-Fa).',
      [0, 4, 7, 10],
    ),
    ChordQuality(
      'hdim7',
      'hdim7',
      'Yarım eksik 7\'li',
      'Eksik üçlü ve küçük 7\'li (Si-Re-Fa-La).',
      [0, 3, 6, 10],
    ),
    ChordQuality(
      'dim7',
      'dim7',
      'Eksik 7\'li',
      'Dört küçük 3\'lü; sesler eşit aralıklı.',
      [0, 3, 6, 9],
    ),
  ];
  static ChordQuality byId(String id) => all.firstWhere((c) => c.id == id);
}

class ScaleType {
  const ScaleType(this.id, this.name, this.feel, this.steps, {this.color});
  final String id;
  final String name;
  final String feel;

  /// Semitones above the root, ascending, without the octave.
  final List<int> steps;

  /// Index into [steps] of the characteristic "color note", if any.
  final int? color;
}

abstract final class Scales {
  static const all = [
    ScaleType('major', 'Majör', 'T T Y T T T Y · Do\'dan beyaz tuşlar.', [
      0,
      2,
      4,
      5,
      7,
      9,
      11,
    ]),
    ScaleType(
      'natural_minor',
      'Doğal minör',
      'T Y T T Y T T · La\'dan beyaz tuşlar.',
      [0, 2, 3, 5, 7, 8, 10],
      color: 2,
    ),
    ScaleType(
      'harmonic_minor',
      'Armonik minör',
      'Doğal minör, 7. derece yarım ses tiz.',
      [0, 2, 3, 5, 7, 8, 11],
      color: 6,
    ),
    ScaleType(
      'melodic_minor',
      'Melodik minör',
      'Doğal minör, 6. ve 7. derece tiz.',
      [0, 2, 3, 5, 7, 9, 11],
      color: 5,
    ),
    ScaleType('dorian', 'Dorian', 'T Y T T T Y T · Re\'den beyaz tuşlar.', [
      0,
      2,
      3,
      5,
      7,
      9,
      10,
    ], color: 5),
    ScaleType('phrygian', 'Frigyen', 'Y T T T Y T T · Mi\'den beyaz tuşlar.', [
      0,
      1,
      3,
      5,
      7,
      8,
      10,
    ], color: 1),
    ScaleType('lydian', 'Lidyen', 'T T T Y T T Y · Fa\'dan beyaz tuşlar.', [
      0,
      2,
      4,
      6,
      7,
      9,
      11,
    ], color: 3),
    ScaleType(
      'mixolydian',
      'Miksolidyen',
      'T T Y T T Y T · Sol\'den beyaz tuşlar.',
      [0, 2, 4, 5, 7, 9, 10],
      color: 6,
    ),
    ScaleType(
      'pentatonic_major',
      'Majör pentatonik',
      'Majörden 4. ve 7. derece çıkarılmış beş ses.',
      [0, 2, 4, 7, 9],
    ),
    ScaleType(
      'pentatonic_minor',
      'Minör pentatonik',
      'Minörden 2. ve 6. derece çıkarılmış beş ses.',
      [0, 3, 5, 7, 10],
    ),
    ScaleType('blues', 'Blues', 'Minör pentatonik ve artık 4\'lü.', [
      0,
      3,
      5,
      6,
      7,
      10,
    ], color: 3),
  ];
  static ScaleType byId(String id) => all.firstWhere((s) => s.id == id);
}

class Progression {
  const Progression(this.id, this.label, this.minor, this.chords, this.feel);
  final String id;
  final String label;
  final bool minor;

  /// (scale degree root semitone offset, chord quality id)
  final List<(int, String)> chords;
  final String feel;
}

abstract final class Progressions {
  static const all = [
    Progression('I-IV-V-I', 'I-IV-V-I', false, [
      (0, 'maj'),
      (5, 'maj'),
      (7, 'maj'),
      (0, 'maj'),
    ], 'Tonik, alt dominant, dominant, tonik.'),
    Progression('I-V-vi-IV', 'I-V-vi-IV', false, [
      (0, 'maj'),
      (7, 'maj'),
      (9, 'min'),
      (5, 'maj'),
    ], 'Dominanttan 6. derecenin minörüne iner.'),
    Progression('I-vi-IV-V', 'I-vi-IV-V', false, [
      (0, 'maj'),
      (9, 'min'),
      (5, 'maj'),
      (7, 'maj'),
    ], 'Tonikten 6. dereceye, sonra kadansa.'),
    Progression(
      'I-iii-IV-V',
      'I-iii-IV-V',
      false,
      [(0, 'maj'), (4, 'min'), (5, 'maj'), (7, 'maj')],
      '3. derece üzerinden basamak basamak yükselir.',
    ),
    Progression('vi-IV-I-V', 'vi-IV-I-V', false, [
      (9, 'min'),
      (5, 'maj'),
      (0, 'maj'),
      (7, 'maj'),
    ], '6. derecenin minörüyle başlar.'),
    Progression('i-VI-III-VII', 'i-VI-III-VII', true, [
      (0, 'min'),
      (8, 'maj'),
      (3, 'maj'),
      (10, 'maj'),
    ], 'Minör tonikten majör akorlara iner.'),
    Progression('i-iv-i-V', 'i-iv-i-V', true, [
      (0, 'min'),
      (5, 'min'),
      (0, 'min'),
      (7, 'maj'),
    ], 'Minör kadans; majör dominant tonik\'e çeker.'),
    Progression('ii-V-I', 'ii-V-I', false, [
      (2, 'min7'),
      (7, 'dom7'),
      (0, 'maj7'),
    ], '2. derece, dominant 7\'li, majör 7\'li tonik.'),
    Progression('I-IV-I-V', 'I-IV-I-V', false, [
      (0, 'maj'),
      (5, 'maj'),
      (0, 'maj'),
      (7, 'maj'),
    ], 'Tonik ile alt dominant arasında gidip gelir.'),
  ];
  static Progression byId(String id) => all.firstWhere((p) => p.id == id);
}
