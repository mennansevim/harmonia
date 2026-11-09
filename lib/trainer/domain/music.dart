import 'dart:math' as math;

import '../../domain/lang.dart';

/// Pure music-theory vocabulary for the ear trainer. No audio, no IO.

enum NoteNotation { letter, solfege }

/// The learner's note naming, app-wide, like [Lang.en] for wording. Lesson
/// titles and hints are text built from data, so they read this rather
/// than assuming Do Re Mi; [TrainerStore] keeps it in step with the
/// setting.
abstract final class NoteNames {
  static NoteNotation current = NoteNotation.solfege;

  /// Name of pitch class [pc] in the current naming.
  static String of(int pc) => PitchClass.name(pc, current);

  static const _letterFor = {
    'Do': 'C',
    'Re': 'D',
    'Mi': 'E',
    'Fa': 'F',
    'Sol': 'G',
    'La': 'A',
    'Si': 'B',
  };

  // A whole solfège word, optionally altered; never inside another word.
  static final _solfegeWord = RegExp(
    r'(?<![A-Za-zÇĞİÖŞÜçğıöşü])(Do|Re|Mi|Fa|Sol|La|Si)(?![A-Za-zÇĞİÖŞÜçğıöşü])',
  );

  static const _solfegeFor = {
    'C': 'Do',
    'D': 'Re',
    'E': 'Mi',
    'F': 'Fa',
    'G': 'Sol',
    'A': 'La',
    'B': 'Si',
  };

  // Note runs such as "C-E-G" or "E → F": two or more joined letters, so a
  // lone "A" in an English sentence is never touched.
  static final _letterRun = RegExp(
    r'(?<![A-Za-z])[A-G][♭♯]?(?:\s*[-→]\s*[A-G][♭♯]?)+(?![A-Za-z])',
  );
  static final _letter = RegExp(r'[A-G]');

  /// English example text is written in letters; with solfège naming its
  /// note runs read "Do-Mi-Sol". Other text is returned unchanged.
  static String inTextEn(String text) => current == NoteNotation.solfege
      ? text.replaceAllMapped(
          _letterRun,
          (m) => m[0]!.replaceAllMapped(_letter, (l) => _solfegeFor[l[0]]!),
        )
      : text;

  /// Turkish example text is written in solfège ("Do-Mi-Sol"); with letter
  /// naming it reads "C-E-G" instead. Other text is returned unchanged.
  static String inText(String text) => current == NoteNotation.letter
      ? text.replaceAllMapped(_solfegeWord, (m) => _letterFor[m[1]]!)
      : text;
}

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
    Register.low => tr('Pes', 'Low'),
    Register.medium => tr('Orta', 'Mid'),
    Register.high => tr('Tiz', 'High'),
  };
}

/// SATB choir parts with their usual spans (MIDI). Lessons are played where
/// the learner sings: lower parts hear every register one octave down.
enum VoicePart {
  soprano('Soprano', 60, 81),
  alto('Alto', 53, 74),
  tenor('Tenor', 48, 69),
  bass('Bas', 40, 64, 'Bass');

  const VoicePart(this._title, this.low, this.high, [this._titleEn]);
  final String _title;
  final String? _titleEn;
  String get title => tr(_title, _titleEn ?? _title);
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
    this._name,
    this._feel,
    this._anchor,
    this._nameEn,
    this._feelEn,
    this._anchorEn,
  );
  final String id;
  final int semitones;
  final String _name;
  final String _feel;
  final String _anchor;
  final String _nameEn;
  final String _feelEn;
  final String _anchorEn;
  String get name => tr(_name, _nameEn);
  String get feel => tr(NoteNames.inText(_feel), NoteNames.inTextEn(_feelEn));
  String get anchor =>
      tr(NoteNames.inText(_anchor), NoteNames.inTextEn(_anchorEn));

  /// Pitch class the example starts on ("E → F" → 4), for diagrams.
  int get exampleRoot {
    final m = RegExp(r'^([A-G])([♭♯]?)').firstMatch(_anchorEn)!;
    final natural = const {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    }[m[1]]!;
    return (natural +
            (m[2] == '♯'
                ? 1
                : m[2] == '♭'
                ? -1
                : 0)) %
        12;
  }
}

