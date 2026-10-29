import 'music.dart';
import 'trainers.dart';

enum NodeKind { intro, lesson, checkpoint, finalExam }

/// One stop on a trainer's guided path. Draft content: not educator-approved.
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

  /// Items introduced by this lesson (focus of the learn cards).
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

const _w = PitchClass.whiteKeys;
const _all12 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
const _anyReg = [Register.low, Register.medium, Register.high];

List<String> _pcs(List<int> pcs) => [for (final p in pcs) '$p'];

class _B {
  _B(this.trainer);
  final TrainerKind trainer;
  final nodes = <LessonNode>[];
  int _n = 0;

  void intro(String title, String subtitle) => nodes.add(
    LessonNode(
      id: '${trainer.id}-intro',
      trainer: trainer,
      kind: NodeKind.intro,
      title: title,
      subtitle: subtitle,
    ),
  );

  void lesson(
    String title,
    String subtitle,
    List<String> items, {
    List<String>? newItems,
    List<Register> registers = const [Register.medium],
    IntervalDirection direction = IntervalDirection.ascending,
  }) {
    _n++;
    nodes.add(
      LessonNode(
        id: '${trainer.id}-l$_n',
        trainer: trainer,
        kind: NodeKind.lesson,
        title: '$_n. $title',
        subtitle: subtitle,
        items: items,
        newItems: newItems ?? items,
        registers: registers,
        direction: direction,
      ),
    );
  }

  void checkpoint(
    String title,
    String subtitle,
    List<String> items, {
    List<Register> registers = const [Register.medium],
    IntervalDirection direction = IntervalDirection.ascending,
  }) => nodes.add(
    LessonNode(
      id: '${trainer.id}-cp${nodes.where((n) => n.isGate).length + 1}',
      trainer: trainer,
      kind: NodeKind.checkpoint,
      title: title,
      subtitle: subtitle,
      items: items,
      registers: registers,
      direction: direction,
    ),
  );

  void finalExam(
    String title,
    List<String> items, {
    List<Register> registers = _anyReg,
    IntervalDirection direction = IntervalDirection.mixed,
  }) => nodes.add(
    LessonNode(
      id: '${trainer.id}-final',
      trainer: trainer,
      kind: NodeKind.finalExam,
      title: title,
      subtitle: 'Final sınavı',
      items: items,
      registers: registers,
      direction: direction,
    ),
  );
}

