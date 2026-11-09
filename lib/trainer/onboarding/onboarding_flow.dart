import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/resonia_theme.dart';
import '../app/scope.dart';
import '../audio/ui_sounds.dart';
import '../domain/music.dart';
import '../domain/placement.dart';
import '../domain/trainers.dart';
import '../home/daily_route.dart';
import '../state/trainer_store.dart';
import '../ui/celebration.dart';
import '../ui/kit.dart';
import '../ui/motion.dart';
import '../../domain/lang.dart';

/// How the first run ends (PLACE-01).
enum ObExit { home, lesson, placement }

/// Vocalart's short first run (WIDE-01, UX-MOTION-01, PLACE-01): welcome →
/// name → goal → level → daily minutes → first session or placement. A guide orb talks the learner
/// through each step; letters, choices and steps answer with short notes.
/// The name is optional and stays on this device. Microphone check, range measurement and the reminder come later,
/// when they are first useful (Settings, Exercises, Today). Choir membership
/// is a context next to the goal, not a goal of its own (ADR-035). The
/// current step is persisted so a killed app resumes there.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onFinished});

  /// Called when setup ends with what the learner chose to do next.
  final void Function(ObExit exit) onFinished;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum Ob { welcome, name, goal, level, minutes, ready }

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

  void _next() {
    uiCue(context, UiCue.advance);
    _go(Ob.values[_step.index + 1]);
  }

  void _back() {
    if (_step.index == 0) return;
    uiCue(context, UiCue.back);
    _go(Ob.values[_step.index - 1], forward: false);
  }

  List<String> _list(String key) =>
      (_answers[key] as List?)?.whereType<String>().toList() ?? <String>[];

  void _pickGoal(PracticeGoal goal) {
    final store = TrainerScope.of(context).store;
    uiFeedback(
      context,
      store.answers['goal'] == goal.id ? UiCue.tap : UiCue.select,
    );
    store.answers['goal'] = goal.id;
    // Rehearsal prep implies a choir; the box stays visible and can be
    // cleared.
    if (goal == PracticeGoal.choir && !store.inChoir) _setChoir(store, true);
    store.save();
    setState(() {});
  }

  /// Choir context, independent of the goal: shows the Koro tab.
  void _setChoir(TrainerStore store, bool on) {
    uiFeedback(context, on ? UiCue.select : UiCue.deselect);
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

  void _pickLevel(ExperienceLevel level) {
    final store = TrainerScope.of(context).store;
    uiFeedback(
      context,
      store.answers['level'] == level.id ? UiCue.tap : UiCue.select,
    );
    store.answers['level'] = level.id;
    store.save();
    setState(() {});
  }

  void _finish(ObExit exit) {
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
    widget.onFinished(exit);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TC.canvas,
    body: SafeArea(
      child: StepSwitcher(
        forward: _forward,
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
      Ob.name => _NameStep(
        step: _step,
        initial: store.username,
        onBack: _back,
        onDone: (name) {
          store.username = name;
          store.save();
          _next();
        },
      ),
      Ob.goal => _GoalStep(
        step: _step,
        name: store.username.trim(),
        goal: PracticeGoalInfo.fromId(store.answers['goal']),
        inChoir: store.inChoir,
        onBack: _back,
        onNext: _next,
        onGoal: _pickGoal,
        onChoir: (on) => _setChoir(store, on),
      ),
      Ob.level => _LevelStep(
        step: _step,
        level: ExperienceLevelInfo.fromId(store.answers['level']),
        onBack: _back,
        onNext: _next,
        onLevel: _pickLevel,
      ),
      Ob.minutes => _Frame(
        step: _step,
        onBack: _back,
        onNext: _next,
        guide: tr(
          'Az ama her gün, çok ama seyrekten iyidir. Sonra değiştirebilirsin.',
          'A little every day beats a lot now and then. You can change it later.',
        ),
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
            for (final (i, m) in dailyMinuteChoices.indexed)
              Entrance(
                index: i,
                child: Bump(
                  trigger: store.dailyMinutes == m,
                  child: ChoiceChip(
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
                      // More minutes, higher note.
                      uiFeedback(context, UiCue.note(2 + i * 2));
                      store.dailyMinutes = m;
                      store.save();
                      setState(() {});
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
      Ob.ready => _Ready(
        onBegin: () => _finish(ObExit.lesson),
        onLater: () => _finish(ObExit.home),
        onPlacement: () => _finish(ObExit.placement),
      ),
    };
  }
}

/// Shared page frame: progress, the guide's line, title, scrollable body
/// that arrives in a stagger, and the continue button.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.step,
    required this.onBack,
    required this.title,
    required this.child,
    this.guide,
    this.subtitle,
    this.onNext,
    this.nextLabel,
  });
  final Ob step;
  final VoidCallback onBack;
  final String title;
  final String? guide;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onNext;
  final String? nextLabel;

  /// Steps between welcome and ready: name, goal, level and minutes.
  static const _count = 4;

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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: TC.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  // The segment for this step fills as the step arrives.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: i < step.index - 1 ? 1 : 0,
                      end: i < step.index ? 1 : 0,
                    ),
                    duration: ResoniaMotion.reduced(context)
                        ? Duration.zero
                        : Motion.step,
                    curve: Motion.curve,
                    builder: (context, v, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v,
                      child: const ColoredBox(color: TC.primary),
                    ),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          children: [
            if (guide != null) ...[
              GuideBubble(key: ValueKey(guide), message: guide!),
              const SizedBox(height: 18),
            ],
            Entrance(child: Text(title, style: TT.h2)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Entrance(index: 1, child: Text(subtitle!, style: TT.body)),
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
          label: nextLabel ?? tr('Devam', 'Continue'),
          onPressed: onNext,
        ),
      ),
    ],
  );
}

