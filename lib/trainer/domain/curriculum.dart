import 'music.dart';
import 'trainers.dart';

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
      title: 'Başlarken',
      subtitle: '${kind.title} nasıl çalışılır?',
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
        title: 'Ara durak $gates',
        subtitle: '${pool.length} ${kind.unitWord}, karışık sırayla.',
        items: List.of(pool),
      ),
    );
  }

  for (var i = 0; i < stages.length; i++) {
    final s = stages[i];
    pool.addAll(s.add);
    lesson('Yeni: ${s.add.map(name).join(' ve ')}', s.why, s.add);
    if (i > 0) {
      lesson(
        'Karışık tekrar',
        '${pool.length} ${kind.unitWord} yan yana.',
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
      title: 'Konser provası',
      subtitle: 'Tüm ${kind.unitWord} türleri, her bölgede.',
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

final Map<TrainerKind, TrainerPath> trainerPaths = {
  // Notes in a tonal ear-training order: tonic, triad, then scale steps,
  // leading tone, and the chromatic notes last.
  TrainerKind.pitch: _ladder(
    TrainerKind.pitch,
    [
      ..._one([
        ('0', 'Akortun başladığı referans ses.'),
        ('4', 'Majör üçlünün ortası.'),
        ('7', 'Üçlünün tepesi; tonik ile birlikte en sık ses.'),
        ('2', 'Do ile Mi arasındaki basamak.'),
        ('5', 'Mi\'nin yarım ses üstü.'),
        ('9', 'Sol\'ün bir tam ses üstü.'),
        ('11', 'Do\'ya çeken yeden ses.'),
        ('10', 'İlk değiştirilmiş ses.'),
        ('6', 'Fa ile Sol arası.'),
        ('3', 'Re ile Mi arası.'),
      ]),
      const _Stage(['8', '1'], 'Kalan iki değiştirilmiş ses.'),
    ],
    const [
      _Drill(
        'Pes bölge',
        'Aynı notalar bir oktav aşağıda.',
        registers: [Register.low],
      ),
      _Drill(
        'Tiz bölge',
        'Aynı notalar bir oktav yukarıda.',
        registers: [Register.high],
      ),
    ],
    const [
      IntroSlide(
        'Notayı adıyla tanımak',
        'Burada bir sesi duyup hangi nota olduğunu söylemeyi çalışırsın. '
            'Ezgiyi okumadan önce zihninde duymanın ve doğru sesten başlamanın temeli budur.',
        [
          'Her basamak tek bir yeni nota ekler.',
          'Önce dinlersin, sonra kendi sesinle söylersin, sonra ayırt edersin.',
          'Ara duraklar bildiğin yerleri atlamanı sağlar.',
        ],
      ),
      IntroSlide(
        'Doğru dinleme',
        'Her notayı Do\'ya göre düşün: ne kadar yukarıda?',
        [
          'Ses aralığını seçtiysen sesler senin aralığında çalar.',
          'Yanlış cevaptan sonra iki sesi yan yana dinle.',
          'Kısa ve her gün çalışmak en iyi sonucu verir.',
        ],
      ),
    ],
  ),
  // Intervals by how often a singer meets them: steps, thirds, perfect
  // leaps, sixths, sevenths, tritone.
  TrainerKind.interval: _ladder(
    TrainerKind.interval,
    _one([
      ('M2', 'Ezgilerin çoğu tam ses adımlarla ilerler.'),
      ('m2', 'Yarım ses; yeden ve geçişlerde.'),
      ('M3', 'Majör akorun alt aralığı.'),
      ('m3', 'Minör akorun alt aralığı.'),
      ('P5', 'Çok sesli müzikte en sağlam uyumlardan biri.'),
      ('P4', 'Girişlerde sık duyulan sıçrama.'),
      ('P8', 'Farklı bölgelerde aynı nota adı.'),
      ('M6', 'Küçük 3\'lünün çevrimi.'),
      ('m6', 'Büyük 3\'lünün çevrimi.'),
      ('m7', 'Dominant akorun dış sesleri.'),
      ('M7', 'Oktava yarım ses kala.'),
      ('A4', 'Oktavın tam ortası.'),
    ]),
    const [
      _Drill(
        'Aşağı doğru',
        'Aralıklar yukarıdan aşağı.',
        direction: IntervalDirection.descending,
      ),
      _Drill(
        'Birlikte çalınan',
        'İki ses aynı anda, armonik aralık.',
        direction: IntervalDirection.mixed,
      ),
      _Drill(
        'Farklı bölgeler',
        'Pes ve tiz başlangıç notaları.',
        registers: _anyReg,
      ),
    ],
    const [
      IntroSlide(
        'İki ses arasındaki mesafe',
        'Aralık, iki notanın arasındaki uzaklıktır. Ezgiyi doğru kurmanın ve '
            'çok sesli müzikte diğer seslerle uyumun anahtarıdır.',
        [
          'Mesafeler yarım ses sayısıyla anlatılır.',
          'Her aralık için bir solfej örneği verilir (ör. Do → Mi).',
          'Önce yukarı doğru, sonra aşağı ve birlikte çalışırsın.',
        ],
      ),
      IntroSlide(
        'Nasıl çalışılır',
        'Duyduğun iki sesi içinden ya da sesli söyle; mesafeyi bildiğin bir örnekle karşılaştır.',
        [
          'Yeni aralık önce tek başına, sonra diğerleriyle karışık gelir.',
          'Söyleme adımı ölçülmez; yalnız alışkanlık içindir.',
          'Ara durakta %80 ile önceki dersler tamamlanır.',
        ],
      ),
    ],
  ),
  TrainerKind.chord: _ladder(
    TrainerKind.chord,
    [
      const _Stage(['maj', 'min'], 'Tonal repertuvarın iki temel rengi.'),
      ..._one([
        ('dom7', 'Çözülmek isteyen dört sesli akor.'),
        ('dim', 'İki küçük 3\'lüden oluşan dar akor.'),
        ('min7', 'Minör akora eklenen 7\'li.'),
        ('maj7', 'Majör akora eklenen büyük 7\'li.'),
        ('aug', 'İki büyük 3\'lüden oluşan geniş akor.'),
        ('hdim7', 'Eksik üçlünün 7\'li hâli.'),
        ('dim7', 'Simetrik dört sesli akor.'),
      ]),
    ],
    const [
      _Drill(
        'Farklı bölgeler',
        'Akorlar pes ve tiz bölgede.',
        registers: _anyReg,
      ),
    ],
    const [
      IntroSlide(
        'Akorun niteliği',
        'Birlikte çalan seslerin oluşturduğu türü tanırsın. Akorun içindeki '
            'seslerin görevini duymak, kendi sesini doğru yere oturtmayı kolaylaştırır.',
        [
          'Her akor türü bir formülle anlatılır (ör. kök + büyük 3\'lü + tam 5\'li).',
          'Dinlerken önce sesler tek tek, sonra birlikte çalar.',
          'Söyleme adımında akorun en pes sesini mırıldanırsın.',
        ],
      ),
    ],
  ),
  TrainerKind.scale: _ladder(
    TrainerKind.scale,
    [
      const _Stage(['major', 'natural_minor'], 'Tonal müziğin iki ana dizisi.'),
      ..._one([
        ('harmonic_minor', 'Yeden sesi tizleşmiş minör.'),
        ('pentatonic_major', 'Halk ezgilerinde sık beş sesli dizi.'),
        ('dorian', 'Re\'den başlayan mod.'),
        ('mixolydian', 'Sol\'den başlayan mod.'),
        ('melodic_minor', '6. ve 7. derecesi tiz minör.'),
        ('pentatonic_minor', 'Minörden türeyen beş sesli dizi.'),
        ('lydian', 'Fa\'dan başlayan mod.'),
        ('phrygian', 'Mi\'den başlayan mod.'),
        ('blues', 'Minör pentatonik ve artık 4\'lü.'),
      ]),
    ],
    const [
      _Drill(
        'Farklı bölgeler',
        'Diziler farklı başlangıç notalarından.',
        registers: _anyReg,
      ),
    ],
    const [
      IntroSlide(
        'Dizinin yapısı',
        'Dizi, notaların tam ve yarım ses adımlarla sıralanışıdır. Hangi diziyi '
            'duyduğunu bilmek ezgiyi okumanı ve tekrar etmeni kolaylaştırır.',
        [
          'Her dizi T (tam) ve Y (yarım) adımlarla gösterilir.',
          'Diziyi belirleyen ses merdivende işaretlenir.',
          'Söyleme adımında diziyi nota adlarıyla çıkarsın.',
        ],
      ),
    ],
  ),
  TrainerKind.progression: _ladder(
    TrainerKind.progression,
    _one([
      ('I-IV-V-I', 'Tonal kadansın temel hâli.'),
      ('I-IV-I-V', 'Tonik ile alt dominant arasında gidiş geliş.'),
      ('I-V-vi-IV', 'Dominanttan 6. dereceye iniş.'),
      ('i-iv-i-V', 'Minör tonda kadans.'),
      ('I-vi-IV-V', '6. derece üzerinden kadansa.'),
      ('vi-IV-I-V', '6. derecenin minörüyle başlayan dizi.'),
      ('ii-V-I', '7\'li akorlarla kadans.'),
      ('I-iii-IV-V', '3. derece üzerinden yükseliş.'),
      ('i-VI-III-VII', 'Minör tonikten majör akorlara.'),
    ]),
    const [
      _Drill('Farklı tonlar', 'Aynı dizi başka tonlarda.', registers: _anyReg),
    ],
    const [
      IntroSlide(
        'Akorların sırası',
        'Bir eserin armonisi akorların belirli sıralarla ilerlemesidir. '
            'En pes sesin yolu çoğu zaman bu sırayı ele verir.',
        [
          'Dereceler Roma rakamıyla yazılır: büyük harf majör, küçük harf minör.',
          'Dinlerken en pes sesi takip et.',
          'Söyleme adımında bas sesini mırıldanırsın.',
        ],
      ),
    ],
  ),
};