abstract final class Intervals {
  static const all = [
    IntervalType(
      'm2',
      1,
      'Küçük 2\'li',
      'En küçük adım: klavyede hemen yan yana iki tuş, arada tuş yok.',
      'Mi → Fa',
      'Minor 2nd',
      'The smallest step: two keys right next to each other, nothing in between.',
      'E → F',
    ),
    IntervalType(
      'M2',
      2,
      'Büyük 2\'li',
      'İki yarım ses: arada bir tuş atlanır. Bir dizide notadan notaya olağan adım.',
      'Do → Re',
      'Major 2nd',
      'Two semitones: one key is skipped. The usual step from note to note in a scale.',
      'C → D',
    ),
    IntervalType(
      'm3',
      3,
      'Küçük 3\'lü',
      'Üç yarım ses. Minör (daha koyu duyulan) akorun ilk iki notası arası.',
      'La → Do',
      'Minor 3rd',
      'Three semitones. The gap between the first two notes of a minor (darker-sounding) chord.',
      'A → C',
    ),
    IntervalType(
      'M3',
      4,
      'Büyük 3\'lü',
      'Dört yarım ses. Majör (daha parlak duyulan) akorun ilk iki notası arası.',
      'Do → Mi',
      'Major 3rd',
      'Four semitones. The gap between the first two notes of a major (brighter-sounding) chord.',
      'C → E',
    ),
    IntervalType(
      'P4',
      5,
      'Tam 4\'lü',
      'Beş yarım ses. Açık ve sağlam duyulan bir sıçrama.',
      'Sol → Do',
      'Perfect 4th',
      'Five semitones. An open, steady-sounding leap.',
      'G → C',
    ),
    IntervalType(
      'A4',
      6,
      'Artık 4\'lü',
      'Altı yarım ses: oktavın tam ortası. Gergin, çözülmek isteyen bir ses.',
      'Fa → Si',
      'Augmented 4th',
      'Six semitones: exactly half an octave. A tense sound that wants to move on.',
      'F → B',
    ),
    IntervalType(
      'P5',
      7,
      'Tam 5\'li',
      'Yedi yarım ses. Çok boş ve uyumlu duyulur; telli çalgılar böyle akort edilir.',
      'Do → Sol',
      'Perfect 5th',
      'Seven semitones. Very open and stable; string instruments are tuned this way.',
      'C → G',
    ),
    IntervalType(
      'm6',
      8,
      'Küçük 6\'lı',
      'Sekiz yarım ses. Geniş, biraz hüzünlü bir sıçrama.',
      'Mi → Do',
      'Minor 6th',
      'Eight semitones. A wide, slightly sad leap.',
      'E → C',
    ),
    IntervalType(
      'M6',
      9,
      'Büyük 6\'lı',
      'Dokuz yarım ses. Geniş, sıcak ve açık bir sıçrama.',
      'Do → La',
      'Major 6th',
      'Nine semitones. A wide, warm and open leap.',
      'C → A',
    ),
    IntervalType(
      'm7',
      10,
      'Küçük 7\'li',
      'On yarım ses. Oktavdan iki yarım ses dar; çözülmemiş duyulur.',
      'Sol → Fa',
      'Minor 7th',
      'Ten semitones. Two semitones short of an octave; sounds unresolved.',
      'G → F',
    ),
    IntervalType(
      'M7',
      11,
      'Büyük 7\'li',
      'On bir yarım ses. Oktavın hemen bir alt tuşu; çok gergin.',
      'Do → Si',
      'Major 7th',
      'Eleven semitones. One key short of an octave; very tense.',
      'C → B',
    ),
    IntervalType(
      'P8',
      12,
      'Oktav',
      'On iki yarım ses: aynı nota, bir kat yukarıda.',
      'Do → Do',
      'Octave',
      'Twelve semitones: the same note, one level higher.',
      'C → C',
    ),
  ];
  static IntervalType byId(String id) => all.firstWhere((i) => i.id == id);
}

class ChordQuality {
  const ChordQuality(
    this.id,
    this.label,
    this._name,
    this._feel,
    this.tones,
    this._nameEn,
    this._feelEn, {
    this.exampleRoot = 0,
  });
  final String id;
  final String label;