class _Welcome extends StatefulWidget {
  const _Welcome({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  bool _greeted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_greeted) return;
    _greeted = true;
    // The notes around the orb pop in to a light rising run.
    uiCue(context, UiCue.hello);
  }

  /// The seven note names in the learner's language.
  static List<String> get _notes => Lang.en
      ? const ['C', 'D', 'E', 'F', 'G', 'A', 'B']
      : const ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

  @override
  Widget build(BuildContext context) => FitOrScroll(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerRight, child: _LanguagePick()),
          const Spacer(),
          Center(child: FloatingNotes(labels: _notes, size: 190)),
          const SizedBox(height: 18),
          Entrance(
            index: 2,
            child: Text(
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
          ),
          const SizedBox(height: 10),
          Entrance(
            index: 3,
            child: Text(
              tr(
                'Günde birkaç dakika, kendi hızında. Ne yapacağını her gün Bugün sekmesi söyler.',
                'A few minutes a day, at your pace. The Today tab tells you what to do each day.',
              ),
              style: TT.body,
            ),
          ),
          const SizedBox(height: 18),
          // What the app offers, in the order the tabs show it.
          for (final (i, (icon, title, body)) in [
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
          ].indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Entrance(
                index: 4 + i,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
            ),
          const Spacer(flex: 2),
          BigButton(
            key: const Key('get_started'),
            label: tr('Başlayalım', 'Get started'),
            chevron: true,
            onPressed: widget.onStart,
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
    ),
  );
}

/// Language at the very first screen: Türkçe or English. The choice is the
/// same setting as in Settings (null there means the device's language),
/// and the note naming chosen at "Get started" follows it.
class _LanguagePick extends StatelessWidget {
  const _LanguagePick();

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final current = store.language ?? (Lang.en ? 'en' : 'tr');
    return Semantics(
      label: tr('Dil', 'Language'),
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (code, label) in const [
            ('tr', 'Türkçe'),
            ('en', 'English'),
          ])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                key: Key('lang_$code'),
                label: Text(label),
                selected: current == code,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: current == code ? Colors.white : TC.ink,
                ),
                selectedColor: TC.primary,
                backgroundColor: TC.card,
                side: const BorderSide(color: TC.line),
                onSelected: (_) {
                  if (store.language == code) return;
                  uiFeedback(context, UiCue.select);
                  store.language = code;
                  store.save();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Optional first name. Each letter becomes a note tile that pops in with
/// the next note of a pentatonic run, so typing a name plays a little tune.
class _NameStep extends StatefulWidget {
  const _NameStep({
    required this.step,
    required this.initial,
    required this.onBack,
    required this.onDone,
  });
  final Ob step;
  final String initial;
  final VoidCallback onBack;
  final ValueChanged<String> onDone;

  /// Longest stored name; longer input is cut at the field.
  static const maxLength = 24;

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  late int _letters = _count(widget.initial);

  static int _count(String s) =>
      s.characters.where((c) => c.trim().isNotEmpty).length;

  void _changed(String value) {
    final n = _count(value);
    if (n > _letters) uiCue(context, UiCue.note(n - 1));
    setState(() => _letters = n);
  }

  void _done() => widget.onDone(_text.text.trim());

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = _text.text.trim().isEmpty;
    return _Frame(
      step: widget.step,
      onBack: widget.onBack,
      onNext: _done,
      nextLabel: empty ? tr('Şimdilik atla', 'Skip for now') : null,
      guide: tr(
        'Merhaba! Ben ses rehberin. Önce tanışalım.',
        'Hi! I\'m your voice guide. Let\'s meet first.',
      ),
      title: tr('Sana nasıl seslenelim?', 'What should we call you?'),
      subtitle: tr(
        'İstersen boş bırak. Adın yalnız bu cihazda kalır.',
        'You can leave it empty. Your name stays on this device.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            index: 2,
            child: TextField(
              key: const Key('ob_name'),
              controller: _text,
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_NameStep.maxLength),
              ],
              style: TT.title.copyWith(fontSize: 18),
              decoration: InputDecoration(
                labelText: tr('Adın', 'First name'),
                filled: true,
                fillColor: TC.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: TC.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: TC.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: TC.primary, width: 2),
                ),
              ),
              onChanged: _changed,
              onSubmitted: (_) => _done(),
            ),
          ),
          const SizedBox(height: 18),
          LetterTiles(text: _text.text),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({
    required this.step,
    required this.name,
    required this.goal,
    required this.inChoir,
    required this.onBack,
    required this.onNext,
    required this.onGoal,
    required this.onChoir,
  });
  final Ob step;
  final String name;
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
    guide: name.isEmpty
        ? tr(
            'Bugünkü çalışmanı hedefine göre kuracağım.',
            'I\'ll build today\'s session around your goal.',
          )
        : tr(
            'Tanıştığımıza sevindim, $name! Çalışmanı hedefine göre kuracağım.',
            'Nice to meet you, $name! I\'ll build your session around your goal.',
          ),
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
        for (final (i, g) in PracticeGoal.values.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Entrance(
              index: 2 + i,
              child: Bump(
                trigger: g == goal,
                child: AppCard(
                  key: Key('goal_${g.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: g == goal ? TC.primary : null,
                  color: g == goal ? TC.primarySoft : Colors.white,
                  onTap: () => onGoal(g),
                  // Merged into the card's node, so screen readers say
                  // which goal is selected.
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(
                              parent: anim,
                              curve: Motion.spring,
                            ),
                            child: child,
                          ),
                          child: Icon(
                            g == goal ? Ic.circleDot : Ic.circle,
                            key: ValueKey(g == goal),
                            color: g == goal ? TC.primary : TC.faint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Entrance(
          index: 2 + PracticeGoal.values.length,
          child: AppCard(
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
        ),
      ],
    ),
  );
}

/// Where the learner starts (PLACE-01). Separate from the goal; it only
/// decides whether a placement test is offered.
class _LevelStep extends StatelessWidget {
  const _LevelStep({
    required this.step,
    required this.level,
    required this.onBack,
    required this.onNext,
    required this.onLevel,
  });
  final Ob step;
  final ExperienceLevel? level;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final ValueChanged<ExperienceLevel> onLevel;

  static IconData _icon(ExperienceLevel l) => switch (l) {
    ExperienceLevel.beginner => Ic.sprout,
    ExperienceLevel.some => Ic.music2,
    ExperienceLevel.experienced => Ic.graduationCap,
  };

  @override
  Widget build(BuildContext context) => _Frame(
    step: step,
    onBack: onBack,
    onNext: level == null ? null : onNext,
    guide: tr(
      'Bildiklerini tekrar ettirmeyeyim; nereden başladığını söyle.',
      'I won\'t make you repeat what you know; tell me where you start.',
    ),
    title: tr('Müzikte neredesin?', 'Where are you in music?'),
    subtitle: tr(
      'Biliyorsan kısa bir testle ileri atlarsın. Ayarlar\'dan '
          'değiştirebilirsin.',
      'If you know some already, a short test moves you ahead. You can '
          'change it in Settings.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, l) in ExperienceLevel.values.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Entrance(
              index: 2 + i,
              child: Bump(
                trigger: l == level,
                child: AppCard(
                  key: Key('level_${l.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: l == level ? TC.primary : null,
                  color: l == level ? TC.primarySoft : Colors.white,
                  onTap: () => onLevel(l),
                  child: Semantics(
                    selected: l == level,
                    inMutuallyExclusiveGroup: true,
                    child: Row(
                      children: [
                        Icon(_icon(l), color: TC.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.title, style: TT.title),
                              const SizedBox(height: 2),
                              Text(l.subtitle, style: TT.small),
                            ],
                          ),
                        ),
                        Icon(
                          l == level ? Ic.circleDot : Ic.circle,
                          color: l == level ? TC.primary : TC.faint,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Ready extends StatefulWidget {
  const _Ready({
    required this.onBegin,
    required this.onLater,
    required this.onPlacement,
  });
  final VoidCallback onBegin;
  final VoidCallback onLater;
  final VoidCallback onPlacement;
  @override
  State<_Ready> createState() => _ReadyState();
}

class _ReadyState extends State<_Ready> {
  bool _cheered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cheered) return;
    _cheered = true;
    // Setup really finished here: the one celebration of the first run.
    uiCue(context, UiCue.success);
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final name = store.username.trim();
    final route = store.route;
    final goal = route.goal;
    final focus =
        (store.answers['focus'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final trainer = goal != null
        ? goal.lesson
        : TrainerKind.values.where((k) => focus.contains(k.id)).firstOrNull ??
              TrainerKind.interval;
    final level = ExperienceLevelInfo.fromId(store.answers['level']);
    final placement = trainer != null && (level?.offersPlacement ?? false);
    final rows = [
      if (goal != null) (Ic.target, tr('Hedef', 'Goal'), goal.title),
      if (level != null) (Ic.signal, tr('Seviye', 'Level'), level.title),
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
      if (route.echoStep != null)
        (
          Ic.repeat,
          tr('Tekrar', 'Echo'),
          tr(
            'Melodi yankısı ile alkışla ritim dönüşümlü; taslak ölçüm',
            'Melody echo and clap the rhythm in turn; draft measurement',
          ),
        ),
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
    return Stack(
      children: [
        FitOrScroll(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const PopIn(child: GuideOrb(size: 56, talking: true)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Entrance(
                            index: 1,
                            child: Text(
                              name.isEmpty
                                  ? tr('HAZIR', 'READY')
                                  : trCaps(
                                      tr(
                                        'Hazırsın, $name!',
                                        'You\'re all set, $name!',
                                      ),
                                    ),
                              key: const Key('ob_ready_caps'),
                              style: TT.caps,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Entrance(
                            index: 2,
                            child: Text(
                              tr('Planın kuruldu', 'Your plan is ready'),
                              style: TT.h1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppCard(
                  child: Column(
                    children: [
                      for (final (i, (icon, label, value)) in rows.indexed)
                        Entrance(
                          index: 3 + i,
                          child: Padding(
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
                // Experienced: the placement test leads; otherwise it is
                // an optional link under the first session.
                if (placement && level == ExperienceLevel.experienced) ...[
                  BigButton(
                    key: const Key('ob_placement'),
                    label: tr('Seviyemi bul', 'Find my level'),
                    icon: Ic.target,
                    onPressed: widget.onPlacement,
                  ),
                  Center(
                    child: TextLink(
                      tr(
                        'Testi atla, baştan başla',
                        'Skip the test, start at the beginning',
                      ),
                      key: const Key('today_session_begin'),
                      onTap: widget.onBegin,
                    ),
                  ),
                ] else ...[
                  BigButton(
                    key: const Key('today_session_begin'),
                    label: tr('İlk çalışmaya başla', 'Start the first session'),
                    icon: Ic.play,
                    onPressed: widget.onBegin,
                  ),
                  if (placement)
                    Center(
                      child: TextLink(
                        tr(
                          'Önce kısa seviye testi',
                          'Take a short placement first',
                        ),
                        key: const Key('ob_placement'),
                        onTap: widget.onPlacement,
                      ),
                    ),
                ],
                Center(
                  child: TextLink(
                    tr('Ana sayfaya git', 'Go to home'),
                    onTap: widget.onLater,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Decorative burst over the plan; ignores touches.
        const Positioned.fill(
          child: IgnorePointer(
            child: Celebration(tier: CelebrationTier.lesson, seed: 5),
          ),
        ),
      ],
    );
  }
}
