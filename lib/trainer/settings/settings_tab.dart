import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../application/practice_preferences.dart';
import '../../application/practice_reminder.dart';
import '../../choir/app/choir_scope.dart';
import '../../choir/app/choir_tab.dart';
import '../../choir/data/choir_store.dart';
import '../app/scope.dart';
import '../audio/synth.dart';
import '../domain/music.dart';
import '../home/home_shell.dart';
import '../home/daily_route.dart';
import '../state/trainer_store.dart';
import '../stats/stats_tab.dart';
import '../ui/kit.dart';
import '../prepare/mic_check_screen.dart';
import 'membership_screen.dart';
import '../../domain/audio/mic_check.dart';
import '../../domain/lang.dart';

String get appVersionLabel => tr('Sürüm 1.0 (beta)', 'Version 1.0 (beta)');

String? _rangeLabel(TrainerStore store) {
  final r = store.koroRange?.split('-').map(int.tryParse).toList();
  if (r == null || r.length != 2 || r.contains(null)) return null;
  return '${PitchClass.midiName(r[0]!, store.notation)} – ${PitchClass.midiName(r[1]!, store.notation)}';
}

/// Turns the daily reminder on/off and mirrors the outcome in the store.
Future<String?> setReminder(BuildContext context, bool on) async {
  final scope = TrainerScope.of(context);
  final reminders = scope.reminders;
  if (reminders == null) {
    return tr(
      'Bildirimler bu cihazda kullanılamıyor.',
      'Notifications are not available on this device.',
    );
  }
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
      return tr(
        'Bildirim izni verilmedi. iOS Ayarlar\'dan açabilirsin.',
        'Notification permission was not given. You can turn it on in iOS Settings.',
      );
    case ReminderUpdateOutcome.unavailable:
    case ReminderUpdateOutcome.failed:
    case ReminderUpdateOutcome.busy:
      scope.store.save();
      return tr(
        'Hatırlatıcı şu an ayarlanamadı.',
        'The reminder could not be set right now.',
      );
  }
  scope.store.save();
  return null;
}

