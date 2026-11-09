import 'dart:math' as math;

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
    return store.inChoir || choir.store.choirs.isNotEmpty;
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
            Ic.house,
            Ic.house,
            tr('Bugün', 'Today'),
            PlayTab(onSeeAll: () => setState(() => _tab = 'tab_1')),
          ),
          _Destination(
            'tab_1',
            Ic.layoutGrid,
            Ic.layoutGrid,
            tr('Egzersizler', 'Exercises'),
            KoroHub(asTab: true),
          ),
          if (_showsChoir(store))
            _Destination(
              'tab_koro',
              Ic.users,
              Ic.users,
              CT.of(context).tabLabel,
              const ChoirTab(trailing: ProfileButton()),
            ),
          _Destination(
            'tab_2',
            Ic.chartNoAxesColumn,
            Ic.chartNoAxesColumn,
            tr('Gelişim', 'Progress'),
            StatsTab(),
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

/// Three destinations, four for choir members; Settings sits behind the
/// profile button on each tab (DESIGN-09). Exercises are for everyone
/// (ADR-035).
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
        color: TC.navBar,
        border: Border(top: BorderSide(color: TC.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F342553),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
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
                            width: 40,
                            height: 28,
                            decoration: BoxDecoration(
                              color: i == index
                                  ? TC.navPill
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              items[i].icon,
                              color: i == index ? TC.hero : TC.muted,
                              size: 21,
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
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == index ? TC.hero : TC.body,
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
  const PlayTab({super.key, this.onSeeAll});

  /// "Tümünü gör": switches to the Exercises tab.
  final VoidCallback? onSeeAll;
  @override
  State<PlayTab> createState() => _PlayTabState();
}

/// Walks today's route: the breathing guide first (unless done or not in
/// today's route), then the ear lesson when the route has one. Nothing here
/// opens the microphone; voice steps start only from their own card.
Future<void> beginTodayRoute(TrainerStore store, NavigatorState nav) async {
  final route = routeFor(store.answers, store.dailyMinutes);
  if (route.breath && !store.breathedToday) {
    final go = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => BreathScreen(
          totalSeconds: route.breathSeconds,
          lessonNext: route.lesson,
          stepLabel: tr(
            'ADIM 1 / ${route.stepCount}',
            'STEP 1 / ${route.stepCount}',
          ),
        ),
      ),
    );
    if (go != true) return;
  }
  if (route.lesson) await startTodaySession(store, nav);
}

