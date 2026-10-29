import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../audio/synth.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../settings/settings_tab.dart';
import '../ui/kit.dart';
import 'level_check.dart';
import 'samples.dart';

/// The full first-run journey. The current step is persisted so a killed
/// app resumes where the learner left off.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  /// Called when setup ends; `startLesson` = learner tapped "Begin".
  final void Function(bool startLesson) onFinished;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum Ob {
  welcome,
  intro1,
  intro2,
  intro3,
  instrument,
  level,
  aims,
  experience,
  tryIt,
  samples,
  greatJob,
  focus,
  blockers,
  minutes,
  marathon,
  goals,
  potential,
  reminder,
  allDone,
  building,
  plan,
  save,
  free,
  allSet,
  hear,
  ways,
  notation,
  prefs,
  levelCheck,
  today,
}

const _surveySteps = {
  Ob.instrument,
  Ob.level,
  Ob.aims,
  Ob.experience,
  Ob.focus,
  Ob.blockers,
  Ob.minutes,
  Ob.marathon,
  Ob.goals,
  Ob.potential,
  Ob.reminder,
};

const _setupSteps = [
  Ob.allSet,
  Ob.hear,
  Ob.ways,
  Ob.notation,
  Ob.prefs,
  Ob.levelCheck,
];

class _OnboardingFlowState extends State<OnboardingFlow> {
  Ob _step = Ob.welcome;
  bool _forward = true;
  bool _ready = false;

