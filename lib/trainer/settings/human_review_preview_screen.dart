import 'package:flutter/material.dart';

import '../../domain/human_review/human_review_draft.dart';
import '../../domain/lang.dart';
import '../ui/kit.dart';

/// Safe HUM-02 preview. It prepares no upload and exposes no submission path.
/// Recording, consent, entitlement, capacity and backend remain fail-closed.
class HumanReviewPreviewScreen extends StatefulWidget {
  const HumanReviewPreviewScreen({super.key});

  @override
  State<HumanReviewPreviewScreen> createState() =>
      _HumanReviewPreviewScreenState();
}

class _HumanReviewPreviewScreenState extends State<HumanReviewPreviewScreen> {
  final _question = TextEditingController();
  HumanReviewGoal _goal = HumanReviewGoal.conservatoryEar;
  HumanReviewProgressScope _progress = HumanReviewProgressScope.sevenDays;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TC.canvas,
    body: SafeArea(
      child: Column(
        children: [
          CrumbBar(
            crumb: tr('PLUS / EĞİTİMCİ YORUMU', 'PLUS / EDUCATOR REVIEW'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              children: [
                PageTitle(
                  tr('Başvurunu hazırla', 'Prepare your request'),
                  subtitle: tr(
                    'Gönderim kapalı · yerel akış önizlemesi',
                    'Submission off · local flow preview',
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  color: TC.primarySoft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ToneIcon(Ic.userRoundCheck),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(
                            'Yorumu gerçek bir eğitimci kendi yazar. Yapay zekâ '
                                'insan teslimi yerine geçmez ve kayıt AI servisine '
                                'otomatik gönderilmez.',
                            'A real educator writes the review. AI never replaces '
                                'the human delivery, and the take is not sent to an '
                                'AI service automatically.',
                          ),
                          style: TT.body.copyWith(color: TC.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _Section(
                  number: '1',
                  title: tr('Hedefini seç', 'Choose your goal'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: HumanReviewGoal.values
                        .map(
                          (goal) => ChoiceChip(
                            key: Key('human_review_goal_${goal.name}'),
                            label: Text(_goalLabel(goal)),
                            selected: _goal == goal,
                            onSelected: (_) => setState(() => _goal = goal),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  number: '2',
                  title: tr('Tek sorunu yaz', 'Write one question'),
                  child: TextField(
                    key: const Key('human_review_question'),
                    controller: _question,
                    maxLength: 400,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: tr(
                        'Örn. İkinci cümlede girişimi nasıl daha kararlı tutabilirim?',
                        'E.g. How can I make my entry into the second phrase steadier?',
                      ),
                      filled: true,
                      fillColor: TC.canvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: TC.line),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  number: '3',
                  title: tr(
                    'Paylaşacağın özeti seç',
                    'Choose the summary to share',
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: HumanReviewProgressScope.values
                        .map(
                          (scope) => ChoiceChip(
                            key: Key('human_review_progress_${scope.name}'),
                            label: Text(_progressLabel(scope)),
                            selected: _progress == scope,
                            onSelected: (_) =>
                                setState(() => _progress = scope),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(height: 12),
                _Section(
                  number: '4',
                  title: tr('Kaydı ve izni ekle', 'Add the take and consent'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr(
                          'Pilot önerisi 30–120 saniye. Süre, saklama, alıcılar '
                              've silme metni hukuk ve pilot onayı olmadan açılmaz.',
                          'The pilot proposal is 30–120 seconds. Duration, '
                              'retention, recipients and deletion terms stay off '
                              'until legal and pilot approval.',
                        ),
                        style: TT.body,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('human_review_recording_disabled'),
                        onPressed: null,
                        icon: const Icon(Ic.mic),
                        label: Text(
                          tr('Kayıt seçme kapalı', 'Take selection off'),
                        ),
                      ),
                      CheckboxListTile(
                        key: const Key('human_review_consent_disabled'),
                        value: false,
                        onChanged: null,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          tr(
                            'Amaç bazlı paylaşım onayı bekleniyor',
                            'Purpose-specific sharing consent is pending',
                          ),
                          style: TT.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                BigButton(
                  key: const Key('human_review_submit'),
                  label: tr(
                    'Gönderim henüz kapalı',
                    'Submission is not open yet',
                  ),
                  onPressed: null,
                ),
                const SizedBox(height: 10),
                Text(
                  tr(
                    'Bu ekrandaki seçimler kaydedilmez, kayıt alınmaz, hak '
                        'tüketilmez ve dışarı veri gönderilmez.',
                    'Selections on this screen are not saved; no recording, '
                        'credit use or external data transfer occurs.',
                  ),
                  textAlign: TextAlign.center,
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

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: TC.hero,
              foregroundColor: Colors.white,
              child: Text(number, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TT.section)),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

String _goalLabel(HumanReviewGoal goal) => switch (goal) {
  HumanReviewGoal.conservatoryEar => tr('Konservatuvar', 'Conservatoire'),
  HumanReviewGoal.choir => tr('Koro', 'Choir'),
  HumanReviewGoal.voice => tr('Şan', 'Voice'),
  HumanReviewGoal.instrument => tr('Çalgı', 'Instrument'),
};

String _progressLabel(HumanReviewProgressScope scope) => switch (scope) {
  HumanReviewProgressScope.none => tr('Özet yok', 'No summary'),
  HumanReviewProgressScope.sevenDays => tr('Son 7 gün', 'Last 7 days'),
  HumanReviewProgressScope.thirtyDays => tr('Son 30 gün', 'Last 30 days'),
  HumanReviewProgressScope.selectedSessions => tr(
    'Seçili oturumlar',
    'Selected sessions',
  ),
};
