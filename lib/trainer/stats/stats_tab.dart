import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/trainers.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';

/// Progress tab: a choir-themed level from local XP, then the learner's own
/// evidence (no unlock gate, no leaderboard: there is no account server).
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Header('İlerleme', 'Yalnız bu cihazdaki kendi kanıtın'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LevelCard(store: store),
                const SizedBox(height: 14),
                _Unlocked(store: store),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Practice ladder derived from total XP (10 per correct answer, 2 per
/// try). Role-neutral apprentice → master names: Personal is for everyone
/// (ADR-035), not only choir singers.
const practiceLevels = [
  (0, 'Dinleyici', Icons.hearing_rounded),
  (500, 'Çırak', Icons.mic_none_rounded),
  (1500, 'Kalfa', Icons.record_voice_over_rounded),
  (4000, 'Usta', Icons.star_outline_rounded),
  (8000, 'Üstat', Icons.queue_music_rounded),
  (15000, 'Maestro', Icons.workspace_premium_outlined),
];

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final xp = store.xp;
    var i = 0;
    while (i + 1 < practiceLevels.length && xp >= practiceLevels[i + 1].$1) {
      i++;
    }
    final level = practiceLevels[i];
    final next = i + 1 < practiceLevels.length ? practiceLevels[i + 1] : null;
    final progress = next == null
        ? 1.0
        : (xp - level.$1) / (next.$1 - level.$1);
    return Container(
      key: const Key('level_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TC.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: TC.sun,
                  shape: BoxShape.circle,
                ),
                child: Icon(level.$3, color: TC.onSun),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEVİYE ${i + 1} · $xp XP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      level.$2,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              color: TC.sun,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'En üst seviyedesin · bu hafta ${store.weeklyXp()} XP'
                : '${next.$2} için ${next.$1 - xp} XP · bu hafta ${store.weeklyXp()} XP',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle, {this.trailing});
  final String title;
  final String subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TT.h1),
              const SizedBox(height: 2),
              Text(subtitle, style: TT.small),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Shared tab header.
Widget tabHeader(String title, String subtitle, {Widget? trailing}) =>
    _Header(title, subtitle, trailing: trailing);

class _Unlocked extends StatelessWidget {
  const _Unlocked({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final now = store.now;
    final today = DateTime(now.year, now.month, now.day);
    final week = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final counts = [
      for (final d in week) store.days[dayKey(d)]?.questions ?? 0,
    ];
    final peak = counts.fold(1, math.max);
    const labels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SON 7 GÜN · SORU', style: TT.caps),
              const SizedBox(height: 14),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${counts[i]}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: TC.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              height: math.max(4, 80 * counts[i] / peak),
                              decoration: BoxDecoration(
                                color: i == 6
                                    ? TC.primary
                                    : TC.primary.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              labels[week[i].weekday - 1],
                              style: const TextStyle(
                                fontSize: 11,
                                color: TC.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('BECERİLER · İLK DENEME DOĞRULUĞU', style: TT.caps),
        const SizedBox(height: 10),
        _TrainerList(store: store),
      ],
    );
  }
}

class _TrainerList extends StatelessWidget {
  const _TrainerList({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Column(
      children: [
        for (final k in TrainerKind.values)
          InkWell(
            key: Key('stats_${k.id}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrainerStatsScreen(trainer: k),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(trainerIcon(k), color: trainerColor(k)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(k.shortTitle, style: TT.title),
                            ),
                            Text(
                              _accuracy(store, k) == null
                                  ? '—'
                                  : '%${(_accuracy(store, k)! * 100).round()}',
                              style: TT.title.copyWith(color: trainerColor(k)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressBar(
                          value: _accuracy(store, k) ?? 0,
                          color: trainerColor(k),
                          height: 6,
                        ),
                        const SizedBox(height: 4),
                        Text(_bestLine(store, k), style: TT.small),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: TC.faint),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

double? _accuracy(TrainerStore store, TrainerKind k) {
  final stats = store.itemStats(k).values;
  final n = stats.fold(0, (s, i) => s + i.attempts);
  if (n == 0) return null;
  return stats.fold(0, (s, i) => s + i.correct) / n;
}

String _bestLine(TrainerStore store, TrainerKind k) {
  final reps = store.trainerReps(k);
  if (reps == 0) return 'Henüz deneme yok';
  final best = store
      .itemStats(k)
      .entries
      .where((e) => e.value.attempts >= 3)
      .fold<MapEntry<String, ItemStat>?>(
        null,
        (b, e) => b == null || e.value.accuracy! > b.value.accuracy! ? e : b,
      );
  final bestLabel = best == null
      ? ''
      : ' · en iyi ${itemLabel(k, best.key, notation: store.notation, long: true)}';
  return '$reps tekrar$bestLabel';
}

/// Per-skill evidence table: every item with first-attempt accuracy and
/// attempt count, weakest first. Local listening answers only.
class TrainerStatsScreen extends StatelessWidget {
  const TrainerStatsScreen({super.key, required this.trainer});
  final TrainerKind trainer;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final color = trainerColor(trainer);
    final stats = store.itemStats(trainer);
    final rows = [for (final id in trainer.allItems) (id, stats[id])]
      ..sort((a, b) {
        final x = a.$2?.accuracy;
        final y = b.$2?.accuracy;
        if (x == null) return y == null ? 0 : 1;
        if (y == null) return -1;
        return x.compareTo(y);
      });
    final attempts = stats.values.fold(0, (n, s) => n + s.attempts);
    final correct = stats.values.fold(0, (n, s) => n + s.correct);
    final week = store.trend(trainer, span: 7).whereType<double>().toList();
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Geri',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, color: TC.ink),
                ),
                Expanded(child: Text(trainer.title, style: TT.h3)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        _Figure(
                          attempts == 0
                              ? '—'
                              : '%${(correct * 100 / attempts).round()}',
                          'doğruluk',
                          color,
                        ),
                        _Figure('$attempts', 'cevap', TC.ink),
                        _Figure(
                          week.isEmpty ? '—' : '%${(week.last * 100).round()}',
                          'son gün',
                          TC.ink,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('ÖĞE BAZINDA · ZAYIFTAN GÜÇLÜYE', style: TT.caps),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        for (final (id, st) in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 96,
                                  child: Text(
                                    itemLabel(
                                      trainer,
                                      id,
                                      notation: store.notation,
                                      long: true,
                                    ),
                                    style: TT.title.copyWith(
                                      color: st == null ? TC.muted : TC.ink,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ProgressBar(
                                    value: st?.accuracy ?? 0,
                                    color: (st?.accuracy ?? 0) >= 0.8
                                        ? TC.green
                                        : color,
                                    height: 8,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    st == null
                                        ? '—'
                                        : '${st.correct}/${st.attempts}',
                                    textAlign: TextAlign.right,
                                    style: TT.small.copyWith(
                                      fontWeight: FontWeight.w800,
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
                  const Text(
                    'Yalnız bu cihazdaki dinleme cevapları; sınav ya da eğitimci değerlendirmesi değildir.',
                    style: TT.small,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: TT.small),
      ],
    ),
  );
}
