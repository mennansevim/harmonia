import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../domain/music.dart';
import '../koro/koro_hub.dart';
import '../koro/range_test.dart';
import '../koro/voice_count.dart';
import '../prepare/breath_screen.dart';
import '../learn/lesson_flow.dart';
import '../practice/practice_setup.dart';
import '../settings/settings_tab.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'daily_route.dart';
import '../learn/skill_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        backgroundColor: TC.canvas,
        body: IndexedStack(
          index: _tab,
          children: const [
            PlayTab(),
            KoroHub(asTab: true),
            StatsTab(),
            SettingsTab(),
          ],
        ),
        bottomNavigationBar: _NavBar(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

/// Four destinations. The voice workshop is for everyone (ADR-035); the
/// invite-only choir module will add its own entry once it exists.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'Bugün'),
      (Icons.graphic_eq_outlined, Icons.graphic_eq_rounded, 'Ses'),
      (Icons.insights_outlined, Icons.insights_rounded, 'İlerleme'),
      (Icons.tune_outlined, Icons.tune_rounded, 'Ayarlar'),
    ];
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$3,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('tab_$i'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        tapHaptic();
                        onTap(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: i == index
                              ? TC.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              i == index ? items[i].$2 : items[i].$1,
                              color: i == index ? TC.primary : TC.muted,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].$3,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: i == index
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: i == index ? TC.primary : TC.muted,
                              ),
                            ),
                          ],
                        ),
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
  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const _weekdays = [
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
            stepLabel: 'ADIM 1 / ${route.stepCount}',
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
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}'
                          .toUpperCase(),
                      style: TT.caps,
                    ),
                    const SizedBox(height: 2),
                    const Text('Bugün', style: TT.h1),
                  ],
                ),
              ),
              _StreakChip(days: store.streak),
            ],
          ),
          const SizedBox(height: 12),
          _WeekBar(store: store),
          const SizedBox(height: 16),
          _DailyRoute(
            store: store,
            trainer: focus,
            next: next,
            onBegin: _beginToday,
          ),
          const SizedBox(height: 26),
          const Text('TÜM BECERİLER', style: TT.caps),
          const SizedBox(height: 10),
          for (final k in TrainerKind.values) _SkillRow(kind: k, store: store),
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
    label: '$days günlük seri',
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
          Icon(
            Icons.wb_sunny_rounded,
            size: 18,
            color: days > 0 ? TC.onSun : TC.muted,
          ),
          const SizedBox(width: 5),
          Text(
            '$days gün',
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
        const Text('Sesin hangi aralığa yakın?', style: TT.h3),
        const SizedBox(height: 6),
        const Text(
          'Tenor ve bas seçilince dersler bir oktav pesten çalar. '
          'Emin değilsen Ses sekmesindeki ses aralığı testi taslak bir öneri verir.',
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
          'Seçme, varsayılan aralıkta çal',
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

/// This week as seven bars: filled for days with practice.
class _WeekBar extends StatelessWidget {
  const _WeekBar({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final d = monday.add(Duration(days: i));
                final active = store.activeOn(d);
                final isToday = d == today;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? TC.primary : TC.line,
                          borderRadius: BorderRadius.circular(4),
                          border: isToday && !active
                              ? Border.all(color: TC.primary, width: 1.5)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: isToday ? TC.primary : TC.muted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
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
    final lesson = next;
    final part = store.part;
    final steps = <_StepData>[
      if (route.breath)
        _StepData(
          key: 'route_breath',
          title: 'Nefes',
          subtitle:
              '${route.breathSeconds ~/ 60} dk · yönlendirmeli, mikrofonsuz',
          icon: Icons.air_rounded,
          done: breathDone,
        ),
      _StepData(
        key: 'route_lesson',
        title: lesson == null ? '${trainer.title} tamam' : lesson.title,
        subtitle: lesson == null
            ? 'Serbest pratikle devam et'
            : lesson.kind == NodeKind.intro
            ? '${trainer.shortTitle} · kısa tanıtım'
            : '${trainer.shortTitle} · dinle, söyle, ayırt et',
        icon: trainerIcon(trainer),
        done: lessonDone,
      ),
      if (route.voiceStep)
        _StepData(
          key: 'route_voice',
          title: hasRange ? 'Kaç ses duyuyorsun?' : 'Ses aralığı testi',
          subtitle: hasRange
              ? 'Ses · 2/3/4 sesli dokuyu ayırt et'
              : 'Ses · isteğe bağlı mikrofon, taslak ölçüm',
          icon: hasRange ? Icons.layers_outlined : Icons.mic_none_rounded,
          done: false,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  hasRange ? const VoiceCountScreen() : const RangeTestScreen(),
            ),
          ),
        ),
    ];
    final current = steps.indexWhere((s) => !s.done && s.onTap == null);
    final pitch = route.breath
        ? 'Nefesini hazırla, sesleri duy, istersen söyle. '
              'Sonuçta yalnız ölçülenleri görürsün.'
        : 'Kısa gün: tek bir kulak dersi. '
              'Sonuçta yalnız ölçülenleri görürsün.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 138),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroPill('~${store.dailyMinutes} DAKİKA'),
                const SizedBox(height: 11),
                Padding(
                  padding: const EdgeInsets.only(right: 90),
                  child: Text(
                    part == null
                        ? 'Günlük rotan'
                        : '${part.title} için günlük rota',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  pitch,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 14,
                    height: 1.42,
                  ),
                ),
                if (part == null) ...[
                  const SizedBox(height: 12),
                  _PartLink(onTap: () => showVoicePartSheet(context)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          key: const Key('daily_plan'),
          children: [
            for (var i = 0; i < steps.length; i++)
              _RouteStep(
                index: i + 1,
                data: steps[i],
                current: i == current && !lessonDone,
              ),
          ],
        ),
        const SizedBox(height: 6),
        BigButton(
          key: const Key('today_begin'),
          label: lessonDone
              ? 'Bugünlük ders tamam'
              : lesson == null
              ? 'Pratik yap'
              : breathDone || !route.breath
              ? 'Derse başla'
              : 'Çalışmaya başla',
          icon: Icons.arrow_forward_rounded,
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
        const SizedBox(height: 9),
        const Text(
          'Kayıtlar cihazdan çıkmaz; mikrofon adımları isteğe bağlıdır ve atlanabilir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: TC.muted, height: 1.35),
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      key: const Key('part_chip'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.mic_none_rounded, size: 17, color: Colors.white),
            SizedBox(width: 5),
            Text(
              'Ses aralığını seç',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RouteStep extends StatelessWidget {
  const _RouteStep({
    required this.index,
    required this.data,
    required this.current,
  });
  final int index;
  final _StepData data;
  final bool current;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppCard(
      key: Key(data.key),
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: data.onTap,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.done ? TC.green : TC.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: data.done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: TC.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title, style: TT.title.copyWith(fontSize: 14.5)),
                Text(data.subtitle, style: TT.small.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (current)
            const Tag('ŞİMDİ', color: TC.primary)
          else if (data.onTap != null)
            const Icon(Icons.chevron_right_rounded, color: TC.faint)
          else if (!data.done)
            Icon(data.icon, color: TC.faint, size: 20),
        ],
      ),
    ),
  );
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.kind, required this.store});
  final TrainerKind kind;
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final color = trainerColor(kind);
    final m = store.mastery(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('skill_${kind.id}'),
        padding: const EdgeInsets.all(14),
        onTap: () => openSkill(context, kind),
        child: Row(
          children: [
            TrainerBadge(color: color, icon: trainerIcon(kind), size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(kind.shortTitle, style: TT.title)),
                      Text(
                        '%${(m * 100).round()}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(kind.tagline, style: TT.small),
                  const SizedBox(height: 8),
                  ProgressBar(value: m, color: color, height: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