class _PlayTabState extends State<PlayTab> {
  Future<void> _beginToday() =>
      beginTodayRoute(TrainerScope.of(context).store, Navigator.of(context));

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final focus = focusTrainer(store);
    final next = store.nextNode(focus);
    final resume = TrainerKind.values
        .where((k) => k.id == store.lastTrainer)
        .firstOrNull;
    final name = store.username.trim();
    return Stack(
      children: [
        // The design's lavender ring behind the header, top right.
        const Positioned(
          top: -74,
          right: -84,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.68,
              child: SizedBox.square(
                dimension: 220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFFECE2FF), width: 42),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          trCaps(
                            name.isEmpty
                                ? tr('Merhaba', 'Hello')
                                : tr('Merhaba $name', 'Hello $name'),
                          ),
                          style: TT.crumb,
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          header: true,
                          child: Text(
                            tr(
                              'Bugün sesin nasıl?',
                              'How is your voice today?',
                            ),
                            style: TT.h1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(
                            'Sesini çalıştırmaya hazır mısın?',
                            'Ready to work your voice?',
                          ),
                          style: TT.body.copyWith(color: TC.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StreakChip(days: store.streak),
                  const SizedBox(width: 4),
                  const ProfileButton(),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: _WeekChip(store: store),
              ),
              const SizedBox(height: 14),
              _DailyRoute(
                store: store,
                trainer: focus,
                next: next,
                onBegin: _beginToday,
              ),
              if (reminderNudgeDue(store)) const _ReminderNudge(),
              const SizedBox(height: 18),
              _SectionHeading(
                tr('Hızlı egzersizler', 'Quick exercises'),
                action: widget.onSeeAll == null
                    ? null
                    : (tr('Tümünü gör', 'See all'), widget.onSeeAll!),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, k) in TrainerKind.values.indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        SizedBox(
                          width: 116,
                          child: _QuickCard(kind: k, tone: i, store: store),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (resume != null) ...[
                const SizedBox(height: 18),
                _SectionHeading(
                  tr('Kaldığın yerden', 'Pick up where you left'),
                ),
                _ResumeCard(kind: resume, store: store),
              ],
              const _ChoirDue(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The daily reminder is offered once, after the learner's first real
/// session or breath guide (WIDE-01), never during onboarding. Saves from
/// before WIDE-01 have no pending flag and are not asked again.
bool reminderNudgeDue(TrainerStore store) =>
    store.answers['reminderAsked'] == false &&
    !store.notifications &&
    (store.activeDayCount > 0 || store.breathDay != null);

class _ReminderNudge extends StatefulWidget {
  const _ReminderNudge();
  @override
  State<_ReminderNudge> createState() => _ReminderNudgeState();
}

class _ReminderNudgeState extends State<_ReminderNudge> {
  bool _busy = false;

  void _close(TrainerStore store) => store
    ..answers['reminderAsked'] = true
    ..save();

  Future<void> _allow() async {
    final store = TrainerScope.of(context).store;
    setState(() => _busy = true);
    final error = await setReminder(context, true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
    _close(store);
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: AppCard(
        key: const Key('reminder_nudge'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Ic.bellRing, color: TC.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(
                      'Günlük hatırlatma ister misin?',
                      'Would you like a daily reminder?',
                    ),
                    style: TT.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                'Günde tek bir bildirim. Ayarlar\'dan istediğin zaman '
                    'kapatabilirsin.',
                'One notification a day. You can turn it off in Settings '
                    'any time.',
              ),
              style: TT.small,
            ),
            const SizedBox(height: 12),
            // Secondary on purpose: the route above keeps the one primary
            // action on Today.
            SoftButton(
              key: const Key('reminder_allow'),
              label: tr('Hatırlat', 'Remind me'),
              onPressed: _busy ? null : _allow,
            ),
            TextLink(
              tr('Şimdilik hayır', 'Not now'),
              key: const Key('reminder_skip'),
              onTap: _busy ? () {} : () => _close(store),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sentence-case section title with an optional violet link on the right.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, {this.action});
  final String title;
  final (String, VoidCallback)? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: TT.section)),
        ),
        if (action case (final label, final onTap))
          TextButton(
            key: const Key('today_see_all'),
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: TC.primary,
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.only(left: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Ic.chevronRight, size: 16),
              ],
            ),
          ),
      ],
    ),
  );
}

