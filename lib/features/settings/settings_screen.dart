import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_channel.dart';
import '../../app/app_services.dart';
import '../../app/theme/resonia_theme.dart';
import '../../application/app_shell_controller.dart';
import '../../application/error_log.dart';
import '../../application/result_history.dart';
import '../../application/practice_reminder.dart';
import '../../application/practice_preferences.dart';
import '../common/ui/resonia_ui.dart';
import '../history/history_screen.dart';
import '../onboarding/goal_selection_screen.dart';
import 'data_transfer_screen.dart';
import 'reminder_settings_card.dart';

/// Settings, help, privacy, subscription and account — all describing only
/// what exists today. No purchase, account or upload flow is implemented.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.history,
    this.channel = AppChannel.dev,
    this.errorLog,
    this.reminders,
    this.preferences,
    this.hapticsEnabled,
    this.onPreferencesImported,
  });

  final AppShellController controller;
  final ResultHistoryRepository? history;
  final AppChannel channel;
  final LocalErrorLog? errorLog;
  final PracticeReminderCoordinator? reminders;
  final PracticePreferencesRepository? preferences;
  final ValueNotifier<bool>? hapticsEnabled;
  final VoidCallback? onPreferencesImported;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppShellController get controller => widget.controller;
  ResultHistoryRepository? get history => widget.history;
  AppChannel get channel => widget.channel;
  LocalErrorLog? get errorLog => widget.errorLog;
  bool _deleting = false;
  bool _copying = false;
  String? _copyStatus;
  bool _savingHaptics = false;
  String? _hapticsError;

  Future<void> _setHaptics(bool enabled) async {
    final preferences = widget.preferences;
    final state = widget.hapticsEnabled;
    if (_savingHaptics || preferences == null || state == null) return;
    setState(() {
      _savingHaptics = true;
      _hapticsError = null;
    });
    try {
      await preferences.saveHapticsEnabled(enabled);
      if (mounted) state.value = enabled;
    } catch (_) {
      _hapticsError = 'Titreşim ayarı kaydedilemedi. Önceki seçim korundu.';
    } finally {
      if (mounted) setState(() => _savingHaptics = false);
    }
  }

  Future<void> _copyReport(LocalErrorLog log) async {
    if (_copying) return;
    setState(() {
      _copying = true;
      _copyStatus = null;
    });
    try {
      // SystemChannels.platform is optional: Clipboard.setData can silently
      // succeed when no platform handler exists. Require an acknowledgement
      // here so an unavailable clipboard cannot produce a success message.
      await MethodChannel(
        SystemChannels.platform.name,
        SystemChannels.platform.codec,
      ).invokeMethod<void>('Clipboard.setData', <String, Object?>{
        'text': log.report(channel: channel.name),
      });
      _copyStatus = 'Hata raporu panoya kopyalandı.';
    } on PlatformException {
      _copyStatus = 'Panoya kopyalama doğrulanamadı. Yeniden deneyebilirsin.';
    } on MissingPluginException {
      _copyStatus = 'Bu cihazda pano kullanılamıyor. Yeniden deneyebilirsin.';
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  Future<void> _changeGoal(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => ListenableBuilder(
        listenable: controller,
        builder: (_, _) => GoalSelectionScreen(
          selected: controller.profile?.goal,
          saving: controller.saving,
          errorText: controller.failure == null
              ? null
              : 'Seçim kaydedilemedi. Yeniden dene.',
          onSelected: (goal) async {
            if (await controller.chooseGoal(goal) && routeContext.mounted) {
              Navigator.of(routeContext).pop();
            }
          },
        ),
      ),
    ),
  );

  Future<void> _confirmDelete(BuildContext context) async {
    if (_deleting || controller.saving) return;
    setState(() => _deleting = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bu cihazdaki profil silinsin mi?'),
          content: const Text(
            'Hedef seçimin bu cihazdan silinir ve başlangıç ekranına dönersin. Bu işlem geri alınamaz. Çalışma geçmişin silinmez; geçmiş ekranından ayrıca silebilirsin. Sunucuda saklanan bir verin yok.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              key: const Key('confirm_delete_profile'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final deleted = await controller.deleteLocalProfile();
      if (!context.mounted) return;
      if (deleted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil silinemedi. Yeniden dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: ResoniaSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(ResoniaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: text.titleMedium),
            ),
            const SizedBox(height: ResoniaSpacing.sm),
            ...children,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar ve yardım')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(ResoniaSpacing.lg),
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusPill('Misafir • bu cihazda'),
              ),
              const SizedBox(height: ResoniaSpacing.md),
              section('Hedef', [
                Text(
                  controller.profile == null
                      ? 'Hedef seçilmedi'
                      : goalTitle(controller.profile!.goal),
                ),
                const SizedBox(height: ResoniaSpacing.sm),
                ChunkyButton(
                  key: const Key('change_goal'),
                  tone: ChunkyTone.neutral,
                  onPressed: _deleting || controller.saving
                      ? null
                      : () => _changeGoal(context),
                  label: 'Hedefi değiştir',
                ),
              ]),
              section('Mikrofon yardımı', const [
                Text(
                  'Mikrofon yalnız kayıt veya ortam ölçümünü sen başlattığında açılır.',
                ),
                ExpansionTile(
                  key: Key('settings_microphone_help'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('İzin ve kulaklık rehberi'),
                  children: [
                    Text(
                      'İzin vermediysen telefonun Ayarlar > Vocalart > Mikrofon bölümünden açabilirsin. İzin vermeden de referansları dinleyebilir ve önizlemeleri görebilirsin.',
                    ),
                    SizedBox(height: ResoniaSpacing.sm),
                    Text(
                      'En güvenilir sonuç için kablolu kulaklık ve sessiz bir oda önerilir. Bluetooth kulaklıkta gecikme ölçülmediği için ritim çalışmaları desteklenmeyecek.',
                    ),
                  ],
                ),
              ]),
              if (widget.reminders case final reminders?)
                ReminderSettingsCard(coordinator: reminders),
              if (widget.preferences != null && widget.hapticsEnabled != null)
                ValueListenableBuilder<bool>(
                  valueListenable: widget.hapticsEnabled!,
                  builder: (context, enabled, _) => section(
                    'Dokunuş geri bildirimi',
                    [
                      SwitchListTile.adaptive(
                        key: const Key('haptics_toggle'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Titreşim'),
                        subtitle: const Text(
                          'Düğme, seçenek, beceri yolu ve ritim dokunuşlarında hafif geri bildirim.',
                        ),
                        value: enabled,
                        onChanged: _savingHaptics ? null : _setHaptics,
                      ),
                      if (_savingHaptics || _hapticsError != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _savingHaptics
                                ? 'Titreşim ayarı kaydediliyor…'
                                : _hapticsError!,
                            key: const Key('haptics_status'),
                          ),
                        ),
                    ],
                  ),
                ),
              section('Gizlilik ve verilerin', [
                const Text(
                  'Hedef ve sonuç özetlerin bu cihazda saklanır. Ses kayıtların sunucuya veya yapay zekâya gönderilmez.',
                ),
                const ExpansionTile(
                  key: Key('settings_privacy_help'),
                  tilePadding: EdgeInsets.zero,
                  title: Text('Ne saklanır, ne silinir?'),
                  children: [
                    Text(
                      'Ses kayıtların yalnız bu cihazda geçici olarak tutulur ve analizden sonra veya ekrandan çıkınca silinir. Hedef ve ölçülen sonuç özetleri (ses değil) kalır. Profili silmek çalışma geçmişini silmez; sonuçlarını aşağıdaki geçmiş ekranından silebilirsin.',
                    ),
                  ],
                ),
                if (AppServices.maybeOf(context)?.cleanup case final cleanup?)
                  ValueListenableBuilder(
                    valueListenable: cleanup,
                    builder: (context, report, _) =>
                        report == null || report.clean
                        ? const SizedBox.shrink()
                        : const Padding(
                            padding: EdgeInsets.only(top: ResoniaSpacing.sm),
                            child: Text(
                              'Önceki bir oturumdan kalan bazı geçici ses dosyaları silinemedi. Uygulamayı yeniden açtığında tekrar denenir; dosyalar cihaz dışına çıkmaz.',
                              key: Key('cleanup_warning'),
                            ),
                          ),
                  ),
                if (history != null)
                  ChunkyButton(
                    key: const Key('open_history_settings'),
                    tone: ChunkyTone.neutral,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryScreen(history: history!),
                      ),
                    ),
                    label: 'Çalışma geçmişini gör veya sil',
                  ),
                if (history != null)
                  Padding(
                    padding: const EdgeInsets.only(top: ResoniaSpacing.sm),
                    child: ChunkyButton(
                      key: const Key('open_data_transfer'),
                      tone: ChunkyTone.neutral,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DataTransferScreen(
                            history: history!,
                            profile: controller.profile,
                            preferences: widget.preferences,
                            onPreferencesImported: widget.onPreferencesImported,
                          ),
                        ),
                      ),
                      label: 'Verilerini dışa veya içe aktar',
                    ),
                  ),
              ]),
              section('Abonelik', const [
                Text(
                  'Şu anda satın alma veya abonelik yok; ücretli bir özellik açık değil. Premium ve gerçek eğitimci desteği (Plus) doğrulandıktan sonra fiyat ve koşullar açıkça gösterilecek.',
                  key: Key('subscription_status'),
                ),
              ]),
              section('Hesap', [
                const Text(
                  'Misafir olarak kullanıyorsun; hesap gerekmez. Hesap ve cihazlar arası eşitleme henüz yok.',
                ),
                const SizedBox(height: ResoniaSpacing.sm),
                ChunkyButton(
                  key: const Key('delete_profile'),
                  tone: ChunkyTone.neutral,
                  onPressed: _deleting || controller.saving
                      ? null
                      : () => _confirmDelete(context),
                  icon: Icons.delete_outline,
                  label: 'Bu cihazdaki profili sil',
                ),
                if (_deleting)
                  Semantics(
                    liveRegion: true,
                    child: const Text(
                      'Onay veya silme işlemi bekleniyor…',
                      key: Key('profile_delete_busy'),
                    ),
                  ),
              ]),
              if (errorLog case final log?)
                ListenableBuilder(
                  listenable: log,
                  builder: (context, _) => log.records.isEmpty
                      ? const SizedBox.shrink()
                      : section('Uygulama hataları', [
                          Text(
                            'Bu oturumda ${log.records.length + log.dropped} beklenmeyen hata yakalandı. '
                            'Rapor yalnız hata türü ve kod konumunu içerir; ses, sonuç veya yazdığın metin yoktur. '
                            'Cihazdan çıkmaz; istersen kopyalayıp destekle paylaşabilirsin.',
                            key: const Key('error_summary'),
                          ),
                          const SizedBox(height: ResoniaSpacing.sm),
                          ChunkyButton(
                            key: const Key('copy_error_report'),
                            tone: ChunkyTone.neutral,
                            onPressed: _copying ? null : () => _copyReport(log),
                            label: 'Hata raporunu kopyala',
                          ),
                          if (_copying || _copyStatus != null)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _copying ? 'Kopyalanıyor…' : _copyStatus!,
                                key: const Key('error_copy_status'),
                              ),
                            ),
                        ]),
                ),
              section('Hakkında', [
                Text(
                  'Vocalart ${channel.label.toLowerCase()}dür. Ses değerlendirmesi deterministik ölçümle yapılır; yapay zekâ puan vermez. Sınav kazanma garantisi verilmez.',
                  key: const Key('about_channel'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
