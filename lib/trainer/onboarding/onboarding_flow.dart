import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../home/daily_route.dart';
import '../settings/settings_tab.dart';
import '../ui/kit.dart';

/// Harmonia's short first run: how you use Harmonia, your vocal range
/// (optional), what to train and how often. Personal practice is the same
/// for every role; the choir module is separate (ADR-035). The current step is persisted so a killed app resumes there.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  /// Called when setup ends; `startLesson` = learner tapped the first lesson.
  final void Function(bool startLesson) onFinished;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum Ob { welcome, role, part, focus, notation, minutes, reminder, ready }

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
    if (saved is String) _step = Ob.values.asNameMap()[saved] ?? Ob.welcome;
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
    if (_step.index > 0) _go(Ob.values[_step.index - 1], forward: false);
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

  void _finish(bool begin) {
    final store = TrainerScope.of(context).store;
    final first = TrainerKind.values
        .where((k) => _list('focus').contains(k.id))
        .firstOrNull;
    store.lastTrainer ??= (first ?? TrainerKind.interval).id;
    store.onboardingDone = true;
    store.setupDone = true;
    store.answers.remove('obStep');
    store.save();
    widget.onFinished(begin);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TC.canvas,
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween(
            begin: Offset(0, _forward ? 0.06 : -0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: KeyedSubtree(key: ValueKey(_step), child: _page()),
      ),
    ),
  );

  Widget _page() {
    final store = TrainerScope.of(context).store;
    return switch (_step) {
      Ob.welcome => _Welcome(onStart: _next),
      Ob.role => _choices(
        'Harmonia\'yı nasıl kullanacaksın?',
        'Ses, nefes ve kulak çalışması herkes için aynı. '
            'Koro ödevleri ayrı bir sekmede açılır.',
        [
          (
            'solo',
            Icons.person_outline_rounded,
            'Sesimi ve kulağımı geliştirmek istiyorum',
          ),
          ('musician', Icons.piano_outlined, 'Enstrüman çalıyorum'),
          ('singer', Icons.mic_none_rounded, 'Bir koroda söylüyorum'),
          ('conductor', Icons.groups_outlined, 'Koro şefi / eğitmeniyim'),
        ],
        selected: [if (_answers['role'] is String) _answers['role'] as String],
        onTap: (id) {
          store.answers['role'] = id;
          store.save();
          setState(() {});
        },
      ),
      Ob.part => _choices(
        'Sesin hangi aralığa yakın?',
        'Dersler bu aralıkta çalar; tenor ve bas bir oktav pesten duyar. '
            'Bilmiyorsan atla, Ses sekmesindeki testle sonra bulursun.',
        [
          for (final p in VoicePart.values)
            (p.name, Icons.graphic_eq_rounded, p.title),
        ],
        selected: [?store.voicePart],
        optional: true,
        onTap: (id) {
          // Tapping the chosen range again clears it.
          store.voicePart = store.voicePart == id ? null : id;
          store.save();
          setState(() {});
        },
      ),
      Ob.focus => _choices(
        'Önce neye odaklanalım?',
        'Birden fazla seçebilirsin.',
        [
          ('voice', Icons.graphic_eq_rounded, 'Ses: aralık, ritim, ezgi'),
          for (final k in TrainerKind.values) (k.id, trainerIcon(k), k.title),
        ],
        selected: _list('focus'),
        multi: true,
        onTap: (id) => _toggle('focus', id),
      ),
      Ob.notation => _Frame(
        step: _step,
        onBack: _back,
        onNext: _next,
        title: 'Notaları nasıl yazalım?',
        subtitle: 'Ayarlar\'dan istediğin zaman değiştirebilirsin.',
        child: Column(
          children: [
            for (final (n, big, small) in [
              (NoteNotation.solfege, 'Do  Re  Mi', 'Solfej'),
              (NoteNotation.letter, 'C  D  E', 'Harf isimleri'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  key: Key('notation_${n.name}'),
                  border: store.notation == n ? TC.primary : null,
                  color: store.notation == n ? TC.primarySoft : Colors.white,
                  onTap: () {
                    store.notation = n;
                    store.save();
                    setState(() {});
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          big,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: TC.ink,
                          ),
                        ),
                      ),
                      Text(small, style: TT.small),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      Ob.minutes => _Frame(
        step: _step,
        onBack: _back,
        onNext: _next,
        title: 'Günde kaç dakika ayırabilirsin?',
        subtitle:
            'Kısa ama her gün çalışmak, uzun ama seyrek çalışmaktan iyidir.',
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final m in const [3, 5, 10, 15, 20])
              ChoiceChip(
                key: Key('minutes_$m'),
                label: Text('$m dk'),
                selected: store.dailyMinutes == m,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: store.dailyMinutes == m ? Colors.white : TC.ink,
                ),
                selectedColor: TC.primary,
                backgroundColor: Colors.white,
                side: const BorderSide(color: TC.line),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                onSelected: (_) {
                  store.dailyMinutes = m;
                  store.save();
                  setState(() {});
                },
              ),
          ],
        ),
      ),
      Ob.reminder => _Reminder(step: _step, onBack: _back, onNext: _next),
      Ob.ready => _Ready(
        onBegin: () => _finish(true),
        onLater: () => _finish(false),
      ),
    };
  }

  Widget _choices(
    String title,
    String subtitle,
    List<(String, IconData, String)> options, {
    required List<String> selected,
    required ValueChanged<String> onTap,
    bool multi = false,
    bool optional = false,
  }) => _Frame(
    step: _step,
    onBack: _back,
    onNext: selected.isEmpty && !optional ? null : _next,
    button: selected.isEmpty && optional ? 'Atla' : 'Devam',
    title: title,
    subtitle: subtitle,
    child: Column(
      children: [
        for (final (id, icon, label) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              key: Key('opt_$id'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: selected.contains(id) ? TC.primary : null,
              color: selected.contains(id) ? TC.primarySoft : Colors.white,
              onTap: () => onTap(id),
              child: Row(
                children: [
                  Icon(icon, color: TC.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: TT.title)),
                  Icon(
                    selected.contains(id)
                        ? (multi
                              ? Icons.check_box_rounded
                              : Icons.radio_button_checked_rounded)
                        : (multi
                              ? Icons.check_box_outline_blank_rounded
                              : Icons.radio_button_unchecked_rounded),
                    color: selected.contains(id) ? TC.primary : TC.faint,
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Shared page frame: step counter, title, scrollable body, continue button.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.step,
    required this.onBack,
    required this.title,
    required this.child,
    this.subtitle,
    this.onNext,
    this.button = 'Devam',
  });
  final Ob step;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onNext;
  final String? button;

  /// Steps between welcome and ready.
  static const _count = 6;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            BackSquare(onTap: onBack),
            const SizedBox(width: 14),
            for (var i = 0; i < _count; i++)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < step.index ? TC.primary : TC.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Text('${step.index}/$_count', style: TT.small),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          children: [
            Text(title, style: TT.h2),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: TT.body),
            ],
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
      if (button != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: BigButton(
            key: const Key('ob_continue'),
            label: button!,
            onPressed: onNext,
          ),
        ),
    ],
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const _ChoirMark(),
        const SizedBox(height: 32),
        const Text(
          'Sesini ve kulağını\nher gün geliştir',
          style: TextStyle(
            fontFamily: 'Bricolage',
            fontSize: 34,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: TC.ink,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Nefesini hazırla, kulağını eğit, ritmi ve ezgiyi tekrar et. '
          'Ölçemediğimiz şeyi puanlamayız.',
          style: TT.body,
        ),
        const Spacer(flex: 2),
        BigButton(
          key: const Key('get_started'),
          label: 'Başlayalım',
          onPressed: onStart,
        ),
        const SizedBox(height: 8),
        const Text(
          'Hesap gerekmez · veriler bu cihazda kalır',
          textAlign: TextAlign.center,
          style: TT.small,
        ),
      ],
    ),
  );
}