  /// Pitch class the example chord is built on, for diagrams.
  final int exampleRoot;
  final String _name;
  final String _feel;
  final String _nameEn;
  final String _feelEn;
  String get name => tr(_name, _nameEn);
  String get feel => tr(NoteNames.inText(_feel), NoteNames.inTextEn(_feelEn));

  /// Semitones above the root.
  final List<int> tones;
}

abstract final class Chords {
  static const all = [
    ChordQuality(
      'maj',
      'maj',
      'Majör üçlü',
      'Üç nota birlikte: kök, 4 yarım ses yukarısı ve 7 yarım ses yukarısı. Parlak ve kararlı duyulur (Do-Mi-Sol).',
      [0, 4, 7],
      'Major triad',
      'Three notes together: the root, 4 semitones up and 7 semitones up. Bright and settled (C-E-G).',
      exampleRoot: 0,
    ),
    ChordQuality(
      'min',
      'min',
      'Minör üçlü',
      'Majörün ortadaki notası bir tuş aşağıda: kökten 3 yarım ses. Daha koyu duyulur (La-Do-Mi).',
      [0, 3, 7],
      'Minor triad',
      'A major chord with the middle note one key lower: 3 semitones from the root. Darker (A-C-E).',
      exampleRoot: 9,
    ),
    ChordQuality(
      'dim',
      'dim',
      'Eksik üçlü',
      'Üst üste iki küçük 3\'lü: 3 + 3 yarım ses. Sıkışık ve gergin (Si-Re-Fa).',
      [0, 3, 6],
      'Diminished triad',
      'Two minor 3rds stacked: 3 + 3 semitones. Tight and tense (B-D-F).',
      exampleRoot: 11,
    ),
    ChordQuality(
      'aug',
      'aug',
      'Artık üçlü',
      'Üst üste iki büyük 3\'lü: 4 + 4 yarım ses. Havada kalan bir ses (Do-Mi-Sol♯).',
      [0, 4, 8],
      'Augmented triad',
      'Two major 3rds stacked: 4 + 4 semitones. Sounds suspended in the air (C-E-G♯).',
      exampleRoot: 0,
    ),
    ChordQuality(
      'maj7',
      'maj7',
      'Majör 7\'li',
      'Majör akor ve kökün bir tuş altındaki nota (11 yarım ses). Yumuşak bir caz rengi (Do-Mi-Sol-Si).',
      [0, 4, 7, 11],
      'Major 7th',
      'A major chord plus the note one key below the octave (11 semitones). A soft jazz colour (C-E-G-B).',
      exampleRoot: 0,
    ),
    ChordQuality(
      'min7',
      'min7',
      'Minör 7\'li',
      'Minör akor ve kökten 10 yarım ses yukarıdaki nota. Yumuşak ve koyu (Re-Fa-La-Do).',
      [0, 3, 7, 10],
      'Minor 7th',
      'A minor chord plus the note 10 semitones above the root. Soft and dark (D-F-A-C).',
      exampleRoot: 2,
    ),
    ChordQuality(
      'dom7',
      'dom7',
      'Dominant 7\'li',
      'Majör akor ve kökten 10 yarım ses yukarıdaki nota. Bir sonraki akora gitmek ister (Sol-Si-Re-Fa).',
      [0, 4, 7, 10],
      'Dominant 7th',
      'A major chord plus the note 10 semitones above the root. It wants to move on to the next chord (G-B-D-F).',
      exampleRoot: 7,
    ),
    ChordQuality(
      'hdim7',
      'hdim7',
      'Yarım eksik 7\'li',
      'Eksik akor ve kökten 10 yarım ses yukarıdaki nota. Gergin ama eksik 7\'liden yumuşak (Si-Re-Fa-La).',
      [0, 3, 6, 10],
      'Half-diminished 7th',
      'A diminished chord plus the note 10 semitones above the root. Tense, but softer than a diminished 7th (B-D-F-A).',
      exampleRoot: 11,
    ),
    ChordQuality(
      'dim7',
      'dim7',
      'Eksik 7\'li',
      'Dört nota, hepsi 3\'er yarım ses arayla. Çok gergin ve simetrik.',
      [0, 3, 6, 9],
      'Diminished 7th',
      'Four notes, each 3 semitones apart. Very tense and symmetrical.',
      exampleRoot: 11,
    ),
  ];
  static ChordQuality byId(String id) => all.firstWhere((c) => c.id == id);
}

