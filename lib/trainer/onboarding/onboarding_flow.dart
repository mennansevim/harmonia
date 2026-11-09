import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../home/daily_route.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';
import '../../domain/lang.dart';

/// Vocalart's short first run (WIDE-01): goal → daily minutes → first
/// session. Microphone check, range measurement and the reminder come later,
/// when they are first useful (Settings, Exercises, Today). Choir membership
/// is a context next to the goal, not a goal of its own (ADR-035). The
/// current step is persisted so a killed app resumes there.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  /// Called when setup ends; `startLesson` = learner tapped the first lesson.
  final void Function(bool startLesson) onFinished;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum Ob { welcome, goal, minutes, ready }

/// Where a run saved by an older build resumes. Earlier answers (role,
/// focus, range) are kept; only the position maps onto the shorter flow.
Ob resumeStep(String saved) => switch (saved) {
  'role' || 'mic' || 'part' || 'focus' => Ob.goal,
  'notation' || 'minutes' => Ob.minutes,
  'reminder' => Ob.ready,
  _ => Ob.values.asNameMap()[saved] ?? Ob.welcome,
};

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
    if (saved is String) _step = resumeStep(saved);
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

  void _pickGoal(PracticeGoal goal) {
    final store = TrainerScope.of(context).store;
    store.answers['goal'] = goal.id;
    // Rehearsal prep implies a choir; the box stays visible and can be
    // cleared.
    if (goal == PracticeGoal.choir && !store.inChoir) _setChoir(store, true);
    store.save();
    setState(() {});
  }

  /// Choir context, independent of the goal: shows the Koro tab.
  void _setChoir(TrainerStore store, bool on) {
    // Legacy saves hold one string; normalise to a list first.
    final roles = store.roles.toList();
    if (on) {
      roles.add('singer');
    } else {
      roles.removeWhere((r) => r == 'singer' || r == 'conductor');
    }
    store.answers['role'] = roles;
    store.save();
    setState(() {});
  }

  void _finish(bool begin) {
    final store = TrainerScope.of(context).store;
    final goal = PracticeGoalInfo.fromId(store.answers['goal']);
    if (goal == null) {
      // A run resumed from an older build: its focus answer decides, as
      // before.
      final first = TrainerKind.values
          .where((k) => _list('focus').contains(k.id))
          .firstOrNull;
      store.lastTrainer ??= (first ?? TrainerKind.interval).id;
    } else if (goal.lesson != null) {
      // The goal's own lesson; a goal without a ready lesson gets none
      // rather than a silent interval fallback.
      store.lastTrainer ??= goal.lesson!.id;
      if (_list('focus').isEmpty) store.answers['focus'] = [goal.lesson!.id];
    }
    // The reminder is offered on Today after the first session (WIDE-01).
    if (!store.notifications) store.answers['reminderAsked'] = false;
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
      Ob.welcome => _Welcome(
        onStart: () {
          // No notation question: Do Re Mi in Turkish, C D E in English.
          // Settings can change it.
          store.notation = Lang.en ? NoteNotation.letter : NoteNotation.solfege;
          _next();
        },
      ),
      Ob.goal => _GoalStep(
        step: _step,
        goal: PracticeGoalInfo.fromId(store.answers['goal']),
        inChoir: store.inChoir,
        onBack: _back,
        onNext: _next,
        onGoal: _pickGoal,
        onChoir: (on) => _setChoir(store, on),
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
            for (final m in dailyMinuteChoices)
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
      Ob.ready => _Ready(
        onBegin: () => _finish(true),
        onLater: () => _finish(false),
      ),
    };
  }
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
  });
  final Ob step;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onNext;

  /// Steps between welcome and ready: goal and minutes.
  static const _count = 2;

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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: BigButton(
          key: const Key('ob_continue'),
          label: tr('Devam', 'Continue'),
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

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    required this.step,
    required this.goal,
    required this.inChoir,
    required this.onBack,
    required this.onNext,
    required this.onGoal,
    required this.onChoir,
  });
  final Ob step;
  final PracticeGoal? goal;
  final bool inChoir;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final ValueChanged<PracticeGoal> onGoal;
  final ValueChanged<bool> onChoir;

  static IconData _icon(PracticeGoal g) => switch (g) {
    PracticeGoal.beginner => Ic.sprout,
    PracticeGoal.ear => Ic.ear,
    PracticeGoal.voice => Ic.mic,
    PracticeGoal.choir => Ic.users,
    PracticeGoal.stage => Ic.speech,
    PracticeGoal.exam => Ic.graduationCap,
  };

  @override
  Widget build(BuildContext context) => _Frame(
    step: step,
    onBack: onBack,
    onNext: goal == null ? null : onNext,
    title: tr('Ne için çalışıyorsun?', 'What are you practising for?'),
    subtitle: tr(
      'Birini seç; bugünkü çalışman buna göre kurulur. Ayarlar\'dan '
          'istediğin zaman değiştirebilirsin.',
      'Pick one; today\'s session is built around it. You can change it '
          'any time in Settings.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in PracticeGoal.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              key: Key('goal_${g.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: g == goal ? TC.primary : null,
              color: g == goal ? TC.primarySoft : Colors.white,
              onTap: () => onGoal(g),
              // Merged into the card's node, so screen readers say which
              // goal is selected.
              child: Semantics(
                selected: g == goal,
                inMutuallyExclusiveGroup: true,
                child: Row(
                  children: [
                    Icon(_icon(g), color: TC.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.title, style: TT.title),
                          const SizedBox(height: 2),
                          Text(g.subtitle, style: TT.small),
                        ],
                      ),
                    ),
                    Icon(
                      g == goal ? Ic.circleDot : Ic.circle,
                      color: g == goal ? TC.primary : TC.faint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        AppCard(
          key: const Key('ob_choir'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => onChoir(!inChoir),
          child: Semantics(
            checked: inChoir,
            child: Row(
              children: [
                Icon(
                  inChoir ? Ic.squareCheck : Ic.square,
                  color: inChoir ? TC.primary : TC.faint,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          'Bir korodayım ya da koro yönetiyorum',
                          'I sing in or lead a choir',
                        ),
                        style: TT.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          'Koro ödevleri için ayrı bir sekme açılır',
                          'A separate tab opens for choir assignments',
                        ),
                        style: TT.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
    final route = routeFor(store.answers, store.dailyMinutes);
    final goal = route.goal;
    final focus =
        (store.answers['focus'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final trainer = goal != null
        ? goal.lesson
        : TrainerKind.values.where((k) => focus.contains(k.id)).firstOrNull ??
              TrainerKind.interval;
    final rows = [
      if (goal != null) (Ic.target, tr('Hedef', 'Goal'), goal.title),
      if (route.breath)
        (
          Ic.wind,
          tr('İlk adım', 'First step'),
          tr(
            'Nefes rehberi · ${route.breathSeconds ~/ 60} dk, mikrofonsuz',
            'Breath guide · ${route.breathSeconds ~/ 60} min, no microphone',
          ),
        ),
      if (trainer != null)
        (trainerIcon(trainer), tr('Ders', 'Lesson'), trainer.title),
      if (route.voiceStep)
        (
          Ic.audioLines,
          tr('Ses', 'Voice'),
          tr(
            'Rotanın sonunda isteğe bağlı bir ses adımı',
            'An optional voice step at the end of the route',
          ),
        ),
      (
        Ic.timer,
        tr('Günlük', 'Daily'),
        tr('${store.dailyMinutes} dakika', '${store.dailyMinutes} minutes'),
      ),
      if (store.inChoir)
        (
          Ic.users,
          tr('Koro', 'Choir'),
          tr(
            'Ödevlerin Koro sekmesinde',
            'Your assignments are in the Choir tab',
          ),
        ),
    ];
    final pending = goal?.pendingContent;
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
            if (pending != null) ...[
              const SizedBox(height: 10),
              Text(pending, key: const Key('ob_pending'), style: TT.small),
            ],
            const SizedBox(height: 10),
            Text(
              tr(
                'Mikrofon izni yalnız sesli bir adımı açınca istenir.',
                'Microphone access is asked only when you open a voice step.',
              ),
              style: TT.small,
            ),
            const SizedBox(height: 16),
            const Spacer(),
            BigButton(
              key: const Key('today_session_begin'),
              label: tr('İlk çalışmaya başla', 'Start the first session'),
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
