import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../application/practice_preferences.dart';
import '../../application/practice_reminder.dart';
import '../../choir/app/choir_scope.dart';
import '../../choir/app/choir_tab.dart';
import '../app/scope.dart';
import '../audio/synth.dart';
import '../domain/music.dart';
import '../home/home_shell.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import 'membership_screen.dart';

const appVersionLabel = 'Sürüm 1.0 (beta)';

String? _rangeLabel(TrainerStore store) {
  final r = store.koroRange?.split('-').map(int.tryParse).toList();
  if (r == null || r.length != 2 || r.contains(null)) return null;
  return '${PitchClass.midiName(r[0]!, store.notation)} – ${PitchClass.midiName(r[1]!, store.notation)}';
}

/// Turns the daily reminder on/off and mirrors the outcome in the store.
Future<String?> setReminder(BuildContext context, bool on) async {
  final scope = TrainerScope.of(context);
  final reminders = scope.reminders;
  if (reminders == null) return 'Bildirimler bu cihazda kullanılamıyor.';
  final outcome = on
      ? await reminders.enable(PracticeReminderTime(hour: 19, minute: 0))
      : await reminders.disable();
  switch (outcome) {
    case ReminderUpdateOutcome.enabled:
      scope.store.notifications = true;
    case ReminderUpdateOutcome.disabled:
      scope.store.notifications = false;
    case ReminderUpdateOutcome.denied:
      scope.store.notifications = false;
      scope.store.save();
      return 'Bildirim izni verilmedi. iOS Ayarlar\'dan açabilirsin.';
    case ReminderUpdateOutcome.unavailable:
    case ReminderUpdateOutcome.failed:
    case ReminderUpdateOutcome.busy:
      scope.store.save();
      return 'Hatırlatıcı şu an ayarlanamadı.';
  }
  scope.store.save();
  return null;
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          tabHeader('Senin düzenin', 'Ayarlar', 'Deneyimini özelleştir'),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: TC.primarySoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Ic.userRound, color: TC.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.part == null
                                  ? 'Vocalart'
                                  : 'Çalışma aralığı: ${store.part!.title}',
                              style: TT.title,
                            ),
                            const Text(
                              'İlerlemen yalnız bu cihazda saklanıyor',
                              style: TT.small,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const _Caption('SES'),
                _Group([
                  _Item(
                    key: const Key('settings_part'),
                    icon: Ic.mic,
                    title: 'Çalışma aralığım',
                    value: store.part?.title ?? 'Seçilmedi',
                    onTap: () => showVoicePartSheet(context),
                  ),
                  _Item(
                    icon: Ic.audioLines,
                    title: 'Ses aralığım',
                    subtitle: 'Ses sekmesindeki testle ölçülür',
                    value: _rangeLabel(store) ?? 'Ölçülmedi',
                  ),
                ]),
                const _Caption('TERCİHLER'),
                _Group([
                  _Item(
                    icon: Ic.music2,
                    title: 'Nota gösterimi',
                    value: store.notation == NoteNotation.solfege
                        ? 'Solfej (Do Re Mi)'
                        : 'Harf (C D E)',
                    onTap: () => _pick<NoteNotation>(
                      context,
                      'Nota gösterimi',
                      NoteNotation.values,
                      store.notation,
                      (n) => n == NoteNotation.solfege
                          ? 'Do Re Mi (solfej)'
                          : 'C D E (harf)',
                      (n) => store
                        ..notation = n
                        ..save(),
                    ),
                  ),
                  _Item(
                    icon: Ic.arrowLeftRight,
                    title: 'Transpozisyon',
                    subtitle: 'Yalnız pratik modu',
                    value: PitchClass.name(store.transposition, store.notation),
                    onTap: () => _pick<int>(
                      context,
                      'Hangi notayı Do duyacaksın?',
                      List.generate(12, (i) => i),
                      store.transposition,
                      (i) => PitchClass.name(i, store.notation),
                      (i) => store
                        ..transposition = i
                        ..save(),
                    ),
                  ),
                  _Item(
                    icon: Ic.volume2,
                    title: 'Ses',
                    value: store.timbre.label,
                    onTap: () => _pick<Timbre>(
                      context,
                      'Enstrüman sesi',
                      Timbre.values,
                      store.timbre,
                      (t) => t.label,
                      (t) {
                        store
                          ..timbre = t
                          ..save();
                        TrainerScope.of(context).audio.timbre = t;
                      },
                    ),
                  ),
                  _Toggle(
                    icon: Ic.keyboard,
                    title: 'Klavye',
                    subtitle: 'Yalnız nota eğitimi',
                    value: store.keyboard,
                    onChanged: (v) => store
                      ..keyboard = v
                      ..save(),
                  ),
                  _Toggle(
                    icon: Ic.lightbulb,
                    title: 'Cevap ipuçları',
                    subtitle: 'Kaçırınca seçtiğini doğru cevapla karşılaştır',
                    value: store.hints,
                    onChanged: (v) => store
                      ..hints = v
                      ..save(),
                  ),
                  _Toggle(
                    key: const Key('notifications_toggle'),
                    icon: Ic.bell,
                    title: 'Bildirimler',
                    subtitle: 'Her akşam 19:00 hatırlatma',
                    value: store.notifications,
                    onChanged: (v) async {
                      final messenger = ScaffoldMessenger.of(context);
                      final error = await setReminder(context, v);
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
                  ),
                ]),
                const _Caption('ÜYELİK'),
                _Group([
                  _Item(
                    key: const Key('settings_choir'),
                    icon: Ic.users,
                    title: 'Koro modülü',
                    subtitle: 'Ödev, eşlikli kayıt, şefin geri bildirimi',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChoirTab(asTab: false),
                      ),
                    ),
                  ),
                  _Item(
                    key: const Key('settings_membership'),
                    icon: Ic.gem,
                    title: 'Premium ve Plus',
                    subtitle: 'Bugün tüm çalışmalar ücretsiz',
                    value: 'Yakında',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MembershipScreen(),
                      ),
                    ),
                  ),
                ]),
                const _Caption('HAKKINDA'),
                _Group([
                  _Item(
                    icon: Ic.circleHelp,
                    title: 'Nasıl çalışır?',
                    onTap: () => _info(
                      context,
                      'Nasıl çalışır?',
                      'Her eğitmenin bir Öğren yolu (dersler, kontrol noktaları, final) ve bir Pratik modu vardır. '
                          'Dersler yeni sesi tanıtır, hızlı kontrolle pekiştirir, sonra pratikte ölçer. '
                          'Sesler cihazda sentezlenir. Ses Atölyesi mikrofonla ses aralığı ve tekrar çalışmaları sunar; '
                          'bu ölçümler deneyseldir ve eğitimci değerlendirmesinin yerini tutmaz.',
                    ),
                  ),
                  _Item(
                    icon: Ic.shield,
                    title: 'Gizlilik',
                    onTap: () => _info(
                      context,
                      'Gizlilik',
                      'Cevapların, ilerlemen ve tercihlerin yalnız bu cihazda saklanır. Hesap, reklam ya da izleme yoktur. '
                          'Mikrofon yalnız kaydı sen başlattığında kullanılır; kayıtlar yüklenmez. '
                          'Koro kayıtların yalnız sen paylaşırsan şefe gider.',
                    ),
                  ),
                  _Item(
                    icon: Ic.fileMusic,
                    title: 'Kullanım koşulları',
                    onTap: () => _info(
                      context,
                      'Kullanım koşulları',
                      'Vocalart beta sürümündedir. İçerik taslaktır, eğitimci onayından geçmemiştir ve sınav başarısı garantisi vermez.',
                    ),
                  ),
                  _Item(
                    icon: Ic.heart,
                    title: 'Teşekkürler',
                    onTap: () => _info(
                      context,
                      'Teşekkürler',
                      'Flutter, just_audio, record ve açık kaynak topluluğuna. Tüm sesler uygulama içinde sentezlenir; lisanslı kayıt kullanılmaz.',
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _Group([
                  _Item(
                    icon: Ic.logOut,
                    title: 'Baştan başla',
                    subtitle: 'Tanıtımı yeniden göster, ilerlemeyi sıfırla',
                    onTap: () => _reset(context, store),
                  ),
                  _Item(
                    key: const Key('delete_data'),
                    icon: Ic.trash2,
                    iconColor: TC.red,
                    title: 'Verilerimi sil',
                    onTap: () => _reset(context, store),
                  ),
                ]),
                const SizedBox(height: 16),
                const Text(
                  appVersionLabel,
                  textAlign: TextAlign.center,
                  style: TT.small,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _reset(BuildContext context, TrainerStore store) async {
    final ok = await confirmDialog(
      context,
      title: 'Tüm veriler silinsin mi?',
      message:
          'Bu cihazdaki ilerleme, istatistik ve tercihler silinir. Geri alınamaz.',
      cancel: 'Vazgeç',
      confirm: 'Sil',
    );
    if (!ok || !context.mounted) return;
    final choir = ChoirScope.maybeOf(context)?.store;
    await store.resetAll();
    await choir?.clearAll();
  }

  static void _info(BuildContext context, String title, String body) =>
      showTrainerSheet<void>(
        context,
        (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, textAlign: TextAlign.center, style: TT.h3),
            const SizedBox(height: 10),
            Text(body, style: TT.body),
            const SizedBox(height: 16),
            BigButton(label: 'Tamam', onPressed: () => Navigator.pop(context)),
          ],
        ),
      );

  static void _pick<T>(
    BuildContext context,
    String title,
    List<T> values,
    T current,
    String Function(T) label,
    ValueChanged<T> onPick,
  ) => showTrainerSheet<void>(
    context,
    (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(title, textAlign: TextAlign.center, style: TT.h3),
          const SizedBox(height: 12),
          for (final v in values)
            ChoiceTile(
              label: label(v),
              selected: v == current,
              multi: false,
              color: TC.primary,
              onTap: () {
                onPick(v);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
    child: Text(text, style: TT.caps),
  );
}

class _Group extends StatelessWidget {
  const _Group(this.children);
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 60, color: Color(0xFFF0EFF8)),
          children[i],
        ],
      ],
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.iconColor = TC.body,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Color iconColor;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor == TC.red
                  ? const Color(0xFFFDE5E1)
                  : const Color(0xFFF0EFF8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TT.title),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12, color: TC.muted),
                  ),
              ],
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(color: TC.body, fontSize: 13.5),
            ),
          const Icon(Ic.chevronRight, color: TC.faint),
        ],
      ),
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EFF8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: TC.body),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TT.title),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: TC.muted),
                ),
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: TC.primary,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