TrainerPath _pitchPath() {
  final b = _B(TrainerKind.pitch)
    ..intro('Giriş: Nota Eğitimi', 'Nota eğitimi nedir, nasıl çalışır?');
  b
    ..lesson('Orta Do', 'Piyanonun merkezi.', _pcs([0]))
    ..lesson(
      'Do ve Sol',
      'Sol\'ü ekle. En güçlü ikili.',
      _pcs([0, 7]),
      newItems: _pcs([7]),
    )
    ..lesson(
      'Majör üçlü',
      'Mi\'yi ekle. Artık bir akorun var.',
      _pcs([0, 4, 7]),
      newItems: _pcs([4]),
    )
    ..lesson(
      'Pentatonik başlangıç',
      'Re ve La. Yanlış nota yok.',
      _pcs([0, 2, 4, 7, 9]),
      newItems: _pcs([2, 9]),
    )
    ..lesson('Fa ve Si', 'Gerilim notaları.', _pcs(_w), newItems: _pcs([5, 11]))
    ..checkpoint('Orta Do majör', 'Tüm beyaz tuşlar, orta oktav.', _pcs(_w))
    ..lesson(
      'Fa♯ (parlak, gergin)',
      'Parlak ve keskin.',
      _pcs([..._w, 6]),
      newItems: _pcs([6]),
    )
    ..lesson(
      'Si♭ (yumuşak, bluesy)',
      'Yumuşak ve pes.',
      _pcs([..._w, 6, 10]),
      newItems: _pcs([10]),
    )
    ..lesson(
      'Mi♭ (hüzünlü)',
      'Hüzün.',
      _pcs([..._w, 6, 10, 3]),
      newItems: _pcs([3]),
    )
    ..lesson(
      'La♭ ve Re♭',
      'Karanlık taraf.',
      _pcs(_all12),
      newItems: _pcs([8, 1]),
    )
    ..checkpoint('Kromatik orta', '12 notanın hepsi, orta oktav.', _pcs(_all12))
    ..lesson(
      'Pes Do ve Sol',
      'Do ve Sol, ama derinde.',
      _pcs([0, 7]),
      registers: [Register.low],
    )
    ..lesson(
      'Pes üçlü',
      'Gürültüde Mi\'yi duyabilir misin?',
      _pcs([0, 4, 7]),
      registers: [Register.low],
    )
    ..lesson(
      'Pes dizi',
      'Tüm beyaz tuşlar, pes.',
      _pcs(_w),
      registers: [Register.low],
    )
    ..checkpoint(
      'Bodrum',
      'Pes oktav ustalığı.',
      _pcs(_w),
      registers: [Register.low],
    )
    ..lesson(
      'Tiz Do ve Sol',
      'Do ve Sol, kristal netliğinde.',
      _pcs([0, 7]),
      registers: [Register.high],
    )
    ..lesson(
      'Tiz üçlü',
      'Mi burada çok parlak.',
      _pcs([0, 4, 7]),
      registers: [Register.high],
    )
    ..lesson(
      'Tiz dizi',
      'Tüm beyaz tuşlar, tiz.',
      _pcs(_w),
      registers: [Register.high],
    )
    ..checkpoint(
      'Çatı katı',
      'Tiz oktav ustalığı.',
      _pcs(_w),
      registers: [Register.high],
    )
    ..lesson(
      'Rastgele Do / Sol',
      'Her oktavda. Kanma.',
      _pcs([0, 7]),
      registers: _anyReg,
    )
    ..lesson(
      'Rastgele üçlü',
      'Do, Mi, Sol klavyenin her yerinde.',
      _pcs([0, 4, 7]),
      registers: _anyReg,
    )
    ..lesson(
      'Rastgele pentatonik',
      'Halk notaları, her yerde.',
      _pcs([0, 2, 4, 7, 9]),
      registers: _anyReg,
    )
    ..lesson(
      'Rastgele beyaz tuşlar',
      'Yedi beyaz tuş, tamamen açık.',
      _pcs(_w),
      registers: _anyReg,
    )
    ..checkpoint(
      'Beyaz tuş ustalığı',
      'Tüm beyaz tuşlar, her oktav.',
      _pcs(_w),
      registers: _anyReg,
    )
    ..lesson(
      'Rastgele Fa♯ ve Si♭',
      'Yaygın arızalar.',
      _pcs([..._w, 6, 10]),
      registers: _anyReg,
    )
    ..lesson(
      'Rastgele siyah tuşlar',
      'Yalnız pentatonik siyahlar.',
      _pcs(PitchClass.blackKeys),
      registers: _anyReg,
    )
    ..checkpoint(
      'Kromatik ustalık',
      'Tüm siyah tuşlar, her oktav.',
      _pcs(_all12),
      registers: _anyReg,
    )
    ..lesson(
      'Yarım ses çatışmaları',
      'Mi–Fa, Si–Do. Her oktav.',
      _pcs([4, 5, 11, 0]),
      registers: _anyReg,
    )
    ..lesson(
      'Triton',
      'Fa–Si. En zor aralık.',
      _pcs([5, 11]),
      registers: _anyReg,
    )
    ..lesson(
      'Küme',
      'Do, Re♭, Re. Yakın kromatik gruplar.',
      _pcs([0, 1, 2]),
      registers: _anyReg,
    )
    ..finalExam('Mutlak ses', _pcs(_all12));
  return TrainerPath(TrainerKind.pitch, b.nodes, const [
    IntroSlide(
      'Nota eğitimi nedir?',
      'Her notanın kendine ait bir rengi vardır. Bu renkleri tek tek '
          'öğrenerek bir notayı duyunca adını söyleyebilirsin.',
      [
        'Önce merkezdeki Do\'yu ezberlersin.',
        'Sonra her derste bir nota eklenir.',
        'Kontrol noktaları bölümü bildiğini kanıtlamanı sağlar.',
      ],
    ),
    IntroSlide(
      'Nasıl dinlemeli?',
      'Notayı içinden tekrar et. Parlak mı, karanlık mı, gergin mi?',
      [
        'Notanın hissine odaklan, hesap yapma.',
        'Yanlış cevap öğrenmenin parçası; karşılaştır ve devam et.',
        'Kısa ve her gün çalışmak en hızlısıdır.',
      ],
    ),
  ]);
}

