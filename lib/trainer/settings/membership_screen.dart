import 'package:flutter/material.dart';

import '../ui/kit.dart';

enum _Plan { premium, plus }

/// Transparent membership preview. Nothing is sold yet: prices are not set,
/// there is no store product and the call to action stays disabled. Plus is
/// a real educator's written review, never AI text.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});
  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  _Plan _plan = _Plan.premium;

  @override
  Widget build(BuildContext context) {
    final premium = _plan == _Plan.premium;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Row(
              children: [
                const BackSquare(),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('ŞEFFAF ÜYELİK', style: TT.caps),
                      SizedBox(height: 2),
                      Text('Önce değeri gör', style: TT.h2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Segmented<_Plan>(
              key: const Key('membership_tabs'),
              values: _Plan.values,
              selected: _plan,
              joined: true,
              label: (p) => p == _Plan.premium ? 'Premium' : 'Plus',
              onChanged: (p) => setState(() => _plan = p),
            ),
            const SizedBox(height: 12),
            AppCard(
              key: Key('membership_${_plan.name}'),
              radius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tag(
                    premium ? 'PLANLANIYOR' : 'PİLOT · KONTENJANLI',
                    color: TC.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    premium ? 'Premium' : 'Plus · gerçek eğitimci',
                    style: TT.h2,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fiyat henüz belirlenmedi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: TC.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final f
                      in premium
                          ? const [
                              'Süreye göre kişisel günlük rota',
                              'Ayrıntılı hata tekrarı ve haftalık rapor',
                              'Konservatuvar hazırlık programları',
                            ]
                          : const [
                              'Premium’daki her şey',
                              'Ayda 1 yazılı eğitimci değerlendirmesi',
                              'Açık teslim süresi ve kaydı silme seçeneği',
                            ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            color: TC.green,
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              f,
                              style: const TextStyle(
                                fontSize: 14,
                                color: TC.ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  const BigButton(
                    key: Key('membership_cta'),
                    label: 'Henüz satışta değil',
                    onPressed: null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    premium
                        ? 'Satışa açıldığında deneme bitişi, yenileme tutarı, '
                              'iptal ve satın alımı geri yükleme satın almadan '
                              'önce görünecek. Bugün tüm çalışmalar ücretsiz.'
                        : 'Yorumu gerçek bir eğitimci yazar; yapay zekâ metni '
                              'eğitimci yorumu diye sunulmaz. Kontenjan ve '
                              'teslim süresi pilotta belirlenecek.',
                    textAlign: TextAlign.center,
                    style: TT.small.copyWith(fontSize: 12.5),
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
