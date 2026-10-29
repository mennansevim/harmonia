import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/curriculum.dart';
import '../domain/trainers.dart';
import '../koro/koro_hub.dart';
import '../learn/lesson_flow.dart';
import '../practice/practice_setup.dart';
import '../settings/settings_tab.dart';
import '../state/trainer_store.dart';
import '../stats/ranks_tab.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'trainer_sheet.dart';

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
          children: const [PlayTab(), StatsTab(), RanksTab(), SettingsTab()],
        ),
        bottomNavigationBar: _NavBar(
          index: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.play_arrow_outlined, 'Oyna'),
      (Icons.bar_chart_rounded, 'İstatistik'),
      (Icons.emoji_events_outlined, 'Sıralama'),
      (Icons.settings_outlined, 'Ayarlar'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEDEFF3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$2,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('tab_$i'),
                      onTap: () {
                        tapHaptic();
                        onTap(i);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[i].$1,
                            color: i == index ? TC.orange : TC.muted,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: i == index ? TC.orange : TC.muted,
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
  final _gridKey = GlobalKey();

  String _greeting(DateTime now) => now.hour < 12
      ? 'Günaydın'
      : now.hour < 18
      ? 'İyi günler'
      : 'İyi akşamlar';

  Future<void> _beginToday() =>
      startTodaySession(TrainerScope.of(context).store, Navigator.of(context));

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final now = store.now;
    final focus = focusTrainer(store);
    final next = store.nextNode(focus);
    final last = TrainerKind.values
        .where((k) => k.id == store.lastTrainer)
        .firstOrNull;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(now), style: TT.small),
                            const Text('Çalışmaya hazır mısın?', style: TT.h2),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TC.orangeSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🔥 ${store.streak}',
                          key: const Key('streak_badge'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TC.orangeDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _WeekStrip(store: store),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(
              children: [
                _TodayCard(
                  done: store.sessionToday,
                  next: next,
                  minutes: store.dailyMinutes,
                  onBegin: _beginToday,
                  onExplore: () => Scrollable.ensureVisible(
                    _gridKey.currentContext!,
                    duration: const Duration(milliseconds: 400),
                  ),
                ),
                if (last != null && store.nextNode(last) != null) ...[
                  const SizedBox(height: 14),
                  _ResumeCard(kind: last),
                ],
                const SizedBox(height: 22),
                Row(
                  key: _gridKey,
                  children: const [
                    Expanded(child: Divider(color: TC.line)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('BİR BECERİ ÇALIŞ', style: TT.caps),
                    ),
                    Expanded(child: Divider(color: TC.line)),
                  ],
                ),
                const SizedBox(height: 12),
                _SkillGrid(),
                const SizedBox(height: 12),
                const _KoroCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final d = monday.add(Duration(days: i));
              final isToday = d == today;
              final active = store.activeOn(d);
              return Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active || isToday ? TC.orange : Colors.white,
                      border: Border.all(
                        color: active || isToday ? TC.orange : TC.line,
                        width: 1.5,
                      ),
                    ),
                    child: active
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : Text(
                            labels[i],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: isToday ? Colors.white : TC.muted,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: const TextStyle(fontSize: 11, color: TC.muted),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.done,
    required this.next,
    required this.minutes,
    required this.onBegin,
    required this.onExplore,
  });
  final bool done;
  final LessonNode? next;
  final int minutes;
  final VoidCallback onBegin;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final lesson = next;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8A43A), TC.orangeDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: TC.orange.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'BUGÜNÜN OTURUMU · ~$minutes DK',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (done)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '✓ Bitti',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? 'Bugünlük bitti'
                : (lesson == null
                      ? 'Tüm yollar tamam!'
                      : 'Hafıza, tekrar, sonra yeni'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            done
                ? 'Tekrar listende bir şey kalmadı. Yeni bir eğitmen keşfederek yarına önden başla.'
                : lesson == null
                ? 'Pratik modunda kulağını keskin tut ya da Koro Atölyesi\'ni dene.'
                : 'Öğren · ${lesson.title}\nPratik · yalnız yeni ses',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              key: const Key('today_begin'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: TC.orangeDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              onPressed: done || lesson == null ? onExplore : onBegin,
              icon: Icon(
                done || lesson == null
                    ? Icons.explore_outlined
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                done || lesson == null ? 'Bir eğitmen keşfet' : 'Başla',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.kind});
  final TrainerKind kind;
  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final color = trainerColor(kind);
    final m = store.mastery(kind);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TrainerBadge(color: color, icon: trainerIcon(kind), size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('KALDIĞIN YERDEN DEVAM ET', style: TT.caps),
                    Text(kind.title, style: TT.title),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ProgressBar(value: m, color: color, height: 8),
              ),
              const SizedBox(width: 8),
              Text(
                '%${(m * 100).round()}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BigButton(
            label: 'Pratiğe devam et',
            icon: Icons.play_arrow_rounded,
            color: color,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PracticeSetupScreen(trainer: kind),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = (c.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final k in TrainerKind.values)
            SizedBox(
              width: k == TrainerKind.progression ? c.maxWidth : w,
              child: AppCard(
                key: Key('skill_${k.id}'),
                onTap: () => openTrainerSheet(context, k),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrainerBadge(color: trainerColor(k), icon: trainerIcon(k)),
                    const SizedBox(height: 14),
                    Text(k.shortTitle, style: TT.title),
                    const SizedBox(height: 2),
                    Text(k.tagline, style: TT.small),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _KoroCard extends StatelessWidget {
  const _KoroCard();
  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('skill_koro'),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const KoroHub())),
    color: const Color(0xFFF1EFFE),
    child: Row(
      children: [
        const TrainerBadge(
          color: TC.indigo,
          icon: Icons.groups_rounded,
          size: 52,
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Koro Atölyesi', style: TT.title),
              SizedBox(height: 2),
              Text(
                'Ses aralığı testi, ritim, ezgi, aksak ritim ve 2/3/4 sesli çalışma',
                style: TT.small,
              ),
            ],
          ),
        ),
        const Tag('YENİ', color: TC.indigo),
      ],
    ),
  );
}