class ScaleType {
  const ScaleType(
    this.id,
    this._name,
    this._feel,
    this.steps,
    this._nameEn,
    this._feelEn, {
    this.color,
    this.exampleRoot = 0,
  });
  final String id;
  final String _name;
  final String _feel;
  final String _nameEn;
  final String _feelEn;
  String get name => tr(_name, _nameEn);
  String get feel => tr(NoteNames.inText(_feel), NoteNames.inTextEn(_feelEn));

  /// Semitones above the root, ascending, without the octave.
  final List<int> steps;

  /// Index into [steps] of the characteristic "color note", if any.
  final int? color;

  /// Pitch class the example scale starts on, for diagrams.
  final int exampleRoot;
}

abstract final class Scales {
  static const all = [
    ScaleType(
      'major',
      'Majör',
      'Yedi nota, adımlar T T Y T T T Y. Bildik "Do Re Mi" dizisi; beyaz tuşlarda Do sesinden başlar.',
      [0, 2, 4, 5, 7, 9, 11],
      'Major',
      'Seven notes, steps W W H W W W H. The familiar "do re mi" scale; the white keys from C.',
      exampleRoot: 0,
    ),
    ScaleType(
      'natural_minor',
      'Doğal minör',
      'Adımlar T Y T T Y T T. Majörden daha koyu; beyaz tuşlarda La sesinden başlar.',
      [0, 2, 3, 5, 7, 8, 10],
      'Natural minor',
      'Steps W H W W H W W. Darker than major; the white keys from A.',
      exampleRoot: 9,
      color: 2,
    ),
    ScaleType(
      'harmonic_minor',
      'Armonik minör',
      'Doğal minör, yalnız 7. nota bir yarım ses yukarıda; 6. ile 7. nota arasında 3 yarım seslik geniş bir adım oluşur.',
      [0, 2, 3, 5, 7, 8, 11],
      'Harmonic minor',
      'Natural minor with only the 7th note a semitone higher; a wide 3-semitone step appears between the 6th and 7th.',
      exampleRoot: 9,
      color: 6,
    ),
    ScaleType(
      'melodic_minor',
      'Melodik minör',
      'Doğal minör, 6. ve 7. notalar birer yarım ses yukarıda; yukarı çıkarken yumuşak akar.',
      [0, 2, 3, 5, 7, 9, 11],
      'Melodic minor',
      'Natural minor with the 6th and 7th notes a semitone higher; it flows smoothly going up.',
      exampleRoot: 9,
      color: 5,
    ),
    ScaleType(
      'dorian',
      'Dorian',
      'Adımlar T Y T T T Y T. Minöre benzer ama 6. nota daha yukarıda; beyaz tuşlarda Re sesinden başlar.',
      [0, 2, 3, 5, 7, 9, 10],
      'Dorian',
      'Steps W H W W W H W. Like minor, but the 6th note is higher; the white keys from D.',
      exampleRoot: 2,
      color: 5,
    ),
    ScaleType(
      'phrygian',
      'Frigyen',
      'Adımlar Y T T T Y T T. İlk adım yarım ses; beyaz tuşlarda Mi sesinden başlar.',
      [0, 1, 3, 5, 7, 8, 10],
      'Phrygian',
      'Steps H W W W H W W. The first step is a semitone; the white keys from E.',
      exampleRoot: 4,
      color: 1,
    ),
    ScaleType(
      'lydian',
      'Lidyen',
      'Adımlar T T T Y T T Y. Majöre benzer ama 4. nota yarım ses yukarıda; beyaz tuşlarda Fa sesinden başlar.',
      [0, 2, 4, 6, 7, 9, 11],
      'Lydian',
      'Steps W W W H W W H. Like major, but the 4th note is a semitone higher; the white keys from F.',
      exampleRoot: 5,
      color: 3,
    ),
    ScaleType(
      'mixolydian',
      'Miksolidyen',
      'Adımlar T T Y T T Y T. Majöre benzer ama 7. nota yarım ses aşağıda; beyaz tuşlarda Sol sesinden başlar.',
      [0, 2, 4, 5, 7, 9, 10],
      'Mixolydian',
      'Steps W W H W W H W. Like major, but the 7th note is a semitone lower; the white keys from G.',
      exampleRoot: 7,
      color: 6,
    ),
    ScaleType(
      'pentatonic_major',
      'Majör pentatonik',
      'Beş nota: majörün 4. ve 7. notaları çıkarılmış. Yarım ses adımı yok, çok yumuşak duyulur.',
      [0, 2, 4, 7, 9],
      'Major pentatonic',
      'Five notes: major without its 4th and 7th. No semitone steps, so it sounds very smooth.',
      exampleRoot: 0,
    ),
    ScaleType(
      'pentatonic_minor',
      'Minör pentatonik',
      'Beş nota: minörün 2. ve 6. notaları çıkarılmış. Pop ve blues\'ta çok sık.',
      [0, 3, 5, 7, 10],
      'Minor pentatonic',
      'Five notes: minor without its 2nd and 6th. Very common in pop and blues.',
      exampleRoot: 9,
    ),
    ScaleType(
      'blues',
      'Blues',
      'Minör pentatonik ve araya eklenen bir "blues notası" (kökten 6 yarım ses).',
      [0, 3, 5, 6, 7, 10],
      'Blues',
      'Minor pentatonic plus one added "blue note" (6 semitones above the root).',
      exampleRoot: 9,
      color: 3,
    ),
  ];
  static ScaleType byId(String id) => all.firstWhere((s) => s.id == id);
}

