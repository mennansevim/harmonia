import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../home/daily_route.dart';
import '../koro/range_test.dart';
import '../settings/settings_tab.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';
import '../../domain/lang.dart';

/// Vocalart's short first run: how you use Vocalart, your vocal range
/// (optional), what to train and how often. Personal practice is the same
/// for every role; the choir module is separate (ADR-035). The current step is persisted so a killed app resumes there.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  /// Called when setup ends; `startLesson` = learner tapped the first lesson.
  final void Function(bool startLesson) onFinished;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum Ob { welcome, role, part, focus, minutes, reminder, ready }

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
    // 'notation' was a step until DESIGN-08; resume just after it.
    if (saved is String) {
      _step = saved == 'notation'
          ? Ob.minutes
          : Ob.values.asNameMap()[saved] ?? Ob.welcome;
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

  String? _measuredRange(TrainerStore store) {
    final r = store.koroRange?.split('-').map(int.tryParse).toList();
    if (r == null || r.length != 2 || r.contains(null)) return null;
    return '${PitchClass.midiName(r[0]!, store.notation)} – '
        '${PitchClass.midiName(r[1]!, store.notation)}';
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
      Ob.welcome => _Welcome(
        onStart: () {
          // No notation question: Do Re Mi in Turkish, C D E in English.
          // Settings can change it.
          store.notation = Lang.en ? NoteNotation.letter : NoteNotation.solfege;
          _next();
        },
      ),
      Ob.role => _choices(
        tr('Vocalart\'ı nasıl kullanacaksın?', 'How will you use Vocalart?'),
        tr(
          'Ses, nefes ve kulak çalışması herkes için aynı. '
              'Koro ödevleri ayrı bir sekmede açılır.',
          'Voice, breath and ear work is the same for everyone. '
              'Choir assignments open in a separate tab.',
        ),
        [
          (
            'solo',
            Ic.userRound,
            tr(
              'Sesimi ve kulağımı geliştirmek istiyorum',
              'I want to improve my voice and ear',
            ),
          ),
          (
            'musician',
            Ic.piano,
            tr('Enstrüman çalıyorum', 'I play an instrument'),
          ),
          ('singer', Ic.mic, tr('Bir koroda söylüyorum', 'I sing in a choir')),
          (
            'conductor',
            Ic.users,
            tr('Koro şefi / eğitmeniyim', 'I am a conductor / teacher'),
          ),
        ],
        selected: [if (_answers['role'] is String) _answers['role'] as String],
        onTap: (id) {
          store.answers['role'] = id;
          store.save();
          setState(() {});
        },
      ),
      // No voice-group question: the range is measured, or skipped (ADR-040).
      Ob.part => _Frame(
        step: _step,
        onBack: _back,
        onNext: _next,
        button: store.koroRange == null
            ? tr('Atla', 'Skip')
            : tr('Devam', 'Continue'),
        title: tr('Ses aralığını ölçelim', 'Let us measure your range'),
        subtitle: tr(
          'Piyano bir nota çalar, sen tekrar edersin; birkaç dakika sürer. '
              'Dersler ölçülen aralıkta çalar. İstersen atla, Ses sekmesinden '
              'sonra ölçersin.',
          'The piano plays a note and you repeat it; it takes a few minutes. '
              'Lessons then play in the measured range. Skip it if you like '
              'and measure later in the Voice tab.',
        ),
        child: _RangeStep(
          measured: _measuredRange(store),
          onMeasure: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RangeTestScreen()),
          ),
        ),
      ),
      Ob.focus => _choices(
        tr('Önce neye odaklanalım?', 'What should we focus on first?'),
        tr('Birden fazla seçebilirsin.', 'You can pick more than one.'),
        [
          (
            'voice',
            Ic.audioLines,
            tr('Ses: aralık, ritim, ezgi', 'Voice: range, rhythm, melody'),
          ),
          for (final k in TrainerKind.values) (k.id, trainerIcon(k), k.title),
        ],
        selected: _list('focus'),
        multi: true,
        onTap: (id) => _toggle('focus', id),
      ),
      Ob.minutes => _Frame(
        step: _step,
        onBack: _back,
        onNext: _next,
        title: tr(
          'Günde kaç dakika ayırabilirsin?',
          'How many minutes a day can you spare?',
        ),
        subtitle: tr(
          'Kısa ama her gün çalışmak, uzun ama seyrek çalışmaktan iyidir.',
          'A little every day beats a lot now and then.',
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final m in const [3, 5, 10, 15, 20])
              ChoiceChip(
                key: Key('minutes_$m'),
                label: Text(tr('$m dk', '$m min')),
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
    button: selected.isEmpty && optional
        ? tr('Atla', 'Skip')
        : tr('Devam', 'Continue'),
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
                        ? (multi ? Ic.squareCheck : Ic.circleDot)
                        : (multi ? Ic.square : Ic.circle),
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
class _RangeStep extends StatelessWidget {
  const _RangeStep({required this.measured, required this.onMeasure});
  final String? measured;
  final VoidCallback onMeasure;
  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('ob_measure_range'),
    padding: const EdgeInsets.all(16),
    border: measured == null ? null : TC.primary,
    color: measured == null ? Colors.white : TC.primarySoft,
    onTap: onMeasure,
    child: Row(
      children: [
        const Icon(Ic.mic, color: TC.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                measured == null
                    ? tr('Şimdi ölç', 'Measure now')
                    : tr('Ölçüldü: $measured', 'Measured: $measured'),
                style: TT.title,
              ),
              const SizedBox(height: 2),
              Text(
                measured == null
                    ? tr(
                        'Dinle ve tekrar et · mikrofon',
                        'Listen and repeat · microphone',
                      )
                    : tr('Tekrar ölçmek için dokun', 'Tap to measure again'),
                style: TT.small,
              ),
            ],
          ),
        ),
        const Icon(Ic.chevronRight, color: TC.muted),
      ],
    ),
  );
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.step,
    required this.onBack,
    required this.title,
    required this.child,
    this.subtitle,
    this.onNext,
    this.button,
    this.showButton = true,
  });
  final Ob step;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onNext;
  final String? button;
  final bool showButton;

  /// Steps between welcome and ready.
  static const _count = 5;

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
      if (showButton)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: BigButton(
            key: const Key('ob_continue'),
            label: button ?? tr('Devam', 'Continue'),
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
  Widget build(BuildContext context) => FitOrScroll(child: _content());

  Widget _content() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const TrainerBadge(color: TC.primary, icon: Ic.music2, size: 64),
        const SizedBox(height: 24),
        Text(
          tr(
            'Sesini ve kulağını\nher gün geliştir',
            'Grow your voice\nand ear every day',
          ),
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 34,
            height: 1.1,
            fontWeight: FontWeight.w400,
            color: TC.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr(
            'Günde birkaç dakika, kendi hızında. Ne yapacağını her gün Bugün sekmesi söyler.',
            'A few minutes a day, at your pace. The Today tab tells you what to do each day.',
          ),
          style: TT.body,
        ),
        const SizedBox(height: 24),
        // What the app offers, in the order the tabs show it.
        for (final (icon, title, body) in [
          (
            Ic.ear,
            tr('Kulak', 'Ear'),
            tr(
              'Nota, aralık, akor ve dizi; kısa derslerle',
              'Notes, intervals, chords and scales in short lessons',
            ),
          ),
          (
            Ic.mic,
            tr('Ses', 'Voice'),
            tr(
              'Nefes, ses aralığı, ritim ve ezgi tekrarı',
              'Breath, vocal range, rhythm and melody echo',
            ),
          ),
          (
            Ic.users,
            tr('Koro', 'Choir'),
            tr(
              'Şefin ödevleri ve eşlikle parti çalışması',
              'Your conductor\'s assignments and part practice',
            ),
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: TC.primary),
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
          ),
        const Spacer(flex: 2),
        BigButton(
          key: const Key('get_started'),
          label: tr('Başlayalım', 'Get started'),
          onPressed: onStart,
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Hesap gerekmez · veriler bu cihazda kalır',
            'No account needed · data stays on this device',
          ),
          textAlign: TextAlign.center,
          style: TT.small,
        ),
      ],
    ),
  );
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
    title: tr(
      'Günlük hatırlatma ister misin?',
      'Would you like a daily reminder?',
    ),
    subtitle: tr(
      'Her akşam 19:00\'da tek bir bildirim. Ayarlar\'dan kapatabilirsin.',
      'One notification at 19:00 each evening. You can turn it off in Settings.',
    ),
    showButton: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BigButton(
          key: const Key('reminder_allow'),
          label: tr('Hatırlat', 'Remind me'),
          icon: Ic.bellRing,
          busy: _busy,
          onPressed: _allow,
        ),
        const SizedBox(height: 6),
        TextLink(
          tr('Şimdilik hayır', 'Not now'),
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
        Ic.mic,
        tr('Aralık', 'Range'),
        store.part?.title ??
            tr(
              'Ölçülmedi · Ses sekmesinde ölç',
              'Not measured · measure it in the Voice tab',
            ),
      ),
      (trainerIcon(trainer), tr('İlk ders', 'First lesson'), trainer.title),
      if (DailyRoute.forMinutes(store.dailyMinutes).voiceStep)
        (
          Ic.audioLines,
          tr('Ses', 'Voice'),
          tr(
            'Rotanın sonunda bir ses adımı',
            'A voice step at the end of the route',
          ),
        ),
      (
        Ic.timer,
        tr('Günlük', 'Daily'),
        tr('${store.dailyMinutes} dakika', '${store.dailyMinutes} minutes'),
      ),
      if (role == 'singer' || role == 'conductor')
        (
          Ic.users,
          tr('Koro', 'Choir'),
          tr(
            'Ödevlerin Koro sekmesinde',
            'Your assignments are in the Choir tab',
          ),
        ),
    ];
    return FitOrScroll(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('HAZIR', 'READY'), style: TT.caps),
            const SizedBox(height: 4),
            Text(tr('Planın kuruldu', 'Your plan is ready'), style: TT.h1),
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
              label: tr('İlk derse başla', 'Start the first lesson'),
              icon: Ic.play,
              onPressed: onBegin,
            ),
            Center(
              child: TextLink(
                tr('Ana sayfaya git', 'Go to home'),
                onTap: onLater,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
