import 'package:flutter/material.dart';

import '../../choir/app/choir_scope.dart';
import '../../choir/app/assignment_screen.dart';
import '../../choir/app/choir_tab.dart';
import '../../choir/app/choir_text.dart';
import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../domain/music.dart';
import '../koro/koro_hub.dart';
import '../koro/range_test.dart';
import '../koro/voice_count.dart';
import '../learn/review_cards.dart';
import '../prepare/breath_screen.dart';
import '../learn/lesson_flow.dart';
import '../practice/practice_setup.dart';
import '../settings/settings_tab.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'daily_route.dart';
import '../learn/skill_screen.dart';
import '../../domain/lang.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  String _tab = 'tab_0';

  /// Koro shows for those who said they sing in or lead a choir, and for
  /// anyone who already has one. Everyone else reaches it from Settings.
  bool _showsChoir(TrainerStore store) {
    final choir = ChoirScope.maybeOf(context);
    if (choir == null) return false;
    final role = store.answers['role'];
    return role == 'singer' ||
        role == 'conductor' ||
        choir.store.choirs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = <_Destination>[
          _Destination(
            'tab_0',
            Ic.sun,
            Ic.sun,
            tr('Bugün', 'Today'),
            PlayTab(),
          ),
          _Destination(
            'tab_1',
            Ic.audioLines,
            Ic.audioLines,
            tr('Ses', 'Voice'),
            KoroHub(asTab: true),
          ),
          if (_showsChoir(store))
            _Destination(
              'tab_koro',
              Ic.users,
              Ic.users,
              CT.of(context).tabLabel,
              const ChoirTab(),
            ),
          _Destination(
            'tab_2',
            Ic.chartNoAxesCombined,
            Ic.chartNoAxesCombined,
            tr('İlerleme', 'Progress'),
            StatsTab(),
          ),
          _Destination(
            'tab_3',
            Ic.settings2,
            Ic.settings2,
            tr('Ayarlar', 'Settings'),
            SettingsTab(),
          ),
        ];
        final index = items.indexWhere((d) => d.key == _tab);
        final selected = index < 0 ? 0 : index;
        return Scaffold(
          backgroundColor: TC.canvas,
          body: IndexedStack(
            index: selected,
            children: [
              for (final d in items)
                KeyedSubtree(key: ValueKey(d.key), child: d.body),
            ],
          ),
          bottomNavigationBar: _NavBar(
            items: items,
            index: selected,
            onTap: (i) => setState(() => _tab = items[i].key),
          ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(
    this.key,
    this.icon,
    this.selectedIcon,
    this.label,
    this.body,
  );
  final String key;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget body;
}

/// Four destinations, five for choir members. The voice workshop is for
/// everyone (ADR-035).
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<_Destination> items;
  final int index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TC.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].label,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key(items[i].key),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        tapHaptic();
                        onTap(i);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 42,
                            height: 28,
                            decoration: ShapeDecoration(
                              color: i == index
                                  ? TC.navPill
                                  : Colors.transparent,
                              shape: const StadiumBorder(),
                            ),
                            child: Icon(
                              items[i].icon,
                              color: i == index ? TC.primary : TC.muted,
                              size: 19,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == index
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: i == index ? TC.primary : TC.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which trainer today's session focuses on: onboarding focus, else the
/// last trainer used, else the first trainer with an unfinished path.
TrainerKind focusTrainer(TrainerStore store) {
  final focus = store.answers['focus'];
  final candidates = <TrainerKind>[
    if (store.lastTrainer != null)
      ...TrainerKind.values.where((k) => k.id == store.lastTrainer),
    if (focus is List)
      for (final f in focus.whereType<String>())
        ...TrainerKind.values.where((k) => k.id == f),
    ...TrainerKind.values,
  ];
  for (final k in candidates) {
    if (store.nextNode(k) != null) return k;
  }
  return TrainerKind.pitch;
}

/// Today's session: the focus trainer's next node (intro first if needed).
Future<void> startTodaySession(TrainerStore store, NavigatorState nav) async {
  final kind = focusTrainer(store);
  var node = store.nextNode(kind);
  if (node == null) return;
  if (node.kind == NodeKind.intro) {
    final ok = await nav.push<bool>(
      MaterialPageRoute(builder: (_) => LessonFlow(node: node!)),
    );
    if (ok != true) return;
    node = store.nextNode(kind);
    if (node == null) return;
  }
  await nav.push<bool>(
    MaterialPageRoute(builder: (_) => LessonFlow(node: node!)),
  );
}

class PlayTab extends StatefulWidget {
  const PlayTab({super.key});
  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  static List<String> get _months => Lang.en
      ? const [
          'January', 'February', 'March', 'April', 'May', 'June', //
          'July', 'August', 'September', 'October', 'November', 'December',
        ]
      : const [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
        ];
  static List<String> get _weekdays => Lang.en
      ? const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ]
      : const [
          'Pazartesi',
          'Salı',
          'Çarşamba',
          'Perşembe',
          'Cuma',
          'Cumartesi',
          'Pazar',
        ];

  /// Walks today's route: the breathing guide first (unless done or not in
  /// today's route), then the ear lesson.
  Future<void> _beginToday() async {
    final store = TrainerScope.of(context).store;
    final nav = Navigator.of(context);
    final route = DailyRoute.forMinutes(store.dailyMinutes);
    if (route.breath && !store.breathedToday) {
      final go = await nav.push<bool>(
        MaterialPageRoute(
          builder: (_) => BreathScreen(
            totalSeconds: route.breathSeconds,
            stepLabel: tr(
              'ADIM 1 / ${route.stepCount}',
              'STEP 1 / ${route.stepCount}',
            ),
          ),
        ),
      );
      if (go != true) return;
    }
    await startTodaySession(store, nav);
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final now = store.now;
    final focus = focusTrainer(store);
    final next = store.nextNode(focus);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('KENDİ RİTMİNDE', 'AT YOUR OWN PACE'),
                  style: TT.crumb,
                ),
              ),
              _StreakChip(days: store.streak),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('Bugün', 'Today'), style: TT.h1),
          const SizedBox(height: 2),
          Text(
            tr(
              '${_weekdays[now.weekday - 1]}, ${now.day} '
                  '${_months[now.month - 1]}',
              '${_weekdays[now.weekday - 1]}, '
                  '${_months[now.month - 1]} ${now.day}',
            ),
            style: TT.small,
          ),
          const SizedBox(height: 18),
          _DailyRoute(
            store: store,
            trainer: focus,
            next: next,
            onBegin: _beginToday,
          ),
          const _ChoirDue(),
          const SizedBox(height: 20),
          Text(tr('BECERİLER', 'SKILLS'), style: TT.caps),
          const SizedBox(height: 10),
          for (var i = 0; i < TrainerKind.values.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SkillCard(
                        kind: TrainerKind.values[i],
                        store: store,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: i + 1 < TrainerKind.values.length
                          ? _SkillCard(
                              kind: TrainerKind.values[i + 1],
                              store: store,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The nearest choir deadline, when there is work still to send.
class _ChoirDue extends StatelessWidget {
  const _ChoirDue();
  @override
  Widget build(BuildContext context) {
    final store = ChoirScope.maybeOf(context)?.store;
    final next = store?.nextDue();
    if (store == null || next == null) return const SizedBox.shrink();
    final (choir, assignment) = next;
    final text = CT.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text.caps(text.choirUpdates), style: TT.caps),
          const SizedBox(height: 10),
          AppCard(
            key: const Key('today_choir_due'),
            padding: const EdgeInsets.all(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AssignmentScreen(assignmentId: assignment.id),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: TC.primarySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Ic.music2, color: TC.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(assignment.title, style: TT.title),
                      Text(
                        '${choir.name} · '
                        '${text.dueLabel(store.now, assignment.dueAt!)}',
                        style: TT.small,
                      ),
                    ],
                  ),
                ),
                const Icon(Ic.chevronRight, color: TC.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});
  final int days;
  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('$days günlük seri', '$days-day streak'),
    excludeSemantics: true,
    child: Container(
      key: const Key('streak_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: days > 0 ? TC.sun : TC.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Ic.sun, size: 18, color: days > 0 ? TC.onSun : TC.muted),
          const SizedBox(width: 5),
          Text(
            tr('$days gün', days == 1 ? '1 day' : '$days days'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: days > 0 ? TC.onSun : TC.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Picker shared by home and settings. Changes playback only, never scores.
Future<void> showVoicePartSheet(BuildContext context) {
  final store = TrainerScope.of(context).store;
  return showTrainerSheet<void>(
    context,
    (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            'Sesin hangi aralığa yakın?',
            'Which range is your voice close to?',
          ),
          style: TT.h3,
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Tenor ve bas seçilince dersler bir oktav pesten çalar. '
                'Emin değilsen Ses sekmesindeki ses aralığı testi taslak bir öneri verir.',
            'With tenor or bass, lessons play an octave lower. '
                'If you are not sure, the range test in the Voice tab gives a draft suggestion.',
          ),
          style: TT.small,
        ),
        const SizedBox(height: 14),
        for (final p in VoicePart.values)
          ChoiceTile(
            key: Key('part_${p.name}'),
            label: p.title,
            multi: false,
            selected: store.voicePart == p.name,
            onTap: () {
              store.voicePart = p.name;
              store.save();
              Navigator.pop(sheet);
            },
          ),
        TextLink(
          tr(
            'Seçme, varsayılan aralıkta çal',
            'Skip, play in the default range',
          ),
          onTap: () {
            store.voicePart = null;
            store.save();
            Navigator.pop(sheet);
          },
        ),
      ],
    ),
  );
}

/// Today's route: one hero, the ordered steps (Hazırla → Ders → Ses, sized
/// by daily minutes) and a single primary action.
class _DailyRoute extends StatelessWidget {
  const _DailyRoute({
    required this.store,
    required this.trainer,
    required this.next,
    required this.onBegin,
  });
  final TrainerStore store;
  final TrainerKind trainer;
  final LessonNode? next;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final route = DailyRoute.forMinutes(store.dailyMinutes);
    final lessonDone = store.sessionToday;
    final breathDone = store.breathedToday;
    final hasRange = store.koroRange != null;
    final due = store.dueReview;
    final lesson = next;
    final part = store.part;
    final steps = <_StepData>[
      if (route.breath)
        _StepData(
          key: 'route_breath',
          title: tr('Nefes', 'Breath'),
          subtitle: tr(
            '${route.breathSeconds ~/ 60} dk · yönlendirmeli, mikrofonsuz',
            '${route.breathSeconds ~/ 60} min · guided, no microphone',
          ),
          icon: Ic.wind,
          done: breathDone,
        ),
      // Spaced review: shown while cards are due, ticked once done today.
      if (due.isNotEmpty || store.reviewedToday)
        _StepData(
          key: 'route_review',
          title: tr('Tekrar kartları', 'Review cards'),
          subtitle: due.isEmpty
              ? tr('Bugünlük tamam', 'Done for today')
              : tr(
                  '${due.length} kart · ~${(due.length * 15 / 60).ceil()} dk · karışık',
                  '${due.length} cards · ~${(due.length * 15 / 60).ceil()} min · mixed',
                ),
          icon: Ic.repeat,
          done: due.isEmpty,
          onTap: due.isEmpty ? null : () => startReview(context),
        ),
      _StepData(
        key: 'route_lesson',
        title: lesson == null
            ? tr('${trainer.title} tamam', '${trainer.title} done')
            : lesson.title,
        subtitle: lesson == null
            ? tr('Serbest pratikle devam et', 'Keep going with free practice')
            : lesson.kind == NodeKind.intro
            ? tr(
                '${trainer.shortTitle} · kısa tanıtım',
                '${trainer.shortTitle} · short introduction',
              )
            : tr(
                '${trainer.shortTitle} · dinle, söyle, ayırt et',
                '${trainer.shortTitle} · listen, sing, tell apart',
              ),
        icon: trainerIcon(trainer),
        done: lessonDone,
      ),
      if (route.voiceStep)
        _StepData(
          key: 'route_voice',
          title: hasRange
              ? tr('Kaç ses duyuyorsun?', 'How many voices do you hear?')
              : tr('Ses aralığı testi', 'Vocal range test'),
          subtitle: hasRange
              ? tr(
                  'Ses · 2/3/4 sesli dokuyu ayırt et',
                  'Voice · tell 2, 3 and 4-part textures apart',
                )
              : tr(
                  'Ses · isteğe bağlı mikrofon, taslak ölçüm',
                  'Voice · optional microphone, draft measurement',
                ),
          icon: hasRange ? Ic.layers : Ic.mic,
          done: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  hasRange ? const VoiceCountScreen() : const RangeTestScreen(),
            ),
          ),
        ),
    ];
    final pitch = route.breath
        ? tr(
            'Nefesini hazırla, sesleri duy, istersen söyle.',
            'Ready your breath, hear the notes, sing if you like.',
          )
        : tr(
            'Kısa gün: tek bir kulak dersi.',
            'Short day: a single ear lesson.',
          );
    final String action;
    if (lessonDone) {
      action = tr('Bugünlük ders tamam', 'Today\'s lesson is done');
    } else if (lesson == null) {
      action = tr('Pratik yap', 'Practise');
    } else if (breathDone || !route.breath) {
      action = tr('Derse başla', 'Start the lesson');
    } else {
      action = tr('Çalışmaya başla', 'Start practising');
    }
    final current = steps.indexWhere((s) => !s.done && s.onTap == null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('GÜNLÜK RUTİN', 'DAILY ROUTINE'),
                      style: TextStyle(
                        color: TC.sun,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      part == null
                          ? tr('Sesine alan aç.', 'Make room for your voice.')
                          : tr(
                              '${part.title} için alan aç.',
                              'Make room for your ${part.title.toLowerCase()}.',
                            ),
                      style: TT.display.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tr(
                        '~${store.dailyMinutes} dakika · $pitch',
                        '~${store.dailyMinutes} minutes · $pitch',
                      ),
                      style: const TextStyle(
                        color: TC.heroMuted,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    // The route already offers the test when it has a voice step.
                    if (part == null && !(route.voiceStep && !hasRange))
                      // Measured, not asked (ADR-040).
                      _PartLink(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RangeTestScreen(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Container(
                  width: 72,
                  height: 86,
                  decoration: BoxDecoration(
                    color: TC.sun,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(Ic.music2, color: TC.ink, size: 38),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Column(
          key: const Key('daily_plan'),
          children: [
            for (var i = 0; i < steps.length; i++)
              _RouteStep(data: steps[i], current: i == current && !lessonDone),
          ],
        ),
        const SizedBox(height: 4),
        BigButton(
          key: const Key('today_begin'),
          label: action,
          icon: Ic.sparkles,
          onPressed: lessonDone
              ? null
              : lesson == null
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PracticeSetupScreen(trainer: trainer),
                  ),
                )
              : onBegin,
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Kayıtlar cihazdan çıkmaz; mikrofon adımları isteğe bağlıdır.',
            'Recordings never leave the device; microphone steps are optional.',
          ),
          textAlign: TextAlign.center,
          style: TT.small,
        ),
      ],
    );
  }
}

class _StepData {
  const _StepData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.done,
    this.onTap,
  });
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool done;
  final VoidCallback? onTap;
}