List<String> _iv(List<String> ids) => ids;

TrainerPath _intervalPath() {
  const desc = IntervalDirection.descending;
  const mixed = IntervalDirection.mixed;
  final b = _B(TrainerKind.interval)
    ..intro('Giriş: Aralık Eğitimi', 'Aralık tanıma nedir, nasıl çalışır?');
  b
    ..lesson('Oktav (P8)', 'Aynı nota, daha tiz.', _iv(['P8']))
    ..lesson(
      'Tam 5\'li (P5)',
      'Sağlam ve güçlü.',
      _iv(['P8', 'P5']),
      newItems: ['P5'],
    )
    ..lesson(
      'Oktav mı 5\'li mi?',
      'İki sütunu ayırt et.',
      _iv(['P8', 'P5']),
      newItems: [],
    )
    ..lesson(
      'Tam 4\'lü (P4)',
      'Sağlam ama hareket ister.',
      _iv(['P8', 'P5', 'P4']),
      newItems: ['P4'],
    )
    ..lesson('Tam aralıklar', 'P4 ve P5.', _iv(['P4', 'P5']), newItems: [])
    ..lesson(
      'Çapalar, yukarıdan',
      'P8, P5, P4 inen.',
      _iv(['P8', 'P5', 'P4']),
      newItems: [],
      direction: desc,
    )
    ..checkpoint(
      'Tam aralıklar',
      'P4, P5, P8; inen ve çıkan.',
      _iv(['P4', 'P5', 'P8']),
      direction: mixed,
    )
    ..lesson(
      'Büyük 3\'lü (M3)',
      'Mutlu ve parlak.',
      _iv(['P4', 'P5', 'P8', 'M3']),
      newItems: ['M3'],
    )
    ..lesson(
      'Küçük 3\'lü (m3)',
      'Hüzünlü ve melankolik.',
      _iv(['P4', 'P5', 'M3', 'm3']),
      newItems: ['m3'],
    )
    ..lesson(
      'Mutlu mu hüzünlü mü?',
      'M3 ile m3.',
      _iv(['M3', 'm3']),
      newItems: [],
    )
    ..lesson(
      'Majör üçlü parçaları',
      'M3 ile P5.',
      _iv(['M3', 'P5']),
      newItems: [],
    )
    ..lesson(
      'Minör üçlü parçaları',
      'm3 ile P5.',
      _iv(['m3', 'P5']),
      newItems: [],
    )
    ..lesson(
      'Üçlüler, yukarıdan',
      'M3 ve m3 inen.',
      _iv(['M3', 'm3']),
      newItems: [],
      direction: desc,
    )
    ..checkpoint(
      'Üçlüler ve tamlar',
      'm3, M3, P4, P5, P8; iki yön.',
      _iv(['m3', 'M3', 'P4', 'P5', 'P8']),
      direction: mixed,
    )
    ..lesson(
      'Büyük 2\'li (M2)',
      'Tam ses.',
      _iv(['M2', 'm3', 'M3']),
      newItems: ['M2'],
    )
    ..lesson(
      'Küçük 2\'li (m2)',
      'Yarım ses. Gerilim.',
      _iv(['m2', 'M2', 'm3', 'M3']),
      newItems: ['m2'],
    )
    ..lesson(
      'Adım mı sıçrama mı?',
      'M2 ile M3.',
      _iv(['M2', 'M3']),
      newItems: [],
    )
    ..lesson(
      'Küçük aralıklar',
      'm2, M2, m3.',
      _iv(['m2', 'M2', 'm3']),
      newItems: [],
    )
    ..lesson(
      'Adımlar, yukarıdan',
      'M2 ve m2 inen.',
      _iv(['m2', 'M2']),
      newItems: [],
      direction: desc,
    )
    ..checkpoint(
      'Küçük aralıklar',
      '4\'lüye kadar, iki yön.',
      _iv(['m2', 'M2', 'm3', 'M3', 'P4']),
      direction: mixed,
    )
    ..lesson(
      'Büyük 6\'lı (M6)',
      'Tatlı ve pastoral.',
      _iv(['M6', 'P5', 'P8']),
      newItems: ['M6'],
    )
    ..lesson(
      'Küçük 6\'lı (m6)',
      'Duygusal ve romantik.',
      _iv(['m6', 'M6', 'P5']),
      newItems: ['m6'],
    )
    ..lesson(
      'Uyumlu aralıklar',
      '3\'lüler ve 6\'lılar.',
      _iv(['m3', 'M3', 'm6', 'M6']),
      newItems: [],
    )
    ..checkpoint(
      'Uyum',
      'Tüm hoş aralıklar.',
      _iv(['m3', 'M3', 'P4', 'P5', 'm6', 'M6', 'P8']),
    )
    ..lesson(
      'Büyük 7\'li (M7)',
      'Rüya gibi esneme.',
      _iv(['M7', 'M6', 'P8']),
      newItems: ['M7'],
    )
    ..lesson(
      'Küçük 7\'li (m7)',
      'Funky esneme.',
      _iv(['m7', 'M7', 'M6']),
      newItems: ['m7'],
    )
    ..lesson(
      'Geniş aralıklar',
      'M6, m7, M7, P8.',
      _iv(['M6', 'm7', 'M7', 'P8']),
      newItems: [],
    )
    ..lesson('Uçlar', 'm2 ile M7.', _iv(['m2', 'M7']), newItems: [])
    ..checkpoint(
      'Esnemeler',
      'm2, M6, m7, M7, P8.',
      _iv(['m2', 'M6', 'm7', 'M7', 'P8']),
    )
    ..lesson(
      'Artık 4\'lü (A4)',
      'Müzikteki şeytan.',
      _iv(['A4', 'P4', 'P5']),
      newItems: ['A4'],
    )
    ..lesson(
      'Uyumsuzluk kontrolü',
      'm2, A4, M7.',
      _iv(['m2', 'A4', 'M7']),
      newItems: [],
    )
    ..checkpoint(
      'Tam kromatik',
      '12 aralığın hepsi, kontrollü.',
      Intervals.all.map((i) => i.id).toList(),
    )
    ..lesson(
      '2\'li ve 3\'lüler (rastgele)',
      'Küçük aralıklar, her oktav.',
      _iv(['m2', 'M2', 'm3', 'M3']),
      newItems: [],
      registers: _anyReg,
    )
    ..lesson(
      'Tamlar (rastgele)',
      'P4, P5, P8 her oktav.',
      _iv(['P4', 'P5', 'P8']),
      newItems: [],
      registers: _anyReg,
    )
    ..lesson(
      '6\'lı ve 7\'liler (rastgele)',
      'Geniş aralıklar, her oktav.',
      _iv(['m6', 'M6', 'm7', 'M7']),
      newItems: [],
      registers: _anyReg,
    )
    ..lesson(
      'Sıçramalar, yukarıdan',
      '6\'lılar, 7\'liler ve triton inen.',
      _iv(['m6', 'M6', 'm7', 'M7', 'A4']),
      newItems: [],
      direction: desc,
    )
    ..lesson(
      'Her yön',
      'Her aralık, çıkan ya da inen.',
      Intervals.all.map((i) => i.id).toList(),
      newItems: [],
      direction: mixed,
    )
    ..checkpoint(
      'Her yön',
      '12 aralık, çıkan ya da inen.',
      Intervals.all.map((i) => i.id).toList(),
      direction: mixed,
    )
    ..finalExam(
      'Final: Mutlak ustalık',
      Intervals.all.map((i) => i.id).toList(),
    );
  return TrainerPath(TrainerKind.interval, b.nodes, const [
    IntroSlide(
      'Aralık nedir?',
      'Aralık iki nota arasındaki mesafedir. Nota eğitimi sana tek notaları '
          'öğretti; şimdi aradaki boşlukları öğreneceksin. Bu boşlukları '
          'duyarsan bir ezgiyi kulaktan çıkarabilirsin.',
      [
        'Her ezgi aralıklardan oluşur: notadan notaya sıçramalar.',
        'Aralık büyüklüğü yarım seslerle sayılır.',
        'Her aralığın kendi büyüklüğü ve hissi vardır.',
      ],
    ),
    IntroSlide(
      'Duymanın iki yolu',
      'Bir aralığı hep aynı sırayla duyarsın: pes nota, tiz nota, sonra '
          'ikisi birlikte.',
      [
        'Ayrı çalınca sıçramayı, ikinci notanın ne kadar uzağa gittiğini duyarsın.',
        'Birlikte çalınca karışımı, ne kadar yumuşak ya da gergin olduğunu duyarsın.',
        'İki ipucu da aynı cevaba çıkar.',
      ],
      highlight: ['sıçramayı', 'karışımı'],
    ),
    IntroSlide(
      'Bildiğin şarkılara yaslan',
      'Bir aralığı akılda tutmanın en hızlı yolu onu o aralıkla başlayan '
          'bir şarkıya bağlamaktır.',
      [
        'Tam 5\'li "Twinkle Twinkle" ve Star Wars temasını açar.',
        'Her ders sana böyle bir kanca verir.',
        'Kancayı mırıldan, aralığı bul.',
      ],
    ),
  ]);
}