  Map<String, Object?> get _answers => TrainerScope.of(context).store.answers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final saved = _answers['obStep'];
    if (saved is String) {
      final s = Ob.values.asNameMap()[saved];
      // Transient screens resume at a stable neighbour.
      _step = switch (s) {
        null => Ob.welcome,
        Ob.samples => Ob.tryIt,
        Ob.building => Ob.allDone,
        Ob.levelCheck => Ob.prefs,
        _ => s,
      };
    }
  }

  void _go(Ob next, {bool forward = true}) {
    final store = TrainerScope.of(context).store;
    store.answers['obStep'] = next.name;
    store.save();
    setState(() {
      _forward = forward;
      _step = next;
    });
  }

  void _next() => _go(Ob.values[_step.index + 1]);
  void _back() {
    if (_step.index == 0) return;
    var prev = Ob.values[_step.index - 1];
    if (prev == Ob.samples) prev = Ob.tryIt;
    if (prev == Ob.building) prev = Ob.allDone;
    _go(prev, forward: false);
  }

  List<String> _list(String key) =>
      (_answers[key] as List?)?.whereType<String>().toList() ?? <String>[];

  void _toggle(String key, String value) {
    final list = _list(key);
    if (!list.remove(value)) list.add(value);
    final store = TrainerScope.of(context).store;
    store.answers[key] = list;
    store.save();
    setState(() {});
  }

  void _set(String key, Object? value) {
    final store = TrainerScope.of(context).store;
    store.answers[key] = value;
    store.save();
    setState(() {});
  }

  void _finish(bool begin) {
    final store = TrainerScope.of(context).store;
    store.onboardingDone = true;
    store.setupDone = true;
    store.answers.remove('obStep');
    store.save();
    widget.onFinished(begin);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween(
            begin: Offset(_forward ? 0.25 : -0.25, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: KeyedSubtree(key: ValueKey(_step), child: _page()),
      ),
    ),
  );

  // ---------------------------------------------------------------- pages

  Widget _page() => switch (_step) {
    Ob.welcome => _Welcome(onStart: _next),
    Ob.intro1 => _Intro(
      index: 0,
      title: 'Kulağın kötü değil,\nperde öğrenilebilir bir beceri',
      footnote: '👉 Muhtemelen sana sadece doğru çalışma yolu gösterilmedi.',
      button: 'İleri',
      onNext: _next,
      child: const _EarChart(),
    ),
    Ob.intro2 => _Intro(
      index: 1,
      title: 'Gelişmen için eğlenceli,\noyunlaştırılmış çalışma',
      button: 'İleri',
      onNext: _next,
      child: const _TrainerBubbles(),
    ),
    Ob.intro3 => _Intro(
      index: 2,
      title: 'Kulağını mükemmelleştir',
      button: 'Devam',
      onNext: _next,
      child: const _ProgressDemo(),
    ),
    Ob.instrument => _survey(
      'Hangi enstrümanı çalıyorsun?',
      [
        ('piano', '🎹', 'Piyano / Klavye'),
        ('guitar', '🎸', 'Gitar / Ukulele / Bas'),
        ('strings', '🎻', 'Yaylılar (Keman, Çello, Viyola)'),
        ('brass', '🎺', 'Trompet / Bakır üflemeli'),
        ('wood', '🎷', 'Klarnet / Tahta üflemeli'),
        ('voice', '🎤', 'Şan / Koro / Yok'),
        ('other', '🎵', 'Diğer'),
      ],
      key: 'instrument',
      multi: true,
    ),
    Ob.level => _survey('Seviyeni nasıl tanımlarsın?', [
      ('beginner', null, 'Tamamen yeni başlayan'),
      ('self', null, 'Kendi kendine öğrenen müzisyen'),
      ('hobby', null, 'Hobi / amatör'),
      ('student', null, 'Müzik öğrencisi'),
      ('pro', null, 'Profesyonel müzisyen'),
    ], key: 'level'),
    Ob.aims => _survey(
      'Neyi başarmak istiyorsun?',
      [
        ('byEar', null, 'Kulaktan çalmak'),
        ('improvise', null, 'Daha iyi doğaçlama'),
        ('compose', null, 'Beste yapmak'),
        ('pitch', null, 'Perde doğruluğunu artırmak'),
        ('theory', null, 'Müzik teorisi öğrenmek'),
        ('choir', null, 'Koroda daha güvenli söylemek'),
        ('transcribe', null, 'Şarkıları notaya dökmek'),
      ],
      key: 'aims',
      multi: true,
      subtitle: 'Uyanların hepsini seç',
    ),
    Ob.experience => _survey(
      'Ne kadar kulak eğitimi yaptın?',
      [
        ('never', null, 'Hiç denemedim'),
        ('few', null, 'Birkaç kez denedim'),
        ('sometimes', null, 'Arada bir çalışıyorum'),
        ('regular', null, 'Düzenli çalışıyorum'),
      ],
      key: 'experience',
      autoAdvance: false,
    ),
    Ob.tryIt => _TryIt(onStart: _next, onBack: _back),
    Ob.samples => OnboardingSamples(
      onBack: _back,
      onDone: (results) {
        _set('samples', results);
        _next();
      },
    ),
    Ob.greatJob => _GreatJob(onNext: _next),
    Ob.focus => _survey(
      'Neye odaklanmak istersin?',
      [
        for (final k in TrainerKind.values) (k.id, null, k.title),
        ('koro', null, 'Koro Atölyesi'),
      ],
      key: 'focus',
      multi: true,
    ),
    Ob.blockers => _survey(
      'Gelişmeni ne engelliyor?',
      [
        ('structure', null, 'Plan eksikliği'),
        ('focus', null, 'Neye odaklanacağımı bilmiyorum'),
        ('busy', null, 'Yoğun program'),
        ('consistency', null, 'Süreklilik eksikliği'),
        ('stuck', null, 'Takılıp kalmış hissediyorum'),
        ('other', null, 'Diğer'),
      ],
      key: 'blockers',
      multi: true,
    ),
    Ob.minutes => _Minutes(progress: _progress, onBack: _back, onNext: _next),
    Ob.marathon => _Shell(
      progress: _progress,
      onBack: _back,
      button: 'Devam',
      onNext: _next,
      child: _Centered(
        emoji: '🎹',
        title: 'Bu bir maraton,\nsürat koşusu değil.',
        body:
            'Harmonia en iyi her gün düzenli çalışınca işe yarar. Günde ${TrainerScope.of(context).store.dailyMinutes} dakikayla zamanla gerçek ilerleme görürsün.',
      ),
    ),
    Ob.goals => _survey(
      'Tüm hedeflerini seç',
      [
        ('steady', null, 'Perdede rahatça kalmak'),
        ('fast', null, 'Olabildiğince hızlı gelişmek'),
        ('confidence', null, 'Özgüvenimi artırmak'),
        ('doubt', null, 'Perdemden şüphe etmeyi bırakmak'),
        ('trust', null, 'Kulağıma güvenmek'),
      ],
      key: 'goals',
      multi: true,
    ),
    Ob.potential => _Shell(
      progress: _progress,
      onBack: _back,
      button: 'Gelişmeye hazırım',
      onNext: _next,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hedeflerine ulaşmak için\nbüyük bir potansiyelin var',
              textAlign: TextAlign.center,
              style: TT.h2,
            ),
            SizedBox(height: 24),
            _PotentialChart(),
          ],
        ),
      ),
    ),
    Ob.reminder => _Reminder(progress: _progress, onBack: _back, onNext: _next),
    Ob.allDone => _Shell(
      progress: 1,
      onBack: _back,
      button: 'Devam',
      onNext: _next,
      child: const _Centered(
        emoji: '👏',
        badge: 'Hepsi tamam',
        title: 'Kişisel planını\noluşturma zamanı',
      ),
    ),
    Ob.building => _Building(onDone: _next),
    Ob.plan => _Plan(onNext: _next),
    Ob.save => _Save(onNext: _next),
    Ob.free => _Free(onNext: _next),
    Ob.allSet => _Setup(
      step: 0,
      onBack: null,
      button: 'Hadi başlayalım',
      onNext: _next,
      child: const _AllSet(),
    ),
    Ob.hear => _Setup(
      step: 1,
      onBack: _back,
      onNext: _next,
      child: const _Hear(),
    ),
    Ob.ways => _Setup(
      step: 2,
      onBack: _back,
      onNext: _next,
      child: const _Ways(),
    ),
    Ob.notation => _Setup(
      step: 3,
      onBack: _back,
      onNext: _next,
      child: _NotationPick(onChanged: () => setState(() {})),
    ),
    Ob.prefs => _Setup(
      step: 4,
      onBack: _back,
      onNext: _next,
      child: _Prefs(onChanged: () => setState(() {})),
    ),
    Ob.levelCheck => LevelCheck(
      onBack: _back,
      onDone: () => _go(Ob.today),
      dots: _Dots(count: _setupSteps.length, index: 5),
    ),
    Ob.today => _Today(
      onBegin: () => _finish(true),
      onLater: () => _finish(false),
    ),
  };

  double get _progress {
    final ordered = Ob.values.where(_surveySteps.contains).toList();
    final i = ordered.indexOf(_step);
    return i < 0 ? 0.1 : (i + 1) / (ordered.length + 1);
  }

  Widget _survey(
    String title,
    List<(String, String?, String)> options, {
    required String key,
    bool multi = false,
    bool autoAdvance = true,
    String? subtitle,
  }) {
    final selected = multi
        ? _list(key)
        : [if (_answers[key] is String) _answers[key] as String];
    return _Shell(
      progress: _progress,
      onBack: _back,
      button: multi || !autoAdvance ? 'Devam' : null,
      onNext: selected.isEmpty ? null : _next,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text(title, textAlign: TextAlign.center, style: TT.h2),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TT.small),
          ],
          const SizedBox(height: 22),
          for (final (id, emoji, label) in options)
            ChoiceTile(
              key: Key('opt_$id'),
              label: label,
              leading: emoji,
              multi: multi,
              selected: selected.contains(id),
              onTap: () {
                if (multi) {
                  _toggle(key, id);
                } else {
                  _set(key, id);
                  if (autoAdvance) {
                    Future<void>.delayed(const Duration(milliseconds: 280), () {
                      if (mounted && _step != Ob.values.last) _next();
                    });
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ chrome

class _Shell extends StatelessWidget {
  const _Shell({
    required this.child,
    required this.onBack,
    this.progress,
    this.button,
    this.onNext,
  });
  final Widget child;
  final VoidCallback? onBack;
  final double? progress;
  final String? button;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            if (onBack != null)
              BackSquare(onTap: onBack)
            else
              const SizedBox(width: 36),
            const SizedBox(width: 12),
            if (progress != null)
              Expanded(
                child: ProgressBar(value: progress!, color: TC.blue),
              )
            else
              const Spacer(),
          ],
        ),
      ),
      Expanded(child: child),
      if (button != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: BigButton(
            key: const Key('ob_continue'),
            label: button!,
            onPressed: onNext,
          ),
        ),
    ],
  );
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.emoji,
    required this.title,
    this.body,
    this.badge,
  });
  final String emoji;
  final String title;
  final String? body;
  final String? badge;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 190,
          height: 190,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                const Color(0xFFBDE7FA),
                const Color(0xFFFFF4B8),
                TC.orangeSoft,
                const Color(0xFFBDE7FA),
              ],
            ),
          ),
          child: Container(
            width: 150,
            height: 150,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 76)),
          ),
        ),
        const SizedBox(height: 22),
        if (badge != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: TC.orange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                badge!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TC.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(title, textAlign: TextAlign.center, style: TT.h2),
        if (body != null) ...[
          const SizedBox(height: 12),
          Text(body!, textAlign: TextAlign.center, style: TT.body),
        ],
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  static const color = TC.orange;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == index ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: i == index ? color : const Color(0xFFD5DAE3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------- welcome

class _Welcome extends StatefulWidget {
  const _Welcome({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  int _frame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: _PhoneFrame(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                child: KeyedSubtree(
                  key: ValueKey(_frame),
                  child: switch (_frame) {
                    0 => const _MiniWord('Öğren'),
                    1 => const _MiniQuiz(),
                    2 => const _MiniWord('Pratik'),
                    _ => const _MiniStats(),
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Tahmin etmeyi bırak', style: TT.h2),
        const Text(
          'Kulaktan çalmaya başla',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: TC.blue,
          ),
        ),
        const SizedBox(height: 22),
        BigButton(
          key: const Key('get_started'),
          label: 'Başlayalım',
          onPressed: widget.onStart,
        ),
        const SizedBox(height: 8),
        const Text(
          'Hesap gerekmez · İlerlemen bu cihazda kalır',
          style: TT.small,
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child, this.width = 190});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 2.05,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: const Color(0xFF1B1D22),
      borderRadius: BorderRadius.circular(width * 0.17),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(width * 0.14),
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: width * 0.3,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MiniWord extends StatelessWidget {
  const _MiniWord(this.word);
  final String word;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      word,
      style: const TextStyle(
        color: TC.blue,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _MiniQuiz extends StatelessWidget {
  const _MiniQuiz();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 34, 10, 10),
    child: Column(
      children: [
        const Text(
          'Akor Tanıma',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const ProgressBar(value: 0.25, color: TC.purple, height: 3),
        const Spacer(),
        const Icon(Icons.check_circle_rounded, color: TC.green, size: 42),
        const Spacer(),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final c in ['maj', 'min', 'aug', 'dim', 'maj7', 'min7'])
              Container(
                width: 46,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c == 'min' ? TC.purple : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TC.line),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 9,
                    color: c == 'min' ? Colors.white : TC.ink,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

class _MiniStats extends StatelessWidget {
  const _MiniStats();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 34, 10, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'İstatistik',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final h in [0.5, 0.6, 0.45, 0.7, 0.85, 0.75, 0.3])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 50 * h,
                    color: TC.orange.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final k in TrainerKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                TrainerBadge(
                  color: trainerColor(k),
                  icon: trainerIcon(k),
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  k.shortTitle,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- intros

class _Intro extends StatelessWidget {
  const _Intro({
    required this.index,
    required this.title,
    required this.child,
    required this.button,
    required this.onNext,
    this.footnote,
  });
  final int index;
  final String title;
  final Widget child;
  final String? footnote;
  final String button;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      children: [
        const Spacer(),
        Text(title, textAlign: TextAlign.center, style: TT.h2),
        const SizedBox(height: 24),
        child,
        if (footnote != null) ...[
          const SizedBox(height: 10),
          Text(footnote!, textAlign: TextAlign.center, style: TT.small),
        ],
        const Spacer(),
        _Dots(count: 3, index: index),
        const SizedBox(height: 18),
        BigButton(
          key: const Key('ob_continue'),
          label: button,
          onPressed: onNext,
        ),
      ],
    ),
  );
}

class _EarChart extends StatelessWidget {
  const _EarChart();
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kulak doğruluğun', style: TT.h3),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) =>
                CustomPaint(size: Size.infinite, painter: _CurvesPainter(t)),
          ),
        ),
      ],
    ),
  );
}

class _CurvesPainter extends CustomPainter {
  _CurvesPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final base = size.height * 0.95;
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = TC.faint
        ..strokeWidth = 1.5,
    );
    Path curve(double Function(double) f) {
      final p = Path();
      for (var x = 0.0; x <= size.width * t; x += 2) {
        final y = f(x / size.width);
        x == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      return p;
    }

    final self = curve(
      (u) => size.height * (0.55 - 0.12 * math.sin(u * 2 * math.pi)),
    );
    final trained = curve(
      (u) => size.height * (0.6 - 0.5 * (1 - math.pow(1 - u, 2.2))),
    );
    canvas.drawPath(
      self,
      Paint()
        ..color = const Color(0xFF8E98AA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(
      trained,
      Paint()
        ..color = const Color(0xFFEA580C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    void label(String text, Color c, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at);
    }

    if (t > 0.6) {
      label(
        'Harmonia ile',
        const Color(0xFFEA580C),
        Offset(size.width * 0.12, size.height * 0.2),
      );
      label(
        'Kendi başına',
        const Color(0xFF8E98AA),
        Offset(size.width * 0.66, size.height * 0.52),
      );
    }
  }

  @override
  bool shouldRepaint(_CurvesPainter old) => old.t != t;
}

class _TrainerBubbles extends StatelessWidget {
  const _TrainerBubbles();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const _PhoneFrame(width: 150, child: _MiniQuiz()),
      const SizedBox(height: 14),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final k in TrainerKind.values)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: trainerColor(k),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                k.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: TC.indigo,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Koro Atölyesi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _ProgressDemo extends StatelessWidget {
  const _ProgressDemo();
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aralık Eğitimi', style: TT.h3),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final c in ['Genel', 'm2', 'M2', 'm3', 'M3'])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c == 'Genel' ? TC.blue : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c == 'Genel' ? TC.blue : TC.line),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 12,
                    color: c == 'Genel' ? Colors.white : TC.ink,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            builder: (context, t, _) =>
                CustomPaint(size: Size.infinite, painter: _StepsPainter(t)),
          ),
        ),
        const Center(
          child: Text(
            'Örnek 3 haftalık eğri (gösterim amaçlı)',
            style: TT.small,
          ),
        ),
      ],
    ),
  );
}

class _StepsPainter extends CustomPainter {
  _StepsPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    const ys = [0.85, 0.55, 0.52, 0.55, 0.48, 0.3, 0.05];
    final pts = [
      for (var i = 0; i < ys.length; i++)
        Offset(size.width * i / (ys.length - 1), size.height * ys[i]),
    ];
    final n = (pts.length * t).ceil().clamp(1, pts.length);
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = TC.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(pts[i], 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        pts[i],
        6,
        Paint()
          ..color = TC.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_StepsPainter old) => old.t != t;
}

// ---------------------------------------------------------------- try it

class _TryIt extends StatelessWidget {
  const _TryIt({required this.onStart, required this.onBack});
  final VoidCallback onStart;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => _Shell(
    onBack: onBack,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        const Text('Çalışmayı dene', textAlign: TextAlign.center, style: TT.h2),
        const SizedBox(height: 8),
        const Text(
          'Beş kısa alıştırma. Seni sadece sınamıyoruz, her sesi hatırlamayı öğretiyoruz.',
          textAlign: TextAlign.center,
          style: TT.small,
        ),
        const SizedBox(height: 20),
        for (final (i, k) in TrainerKind.values.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TrainerBadge(
                        color: trainerColor(k),
                        icon: trainerIcon(k),
                        size: 48,
                      ),
                      Positioned(
                        left: -6,
                        top: -6,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: TC.line),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.title, style: TT.title),
                        Text(k.pitchLine, style: TT.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Sınırsız deneme. İstediğin alıştırmayı atlayabilirsin.',
          textAlign: TextAlign.center,
          style: TT.small,
        ),
        const SizedBox(height: 12),
        BigButton(
          key: const Key('try_it'),
          label: 'Dene',
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
        ),
      ],
    ),
  );
}

