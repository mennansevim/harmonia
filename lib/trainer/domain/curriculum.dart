import 'music.dart';
import 'trainers.dart';
import '../../domain/lang.dart';

enum NodeKind { intro, lesson, checkpoint, finalExam }

/// One stop on a skill's lesson list. Draft content: not educator-approved.
class LessonNode {
  const LessonNode({
    required this.id,
    required this.trainer,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.items = const [],
    this.newItems = const [],
    this.registers = const [Register.medium],
    this.direction = IntervalDirection.ascending,
  });

  final String id;
  final TrainerKind trainer;
  final NodeKind kind;
  final String title;
  final String subtitle;

  /// Answer pool once this node is reached.
  final List<String> items;

  /// Items introduced by this lesson (empty = side-by-side comparison).
  final List<String> newItems;
  final List<Register> registers;
  final IntervalDirection direction;

  bool get isGate => kind == NodeKind.checkpoint || kind == NodeKind.finalExam;
}

class TrainerPath {
  const TrainerPath(this.trainer, this.nodes, this.introSlides);
  final TrainerKind trainer;
  final List<LessonNode> nodes;
  final List<IntroSlide> introSlides;

  int get lessonCount => nodes.length;
  LessonNode byId(String id) => nodes.firstWhere((n) => n.id == id);
  int indexOf(String id) => nodes.indexWhere((n) => n.id == id);
}

class IntroSlide {
  const IntroSlide(this.title, this.body, this.bullets, {this.highlight});
  final String title;
  final String body;
  final List<String> bullets;
  final List<String>? highlight;
}

/// One step of Resonia's ladder: the items it adds and why they come now.
class _Stage {
  const _Stage(this.add, this.why);
  final List<String> add;
  final String why;
}

/// A late drill over the whole pool in another register or direction.
class _Drill {
  const _Drill(
    this.title,
    this.why, {
    this.registers = const [Register.medium],
    this.direction = IntervalDirection.ascending,
  });
  final String title;
  final String why;
  final List<Register> registers;
  final IntervalDirection direction;
}

const _anyReg = [Register.low, Register.medium, Register.high];

/// Resonia's generated ladder: per stage a "Yeni" lesson, then (from the
/// second stage) a mixed review; an "Ara durak" after every third stage;
/// register/direction drills; a "Konser provası" at the end.
TrainerPath _ladder(
  TrainerKind kind,
  List<_Stage> stages,
  List<_Drill> drills,
  List<IntroSlide> slides,
) {
  final nodes = <LessonNode>[
    LessonNode(
      id: '${kind.id}-intro',
      trainer: kind,
      kind: NodeKind.intro,
      title: tr('Başlarken', 'Getting started'),
      subtitle: tr(
        '${kind.title} nasıl çalışılır?',
        'How to practise ${kind.title}',
      ),
    ),
  ];
  var n = 0;
  var gates = 0;
  final pool = <String>[];
  String name(String id) => itemLabel(kind, id, long: true);

  void lesson(
    String title,
    String why,
    List<String> newItems, {
    List<Register> registers = const [Register.medium],
    IntervalDirection direction = IntervalDirection.ascending,
  }) {
    n++;
    nodes.add(
      LessonNode(
        id: '${kind.id}-l$n',
        trainer: kind,
        kind: NodeKind.lesson,
        title: '$n. $title',
        subtitle: why,
        items: List.of(pool),
        newItems: newItems,
        registers: registers,
        direction: direction,
      ),
    );
  }

  void gate() {
    gates++;
    nodes.add(
      LessonNode(
        id: '${kind.id}-cp$gates',
        trainer: kind,
        kind: NodeKind.checkpoint,
        title: tr('Ara durak $gates', 'Checkpoint $gates'),
        subtitle: tr(
          '${pool.length} ${kind.unitWord}, karışık sırayla.',
          '${pool.length} ${kind.unitWord}, in mixed order.',
        ),
        items: List.of(pool),
      ),
    );
  }

  for (var i = 0; i < stages.length; i++) {
    final s = stages[i];
    pool.addAll(s.add);
    lesson(
      tr(
        'Yeni: ${s.add.map(name).join(' ve ')}',
        'New: ${s.add.map(name).join(' and ')}',
      ),
      s.why,
      s.add,
    );
    if (i > 0) {
      lesson(
        tr('Karışık tekrar', 'Mixed review'),
        tr(
          '${pool.length} ${kind.unitWord} yan yana.',
          '${pool.length} ${kind.unitWord} side by side.',
        ),
        const [],
      );
    }
    if ((i + 1) % 3 == 0) gate();
  }
  for (final d in drills) {
    lesson(
      d.title,
      d.why,
      const [],
      registers: d.registers,
      direction: d.direction,
    );
  }
  nodes.add(
    LessonNode(
      id: '${kind.id}-final',
      trainer: kind,
      kind: NodeKind.finalExam,
      title: tr('Konser provası', 'Dress rehearsal'),
      subtitle: tr(
        'Tüm ${kind.unitWord} türleri, her bölgede.',
        'Every type of ${kind.unitWord}, in every register.',
      ),
      items: List.of(pool),
      registers: _anyReg,
      direction: IntervalDirection.mixed,
    ),
  );
  return TrainerPath(kind, nodes, slides);
}