TrainerPath _chordPath() {
  const low = [Register.low];
  final b = _B(TrainerKind.chord)
    ..intro('Giriş: Akor Tanıma', 'Akor tanıma nedir, nasıl çalışır?');
  b
    ..lesson('Majör üçlü', 'Mutlu, parlak, dengeli.', ['maj'])
    ..lesson(
      'Minör üçlü',
      'Hüzünlü, ciddi, melankolik.',
      ['maj', 'min'],
      newItems: ['min'],
    )
    ..lesson('Mutlu mu hüzünlü mü?', 'Majör ile minör.', [
      'maj',
      'min',
    ], newItems: [])
    ..checkpoint('Temel üçlüler', 'Majör ve minör ustalığı.', ['maj', 'min'])
    ..lesson(
      'Eksik üçlü',
      'Gergin, ürkütücü, kararsız.',
      ['maj', 'min', 'dim'],
      newItems: ['dim'],
    )
    ..lesson(
      'Artık üçlü',
      'Rüya gibi, havada.',
      ['maj', 'min', 'dim', 'aug'],
      newItems: ['aug'],
    )
    ..lesson('Tuhaf ikili', 'Eksik ile artık.', ['dim', 'aug'], newItems: [])
    ..checkpoint('Tüm üçlüler', 'Maj, min, dim, aug.', [
      'maj',
      'min',
      'dim',
      'aug',
    ])
    ..lesson(
      'Majör 7\'li',
      'Caz, tatlı, nostaljik.',
      ['maj', 'maj7'],
      newItems: ['maj7'],
    )
    ..lesson(
      'Dominant 7\'li',
      'Bluesy, gerilimli, güçlü.',
      ['maj', 'maj7', 'dom7'],
      newItems: ['dom7'],
    )
    ..lesson('Maj7 mi Dom7 mi?', 'Tatlı mı bluesy mi?', [
      'maj7',
      'dom7',
    ], newItems: [])
    ..lesson(
      'Minör 7\'li',
      'Yumuşak, serin, rahat.',
      ['min', 'maj7', 'dom7', 'min7'],
      newItems: ['min7'],
    )
    ..lesson('Dom7 mi Min7 mi?', 'Gerilim mi serinlik mi?', [
      'dom7',
      'min7',
    ], newItems: [])
    ..checkpoint('Yaygın 7\'liler', 'Maj7, Dom7, Min7.', [
      'maj7',
      'dom7',
      'min7',
    ])
    ..lesson(
      'Yarım eksik (m7♭5)',
      'Karanlık, gizemli.',
      ['min7', 'hdim7', 'dom7'],
      newItems: ['hdim7'],
    )
    ..lesson(
      'Eksik 7\'li',
      'Korku, köşeli, simetrik.',
      ['hdim7', 'dim7', 'min7'],
      newItems: ['dim7'],
    )
    ..lesson('Eksikler düellosu', 'Yarım eksik ile tam eksik.', [
      'hdim7',
      'dim7',
    ], newItems: [])
    ..checkpoint('Tüm 7\'liler', 'Maj7, m7, Dom7, ø7, °7.', [
      'maj7',
      'min7',
      'dom7',
      'hdim7',
      'dim7',
    ])
    ..lesson(
      'Pes üçlüler',
      'Çamurda majör ve minör.',
      ['maj', 'min'],
      newItems: [],
      registers: low,
    )
    ..lesson(
      'Pes gerilim',
      'Eksik ve artık, derinde.',
      ['dim', 'aug'],
      newItems: [],
      registers: low,
    )
    ..lesson(
      'Pes 7\'liler',
      'Karmaşık akorlar, pes frekans.',
      ['maj7', 'min7', 'dom7'],
      newItems: [],
      registers: low,
    )
    ..checkpoint(
      'Gümbürtü',
      'Tüm akorlar, pes oktav.',
      Chords.all.map((c) => c.id).toList(),
      registers: low,
    )
    ..lesson(
      'Rastgele üçlüler',
      'Her üçlü, rastgele oktav.',
      ['maj', 'min', 'dim', 'aug'],
      newItems: [],
      registers: _anyReg,
    )
    ..lesson(
      'Rastgele 7\'liler',
      'Her 7\'li, rastgele oktav.',
      ['maj7', 'min7', 'dom7', 'hdim7', 'dim7'],
      newItems: [],
      registers: _anyReg,
    )
    ..finalExam('Final: Armonik ustalık', Chords.all.map((c) => c.id).toList());
  return TrainerPath(TrainerKind.chord, b.nodes, const [
    IntroSlide(
      'Akor nedir?',
      'Akor, birlikte çalınan üç ya da daha fazla notadır. Her akor '
          'niteliğinin kendine özgü bir duygusu vardır.',
      [
        'Majör mutlu, minör hüzünlü duyulur.',
        'Eksik ve artık akorlar gerilim yaratır.',
        '7\'li akorlar renk ve derinlik katar.',
      ],
    ),
    IntroSlide(
      'Nasıl dinlemeli?',
      'Notaları tek tek saymaya çalışma; akorun bütün hissine odaklan.',
      [
        'Önce parlak mı karanlık mı karar ver.',
        'Sonra kararlı mı gergin mi diye sor.',
        'Karışırsan iki akoru arka arkaya dinle.',
      ],
    ),
  ]);
}