/// "Bu hafta N gün" with a dot per weekday, Monday first; a dot fills on a
/// day with at least one answered question.
class _WeekChip extends StatelessWidget {
  const _WeekChip({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final now = store.now;
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final active = [
      for (var i = 0; i < 7; i++)
        i < now.weekday &&
            store.activeOn(DateTime(monday.year, monday.month, monday.day + i)),
    ];
    final days = active.where((a) => a).length;
    return Semantics(
      label: tr(
        'Bu hafta $days gün çalıştın',
        days == 1
            ? 'You practised 1 day this week'
            : 'You practised $days days this week',
      ),
      excludeSemantics: true,
      child: Container(
        key: const Key('week_chip'),
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: TC.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12342553),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: TC.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Ic.target, color: TC.primary, size: 15),
            ),
            const SizedBox(width: 8),
            Text(tr('Bu hafta', 'This week'), style: TT.small),
            const SizedBox(width: 6),
            Text(
              tr('$days gün', days == 1 ? '1 day' : '$days days'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: TC.ink,
              ),
            ),
            const SizedBox(width: 8),
            for (final a in active)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: a ? TC.primaryFill : const Color(0xFFE3DFE5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A one-tap shortcut into a skill (Hızlı egzersizler row).
class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.kind,
    required this.tone,
    required this.store,
  });
  final TrainerKind kind;
  final int tone;
  final TrainerStore store;
  @override
  Widget build(BuildContext context) => AppCard(
    key: Key('quick_${kind.id}'),
    radius: 22,
    padding: const EdgeInsets.all(13),
    onTap: () => openSkill(context, kind),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneIcon(trainerIcon(kind), tone: tone),
          const SizedBox(height: 18),
          const Spacer(),
          Text(
            kind.shortTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TT.title.copyWith(fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              '${store.completedCount(kind)}/${trainerPaths[kind]!.lessonCount} ders',
              '${store.completedCount(kind)}/${trainerPaths[kind]!.lessonCount} lessons',
            ),
            style: TT.small.copyWith(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

/// The last skill worked on, with its measured path progress.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.kind, required this.store});
  final TrainerKind kind;
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final done = store.completedCount(kind);
    final total = trainerPaths[kind]!.lessonCount;
    return AppCard(
      key: const Key('today_resume'),
      padding: const EdgeInsets.all(12),
      onTap: () => openSkill(context, kind),
      child: Row(
        children: [
          ToneIcon(trainerIcon(kind), size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind.title, style: TT.title),
                Text(
                  tr(
                    'Ders ${math.min(done + 1, total)}/$total',
                    'Lesson ${math.min(done + 1, total)}/$total',
                  ),
                  style: TT.small,
                ),
                const SizedBox(height: 8),
                ProgressBar(
                  value: store.mastery(kind),
                  height: 3,
                  color: TC.primaryFill,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: TC.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Ic.chevronRight, color: TC.primary, size: 18),
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
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        button: true,
        child: InkWell(
          key: const Key('today_choir_due'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AssignmentScreen(assignmentId: assignment.id),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const ToneIcon(Ic.users, tone: 1, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(choir.name, style: TT.title.copyWith(height: 1.3)),
                        Text(assignment.title, style: TT.small),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: const ShapeDecoration(
                      color: TC.coralSoft,
                      shape: StadiumBorder(),
                    ),
                    child: Text(
                      text.dueLabel(store.now, assignment.dueAt!),
                      style: const TextStyle(
                        color: TC.coralDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Ic.chevronRight, color: TC.muted, size: 18),
                ],
              ),
            ),
          ),
        ),
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
      height: 38,
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: days > 0 ? TC.streak : TC.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0x14714817)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Ic.flame,
            size: 16,
            color: days > 0 ? const Color(0xFFE8A748) : TC.muted,
          ),
          const SizedBox(width: 4),
          Text(
            '$days',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: days > 0 ? TC.onStreak : TC.muted,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            tr('gün', days == 1 ? 'day' : 'days'),
            style: TextStyle(
              fontSize: 12,
              color: days > 0 ? TC.onStreak : TC.muted,
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
                'Emin değilsen Egzersizler sekmesindeki ses aralığı testi taslak bir öneri verir.',
            'With tenor or bass, lessons play an octave lower. '
                'If you are not sure, the range test in the Exercises tab gives a draft suggestion.',
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
    final route = routeFor(store.answers, store.dailyMinutes);
    final breathDone = store.breathedToday;
    // A route without a ready lesson is done once the guide is done.
    final lessonDone = route.lesson ? store.sessionToday : breathDone;
    final pending = route.goal?.pendingContent;
    final hasRange = store.koroRange != null;
    final due = store.dueReview;
    final lesson = next;
    final part = store.part;
    final steps = <_StepData>[
      if (route.breath)
        _StepData(
          key: 'route_breath',
          short: tr('Nefes', 'Breath'),
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
          short: tr('Tekrar', 'Review'),
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
      if (route.lesson)
        _StepData(
          key: 'route_lesson',
          short: tr('Ders', 'Lesson'),
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
          short: tr('Ses', 'Voice'),
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
    final String action;
    if (!route.lesson) {
      action = breathDone
          ? tr('Bugünlük hazırlık tamam', 'Today\'s preparation is done')
          : tr('Hazırlığa başla', 'Start preparing');
    } else if (lessonDone) {
      action = tr('Bugünlük ders tamam', 'Today\'s lesson is done');
    } else if (lesson == null) {
      action = tr('Pratik yap', 'Practise');
    } else if (breathDone || !route.breath) {
      action = tr('Derse başla', 'Start the lesson');
    } else {
      action = tr('Çalışmaya başla', 'Start practising');
    }
    final current = steps.indexWhere((s) => !s.done && s.onTap == null);
    final doneCount = steps.where((s) => s.done).length;
    final percent = steps.isEmpty
        ? 0
        : (100 * doneCount / steps.length).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          orbs: HeroOrbs.plan,
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('SANA ÖZEL · BUGÜN', 'FOR YOU · TODAY'),
                      style: TT.heroCaps,
                    ),
                  ),
                  Text(
                    tr(
                      '~${store.dailyMinutes} DK',
                      '~${store.dailyMinutes} MIN',
                    ),
                    style: TT.heroCaps,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    part == null
                        ? tr(
                            'Sesini aç,\nritmini yakala',
                            'Open your voice,\nfind your rhythm',
                          )
                        : tr(
                            '${part.title} için alan aç',
                            'Make room for your ${part.title.toLowerCase()}',
                          ),
                    style: TT.display.copyWith(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                      letterSpacing: -1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _PlanBar(
                done: [for (final s in steps) s.done],
                labels: [for (final s in steps) s.short],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        '$doneCount/${steps.length} tamamlandı',
                        '$doneCount/${steps.length} done',
                      ),
                      style: const TextStyle(
                        color: TC.heroMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '%$percent',
                    style: const TextStyle(
                      color: TC.heroMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              // The route already offers the test when it has a voice step.
              if (part == null && !(route.voiceStep && !hasRange))
                // Measured, not asked (ADR-040).
                Align(
                  alignment: Alignment.centerLeft,
                  child: _PartLink(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RangeTestScreen(),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              BigButton(
                key: const Key('today_begin'),
                label: action,
                icon: Ic.play,
                onPressed: lessonDone
                    ? null
                    : route.lesson && lesson == null
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PracticeSetupScreen(trainer: trainer),
                        ),
                      )
                    : onBegin,
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
        if (pending != null) _PendingContent(text: pending),
        const SizedBox(height: 2),
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

/// Content the learner's goal needs but that is not ready yet: said plainly,
/// never offered as a step.
class _PendingContent extends StatelessWidget {
  const _PendingContent({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AppCard(
      key: const Key('route_pending'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Ic.hourglass, color: TC.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Hazırlanıyor', 'In preparation'), style: TT.title),
                const SizedBox(height: 2),
                Text(text, style: TT.small),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// One labelled segment per route step; as many as the route has today.
class _PlanBar extends StatelessWidget {
  const _PlanBar({required this.done, required this.labels});
  final List<bool> done;
  final List<String> labels;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < done.length; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: done[i] ? TC.sun : TC.heroTrack,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: done[i] ? Colors.white : TC.heroMuted,
                    fontSize: 11,
                    fontWeight: done[i] ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _StepData {
  const _StepData({
    required this.key,
    required this.short,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.done,
    this.onTap,
  });
  final String key;

  /// The label under its segment on the plan card.
  final String short;
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
      padding: const EdgeInsets.all(13),
      onTap: data.onTap,
      child: Row(
        children: [
          data.done
              ? Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: TC.limeSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Ic.check, color: TC.green, size: 19),
                )
              : ToneIcon(data.icon, size: 38),
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
                color: TC.sun,
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