class _GreatJob extends StatelessWidget {
  const _GreatJob({required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      children: [
        const Text('🏆', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        const Text('Harika iş!', style: TT.h1),
        const SizedBox(height: 4),
        const Text('Temel çalışmaları deneyimledin.', style: TT.body),
        const SizedBox(height: 20),
        for (final k in TrainerKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: trainerColor(k),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: k.title, style: TT.title),
                          TextSpan(text: '  ·  ${k.tagline}', style: TT.small),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          'Sadece testlerle değil, şarkı kancaları ve hafıza ipuçlarıyla öğretilir.',
          textAlign: TextAlign.center,
          style: TT.small,
        ),
        const Spacer(),
        const Text('Sırada planını kurmak var.', style: TT.small),
        const SizedBox(height: 10),
        BigButton(
          key: const Key('ob_continue'),
          label: 'Devam',
          chevron: true,
          onPressed: onNext,
        ),
      ],
    ),
  );
}

class _Minutes extends StatelessWidget {
  const _Minutes({
    required this.progress,
    required this.onBack,
    required this.onNext,
  });
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return StatefulBuilder(
      builder: (context, setLocal) => _Shell(
        progress: progress,
        onBack: onBack,
        button: 'Devam',
        onNext: onNext,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Her gün ne kadar\nçalışmak istersin?',
                textAlign: TextAlign.center,
                style: TT.h2,
              ),
              const SizedBox(height: 8),
              const Text(
                'Çoğu kişi için günde 8 dakika ideal.',
                style: TT.small,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF55C1F0), TC.blue],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: TC.blue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  '${store.dailyMinutes} dk',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: TC.blue,
                  inactiveTrackColor: const Color(0xFFE2E6EE),
                  thumbColor: Colors.white,
                  overlayColor: TC.blue.withValues(alpha: 0.1),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                    elevation: 3,
                  ),
                ),
                child: Slider(
                  min: 2,
                  max: 20,
                  divisions: 18,
                  value: store.dailyMinutes.toDouble(),
                  semanticFormatterCallback: (v) => '${v.round()} dakika',
                  onChanged: (v) {
                    store.dailyMinutes = v.round();
                    store.save();
                    setLocal(() {});
                  },
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('2 DK', style: TT.caps),
                  Text('20 DK', style: TT.caps),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PotentialChart extends StatelessWidget {
  const _PotentialChart();
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kulak doğruluğun', style: TT.h3),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1600),
            curve: Curves.easeInOut,
            builder: (context, t, _) =>
                CustomPaint(size: Size.infinite, painter: _GrowthPainter(t)),
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('3 gün', style: TT.small),
            Text('1 hafta', style: TT.small),
            Text('3+ hafta', style: TT.small),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Gösterim amaçlı bir eğridir; gerçek gelişimin İstatistik sekmesinde kendi cevaplarından hesaplanır.',
          style: TT.small,
        ),
      ],
    ),
  );
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = TC.line
      ..strokeWidth = 1;
    for (final y in [0.3, 0.6]) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y),
        dash,
      );
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = TC.faint
        ..strokeWidth = 1.5,
    );
    final path = Path();
    for (var x = 0.0; x <= size.width * t; x += 2) {
      final u = x / size.width;
      final y =
          size.height * (0.6 - 0.5 * (1 / (1 + math.exp(-10 * (u - 0.45)))));
      x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFF4B400)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(0, size.height * 0.6),
      6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(0, size.height * 0.6),
      6,
      Paint()
        ..color = const Color(0xFFF4B400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_GrowthPainter old) => old.t != t;
}