/// The avatar at the top right of every tab; opens Settings (DESIGN-09).
/// Shows the learner's initial once a name is set.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  static String? _initial(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TrainerScope>();
    final name = scope?.store.username.trim() ?? '';
    if (name.isEmpty) return null;
    return trCaps(name.characters.first);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr('Ayarlar', 'Settings'),
    excludeSemantics: true,
    child: InkWell(
      key: const Key('open_settings'),
      customBorder: const CircleBorder(),
      onTap: () {
        tapHaptic();
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      },
      child: SizedBox.square(
        dimension: 48,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF342553),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: TC.heroShadow, offset: Offset(0, 5)),
                  ],
                ),
                child: _initial(context) != null
                    ? Text(
                        _initial(context)!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const Icon(Ic.userRound, color: Colors.white, size: 20),
              ),
              Positioned(
                right: 0,
                bottom: 1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB9E847),
                    shape: BoxShape.circle,
                    border: Border.all(color: TC.canvas, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Settings as a page of its own, reached from [ProfileButton].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: TC.canvas,
    body: SettingsTab(pushed: true),
  );
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, this.pushed = false});

  /// Opened as a page: a back arrow above the header.
  final bool pushed;

  @override
  Widget build(BuildContext context) {
    final store = TrainerScope.of(context).store;
    return SafeArea(
      bottom: pushed,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (pushed)
            CrumbBar(
              crumb: trCaps(tr('Profil', 'Profile')),
              onBack: () => Navigator.of(context).pop(),
            ),
          tabHeader(
            tr('Senin düzenin', 'Your setup'),
            tr('Ayarlar', 'Settings'),
            tr('Deneyimini özelleştir', 'Make it yours'),
          ),
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
                                  : tr(
                                      'Çalışma aralığı: ${store.part!.title}',
                                      'Practice range: ${store.part!.title}',
                                    ),
                              style: TT.title,
                            ),
                            Text(
                              tr(
                                'İlerlemen yalnız bu cihazda saklanıyor',
                                'Your progress is kept only on this device',
                              ),
                              style: TT.small,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _Caption(tr('SES', 'VOICE')),
                _Group([
                  _Item(
                    key: const Key('settings_mic_check'),
                    icon: Ic.mic,
                    title: tr('Mikrofon testi', 'Microphone check'),
                    subtitle: tr(
                      'Ses net mi, ortam gürültülü mü?',
                      'Is your voice clear, is the room noisy?',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<MicCheckStatus?>(
                        builder: (_) => const MicCheckScreen(),
                      ),
                    ),
                  ),
                  _Item(
                    key: const Key('settings_part'),
                    icon: Ic.mic,
                    title: tr('Çalışma aralığım', 'My practice range'),
                    value: store.part?.title ?? tr('Seçilmedi', 'Not chosen'),
                    onTap: () => showVoicePartSheet(context),
                  ),
                  _Item(
                    icon: Ic.audioLines,
                    title: tr('Ses aralığım', 'My vocal range'),
                    subtitle: tr(
                      'Egzersizler sekmesindeki testle ölçülür',
                      'Measured by the test in the Exercises tab',
                    ),
                    value:
                        _rangeLabel(store) ?? tr('Ölçülmedi', 'Not measured'),
                  ),
                ]),
                _Caption(tr('TERCİHLER', 'PREFERENCES')),
                _Group([
                  // WIDE-01: the goal and minutes picked in onboarding stay
                  // editable; changing them re-plans today's route only.
                  _Item(
                    key: const Key('settings_goal'),
                    icon: Ic.target,
                    title: tr('Çalışma hedefi', 'Practice goal'),
                    value:
                        PracticeGoalInfo.fromId(store.answers['goal'])?.title ??
                        tr('Seçilmedi', 'Not chosen'),
                    onTap: () => _pick<PracticeGoal?>(
                      context,
                      tr('Çalışma hedefi', 'Practice goal'),
                      PracticeGoal.values,
                      PracticeGoalInfo.fromId(store.answers['goal']),
                      (g) => g!.title,
                      (g) => store
                        ..answers['goal'] = g!.id
                        ..save(),
                    ),
                  ),
                  _Item(
                    key: const Key('settings_minutes'),
                    icon: Ic.timer,
                    title: tr('Günlük süre', 'Daily time'),
                    value: tr(
                      '${store.dailyMinutes} dk',
                      '${store.dailyMinutes} min',
                    ),
                    onTap: () => _pick<int>(
                      context,
                      tr('Günlük süre', 'Daily time'),
                      dailyMinuteChoices,
                      store.dailyMinutes,
                      (m) => tr('$m dk', '$m min'),
                      (m) => store
                        ..dailyMinutes = m
                        ..save(),
                    ),
                  ),
                  _Item(
                    key: const Key('settings_language'),
                    icon: Ic.languages,
                    title: tr('Dil', 'Language'),
                    value: switch (store.language) {
                      'tr' => 'Türkçe',
                      'en' => 'English',
                      _ => tr('Cihaz dili', 'Device language'),
                    },
                    onTap: () => _pick<String>(
                      context,
                      tr('Dil', 'Language'),
                      const ['device', 'tr', 'en'],
                      store.language ?? 'device',
                      (l) => switch (l) {
                        'tr' => 'Türkçe',
                        'en' => 'English',
                        _ => tr('Cihaz dili', 'Device language'),
                      },
                      (l) => store
                        ..language = l == 'device' ? null : l
                        ..save(),
                    ),
                  ),
                  _Item(
                    icon: Ic.music2,
                    title: tr('Nota gösterimi', 'Note names'),
                    value: store.notation == NoteNotation.solfege
                        ? tr('Solfej (Do Re Mi)', 'Solfège (Do Re Mi)')
                        : tr('Harf (C D E)', 'Letters (C D E)'),
                    onTap: () => _pick<NoteNotation>(
                      context,
                      tr('Nota gösterimi', 'Note names'),
                      NoteNotation.values,
                      store.notation,
                      (n) => n == NoteNotation.solfege
                          ? tr('Do Re Mi (solfej)', 'Do Re Mi (solfège)')
                          : tr('C D E (harf)', 'C D E (letters)'),
                      (n) => store
                        ..notation = n
                        ..save(),
                    ),
                  ),
                  _Item(
                    icon: Ic.arrowLeftRight,
                    title: tr('Transpozisyon', 'Transposition'),
                    subtitle: tr('Yalnız pratik modu', 'Practice mode only'),
                    value: PitchClass.name(store.transposition, store.notation),
                    onTap: () => _pick<int>(
                      context,
                      tr(
                        'Hangi notayı Do duyacaksın?',
                        'Which note should sound as ${PitchClass.name(0, store.notation)}?',
                      ),
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
                    title: tr('Ses', 'Sound'),
                    value: store.timbre.label,
                    onTap: () => _pick<Timbre>(
                      context,
                      tr('Enstrüman sesi', 'Instrument sound'),
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
                    title: tr('Klavye', 'Keyboard'),
                    subtitle: tr('Yalnız nota eğitimi', 'Note training only'),
                    value: store.keyboard,
                    onChanged: (v) => store
                      ..keyboard = v
                      ..save(),
                  ),
                  _Toggle(
                    icon: Ic.lightbulb,
                    title: tr('Cevap ipuçları', 'Answer hints'),
                    subtitle: tr(
                      'Kaçırınca seçtiğini doğru cevapla karşılaştır',
                      'After a miss, compare your pick with the right answer',
                    ),
                    value: store.hints,
                    onChanged: (v) => store
                      ..hints = v
                      ..save(),
                  ),
                  _Toggle(
                    key: const Key('notifications_toggle'),
                    icon: Ic.bell,
                    title: tr('Bildirimler', 'Notifications'),
                    subtitle: tr(
                      'Her akşam 19:00 hatırlatma',
                      'A reminder at 19:00 each evening',
                    ),
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
                _Caption(tr('ÜYELİK', 'MEMBERSHIP')),
                _Group([
                  _Item(
                    key: const Key('settings_choir'),
                    icon: Ic.users,
                    title: tr('Koro modülü', 'Choir module'),
                    subtitle: tr(
                      'Ödev, eşlikli kayıt, şefin geri bildirimi',
                      'Assignments, accompanied takes, conductor feedback',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChoirTab(asTab: false),
                      ),
                    ),
                  ),
                  _Item(
                    key: const Key('settings_membership'),
                    icon: Ic.gem,
                    title: tr('Premium ve Plus', 'Premium and Plus'),
                    subtitle: tr(
                      'Bugün tüm çalışmalar ücretsiz',
                      'All practice is free today',
                    ),
                    value: tr('Yakında', 'Soon'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MembershipScreen(),
                      ),
                    ),
                  ),
                ]),
                _Caption(tr('HAKKINDA', 'ABOUT')),
                _Group([
                  _Item(
                    icon: Ic.circleHelp,
                    title: tr('Nasıl çalışır?', 'How does it work?'),
                    onTap: () => _info(
                      context,
                      tr('Nasıl çalışır?', 'How does it work?'),
                      tr(
                        'Her eğitmenin bir Öğren yolu (dersler, kontrol noktaları, final) ve bir Pratik modu vardır. '
                            'Dersler yeni sesi tanıtır, hızlı kontrolle pekiştirir, sonra pratikte ölçer. '
                            'Sesler cihazda sentezlenir. Ses Atölyesi mikrofonla ses aralığı ve tekrar çalışmaları sunar; '
                            'bu ölçümler deneyseldir ve eğitimci değerlendirmesinin yerini tutmaz.',
                        'Each trainer has a Learn path (lessons, checkpoints, a final) and a Practice mode. '
                            'Lessons introduce a new sound, reinforce it with a quick check, then measure it in practice. '
                            'Sounds are synthesised on the device. The Voice Lab offers range and repeat exercises with the microphone; '
                            'these measurements are experimental and do not replace an educator\'s assessment.',
                      ),
                    ),
                  ),
                  _Item(
                    icon: Ic.shield,
                    title: tr('Gizlilik', 'Privacy'),
                    onTap: () => _info(
                      context,
                      tr('Gizlilik', 'Privacy'),
                      tr(
                        'Cevapların, ilerlemen ve tercihlerin yalnız bu cihazda saklanır. Hesap, reklam ya da izleme yoktur. '
                            'Mikrofon yalnız kaydı sen başlattığında kullanılır; kayıtlar yüklenmez. '
                            'Koro kayıtların yalnız sen paylaşırsan şefe gider.',
                        'Your answers, progress and preferences are kept only on this device. There is no account, advertising or tracking. '
                            'The microphone is used only when you start a recording; recordings are not uploaded. '
                            'Your choir takes reach the conductor only if you share them.',
                      ),
                    ),
                  ),
                  _Item(
                    icon: Ic.fileMusic,
                    title: tr('Kullanım koşulları', 'Terms of use'),
                    onTap: () => _info(
                      context,
                      tr('Kullanım koşulları', 'Terms of use'),
                      tr(
                        'Vocalart beta sürümündedir. İçerik taslaktır, eğitimci onayından geçmemiştir ve sınav başarısı garantisi vermez.',
                        'Vocalart is in beta. The content is a draft, has not been approved by educators and does not guarantee exam success.',
                      ),
                    ),
                  ),
                  _Item(
                    icon: Ic.heart,
                    title: tr('Teşekkürler', 'Thanks'),
                    onTap: () => _info(
                      context,
                      tr('Teşekkürler', 'Thanks'),
                      tr(
                        'Flutter, just_audio, record ve açık kaynak topluluğuna. Tüm sesler uygulama içinde sentezlenir; lisanslı kayıt kullanılmaz.',
                        'To Flutter, just_audio, record and the open source community. All sounds are synthesised in the app; no licensed recordings are used.',
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _Group([
                  _Item(
                    icon: Ic.logOut,
                    title: tr('Baştan başla', 'Start over'),
                    subtitle: tr(
                      'Tanıtımı yeniden göster, ilerlemeyi sıfırla',
                      'Show the introduction again, reset progress',
                    ),
                    onTap: () => _reset(context),
                  ),
                  _Item(
                    key: const Key('delete_data'),
                    icon: Ic.trash2,
                    iconColor: TC.red,
                    title: tr('Verilerimi sil', 'Delete my data'),
                    onTap: () => _reset(context),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
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

  static Future<void> _reset(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: tr('Tüm veriler silinsin mi?', 'Delete all data?'),
      message: tr(
        'Bu cihazdaki ilerleme, sonuçlar, tercihler, hatırlatma ve koro '
            'kayıtları silinir. Geri alınamaz.',
        'Progress, results, preferences, the reminder and choir takes on '
            'this device are deleted. This cannot be undone.',
      ),
      cancel: tr('Vazgeç', 'Cancel'),
      confirm: tr('Sil', 'Delete'),
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final deleted = await _wipe(
      TrainerScope.read(context),
      ChoirScope.maybeOf(context)?.store,
    );
    // The app is back at onboarding underneath; leave this page too.
    if (deleted) {
      nav.popUntil((r) => r.isFirst);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Veriler silinemedi. Bir kısmı silinmiş olabilir, tekrar dene.',
            'The data could not be deleted. Some of it may be gone; try again.',
          ),
        ),
      ),
    );
  }

  /// The trainer store goes last: emptying it leaves this screen, so a failure
  /// stays visible here. Every step is safe to repeat on retry.
  static Future<bool> _wipe(TrainerScope scope, ChoirStore? choir) async {
    try {
      final reminder = await scope.reminders?.wipe();
      if (reminder == ReminderUpdateOutcome.failed ||
          reminder == ReminderUpdateOutcome.busy) {
        return false;
      }
      await scope.history?.clear();
      await choir?.clearAll();
      final temp = await scope.purgeTempAudio?.call();
      if (temp != null && !temp.clean) return false;
      await scope.store.resetAll();
      return true;
    } catch (_) {
      return false;
    }
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
            BigButton(
              label: tr('Tamam', 'OK'),
              onPressed: () => Navigator.pop(context),
            ),
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
          if (value != null) ...[
            const SizedBox(width: 8),
            // Shares the row with the title so a long value wraps, not overflows.
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.end,
                style: const TextStyle(color: TC.body, fontSize: 13.5),
              ),
            ),
          ],
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
  // The whole row is the target: the bare switch is under 44 points tall and
  // a screen reader would announce it without its title.
  Widget build(BuildContext context) => MergeSemantics(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () => onChanged(!value),
      child: Padding(
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
      ),
    ),
  );
}