class Progression {
  const Progression(
    this.id,
    this.label,
    this.minor,
    this.chords,
    this._feel,
    this._feelEn,
  );
  final String id;
  final String label;
  final bool minor;

  /// (scale degree root semitone offset, chord quality id)
  final List<(int, String)> chords;
  final String _feel;
  final String _feelEn;
  String get feel => tr(NoteNames.inText(_feel), NoteNames.inTextEn(_feelEn));
}

abstract final class Progressions {
  static const all = [
    Progression(
      'I-IV-V-I',
      'I-IV-V-I',
      false,
      [(0, 'maj'), (5, 'maj'), (7, 'maj'), (0, 'maj')],
      'Tonik, alt dominant, dominant, tonik.',
      'Tonic, subdominant, dominant, tonic.',
    ),
    Progression(
      'I-V-vi-IV',
      'I-V-vi-IV',
      false,
      [(0, 'maj'), (7, 'maj'), (9, 'min'), (5, 'maj')],
      'Dominanttan 6. derecenin minörüne iner.',
      'From the dominant down to the minor chord on the 6th.',
    ),
    Progression(
      'I-vi-IV-V',
      'I-vi-IV-V',
      false,
      [(0, 'maj'), (9, 'min'), (5, 'maj'), (7, 'maj')],
      'Tonikten 6. dereceye, sonra kadansa.',
      'From the tonic to the 6th, then into the cadence.',
    ),
    Progression(
      'I-iii-IV-V',
      'I-iii-IV-V',
      false,
      [(0, 'maj'), (4, 'min'), (5, 'maj'), (7, 'maj')],
      '3. derece üzerinden basamak basamak yükselir.',
      'Climbs step by step through the 3rd degree.',
    ),
    Progression(
      'vi-IV-I-V',
      'vi-IV-I-V',
      false,
      [(9, 'min'), (5, 'maj'), (0, 'maj'), (7, 'maj')],
      '6. derecenin minörüyle başlar.',
      'Starts on the minor chord of the 6th.',
    ),
    Progression(
      'i-VI-III-VII',
      'i-VI-III-VII',
      true,
      [(0, 'min'), (8, 'maj'), (3, 'maj'), (10, 'maj')],
      'Minör tonikten majör akorlara iner.',
      'Falls from the minor tonic to major chords.',
    ),
    Progression(
      'i-iv-i-V',
      'i-iv-i-V',
      true,
      [(0, 'min'), (5, 'min'), (0, 'min'), (7, 'maj')],
      'Minör kadans; majör dominant tonik\'e çeker.',
      'Minor cadence; the major dominant pulls to the tonic.',
    ),
    Progression(
      'ii-V-I',
      'ii-V-I',
      false,
      [(2, 'min7'), (7, 'dom7'), (0, 'maj7')],
      '2. derece, dominant 7\'li, majör 7\'li tonik.',
      'The 2nd, a dominant 7th, a major 7th tonic.',
    ),
    Progression(
      'I-IV-I-V',
      'I-IV-I-V',
      false,
      [(0, 'maj'), (5, 'maj'), (0, 'maj'), (7, 'maj')],
      'Tonik ile alt dominant arasında gidip gelir.',
      'Rocks between the tonic and the subdominant.',
    ),
  ];
  static Progression byId(String id) => all.firstWhere((p) => p.id == id);
}