class _Reminder extends StatefulWidget {
  const _Reminder({
    required this.progress,
    required this.onBack,
    required this.onNext,
  });
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onNext;
  @override
  State<_Reminder> createState() => _ReminderState();
}

class _ReminderState extends State<_Reminder> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    await setReminder(context, true);
    if (mounted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) => _Shell(
    progress: widget.progress,
    onBack: widget.onBack,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Çalışmayı hatırlatalım', style: TT.h2),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Text(
                    'Harmonia her akşam 19:00\'da kısa bir hatırlatma göndersin mi?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, color: TC.ink),
                  ),
                ),
                const Divider(height: 1),
                SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const Key('reminder_skip'),
                          onPressed: _busy ? null : widget.onNext,
                          child: const Text(
                            'İzin verme',
                            style: TextStyle(color: TC.ink, fontSize: 16),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: TC.orange,
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(24),
                          ),
                          child: InkWell(
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(24),
                            ),
                            onTap: _busy ? null : _allow,
                            child: const Center(
                              child: Text(
                                'İzin ver',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('👆', style: TextStyle(fontSize: 28)),
        ],
      ),
    ),
  );
}

class _Building extends StatefulWidget {
  const _Building({required this.onDone});
  final VoidCallback onDone;
  @override
  State<_Building> createState() => _BuildingState();
}