TrainerPath _scalePath() {
  final b = _B(TrainerKind.scale)
    ..intro('Giriş: Dizi Tanıma', 'Dizi tanıma nedir, neden önemli?');
  const f4 = ['major', 'natural_minor', 'harmonic_minor', 'melodic_minor'];
  const d8 = [...f4, 'dorian', 'phrygian', 'lydian', 'mixolydian'];
  final all = Scales.all.map((s) => s.id).toList();
  b
    ..lesson('Majör mü doğal minör mü?', 'Müzikteki en temel karşıtlık.', [
      'major',
      'natural_minor',
    ])
    ..lesson(
      'Armonik minör',
      'Dramatik yükseltilmiş 7. derece.',
      ['major', 'natural_minor', 'harmonic_minor'],
      newItems: ['harmonic_minor'],
    )
    ..lesson(
      'Melodik minör',
      'En akıcı minör dizi.',
      f4,
      newItems: ['melodic_minor'],
    )
    ..lesson('Armonik mi melodik mi?', 'Zorlu minör karşılaştırması.', [
      'harmonic_minor',
      'melodic_minor',
    ], newItems: [])
    ..lesson('Dördü birlikte', 'Dört temel diziyi karıştır.', f4, newItems: [])
    ..checkpoint('Temel', 'Majör, doğal, armonik ve melodik minör.', f4)
    ..lesson(
      'Dorian',
      'Daha parlak 6\'lı minör.',
      [...f4, 'dorian'],
      newItems: ['dorian'],
    )
    ..lesson(
      'Frigyen',
      'En karanlık mod.',
      [...f4, 'dorian', 'phrygian'],
      newItems: ['phrygian'],
    )
    ..lesson('Dorian mı Frigyen mi?', 'İkisi de minör, bir nota fark.', [
      'dorian',
      'phrygian',
    ], newItems: [])
    ..lesson('Minör modlar', 'Tüm minör renkler birlikte.', [
      'natural_minor',
      'harmonic_minor',
      'melodic_minor',
      'dorian',
      'phrygian',
    ], newItems: [])
    ..checkpoint('Minör modlar', 'Majör, üç minör, Dorian, Frigyen.', [
      ...f4,
      'dorian',
      'phrygian',
    ])
    ..lesson(
      'Lidyen',
      'Rüya gibi yükseltilmiş 4\'lü majör.',
      ['major', 'lydian'],
      newItems: ['lydian'],
    )
    ..lesson(
      'Miksolidyen',
      'Pes 7\'li majör.',
      ['major', 'lydian', 'mixolydian'],
      newItems: ['mixolydian'],
    )
    ..lesson(
      'Lidyen mi Miksolidyen mi?',
      'İkisi de majör, birer nota farklı.',
      ['lydian', 'mixolydian'],
      newItems: [],
    )
    ..lesson(
      'Tüm diyatonikler',
      'Sekiz diyatonik dizi birlikte.',
      d8,
      newItems: [],
    )
    ..checkpoint('Diyatonik ustalık', 'Sekiz diyatonik dizi, her kök.', d8)
    ..lesson(
      'Majör pentatonik',
      'Her zaman uyan beş nota.',
      ['major', 'pentatonic_major'],
      newItems: ['pentatonic_major'],
    )
    ..lesson(
      'Minör pentatonik',
      'Rock ve bluesun beygiri.',
      ['natural_minor', 'pentatonic_major', 'pentatonic_minor'],
      newItems: ['pentatonic_minor'],
    )
    ..lesson(
      'Blues',
      'Minör pentatonik artı blue nota.',
      ['pentatonic_minor', 'blues'],
      newItems: ['blues'],
    )
    ..lesson(
      'Pentatonik mi diyatonik mi?',
      'Seyrek ile dolu: boşlukları duy.',
      ['major', 'natural_minor', 'pentatonic_major', 'pentatonic_minor'],
      newItems: [],
    )
    ..checkpoint('11 dizinin hepsi', 'Her dizi, her kök.', all)
    ..lesson(
      'Pes register',
      '11 dizi pes oktavda.',
      all,
      newItems: [],
      registers: [Register.low],
    )
    ..lesson(
      'Tiz register',
      '11 dizi tiz oktavda.',
      all,
      newItems: [],
      registers: [Register.high],
    )
    ..finalExam('Final: Her dizi, her ton', all);
  return TrainerPath(TrainerKind.scale, b.nodes, const [
    IntroSlide(
      'Dizi nedir?',
      'Dizi, bir ana notadan tırmandığın sabit bir adım kalıbıdır; bir '
          'şarkının üzerine kurulduğu notalar. Diziyi bulursan hangi '
          'notaların uyacağını bilirsin.',
      [
        'Dizi kök notasından başlar ve adım adım tırmanır.',
        'Kökten yukarı her nota bir derecedir: 1., 2., 3. ...',
        'Her adım tam ses ya da yarım sestir.',
      ],
      highlight: ['kök', 'derece', 'tam ses', 'yarım ses'],
    ),
    IntroSlide(
      'Bir nota her şeyi değiştirir',
      'Dizilerin çoğu tek notası oynatılmış bir majör ya da minördür; o '
          'tek nota bütün rengi taşır.',
      [
        'Bir dereceyi yükselt ya da alçalt, bildiğin dizi yeni bir mod olur.',
        'O değişen nota renk notasıdır; merdivende vurgulanır.',
        'Renk notasını öğren, diziyi adlandır.',
      ],
      highlight: ['mod', 'renk notası'],
    ),
  ]);
}

