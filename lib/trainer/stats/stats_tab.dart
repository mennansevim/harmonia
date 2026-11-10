import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/music.dart';
import '../domain/trainers.dart';
import '../koro/range_test.dart';
import '../learn/skill_screen.dart';
import '../state/trainer_store.dart';
import '../settings/settings_tab.dart';
import '../ui/kit.dart';
import '../ui/range_dial.dart';
import '../../domain/lang.dart';

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
          _Header(
            tr('Sesinin haritası', 'Map of your voice'),
            tr('Gelişim', 'Progress'),
            tr(
              'Yalnız bu cihazdaki kendi kanıtın',
              'Only your own evidence, on this device',
            ),
            const ProfileButton(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LevelCard(store: store),
                const SizedBox(height: 14),
                _Unlocked(store: store),
                const SizedBox(height: 20),
                Text(tr('Ses aralığı', 'Vocal range'), style: TT.section),
                const SizedBox(height: 10),
                _RangeCard(store: store),
                if (_suggestion(store) case final k?) ...[
                  const SizedBox(height: 20),
                  Text(
                    tr('Sana önerilen', 'Suggested for you'),
                    style: TT.section,
                  ),
                  const SizedBox(height: 10),
                  _SuggestionCard(store: store, kind: k),
                ],
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
List<(int, String, IconData)> get practiceLevels => [
  (0, tr('Dinleyici', 'Listener'), Ic.ear),
  (500, tr('Çırak', 'Apprentice'), Ic.mic),
  (1500, tr('Kalfa', 'Journeyman'), Ic.speech),
  (4000, tr('Usta', 'Master'), Ic.star),
  (8000, tr('Üstat', 'Virtuoso'), Ic.fileMusic),
  (15000, 'Maestro', Ic.crown),
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
    return HeroCard(
      key: const Key('level_card'),
      orbs: HeroOrbs.level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'PRATİK SEVİYESİ ${i + 1} · $xp XP',
                        'PRACTICE LEVEL ${i + 1} · $xp XP',
                      ),
                      style: TT.heroCaps,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      level.$2,
                      style: TT.display.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: TC.sun,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(level.$3, color: TC.hero, size: 26),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressBar(
            value: progress,
            color: TC.sun,
            height: 6,
            track: TC.heroTrack,
          ),
          const SizedBox(height: 10),
          Text(
            next == null
                ? tr(
                    'En üst seviyedesin · bu hafta ${store.weeklyXp()} XP',
                    'You are at the top level · ${store.weeklyXp()} XP this week',
                  )
                : tr(
                    '${next.$2} için ${next.$1 - xp} XP · bu hafta ${store.weeklyXp()} XP',
                    '${next.$1 - xp} XP to ${next.$2} · ${store.weeklyXp()} XP this week',
                  ),
            style: const TextStyle(
              color: TC.heroMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          // WIDE-03: the ladder counts practice, not ability.
          Text(
            tr(
              'Ne kadar çalıştığını gösterir; ses ya da kulak becerisi '
                  'ölçümü değildir.',
              'Shows how much you practised; it does not measure voice or '
                  'ear skill.',
            ),
            key: const Key('level_scope'),
            style: const TextStyle(
              color: TC.heroMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroFigure(
                value: '${store.totalQuestions}',
                label: tr('soru', 'questions'),
              ),
              const SizedBox(width: 10),
              _HeroFigure(
                value: '${store.activeDayCount}',
                label: tr('aktif gün', 'active days'),
              ),
              const SizedBox(width: 10),
              _HeroFigure(
                value: '${store.streak}',
                label: tr('gün seri', 'day streak'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A counted figure on the dark level card (questions, days — no minutes:
/// practice time is not measured).
class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: TC.heroTile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: TC.heroMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

/// The last range-test result on a C2–C6 strip, always marked as a draft;
/// an honest empty state when it was never measured.
class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.store});
  final TrainerStore store;

  @override
  Widget build(BuildContext context) {
    final parts = store.koroRange?.split('-').map(int.tryParse).toList();
    final range =
        parts != null && parts.length == 2 && parts.every((m) => m != null)
        ? (parts[0]!, parts[1]!)
        : null;
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RangeTestScreen()));
    if (range == null) {
      return AppCard(
        key: const Key('stats_range'),
        onTap: open,
        child: Row(
          children: [
            const Icon(Ic.audioLines, color: TC.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Ölçülmedi', 'Not measured'), style: TT.title),
                  Text(
                    tr(
                      'Egzersizler sekmesindeki deneysel testle ölçebilirsin',
                      'You can measure it with the experimental test in Exercises',
                    ),
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
    final (lo, hi) = range;
    String name(int m) => PitchClass.midiName(m, store.notation);
    return AppCard(
      key: const Key('stats_range'),
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${name(lo)} – ${name(hi)}', style: TT.h3)),
              Tag(tr('TASLAK ÖLÇÜM', 'DRAFT MEASUREMENT'), color: TC.koro),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: RangeDial(
              low: lo,
              high: hi,
              notation: store.notation,
              size: 220,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('${hi - lo} yarım ses', '${hi - lo} semitones'),
                    style: TT.title,
                  ),
                  if (store.part case final part?)
                    Text(part.title, style: TT.small),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'Deneysel aralık testinin son sonucu; doğrulanmış ses aralığı değildir.',
              'Last result of the experimental range test; not a validated range.',
            ),
            style: TT.small,
          ),
        ],
      ),
    );
  }
}

/// Skill with the lowest first-try accuracy among those with at least
/// 10 answers; null until there is enough evidence.
TrainerKind? _suggestion(TrainerStore store) {
  TrainerKind? pick;
  double? low;
  for (final k in TrainerKind.values) {
    final n = store.itemStats(k).values.fold(0, (s, i) => s + i.attempts);
    final a = _accuracy(store, k);
    if (n < 10 || a == null) continue;
    if (low == null || a < low) {
      low = a;
      pick = k;
    }
  }
  return pick;
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.store, required this.kind});
  final TrainerStore store;
  final TrainerKind kind;
  @override
  Widget build(BuildContext context) => AppCard(
    key: const Key('stats_suggest'),
    color: TC.primarySoft,
    onTap: () => openSkill(context, kind),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: TC.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(trainerIcon(kind), color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('${kind.shortTitle} çalış', 'Practise ${kind.shortTitle}'),
                style: TT.title,
              ),
              Text(
                tr(
                  'İlk deneme doğruluğun en düşük burada · '
                      '${percent(_accuracy(store, kind)!)}',
                  'Your lowest first-try accuracy · '
                      '${percent(_accuracy(store, kind)!)}',
                ),
                style: TT.small.copyWith(color: TC.body),
              ),
            ],
          ),
        ),
        const Icon(Ic.chevronRight, color: TC.primary),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.eyebrow, this.title, this.subtitle, this.trailing);
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trCaps(eyebrow), style: TT.crumb),
              const SizedBox(height: 6),
              Semantics(header: true, child: Text(title, style: TT.h1)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TT.small),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    ),
  );
}