/// How interval names read, for anyone who has never seen "m2" (QA-INT-01).
/// Text only; shared by the intro slide and the quiz help sheet.
List<String> intervalNamingRules() {
  final n = NoteNames.of;
  return [
    tr(
      'Sayı, iki notayı da sayarak kaç nota adı kapsadığıdır: '
          '${n(0)}→${n(2)} 2\'li, ${n(0)}→${n(4)} 3\'lü, ${n(0)}→${n(7)} 5\'li.',
      'The number counts the note names covered, both ends included: '
          '${n(0)}→${n(2)} is a 2nd, ${n(0)}→${n(4)} a 3rd, ${n(0)}→${n(7)} a 5th.',
    ),
    tr(
      'Yarım ses en küçük adımdır: klavyede hemen yan yana iki tuş, siyahlar dahil.',
      'A semitone is the smallest step: two keys right next to each other, black ones included.',
    ),
    tr(
      'Küçük ve büyük, aynı sayının iki boyudur; büyük olan bir yarım ses '
          'geniştir. Kısaltma: küçük = m, büyük = M (m2 = küçük 2\'li, M2 = büyük 2\'li).',
      'Minor and major are two sizes of the same number; major is one '
          'semitone wider. Short forms: minor = m, major = M (m2, M2).',
    ),
    tr(
      '4\'lü, 5\'li ve oktav "tam" diye anılır (P4, P5, P8). Tam 4\'lünün bir '
          'yarım ses genişi artık 4\'lüdür (A4).',
      '4ths, 5ths and the octave are called "perfect" (P4, P5, P8). One '
          'semitone wider than a perfect 4th is an augmented 4th (A4).',
    ),
  ];
}

/// How chord names read, for beginners (QA-INT-02).
List<String> chordNamingRules() => [
  tr(
    'Akor, aynı anda çalınan üç ya da daha çok notadır. Notalar genellikle '
        '3\'lü aralıklarla üst üste dizilir.',
    'A chord is three or more notes played at once, usually stacked in '
        '3rds.',
  ),
  tr(
    'Majör (maj) ile minör (min) arasındaki tek fark ortadaki notadır: '
        'majörde kökten 4, minörde 3 yarım ses yukarıda.',
    'The only difference between major (maj) and minor (min) is the middle '
        'note: 4 semitones above the root in major, 3 in minor.',
  ),
  tr(
    'Eksik (dim) iki küçük 3\'lü, artık (aug) iki büyük 3\'lü üst üstedir.',
    'Diminished (dim) is two minor 3rds stacked, augmented (aug) two major '
        '3rds.',
  ),
  tr(
    'Adında 7 olan akorlar (maj7, min7, dom7…) dördüncü bir nota taşır: '
        'kökün 10 ya da 11 yarım ses üstü.',
    'Chords with a 7 in the name (maj7, min7, dom7…) add a fourth note, 10 or '
        '11 semitones above the root.',
  ),
];

/// How scale names read, for beginners (QA-INT-02).
List<String> scaleNamingRules() => [
  tr(
    'Dizi, bir notadan bir üstteki aynı notaya adım adım çıkan notalardır.',
    'A scale is the notes stepping up from one note to the same note an '
        'octave higher.',
  ),
  tr(
    'T = tam ses (2 tuş), Y = yarım ses (1 tuş). Bir diziyi bu adımların '
        'sırası belirler.',
    'W = whole step (2 keys), H = half step (1 key). The order of these '
        'steps defines a scale.',
  ),
  tr(
    'Modlar (Dorian, Frigyen, Lidyen, Miksolidyen) beyaz tuşları farklı bir '
        'notadan başlatarak elde edilir.',
    'The modes (Dorian, Phrygian, Lydian, Mixolydian) are the white keys '
        'started from a different note.',
  ),
  tr(
    'Pentatonik diziler 7 yerine 5 notalıdır.',
    'Pentatonic scales have 5 notes instead of 7.',
  ),
];