TrainerPath _progressionPath() {
  final b = _B(TrainerKind.progression)
    ..intro('Giriş: Akor Yürüyüşleri', 'Yürüyüşler nedir, nasıl duyulur?');
  const majors = ['I-IV-V-I', 'I-V-vi-IV', 'I-vi-IV-V', 'ii-V-I'];
  const minors = ['i-VI-III-VII', 'i-iv-i-V'];
  final all = Progressions.all.map((p) => p.id).toList();
  b
    ..lesson('I-IV-V-I', 'Klasik kadans.', ['I-IV-V-I'])
    ..lesson(
      'I-V-vi-IV',
      'Pop dizisi.',
      ['I-IV-V-I', 'I-V-vi-IV'],
      newItems: ['I-V-vi-IV'],
    )
    ..lesson('Kadans mı pop mu?', 'İki temel kalıp.', [
      'I-IV-V-I',
      'I-V-vi-IV',
    ], newItems: [])
    ..lesson(
      'I-vi-IV-V',
      '50\'ler dizisi.',
      majors.sublist(0, 3),
      newItems: ['I-vi-IV-V'],
    )
    ..lesson('ii-V-I', 'Cazın kadansı.', majors, newItems: ['ii-V-I'])
    ..checkpoint('Pop ve caz', 'Dört majör kalıp.', majors)
    ..lesson(
      'vi-IV-I-V',
      'Minörden başlayan pop.',
      [...majors, 'vi-IV-I-V'],
      newItems: ['vi-IV-I-V'],
    )
    ..lesson(
      'I-iii-IV-V',
      'Yumuşak merdiven.',
      ['I-iii-IV-V', 'I-IV-V-I'],
      newItems: ['I-iii-IV-V'],
    )
    ..lesson(
      'I-IV-I-V',
      'Halk gidişi.',
      ['I-IV-I-V', 'I-IV-V-I'],
      newItems: ['I-IV-I-V'],
    )
    ..checkpoint(
      'Majör kalıplar',
      'Tüm majör yürüyüşler.',
      all.where((p) => !p.startsWith('i-')).toList(),
    )
    ..lesson(
      'i-iv-i-V',
      'Armonik minör kadansı.',
      ['i-iv-i-V', 'I-IV-V-I'],
      newItems: ['i-iv-i-V'],
    )
    ..lesson(
      'i-VI-III-VII',
      'Destansı minör.',
      minors,
      newItems: ['i-VI-III-VII'],
    )
    ..checkpoint('Minör kalıplar', 'Minör yürüyüşler.', minors)
    ..lesson(
      'Hepsi birlikte',
      'Dokuz yürüyüşün hepsi.',
      all,
      newItems: [],
      registers: _anyReg,
    )
    ..finalExam('Final: Yürüyüş ustalığı', all);
  return TrainerPath(TrainerKind.progression, b.nodes, const [
    IntroSlide(
      'Akor yürüyüşü nedir?',
      'Yürüyüş, bir şarkıda akorların sırasıdır. Romen rakamları her '
          'akorun tondaki yerini gösterir.',
      [
        'I evdir; V eve dönmek ister.',
        'Büyük harf majör, küçük harf minör akordur.',
        'Bas notayı takip et: yürüyüşün yolunu çizer.',
      ],
    ),
  ]);
}

final Map<TrainerKind, TrainerPath> trainerPaths = {
  TrainerKind.pitch: _pitchPath(),
  TrainerKind.interval: _intervalPath(),
  TrainerKind.chord: _chordPath(),
  TrainerKind.scale: _scalePath(),
  TrainerKind.progression: _progressionPath(),
};
