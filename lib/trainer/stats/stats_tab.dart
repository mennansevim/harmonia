import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../domain/trainers.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';

/// Statistics unlock after three first steps, then show real local evidence.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final steps = [
      (store.setupDone, 'Nasıl çalıştığını öğren', 'Tanıtım ekranlarını bitir'),
      (
        store.days.values.any((d) => d.sessions > 0),
        'Bir etkinlik tamamla',
        'Günlük oturum, pratik ya da ders',
      ),
      (store.streak >= 2, 'Üst üste 2 gün çalış', 'Bir seri başlat'),
    ];
    final done = steps.where((s) => s.$1).length;
    final unlocked = done == steps.length;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _Header('İstatistik', 'Gelişimini gör'),
          Padding(
            padding: const EdgeInsets.all(16),
            child: unlocked
                ? _Unlocked(store: store)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Column(
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '$done', style: TT.h2),
                                  const TextSpan(
                                    text: ' / 3 tamam',
                                    style: TT.body,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: i < done
                                            ? TC.orange
                                            : const Color(0xFFE2E6EE),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'İlerlemeni izlemek için bunları bitir',
                              style: TT.small,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('İLK ADIMLAR', style: TT.caps),
                      const SizedBox(height: 10),
                      for (var i = 0; i < steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            border:
                                !steps[i].$1 && steps.take(i).every((s) => s.$1)
                                ? TC.orange
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: steps[i].$1
                                        ? TC.orange
                                        : Colors.white,
                                    border: Border.all(
                                      color: TC.orange,
                                      width: 2,
                                    ),
                                  ),
                                  child: steps[i].$1
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: TC.orange,
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(steps[i].$2, style: TT.title),
                                      Text(steps[i].$3, style: TT.small),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (store.totalQuestions > 0) ...[
                        const SizedBox(height: 12),
                        const Text('ŞİMDİYE KADAR', style: TT.caps),
                        const SizedBox(height: 10),
                        _TrainerList(store: store),
                      ],
                    ],
                  ),
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12),
      ],
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TT.h1),
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
    const labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
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
                                    ? TC.orange
                                    : TC.orange.withValues(alpha: 0.4),
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
        const Text('EĞİTMENE GÖRE', style: TT.caps),
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
  Widget build(BuildContext context) => Column(
    children: [
      for (final k in TrainerKind.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            key: Key('stats_${k.id}'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrainerStatsScreen(trainer: k),
              ),
            ),
            child: Row(
              children: [
                TrainerBadge(
                  color: trainerColor(k),
                  icon: trainerIcon(k),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.title, style: TT.title),
                      Text(_bestLine(store, k), style: TT.small),
                    ],
                  ),
                ),
                _Ring(value: _accuracy(store, k), color: trainerColor(k)),
                const Icon(Icons.chevron_right_rounded, color: TC.faint),
              ],
            ),
          ),
        ),
    ],
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

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.color});
  final double? value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    height: 40,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: value ?? 0,
            strokeWidth: 3.5,
            color: color,
            backgroundColor: const Color(0xFFEFF2F7),
          ),
        ),
        Text(
          value == null ? '–' : '${(value! * 100).round()}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

/// Mastery trend, per-item heat map, strongest and weakest item.
class TrainerStatsScreen extends StatelessWidget {
  const TrainerStatsScreen({super.key, required this.trainer});
  final TrainerKind trainer;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    final color = trainerColor(trainer);
    final acc = _accuracy(store, trainer);
    final trend = store.trend(trainer);
    final firstHalf = trend.take(7).whereType<double>().toList();
    final secondHalf = trend.skip(7).whereType<double>().toList();
    double? avg(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    final delta = avg(firstHalf) != null && avg(secondHalf) != null
        ? ((avg(secondHalf)! - avg(firstHalf)!) * 100).round()
        : null;
    final items = store.itemStats(trainer);
    final tested = items.entries.where((e) => e.value.attempts > 0).toList()
      ..sort((a, b) => b.value.accuracy!.compareTo(a.value.accuracy!));
    String label(String id) => itemLabel(
      trainer,
      id,
      notation: store.notation,
      transposition: store.transposition,
    );
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: trainer.title,
              titleIcon: TrainerBadge(
                color: color,
                icon: trainerIcon(trainer),
                size: 32,
              ),
              shadow: true,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Doğruluk eğilimi', style: TT.title),
                            ),
                            if (delta != null)
                              Text(
                                '${delta >= 0 ? '▲' : '▼'} %${delta.abs()}',
                                style: TextStyle(
                                  color: delta >= 0
                                      ? const Color(0xFF16A34A)
                                      : TC.red,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: acc == null
                                    ? '—'
                                    : '${(acc * 100).round()}%',
                                style: TT.h1,
                              ),
                              const TextSpan(text: '  toplam', style: TT.small),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _TrendPainter(trend, color),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('2 hafta önce', style: TT.small),
                            Text('bugün', style: TT.small),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Expanded(
                              child: Text('Öğeye göre', style: TT.title),
                            ),
                            _Legend(Color(0xFF22C55E), 'Güçlü'),
                            _Legend(Color(0xFFEAB308), 'İdare'),
                            _Legend(TC.red, 'Zayıf'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final id in trainer.allItems)
                              _HeatChip(label: label(id), stat: items[id]),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Extreme(
                          caption: 'EN GÜÇLÜ',
                          color: const Color(0xFF16A34A),
                          text: tested.isEmpty
                              ? '—'
                              : '${label(tested.first.key)} · %${(tested.first.value.accuracy! * 100).round()}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Extreme(
                          caption: 'ÇALIŞILMALI',
                          color: TC.red,
                          text: tested.length < 2
                              ? '—'
                              : '${label(tested.last.key)} · %${(tested.last.value.accuracy! * 100).round()}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Bu sayılar yalnız bu cihazdaki dinleme cevaplarından hesaplanır; sınav ya da eğitimci değerlendirmesi değildir.',
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

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: TC.muted)),
      ],
    ),
  );
}

class _HeatChip extends StatelessWidget {
  const _HeatChip({required this.label, required this.stat});
  final String label;
  final ItemStat? stat;
  @override
  Widget build(BuildContext context) {
    final a = stat?.accuracy;
    final (bg, fg) = a == null
        ? (const Color(0xFFF1F3F7), TC.faint)
        : a >= 0.8
        ? (const Color(0xFFDCFCE7), const Color(0xFF15803D))
        : a >= 0.5
        ? (const Color(0xFFFEF9C3), const Color(0xFF854D0E))
        : (const Color(0xFFFEE2E2), TC.red);
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: fg,
            ),
          ),
          Text(
            a == null ? '—' : '%${(a * 100).round()}',
            style: TextStyle(fontSize: 11, color: fg),
          ),
        ],
      ),
    );
  }
}

class _Extreme extends StatelessWidget {
  const _Extreme({
    required this.caption,
    required this.color,
    required this.text,
  });
  final String caption;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(caption, style: TT.caps.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(text, style: TT.title),
      ],
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.color);
  final List<double?> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      points.add(
        Offset(size.width * i / (values.length - 1), size.height * (1 - v)),
      );
    }
    final grid = Paint()
      ..color = TC.line
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      grid,
    );
    if (points.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(text: 'Henüz veri yok', style: TT.small),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final mid = (p0.dx + p1.dx) / 2;
      path.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }
    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(points.last, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}