class _BuildingState extends State<_Building>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4200),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final level = switch (store.answers['level']) {
      'beginner' => 'yeni başlayan',
      'self' => 'kendi kendine öğrenen müzisyen',
      'hobby' => 'hobi müzisyeni',
      'pro' => 'profesyonel müzisyen',
      _ => 'müzik öğrencisi',
    };
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 170,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TC.orangeSoft,
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Text('🎸', style: TextStyle(fontSize: 70)),
          ),
          const SizedBox(height: 26),
          const Text(
            'Günlük rutinin hazırlanıyor',
            textAlign: TextAlign.center,
            style: TT.h2,
          ),
          const SizedBox(height: 4),
          Text('$level olarak', style: TT.small),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Column(
              children: [
                ProgressBar(value: _c.value, color: TC.blue, height: 10),
                const SizedBox(height: 18),
                Text(
                  _c.value < 0.35
                      ? 'Hedeflerin inceleniyor'
                      : _c.value < 0.7
                      ? 'Alıştırmalar hazırlanıyor'
                      : 'Deneyimin kişiselleştiriliyor',
                  style: TT.title,
                ),
              ],
            ),
          ),
          const Spacer(),
          const Text('Lütfen uygulamayı kapatma', style: TT.small),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final samples = store.answers['samples'];
    var weakest = TrainerKind.interval;
    if (samples is Map) {
      for (final k in TrainerKind.values) {
        if (samples[k.id] != true) {
          weakest = k;
          break;
        }
      }
    }
    store.answers['weakest'] = weakest.id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: TC.teal,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tebrikler!',
                  textAlign: TextAlign.center,
                  style: TT.h1,
                ),
                const Text(
                  'Kişisel planın hazır',
                  textAlign: TextAlign.center,
                  style: TT.small,
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _PlanPainter(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.check_rounded, color: TC.blue, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Eğlenceli, oyunlaştırılmış çalışmayla gelişim',
                              style: TT.title,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Deneme cevaplarına ve hedeflerine göre 30 günlük yolun:',
                  textAlign: TextAlign.center,
                  style: TT.small,
                ),
                const SizedBox(height: 12),
                _PlanRow(
                  color: trainerColor(weakest),
                  icon: Icons.hearing_rounded,
                  title: 'Başlangıç odağın',
                  body:
                      'Denemede en çok zorlandığın alan ${weakest.title.toLowerCase()} oldu; planın oradan başlıyor.',
                ),
                _PlanRow(
                  color: TC.purple,
                  icon: Icons.track_changes_rounded,
                  title: 'Günlük çalışma hedefi',
                  body:
                      'Günde ${store.dailyMinutes} dakika; kalıcı alışkanlık için her gün kısa çalış.',
                ),
                if ((store.answers['focus'] as List?)?.contains('koro') ==
                        true ||
                    (store.answers['aims'] as List?)?.contains('choir') == true)
                  const _PlanRow(
                    color: TC.indigo,
                    icon: Icons.groups_rounded,
                    title: 'Koro hazırlığı',
                    body:
                        'Ses aralığı testi, ritim, ezgi ve aksak ritim çalışmaları Koro Atölyesi\'nde.',
                  ),
              ],
            ),
          ),
          BigButton(
            key: const Key('ob_continue'),
            label: 'Planımı başlat',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      child: Row(
        children: [
          TrainerBadge(color: color, icon: icon, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TT.title),
                Text(body, style: TT.small),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(8, size.height - 10);
    path.quadraticBezierTo(
      size.width * 0.55,
      size.height - 10,
      size.width - 8,
      8,
    );
    final fill = Path.from(path)
      ..lineTo(size.width - 8, size.height)
      ..lineTo(8, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = TC.blue.withValues(alpha: 0.18));
    canvas.drawPath(
      path,
      Paint()
        ..color = TC.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(Offset(8, size.height - 10), 5, Paint()..color = TC.blue);
    void label(String text, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 6, at.dy - 3, tp.width + 12, tp.height + 6),
          const Radius.circular(6),
        ),
        Paint()..color = TC.blue,
      );
      tp.paint(canvas, at);
    }

    label('Sen (bugün)', Offset(14, size.height - 52));
    label('Hedeflerin 🎉', Offset(size.width * 0.5, 14));
  }

  @override
  bool shouldRepaint(_PlanPainter old) => false;
}