/// Four stacked voice lines (S/A/T/B) as the welcome illustration.
class _ChoirMark extends StatelessWidget {
  const _ChoirMark();
  @override
  Widget build(BuildContext context) {
    const parts = [
      ('S', TC.coral, 0.92),
      ('A', TC.amber, 0.74),
      ('T', TC.teal, 0.58),
      ('B', TC.primary, 0.44),
    ];
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, color, width) in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: width,
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Reminder extends StatefulWidget {
  const _Reminder({
    required this.step,
    required this.onBack,
    required this.onNext,
  });
  final Ob step;
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
  Widget build(BuildContext context) => _Frame(
    step: widget.step,
    onBack: widget.onBack,
    title: 'Günlük hatırlatma ister misin?',
    subtitle:
        'Her akşam 19:00\'da tek bir bildirim. Ayarlar\'dan kapatabilirsin.',
    button: null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BigButton(
          key: const Key('reminder_allow'),
          label: 'Hatırlat',
          icon: Icons.notifications_active_outlined,
          busy: _busy,
          onPressed: _allow,
        ),
        const SizedBox(height: 6),
        TextLink(
          'Şimdilik hayır',
          key: const Key('reminder_skip'),
          onTap: _busy ? () {} : widget.onNext,
        ),
      ],
    ),
  );
}

class _Ready extends StatelessWidget {
  const _Ready({required this.onBegin, required this.onLater});
  final VoidCallback onBegin;
  final VoidCallback onLater;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final focus =
        (store.answers['focus'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final trainer =
        TrainerKind.values.where((k) => focus.contains(k.id)).firstOrNull ??
        TrainerKind.interval;
    final role = store.answers['role'];
    final rows = [
      (
        Icons.mic_none_rounded,
        'Aralık',
        store.part?.title ?? 'Seçilmedi · Ses sekmesinde test et',
      ),
      (trainerIcon(trainer), 'İlk ders', trainer.title),
      if (DailyRoute.forMinutes(store.dailyMinutes).voiceStep)
        (Icons.graphic_eq_rounded, 'Ses', 'Rotanın sonunda bir ses adımı'),
      (Icons.timer_outlined, 'Günlük', '${store.dailyMinutes} dakika'),
      // Honest about the choir module: not built yet (ADR-035).
      if (role == 'singer' || role == 'conductor')
        (Icons.groups_outlined, 'Koro', 'Koro modülü henüz yok'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('HAZIR', style: TT.caps),
          const SizedBox(height: 4),
          const Text('Planın kuruldu', style: TT.h1),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                for (final (icon, label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(icon, color: TC.primary),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 70,
                          child: Text(label, style: TT.small),
                        ),
                        Expanded(child: Text(value, style: TT.title)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          BigButton(
            key: const Key('today_session_begin'),
            label: 'İlk derse başla',
            icon: Icons.play_arrow_rounded,
            onPressed: onBegin,
          ),
          Center(child: TextLink('Ana sayfaya git', onTap: onLater)),
        ],
      ),
    );
  }
}