/// Shared tab header: a violet eyebrow, the tab's title, one muted line and
/// an optional widget top right (the profile button on tabs).
Widget tabHeader(
  String eyebrow,
  String title,
  String subtitle, {
  Widget? trailing,
}) => _Header(eyebrow, title, subtitle, trailing);

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
    final labels = Lang.en
        ? const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
        : const ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Son 7 gün · soru', 'Last 7 days · questions'),
                style: TT.section.copyWith(fontSize: 14),
              ),
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
                                    ? TC.primaryFill
                                    : const Color(0xFFDCD1F4),
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
        Row(
          children: [
            // Tap answers in listening lessons; not a voice measure.
            Expanded(
              child: Text(
                tr('Dinleme çalışmaları', 'Listening practice'),
                style: TT.section,
              ),
            ),
            Text(
              tr('İlk deneme doğruluğu', 'First-try accuracy'),
              style: TT.small,
            ),
          ],
        ),
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
                                  : percent(_accuracy(store, k)!),
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
                  const Icon(Ic.chevronRight, color: TC.faint),
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
  if (reps == 0) return tr('Henüz deneme yok', 'No attempts yet');
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
      : tr(' · en iyi ', ' · best ') +
            itemLabel(k, best.key, notation: store.notation, long: true);
  return tr('$reps tekrar$bestLabel', '$reps reps$bestLabel');
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
        child: Column(
          children: [
            CrumbBar(crumb: tr('İLERLEME / BECERİ', 'PROGRESS / SKILL')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                children: [
                  PageTitle(trainer.title),
                  const SizedBox(height: 26),
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppCard(
                          child: Row(
                            children: [
                              _Figure(
                                attempts == 0
                                    ? '—'
                                    : percent(correct / attempts),
                                tr('doğruluk', 'accuracy'),
                                color,
                              ),
                              _Figure(
                                '$attempts',
                                tr('cevap', 'answers'),
                                TC.ink,
                              ),
                              _Figure(
                                week.isEmpty ? '—' : percent(week.last),
                                tr('son gün', 'last day'),
                                TC.ink,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr(
                            'ÖĞE BAZINDA · ZAYIFTAN GÜÇLÜYE',
                            'BY ITEM · WEAKEST TO STRONGEST',
                          ),
                          style: TT.caps,
                        ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                                            color: st == null
                                                ? TC.muted
                                                : TC.ink,
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
                        Text(
                          tr(
                            'Yalnız bu cihazdaki dinleme cevapları; sınav ya da eğitimci değerlendirmesi değildir.',
                            'Listening answers on this device only; not an exam or an educator\'s assessment.',
                          ),
                          style: TT.small,
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