class _Save extends StatelessWidget {
  const _Save({required this.onNext});
  final VoidCallback onNext;

  void _unavailable(BuildContext context) => showTrainerSheet<void>(
    context,
    (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hesaplar yakında',
          textAlign: TextAlign.center,
          style: TT.h3,
        ),
        const SizedBox(height: 8),
        const Text(
          'Apple, Google ya da e-posta ile giriş için sunucu bağlantısı henüz açılmadı. İlerlemen bu cihazda güvenle saklanıyor; hesaplar açılınca aktarabileceksin.',
          textAlign: TextAlign.center,
          style: TT.body,
        ),
        const SizedBox(height: 16),
        BigButton(
          label: 'Misafir olarak devam et',
          onPressed: () {
            Navigator.pop(context);
            onNext();
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Spacer(),
        const Text('İlerlemeni kaydet', style: TT.h2),
        const SizedBox(height: 28),
        _AuthButton(
          label: 'Apple ile giriş yap',
          icon: Icons.apple,
          dark: true,
          onTap: () => _unavailable(context),
        ),
        _AuthButton(
          label: 'Google ile giriş yap',
          icon: Icons.g_mobiledata_rounded,
          onTap: () => _unavailable(context),
        ),
        _AuthButton(
          label: 'E-posta ile devam et',
          icon: Icons.mail_outline_rounded,
          onTap: () => _unavailable(context),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Daha sonra mı giriş yapmak istersin? ',
              style: TT.small,
            ),
            GestureDetector(
              key: const Key('save_skip'),
              onTap: onNext,
              child: const Text(
                'Atla',
                style: TextStyle(
                  color: TC.ink,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const Spacer(flex: 2),
        const Text('Koşullar · Gizlilik', style: TT.small),
      ],
    ),
  );
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: dark ? Colors.black : Colors.white,
          foregroundColor: dark ? Colors.white : TC.ink,
          side: BorderSide(color: dark ? Colors.black : TC.line, width: 1.5),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, size: 24),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    ),
  );
}

