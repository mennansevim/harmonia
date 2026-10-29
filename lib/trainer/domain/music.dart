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

class IntervalType {
  const IntervalType(this.id, this.semitones, this.name, this.feel, this.hook);
  final String id;
  final int semitones;
  final String name;
  final String feel;
  final String hook;
}

abstract final class Intervals {
  static const all = [
    IntervalType(
      'm2',
      1,
      'Küçük 2\'li',
      'Yarım ses. Gerilimli, sürtünen.',
      'Jaws (Denizkızı) teması',
    ),
    IntervalType(
      'M2',
      2,
      'Büyük 2\'li',
      'Tam ses. Adım atar gibi.',
      '"İyi ki doğdun" girişi',
    ),
    IntervalType(
      'm3',
      3,
      'Küçük 3\'lü',
      'Hüzünlü, karanlık.',
      'Greensleeves girişi',
    ),
    IntervalType(
      'M3',
      4,
      'Büyük 3\'lü',
      'Parlak, mutlu. Majör akorun sesi.',
      '"Oh When the Saints" girişi',
    ),
    IntervalType(
      'P4',
      5,
      'Tam 4\'lü',
      'Açık, güçlü.',
      '"Here Comes the Bride" girişi',
    ),
    IntervalType(
      'A4',
      6,
      'Artık 4\'lü',
      'Triton. Kararsız, şeytani.',
      'The Simpsons teması',
    ),
    IntervalType(
      'P5',
      7,
      'Tam 5\'li',
      'Güçlü, boş. Sağlam bir sütun.',
      '"Twinkle Twinkle" ve Star Wars teması',
    ),
    IntervalType(
      'm6',
      8,
      'Küçük 6\'lı',
      'Duygusal, romantik.',
      'The Entertainer girişi',
    ),
    IntervalType(
      'M6',
      9,
      'Büyük 6\'lı',
      'Tatlı, pastoral.',
      '"My Bonnie" girişi',
    ),
    IntervalType(
      'm7',
      10,
      'Küçük 7\'li',
      'Bluesy, funky esneme.',
      'Star Trek (orijinal) teması',
    ),
    IntervalType(
      'M7',
      11,
      'Büyük 7\'li',
      'Rüya gibi, gergin esneme.',
      '"Take On Me" nakaratı',
    ),
    IntervalType(
      'P8',
      12,
      'Oktav',
      'Aynı nota, daha tiz. Saf ve açık.',
      '"Somewhere Over the Rainbow" girişi',
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
    ChordQuality('maj', 'maj', 'Majör üçlü', 'Mutlu, parlak, dengeli.', [
      0,
      4,
      7,
    ]),
    ChordQuality('min', 'min', 'Minör üçlü', 'Hüzünlü, ciddi.', [0, 3, 7]),
    ChordQuality('dim', 'dim', 'Eksik üçlü', 'Gergin, ürkütücü, kararsız.', [
      0,
      3,
      6,
    ]),
    ChordQuality('aug', 'aug', 'Artık üçlü', 'Rüya gibi, havada, çözülmemiş.', [
      0,
      4,
      8,
    ]),
    ChordQuality('maj7', 'maj7', 'Majör 7\'li', 'Caz, tatlı, nostaljik.', [
      0,
      4,
      7,
      11,
    ]),
    ChordQuality('min7', 'min7', 'Minör 7\'li', 'Yumuşak, serin, rahat.', [
      0,
      3,
      7,
      10,
    ]),
    ChordQuality(
      'dom7',
      'dom7',
      'Dominant 7\'li',
      'Bluesy, gerilimli, güçlü.',
      [0, 4, 7, 10],
    ),
    ChordQuality('hdim7', 'hdim7', 'Yarım eksik 7\'li', 'Karanlık, gizemli.', [
      0,
      3,
      6,
      10,
    ]),
    ChordQuality('dim7', 'dim7', 'Eksik 7\'li', 'Korku filmi, simetrik.', [
      0,
      3,
      6,
      9,
    ]),
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
    ScaleType('major', 'Majör', 'Parlak, mutlu, çözülmüş. Do-re-mi sesi.', [
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
      'Karanlık ve hüzünlü. Majörün üzgün hâli.',
      [0, 2, 3, 5, 7, 8, 10],
      color: 2,
    ),
    ScaleType(
      'harmonic_minor',
      'Armonik minör',
      'Yükseltilmiş 7. derece ile dramatik.',
      [0, 2, 3, 5, 7, 8, 11],
      color: 6,
    ),
    ScaleType('melodic_minor', 'Melodik minör', 'En akıcı minör dizi.', [
      0,
      2,
      3,
      5,
      7,
      9,
      11,
    ], color: 5),
    ScaleType('dorian', 'Dorian', 'Daha parlak 6. dereceli minör.', [
      0,
      2,
      3,
      5,
      7,
      9,
      10,
    ], color: 5),
    ScaleType('phrygian', 'Frigyen', 'En karanlık mod. Pes 2. derece.', [
      0,
      1,
      3,
      5,
      7,
      8,
      10,
    ], color: 1),
    ScaleType('lydian', 'Lidyen', 'Rüya gibi yükseltilmiş 4. dereceli majör.', [
      0,
      2,
      4,
      6,
      7,
      9,
      11,
    ], color: 3),
    ScaleType('mixolydian', 'Miksolidyen', 'Pes 7. dereceli majör.', [
      0,
      2,
      4,
      5,
      7,
      9,
      10,
    ], color: 6),
    ScaleType(
      'pentatonic_major',
      'Majör pentatonik',
      'Her zaman uyan beş nota.',
      [0, 2, 4, 7, 9],
    ),
    ScaleType(
      'pentatonic_minor',
      'Minör pentatonik',
      'Rock ve bluesun beygiri.',
      [0, 3, 5, 7, 10],
    ),
    ScaleType('blues', 'Blues', 'Minör pentatonik artı blue nota.', [
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
    ], 'Klasik kadans. Eve döner.'),
    Progression('I-V-vi-IV', 'I-V-vi-IV', false, [
      (0, 'maj'),
      (7, 'maj'),
      (9, 'min'),
      (5, 'maj'),
    ], 'Pop dizisi. Sayısız şarkının iskeleti.'),
    Progression('I-vi-IV-V', 'I-vi-IV-V', false, [
      (0, 'maj'),
      (9, 'min'),
      (5, 'maj'),
      (7, 'maj'),
    ], '50\'ler doo-wop dizisi.'),
    Progression('I-iii-IV-V', 'I-iii-IV-V', false, [
      (0, 'maj'),
      (4, 'min'),
      (5, 'maj'),
      (7, 'maj'),
    ], 'Yumuşak yükselen merdiven.'),
    Progression('vi-IV-I-V', 'vi-IV-I-V', false, [
      (9, 'min'),
      (5, 'maj'),
      (0, 'maj'),
      (7, 'maj'),
    ], 'Minörden başlayan pop dizisi.'),
    Progression('i-VI-III-VII', 'i-VI-III-VII', true, [
      (0, 'min'),
      (8, 'maj'),
      (3, 'maj'),
      (10, 'maj'),
    ], 'Destansı minör dizi.'),
    Progression('i-iv-i-V', 'i-iv-i-V', true, [
      (0, 'min'),
      (5, 'min'),
      (0, 'min'),
      (7, 'maj'),
    ], 'Armonik minör kadansı.'),
    Progression('ii-V-I', 'ii-V-I', false, [
      (2, 'min7'),
      (7, 'dom7'),
      (0, 'maj7'),
    ], 'Cazın temel kadansı.'),
    Progression('I-IV-I-V', 'I-IV-I-V', false, [
      (0, 'maj'),
      (5, 'maj'),
      (0, 'maj'),
      (7, 'maj'),
    ], 'Halk ve blues kökenli gidiş.'),
  ];
  static Progression byId(String id) => all.firstWhere((p) => p.id == id);
}
