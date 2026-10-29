import 'package:flutter/material.dart';

import '../app/scope.dart';
import '../state/trainer_store.dart';
import '../ui/kit.dart';
import 'stats_tab.dart';

/// Weekly league. Live multi-player leagues need an account server that does
/// not exist yet, so this shows the learner's own weekly XP and tier only.
class RanksTab extends StatelessWidget {
  const RanksTab({super.key});

  static const tiers = [
    (0, 'Bronz', Color(0xFFCD7F32)),
    (500, 'Gümüş', Color(0xFF9CA3AF)),
    (1500, 'Altın', Color(0xFFEAB308)),
    (4000, 'Safir', Color(0xFF2563EB)),
    (8000, 'Yakut', Color(0xFFDC2626)),
    (15000, 'Elmas', Color(0xFF06B6D4)),
  ];

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          tabHeader(
            'Sıralama',
            'Haftalık ligler',
            trailing: IconButton(
              tooltip: 'Nasıl çalışır?',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEEF1F6),
              ),
              onPressed: () => _explain(context),
              icon: const Icon(Icons.help_outline_rounded, color: TC.body),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: store.leagueJoined
                ? _Joined(store: store)
                : _Join(store: store),
          ),
        ],
      ),
    );
  }

  static void _explain(BuildContext context) => showTrainerSheet<void>(
    context,
    (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ligler nasıl çalışır?',
          textAlign: TextAlign.center,
          style: TT.h3,
        ),
        const SizedBox(height: 10),
        const Text(
          'Her doğru cevap 10, her deneme 2 XP kazandırır. Hafta pazartesi sıfırlanır. '
          'Toplam XP\'n seviyeni (Bronz → Elmas) belirler.\n\n'
          'Diğer çalışanlarla canlı yarış için hesap ve sunucu gerekir; bu bağlantı henüz '
          'açılmadı. O zamana kadar yalnız kendi haftalık ilerlemen gösterilir, uydurma '
          'oyuncu listesi gösterilmez.',
          style: TT.body,
        ),
        const SizedBox(height: 16),
        BigButton(label: 'Tamam', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

class _Join extends StatelessWidget {
  const _Join({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 10),
      const _Podium(),
      const SizedBox(height: 18),
      const Text('Bir lige katıl', textAlign: TextAlign.center, style: TT.h2),
      const SizedBox(height: 8),
      const Text(
        'Haftalık hedefinle yarış. XP\'n şimdiden sayılıyor.',
        textAlign: TextAlign.center,
        style: TT.body,
      ),
      const SizedBox(height: 18),
      AppCard(
        child: Column(
          children: const [
            _Row(
              Icons.groups_outlined,
              'Seviyene göre lig (sunucu bağlanınca)',
            ),
            _Row(Icons.bolt_rounded, 'Tüm pratik XP kazandırır'),
            _Row(Icons.calendar_month_rounded, 'Her pazartesi yeni hafta'),
          ],
        ),
      ),
      const SizedBox(height: 18),
      BigButton(
        key: const Key('league_join'),
        label: 'Bu hafta katıl',
        onPressed: () {
          store.leagueJoined = true;
          store.save();
        },
      ),
      TextLink('Şimdi değil', onTap: () {}),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: TC.orangeSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: TC.orange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TT.title)),
      ],
    ),
  );
}

class _Podium extends StatelessWidget {
  const _Podium();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 140,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _step(2, 60, const Color(0xFFE2E6EE), TC.body),
        _step(1, 90, TC.orange, Colors.white),
        _step(3, 44, const Color(0xFFFCD9B6), TC.orangeDeep),
      ],
    ),
  );

  Widget _step(int n, double h, Color c, Color fg) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Text(
          '$n',
          style: TextStyle(fontWeight: FontWeight.w900, color: fg),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        width: 64,
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
    ],
  );
}

class _Joined extends StatelessWidget {
  const _Joined({required this.store});
  final TrainerStore store;
  @override
  Widget build(BuildContext context) {
    final xp = store.xp;
    var tier = RanksTab.tiers.first;
    (int, String, Color)? next;
    for (var i = 0; i < RanksTab.tiers.length; i++) {
      if (xp >= RanksTab.tiers[i].$1) {
        tier = RanksTab.tiers[i];
        next = i + 1 < RanksTab.tiers.length ? RanksTab.tiers[i + 1] : null;
      }
    }
    final progress = next == null ? 1.0 : (xp - tier.$1) / (next.$1 - tier.$1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              Icon(Icons.shield_rounded, size: 64, color: tier.$3),
              Text('${tier.$2} lig', style: TT.h2),
              const SizedBox(height: 4),
              Text('Toplam $xp XP', style: TT.small),
              const SizedBox(height: 14),
              ProgressBar(value: progress, color: tier.$3, height: 8),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? 'En üst seviyedesin'
                    : '${next.$2} için ${next.$1 - xp} XP kaldı',
                style: TT.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, color: TC.orange, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bu hafta ${store.weeklyXp()} XP', style: TT.title),
                    const Text('Pazartesi sıfırlanır', style: TT.small),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('SEVİYELER', style: TT.caps),
        const SizedBox(height: 10),
        for (final t in RanksTab.tiers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              border: t == tier ? t.$3 : null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, color: t.$3),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t.$2, style: TT.title)),
                  Text('${t.$1} XP', style: TT.small),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Diğer çalışanlarla canlı sıralama için hesap/sunucu bağlantısı gerekiyor ve henüz açık değil.',
          style: TT.small,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