class _Free extends StatelessWidget {
  const _Free({required this.onNext});
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      children: [
        const Text(
          'Beta boyunca her şey ücretsiz',
          textAlign: TextAlign.center,
          style: TT.h2,
        ),
        const Text(
          'herkes kulağını eğitebilsin diye',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: TC.blue,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: const [
              _FreeRow(
                Icons.school_outlined,
                'Beş eğitmenin tüm dersleri',
                '150+ ders, kontrol noktası ve final sınavı',
              ),
              _FreeRow(
                Icons.tune_rounded,
                'Sınırsız pratik',
                'Kendi notalarını, aralıklarını ve akorlarını seç',
              ),
              _FreeRow(
                Icons.groups_outlined,
                'Koro Atölyesi',
                'Ses aralığı testi, ritim, ezgi ve aksak ritim',
              ),
              _FreeRow(
                Icons.bar_chart_rounded,
                'Ayrıntılı istatistik',
                'Öğe bazında güçlü ve zayıf yönlerin',
              ),
              SizedBox(height: 10),
              Text(
                'Harmonia Plus ve fiyatlandırma henüz açılmadı. Bu ekranda ödeme alınmaz, abonelik başlatılmaz.',
                textAlign: TextAlign.center,
                style: TT.small,
              ),
            ],
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_rounded, size: 18),
            SizedBox(width: 6),
            Text('Ödeme yok', style: TT.title),
          ],
        ),
        const SizedBox(height: 10),
        BigButton(
          key: const Key('ob_continue'),
          label: 'Ücretsiz devam et',
          color: const Color(0xFFEF5A0C),
          onPressed: onNext,
        ),
      ],
    ),
  );
}

class _FreeRow extends StatelessWidget {
  const _FreeRow(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: TC.orangeSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: TC.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TT.title),
                Text(body, style: TT.small),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- setup

class _Setup extends StatelessWidget {
  const _Setup({
    required this.step,
    required this.child,
    required this.onBack,
    required this.onNext,
    this.button = 'İleri',
  });
  final int step;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final String button;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: BackSquare(onTap: onBack),
                ),
              _Dots(count: _setupSteps.length, index: step),
            ],
          ),
        ),
      ),
      Expanded(child: child),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: BigButton(
          key: const Key('ob_continue'),
          label: button,
          chevron: true,
          onPressed: onNext,
        ),
      ),
    ],
  );
}

class _AllSet extends StatelessWidget {
  const _AllSet();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF2F4F7)),
              ),
            ),
            Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TC.orangeSoft,
              ),
            ),
            const TrainerBadge(
              color: TC.orange,
              icon: Icons.music_note_rounded,
              size: 110,
            ),
            const Positioned(
              top: 20,
              left: 40,
              child: CircleAvatar(radius: 5, backgroundColor: TC.purple),
            ),
            const Positioned(
              top: 50,
              right: 10,
              child: CircleAvatar(radius: 6, backgroundColor: TC.blue),
            ),
            const Positioned(
              bottom: 50,
              left: 16,
              child: CircleAvatar(radius: 4, backgroundColor: TC.teal),
            ),
            const Positioned(
              bottom: 40,
              right: 36,
              child: CircleAvatar(radius: 3, backgroundColor: TC.orange),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Her şey hazır!', style: TT.h1),
        const SizedBox(height: 8),
        const Text(
          'Harmonia\'ya hoş geldin. Kulak eğitimi yolculuğun şimdi başlıyor.',
          textAlign: TextAlign.center,
          style: TT.body,
        ),
      ],
    ),
  );
}