class _PartLink extends StatelessWidget {
  const _PartLink({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: TextButton.icon(
      key: const Key('part_chip'),
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: TC.sun,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Ic.audioLines, size: 18),
      label: Text(
        tr('Ses aralığını ölç', 'Measure your range'),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ),
  );
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({required this.data, required this.current});
  final _StepData data;
  final bool current;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      key: Key(data.key),
      padding: const EdgeInsets.all(16),
      onTap: data.onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: data.done ? TC.green : TC.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              data.done ? Ic.check : data.icon,
              color: data.done ? Colors.white : TC.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: TT.title),
                Text(data.subtitle, style: TT.small),
              ],
            ),
          ),
          if (current)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const ShapeDecoration(
                color: TC.primarySoft,
                shape: StadiumBorder(),
              ),
              child: Text(
                tr('Şimdi', 'Now'),
                style: TextStyle(
                  color: TC.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (data.onTap != null)
            const Icon(Ic.chevronRight, color: TC.muted),
        ],
      ),
    ),
  );
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.kind, required this.store});
  final TrainerKind kind;
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final color = trainerColor(kind);
    final m = store.mastery(kind);
    return AppCard(
      key: Key('skill_${kind.id}'),
      padding: const EdgeInsets.all(14),
      onTap: () => openSkill(context, kind),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: TC.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(trainerIcon(kind), color: TC.primary, size: 20),
          ),
          const SizedBox(height: 10),
          Text(kind.shortTitle, style: TT.title),
          const SizedBox(height: 6),
          ProgressBar(value: m, color: color, height: 4),
        ],
      ),
    );
  }
}