List<_Stage> _one(List<(String, String)> rows) => [
  for (final (id, why) in rows) _Stage([id], why),
];

/// Built once per wording language: lesson titles are part of the data.
final _paths = <bool, Map<TrainerKind, TrainerPath>>{};

Map<TrainerKind, TrainerPath> get trainerPaths =>
    _paths[Lang.en] ??= _buildPaths();

Map<TrainerKind, TrainerPath> _buildPaths() => {
  // Notes in a tonal ear-training order: tonic, triad, then scale steps,
  // leading tone, and the chromatic notes last.
  TrainerKind.pitch: _ladder(
    TrainerKind.pitch,
    [
      ..._one([
        (
          '0',
          tr(
            'Akortun başladığı referans ses.',
            'The reference note tuning starts from.',
          ),
        ),
        ('4', tr('Majör üçlünün ortası.', 'The middle of the major triad.')),
        (
          '7',
          tr(
            'Üçlünün tepesi; tonik ile birlikte en sık ses.',
            'The top of the triad; with the tonic, the most common note.',
          ),
        ),
        (
          '2',
          tr(
            'Do ile Mi arasındaki basamak.',
            'The step between the tonic and the third.',
          ),
        ),
        ('5', tr('Mi\'nin yarım ses üstü.', 'A semitone above the third.')),
        ('9', tr('Sol\'ün bir tam ses üstü.', 'A whole tone above the fifth.')),
        (
          '11',
          tr(
            'Do\'ya çeken yeden ses.',
            'The leading tone that pulls to the tonic.',
          ),
        ),
        ('10', tr('İlk değiştirilmiş ses.', 'The first altered note.')),
        ('6', tr('Fa ile Sol arası.', 'Between the fourth and the fifth.')),
        ('3', tr('Re ile Mi arası.', 'Between the second and the third.')),
      ]),
      _Stage(
        ['8', '1'],
        tr('Kalan iki değiştirilmiş ses.', 'The two remaining altered notes.'),
      ),
    ],
    [
      _Drill(
        tr('Pes bölge', 'Low register'),
        tr(
          'Aynı notalar bir oktav aşağıda.',
          'The same notes an octave lower.',
        ),
        registers: [Register.low],
      ),
      _Drill(
        tr('Tiz bölge', 'High register'),
        tr(
          'Aynı notalar bir oktav yukarıda.',
          'The same notes an octave higher.',
        ),
        registers: [Register.high],
      ),
    ],
    [
      IntroSlide(
        tr('Notayı adıyla tanımak', 'Knowing a note by name'),
        tr(
          'Burada bir sesi duyup hangi nota olduğunu söylemeyi çalışırsın. '
              'Ezgiyi okumadan önce zihninde duymanın ve doğru sesten başlamanın temeli budur.',
          'Here you hear a sound and practise saying which note it is. '
              'It is the base for hearing a melody in your head before you read it, and for starting on the right note.',
        ),
        [
          tr(
            'Her basamak tek bir yeni nota ekler.',
            'Each step adds one new note.',
          ),
          tr(
            'Önce dinlersin, sonra kendi sesinle söylersin, sonra ayırt edersin.',
            'First you listen, then you sing it, then you tell it apart.',
          ),
          tr(
            'Ara duraklar bildiğin yerleri atlamanı sağlar.',
            'Checkpoints let you skip what you already know.',
          ),
        ],
      ),
      IntroSlide(
        tr('Doğru dinleme', 'Listening well'),
        tr(
          'Her notayı Do\'ya göre düşün: ne kadar yukarıda?',
          'Think of each note against the tonic: how far up is it?',
        ),
        [
          tr(
            'Ses aralığını ölçtüysen sesler senin aralığında çalar.',
            'If you measured your range, notes play in your range.',
          ),
          tr(
            'Yanlış cevaptan sonra iki sesi yan yana dinle.',
            'After a wrong answer, hear the two notes side by side.',
          ),
          tr(
            'Kısa ve her gün çalışmak en iyi sonucu verir.',
            'Short daily practice works best.',
          ),
        ],
      ),
    ],
  ),
  // Intervals by how often a singer meets them: steps, thirds, perfect
  // leaps, sixths, sevenths, tritone.
  TrainerKind.interval: _ladder(
    TrainerKind.interval,
    _one([
      (
        'M2',
        tr(
          'Ezgilerin çoğu tam ses adımlarla ilerler.',
          'Most melodies move in whole steps.',
        ),
      ),
      (
        'm2',
        tr(
          'Yarım ses; yeden ve geçişlerde.',
          'A semitone; in leading tones and passing notes.',
        ),
      ),
      (
        'M3',
        tr('Majör akorun alt aralığı.', 'The lower interval of a major chord.'),
      ),
      (
        'm3',
        tr('Minör akorun alt aralığı.', 'The lower interval of a minor chord.'),
      ),
      (
        'P5',
        tr(
          'Çok sesli müzikte en sağlam uyumlardan biri.',
          'One of the most stable consonances in part singing.',
        ),
      ),
      (
        'P4',
        tr(
          'Girişlerde sık duyulan sıçrama.',
          'A leap often heard at the start of a tune.',
        ),
      ),
      (
        'P8',
        tr(
          'Farklı bölgelerde aynı nota adı.',
          'The same note name in another register.',
        ),
      ),
      ('M6', tr('Küçük 3\'lünün çevrimi.', 'The inversion of a minor 3rd.')),
      ('m6', tr('Büyük 3\'lünün çevrimi.', 'The inversion of a major 3rd.')),
      (
        'm7',
        tr(
          'Dominant akorun dış sesleri.',
          'The outer notes of a dominant chord.',
        ),
      ),
      ('M7', tr('Oktava yarım ses kala.', 'A semitone short of the octave.')),
      ('A4', tr('Oktavın tam ortası.', 'The exact middle of the octave.')),
    ]),
    [
      _Drill(
        tr('Aşağı doğru', 'Downwards'),
        tr('Aralıklar yukarıdan aşağı.', 'Intervals from top to bottom.'),
        direction: IntervalDirection.descending,
      ),
      _Drill(
        tr('Birlikte çalınan', 'Played together'),
        tr(
          'İki ses aynı anda, armonik aralık.',
          'Both notes at once, a harmonic interval.',
        ),
        direction: IntervalDirection.mixed,
      ),
      _Drill(
        tr('Farklı bölgeler', 'Other registers'),
        tr('Pes ve tiz başlangıç notaları.', 'Low and high starting notes.'),
        registers: _anyReg,
      ),
    ],
    [
      IntroSlide(
        tr('İki ses arasındaki mesafe', 'The distance between two notes'),
        tr(
          'Aralık, iki notanın arasındaki uzaklıktır. Ezgiyi doğru kurmanın ve '
              'çok sesli müzikte diğer seslerle uyumun anahtarıdır.',
          'An interval is the distance between two notes. It is the key to '
              'building a melody correctly and to blending with other parts.',
        ),
        [
          tr(
            'Mesafeler yarım ses sayısıyla anlatılır.',
            'Distances are counted in semitones.',
          ),
          tr(
            'Her aralık için bir solfej örneği verilir (ör. Do → Mi).',
            'Each interval comes with an example (e.g. C → E).',
          ),
          tr(
            'Önce yukarı doğru, sonra aşağı ve birlikte çalışırsın.',
            'You practise upwards first, then downwards and together.',
          ),
        ],
      ),
      IntroSlide(
        tr('Nasıl çalışılır', 'How to practise'),
        tr(
          'Duyduğun iki sesi içinden ya da sesli söyle; mesafeyi bildiğin bir örnekle karşılaştır.',
          'Sing the two notes in your head or out loud; compare the distance with an example you know.',
        ),
        [
          tr(
            'Yeni aralık önce tek başına, sonra diğerleriyle karışık gelir.',
            'A new interval comes alone first, then mixed with the others.',
          ),
          tr(
            'Söyleme adımı ölçülmez; yalnız alışkanlık içindir.',
            'The singing step is not measured; it only builds the habit.',
          ),
          tr(
            'Ara durakta %80 ile önceki dersler tamamlanır.',
            'Scoring 80% at a checkpoint completes the lessons before it.',
          ),
        ],
      ),
    ],
  ),
  TrainerKind.chord: _ladder(
    TrainerKind.chord,
    [
      _Stage(
        ['maj', 'min'],
        tr(
          'Tonal repertuvarın iki temel rengi.',
          'The two basic colours of tonal music.',
        ),
      ),
      ..._one([
        (
          'dom7',
          tr(
            'Çözülmek isteyen dört sesli akor.',
            'A four-note chord that wants to resolve.',
          ),
        ),
        (
          'dim',
          tr(
            'İki küçük 3\'lüden oluşan dar akor.',
            'A narrow chord of two minor 3rds.',
          ),
        ),
        (
          'min7',
          tr('Minör akora eklenen 7\'li.', 'A minor chord with a 7th added.'),
        ),
        (
          'maj7',
          tr(
            'Majör akora eklenen büyük 7\'li.',
            'A major chord with a major 7th added.',
          ),
        ),
        (
          'aug',
          tr(
            'İki büyük 3\'lüden oluşan geniş akor.',
            'A wide chord of two major 3rds.',
          ),
        ),
        (
          'hdim7',
          tr('Eksik üçlünün 7\'li hâli.', 'The diminished triad with a 7th.'),
        ),
        (
          'dim7',
          tr('Simetrik dört sesli akor.', 'A symmetrical four-note chord.'),
        ),
      ]),
    ],
    [
      _Drill(
        tr('Farklı bölgeler', 'Other registers'),
        tr(
          'Akorlar pes ve tiz bölgede.',
          'Chords in the low and high registers.',
        ),
        registers: _anyReg,
      ),
    ],
    [
      IntroSlide(
        tr('Akorun niteliği', 'Chord quality'),
        tr(
          'Birlikte çalan seslerin oluşturduğu türü tanırsın. Akorun içindeki '
              'seslerin görevini duymak, kendi sesini doğru yere oturtmayı kolaylaştırır.',
          'You recognise the type that notes form when played together. Hearing '
              'what each note does in a chord makes it easier to place your own voice.',
        ),
        [
          tr(
            'Her akor türü bir formülle anlatılır (ör. kök + büyük 3\'lü + tam 5\'li).',
            'Each chord type has a formula (e.g. root + major 3rd + perfect 5th).',
          ),
          tr(
            'Dinlerken önce sesler tek tek, sonra birlikte çalar.',
            'The notes play one by one first, then together.',
          ),
          tr(
            'Söyleme adımında akorun en pes sesini mırıldanırsın.',
            'In the singing step you hum the lowest note of the chord.',
          ),
        ],
      ),
    ],
  ),
  TrainerKind.scale: _ladder(
    TrainerKind.scale,
    [
      _Stage(
        ['major', 'natural_minor'],
        tr(
          'Tonal müziğin iki ana dizisi.',
          'The two main scales of tonal music.',
        ),
      ),
      ..._one([
        (
          'harmonic_minor',
          tr(
            'Yeden sesi tizleşmiş minör.',
            'Minor with a raised leading tone.',
          ),
        ),
        (
          'pentatonic_major',
          tr(
            'Halk ezgilerinde sık beş sesli dizi.',
            'A five-note scale common in folk tunes.',
          ),
        ),
        ('dorian', tr('Re\'den başlayan mod.', 'The mode that starts on D.')),
        (
          'mixolydian',
          tr('Sol\'den başlayan mod.', 'The mode that starts on G.'),
        ),
        (
          'melodic_minor',
          tr(
            '6. ve 7. derecesi tiz minör.',
            'Minor with a raised 6th and 7th.',
          ),
        ),
        (
          'pentatonic_minor',
          tr(
            'Minörden türeyen beş sesli dizi.',
            'A five-note scale drawn from minor.',
          ),
        ),
        ('lydian', tr('Fa\'dan başlayan mod.', 'The mode that starts on F.')),
        ('phrygian', tr('Mi\'den başlayan mod.', 'The mode that starts on E.')),
        (
          'blues',
          tr(
            'Minör pentatonik ve artık 4\'lü.',
            'Minor pentatonic plus the augmented 4th.',
          ),
        ),
      ]),
    ],
    [
      _Drill(
        tr('Farklı bölgeler', 'Other registers'),
        tr(
          'Diziler farklı başlangıç notalarından.',
          'Scales from other starting notes.',
        ),
        registers: _anyReg,
      ),
    ],
    [
      IntroSlide(
        tr('Dizinin yapısı', 'How a scale is built'),
        tr(
          'Dizi, notaların tam ve yarım ses adımlarla sıralanışıdır. Hangi diziyi '
              'duyduğunu bilmek ezgiyi okumanı ve tekrar etmeni kolaylaştırır.',
          'A scale is notes in order, in whole and half steps. Knowing which scale '
              'you hear makes a melody easier to read and repeat.',
        ),
        [
          tr(
            'Her dizi T (tam) ve Y (yarım) adımlarla gösterilir.',
            'Each scale is written in W (whole) and H (half) steps.',
          ),
          tr(
            'Diziyi belirleyen ses merdivende işaretlenir.',
            'The note that defines the scale is marked on the ladder.',
          ),
          tr(
            'Söyleme adımında diziyi nota adlarıyla çıkarsın.',
            'In the singing step you sing up the scale with note names.',
          ),
        ],
      ),
    ],
  ),
  TrainerKind.progression: _ladder(
    TrainerKind.progression,
    _one([
      (
        'I-IV-V-I',
        tr('Tonal kadansın temel hâli.', 'The basic tonal cadence.'),
      ),
      (
        'I-IV-I-V',
        tr(
          'Tonik ile alt dominant arasında gidiş geliş.',
          'Back and forth between tonic and subdominant.',
        ),
      ),
      (
        'I-V-vi-IV',
        tr(
          'Dominanttan 6. dereceye iniş.',
          'A fall from the dominant to the 6th.',
        ),
      ),
      ('i-iv-i-V', tr('Minör tonda kadans.', 'A cadence in a minor key.')),
      (
        'I-vi-IV-V',
        tr('6. derece üzerinden kadansa.', 'Through the 6th into the cadence.'),
      ),
      (
        'vi-IV-I-V',
        tr(
          '6. derecenin minörüyle başlayan dizi.',
          'Starts on the minor chord of the 6th.',
        ),
      ),
      ('ii-V-I', tr('7\'li akorlarla kadans.', 'A cadence with 7th chords.')),
      (
        'I-iii-IV-V',
        tr('3. derece üzerinden yükseliş.', 'A climb through the 3rd.'),
      ),
      (
        'i-VI-III-VII',
        tr(
          'Minör tonikten majör akorlara.',
          'From the minor tonic to major chords.',
        ),
      ),
    ]),
    [
      _Drill(
        tr('Farklı tonlar', 'Other keys'),
        tr('Aynı dizi başka tonlarda.', 'The same progression in other keys.'),
        registers: _anyReg,
      ),
    ],
    [
      IntroSlide(
        tr('Akorların sırası', 'The order of chords'),
        tr(
          'Bir eserin armonisi akorların belirli sıralarla ilerlemesidir. '
              'En pes sesin yolu çoğu zaman bu sırayı ele verir.',
          'The harmony of a piece is chords moving in set orders. '
              'The path of the lowest note often gives the order away.',
        ),
        [
          tr(
            'Dereceler Roma rakamıyla yazılır: büyük harf majör, küçük harf minör.',
            'Degrees are written in Roman numerals: upper case major, lower case minor.',
          ),
          tr(
            'Dinlerken en pes sesi takip et.',
            'Follow the lowest note as you listen.',
          ),
          tr(
            'Söyleme adımında bas sesini mırıldanırsın.',
            'In the singing step you hum the bass note.',
          ),
        ],
      ),
    ],
  ),
};