class _SetupList extends StatelessWidget {
  const _SetupList({
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    children: [
      Text(title, style: TT.h1),
      const SizedBox(height: 6),
      Text(subtitle, style: TT.body),
      const SizedBox(height: 22),
      ...children,
    ],
  );
}

class _Hear extends StatelessWidget {
  const _Hear();
  @override
  Widget build(BuildContext context) => const _SetupList(
    title: 'Müziği gerçekten duymayı öğren',
    subtitle:
        'Harmonia dinlemeyi çaldığın, söylediğin ve yazdığın her an kullanacağın bir beceriye dönüştürür.',
    children: [
      _IconRow(
        Icons.graphic_eq_rounded,
        TC.orange,
        'Notaları kulaktan tanı',
        'Sonra aralıkları, akorları ve dizileri',
      ),
      _IconRow(
        Icons.queue_music_rounded,
        TC.blue,
        'Akortlu çal ve söyle',
        'Her perdeye güvenle kilitlen',
      ),
      _IconRow(
        Icons.auto_awesome_rounded,
        TC.purple,
        'Her şarkıyı çöz',
        'Değişimleri duy ve eşlik et',
      ),
      _IconRow(
        Icons.groups_rounded,
        TC.indigo,
        'Korona hazırlan',
        'Sesini, ritmi ve çok sesli dokuyu tanı',
      ),
    ],
  );
}

class _IconRow extends StatelessWidget {
  const _IconRow(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: soft(color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TT.title),
              Text(body, style: TT.small),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Ways extends StatelessWidget {
  const _Ways();
  @override
  Widget build(BuildContext context) => _SetupList(
    title: 'Kulağını eğitmenin altı yolu',
    subtitle: 'Her eğitmen farklı bir dinleme becerisi kurar. Sırayla ustalaş.',
    children: [
      for (final (i, k) in TrainerKind.values.indexed)
        _WayCard(
          index: i + 1,
          color: trainerColor(k),
          icon: trainerIcon(k),
          title: k.title,
          body: k.pitchLine,
        ),
      const _WayCard(
        index: 6,
        color: TC.indigo,
        icon: Icons.groups_rounded,
        title: 'Koro Atölyesi',
        body: 'Ses aralığı, ritim, ezgi, aksak',
      ),
    ],
  );
}

class _WayCard extends StatelessWidget {
  const _WayCard({
    required this.index,
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });
  final int index;
  final Color color;
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: soft(color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TT.title),
                Text(body, style: TT.small),
              ],
            ),
          ),
          Text(
            index.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: TC.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _NotationPick extends StatelessWidget {
  const _NotationPick({required this.onChanged});
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    Widget card(NoteNotation n, String big, String small) {
      final selected = store.notation == n;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          key: Key('notation_${n.name}'),
          color: selected ? TC.orangeSoft : Colors.white,
          border: selected ? TC.orange : TC.line,
          onTap: () {
            store.notation = n;
            store.save();
            onChanged();
          },
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      big,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      small,
                      style: TextStyle(
                        color: selected ? TC.orange : TC.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? TC.orange : TC.faint,
                size: 28,
              ),
            ],
          ),
        ),
      );
    }

    return _SetupList(
      title: 'Notaları nasıl gösterelim?',
      subtitle: 'Hangisi okuması doğal geliyorsa onu seç.',
      children: [
        card(NoteNotation.solfege, 'Do  Re  Mi', 'Solfej'),
        card(NoteNotation.letter, 'C  D  E', 'Harf isimleri'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: TC.body),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bunu Ayarlar\'dan istediğin zaman değiştirebilirsin',
                  style: TT.small,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Prefs extends StatelessWidget {
  const _Prefs({required this.onChanged});
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final scope = TrainerScope.of(context);
    final store = scope.store;
    const icons = {
      Timbre.piano: Icons.piano_rounded,
      Timbre.guitar: Icons.music_note_rounded,
      Timbre.cello: Icons.queue_music_rounded,
      Timbre.clarinet: Icons.graphic_eq_rounded,
      Timbre.trumpet: Icons.campaign_outlined,
      Timbre.sine: Icons.waves_rounded,
    };
    return _SetupList(
      title: 'Birkaç hızlı tercih',
      subtitle: 'Çalışmanın hissini ayarla.',
      children: [
        const Text('ENSTRÜMAN SESİ', style: TT.caps),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in Timbre.values)
                  SizedBox(
                    width: w,
                    child: AppCard(
                      key: Key('timbre_${t.name}'),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: store.timbre == t ? TC.orangeSoft : Colors.white,
                      border: store.timbre == t ? TC.orange : TC.line,
                      onTap: () {
                        store.timbre = t;
                        scope.audio.timbre = t;
                        store.save();
                        scope.audio.play(
                          SoundFactory(
                            math.Random(),
                          ).chord('maj', rootMidi: 60, arpeggiate: true),
                        );
                        onChanged();
                      },
                      child: Column(
                        children: [
                          Icon(
                            icons[t],
                            color: store.timbre == t ? TC.orange : TC.body,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t.label,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const Text('PRATİK AYARI', style: TT.caps),
        const SizedBox(height: 10),
        AppCard(
          onTap: () {
            store.transposition = (store.transposition + 1) % 12;
            store.save();
            onChanged();
          },
          child: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: TC.body),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transpozisyon', style: TT.title),
                    Text(
                      'Hangi notayı Do olarak duyacağını seç',
                      style: TT.small,
                    ),
                  ],
                ),
              ),
              Text(
                PitchClass.name(store.transposition, store.notation),
                style: TT.title,
              ),
              const Icon(Icons.chevron_right_rounded, color: TC.faint),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.keyboard_outlined, color: TC.body),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Klavye', style: TT.title),
                    Text('Notaları piyano tuşlarıyla cevapla', style: TT.small),
                  ],
                ),
              ),
              Switch.adaptive(
                value: store.keyboard,
                activeTrackColor: TC.blue,
                onChanged: (v) {
                  store.keyboard = v;
                  store.save();
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.onBegin, required this.onLater});
  final VoidCallback onBegin;
  final VoidCallback onLater;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final weakest = TrainerKind.values.firstWhere(
      (k) => k.id == store.answers['weakest'],
      orElse: () => TrainerKind.interval,
    );
    store.lastTrainer ??= weakest.id;
    final next = store.nextNode(weakest);
    final lesson = next?.kind.name == 'intro'
        ? store.nextNodeAfterIntro(weakest)
        : next;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUGÜN · ~${store.dailyMinutes} DK',
            style: const TextStyle(
              color: TC.orange,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Bugünkü oturumun', style: TT.h1),
          const SizedBox(height: 4),
          const Text(
            'Hafıza kontrolü, tekrar, sonra yeni bir şey.',
            style: TT.body,
          ),
          const SizedBox(height: 24),
          _TodayRow(
            icon: Icons.star_outline_rounded,
            color: TC.orange,
            title: 'Öğren',
            count: weakest.title,
            body: 'Yeni ders · ${lesson?.title ?? 'Giriş'}',
          ),
          Container(
            margin: const EdgeInsets.only(left: 21),
            width: 2,
            height: 18,
            color: TC.line,
          ),
          const _TodayRow(
            icon: Icons.track_changes_rounded,
            color: TC.purple,
            title: 'Pratik',
            count: '10 soru',
            body: 'Sadece yeni ses',
          ),
          const Spacer(),
          BigButton(
            key: const Key('today_session_begin'),
            label: 'Başla',
            icon: Icons.play_arrow_rounded,
            onPressed: onBegin,
          ),
          Center(child: TextLink('Ana sayfaya git', onTap: onLater)),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.count,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String count;
  final String body;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: soft(color)),
        child: Icon(icon, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: TT.title),
                const SizedBox(width: 8),
                Tag(count.toUpperCase(), color: color),
              ],
            ),
            Text(body, style: TT.small),
          ],
        ),
      ),
    ],
  );
}
