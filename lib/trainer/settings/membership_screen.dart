import 'package:flutter/material.dart';

import '../ui/kit.dart';
import '../../domain/lang.dart';
import 'human_review_preview_screen.dart';

enum _Plan { premium, plus, choir }

/// Transparent membership preview. Nothing is sold yet: prices are not set,
/// there is no store product and the call to action stays disabled. Plus is
/// a real educator's written review, never AI text. The choir module is a
/// separate product (ADR-040): it is not part of Premium or Plus.
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
    final plus = _plan == _Plan.plus;
    final choir = _plan == _Plan.choir;
    return Scaffold(
      backgroundColor: TC.canvas,
      body: SafeArea(
        child: Column(
          children: [
            CrumbBar(crumb: tr('AYARLAR / ÜYELİK', 'SETTINGS / MEMBERSHIP')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                children: [
                  PageTitle(
                    tr('Önce değeri gör', 'See the value first'),
                    subtitle: tr('Şeffaf üyelik', 'Transparent membership'),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 16),
                  Segmented<_Plan>(
                    key: const Key('membership_tabs'),
                    values: _Plan.values,
                    selected: _plan,
                    joined: true,
                    label: (p) => switch (p) {
                      _Plan.premium => 'Premium',
                      _Plan.plus => 'Plus',
                      _Plan.choir => tr('Koro', 'Choir'),
                    },
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
                          premium || choir
                              ? tr('PLANLANIYOR', 'PLANNED')
                              : tr(
                                  'PİLOT · KONTENJANLI',
                                  'PILOT · LIMITED PLACES',
                                ),
                          color: TC.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          choir
                              ? tr(
                                  'Koro modülü · ayrı',
                                  'Choir module · separate',
                                )
                              : premium
                              ? 'Premium'
                              : tr(
                                  'Plus · gerçek eğitimci',
                                  'Plus · a real educator',
                                ),
                          style: TT.h2,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('Fiyat henüz belirlenmedi', 'Price not set yet'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: TC.ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (final f
                            in choir
                                ? [
                                    tr(
                                      'Şefin ödevleri ve çok sesli eşlik kayıtları',
                                      'Your conductor\'s assignments and part-mixed accompaniment',
                                    ),
                                    tr(
                                      'Eşlikle öğrenme: dinle → partin önde → partin yok',
                                      'Learn with the choir: listen → part in front → part missing',
                                    ),
                                    tr(
                                      'Eşlikli kayıt ve şefin yazılı geri bildirimi',
                                      'Accompanied takes and your conductor\'s written feedback',
                                    ),
                                  ]
                                : premium
                                ? [
                                    tr(
                                      'Süreye göre kişisel günlük rota',
                                      'A personal daily route for your time',
                                    ),
                                    tr(
                                      'Ayrıntılı hata tekrarı ve haftalık rapor',
                                      'Detailed mistake review and a weekly report',
                                    ),
                                    tr(
                                      'Konservatuvar hazırlık programları',
                                      'Conservatoire preparation programmes',
                                    ),
                                  ]
                                : [
                                    tr(
                                      'Premium’daki her şey',
                                      'Everything in Premium',
                                    ),
                                    tr(
                                      'Ayda 1 yazılı eğitimci değerlendirmesi',
                                      'One written educator review a month',
                                    ),
                                    tr(
                                      'Açık teslim süresi ve kaydı silme seçeneği',
                                      'A clear turnaround and the option to delete your take',
                                    ),
                                  ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Ic.check, color: TC.green, size: 20),
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
                        BigButton(
                          key: Key('membership_cta'),
                          label: plus
                              ? tr('Akışı incele', 'Preview the flow')
                              : tr('Henüz satışta değil', 'Not on sale yet'),
                          onPressed: plus
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const HumanReviewPreviewScreen(),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          choir
                              ? tr(
                                  'Koro modülü Premium ve Plus\'tan ayrı satılır; '
                                      'ses, nefes ve kulak çalışması onsuz da açık kalır. '
                                      'Koro ya da korist başına fiyat henüz belirlenmedi.',
                                  'The choir module is sold apart from Premium and Plus; '
                                      'voice, breath and ear work stay open without it. '
                                      'Per-choir or per-singer pricing is not set yet.',
                                )
                              : premium
                              ? tr(
                                  'Satışa açıldığında deneme bitişi, yenileme tutarı, '
                                      'iptal ve satın alımı geri yükleme satın almadan '
                                      'önce görünecek. Bugün tüm çalışmalar ücretsiz.',
                                  'When it goes on sale, the trial end, renewal price, '
                                      'cancelling and restoring purchases will show before '
                                      'you buy. All practice is free today.',
                                )
                              : tr(
                                  'Yorumu gerçek bir eğitimci yazar; yapay zekâ metni '
                                      'eğitimci yorumu diye sunulmaz. Kontenjan ve '
                                      'teslim süresi pilotta belirlenecek.',
                                  'A real educator writes the review; AI text is never '
                                      'presented as an educator\'s review. Places and '
                                      'turnaround will be set in the pilot.',
                                ),
                          textAlign: TextAlign.center,
                          style: TT.small.copyWith(fontSize: 12.5),
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
