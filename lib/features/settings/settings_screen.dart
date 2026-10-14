import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_channel.dart';
import '../../app/app_services.dart';
import '../../app/theme/harmonia_theme.dart';
import '../../application/app_shell_controller.dart';
import '../../application/error_log.dart';
import '../../application/result_history.dart';
import '../history/history_screen.dart';
import '../onboarding/goal_selection_screen.dart';
import 'data_transfer_screen.dart';

/// Settings, help, privacy, subscription and account — all describing only
/// what exists today. No purchase, account or upload flow is implemented.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.history,
    this.channel = AppChannel.dev,
    this.errorLog,
  });

  final AppShellController controller;
  final ResultHistoryRepository? history;
  final AppChannel channel;
  final LocalErrorLog? errorLog;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bu cihazdaki profil silinsin mi?'),
        content: const Text(
          'Hedef seçimin bu cihazdan silinir ve başlangıç ekranına dönersin. Bu işlem geri alınamaz. Sunucuda saklanan bir verin yok.',
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
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: HarmoniaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: HarmoniaSpacing.sm),
          ...children,
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar ve yardım')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(HarmoniaSpacing.lg),
            children: [
              section('Hedef', [
                Text(
                  controller.profile == null
                      ? 'Hedef seçilmedi'
                      : goalTitle(controller.profile!.goal),
                ),
                TextButton(
                  key: const Key('change_goal'),
                  onPressed: () => _changeGoal(context),
                  child: const Text('Hedefi değiştir'),
                ),
              ]),
              section('Mikrofon yardımı', const [
                Text(
                  'Mikrofon yalnız kayıt veya ortam ölçümünü başlattığında açılır. İzin vermediysen telefonun Ayarlar > Harmonia > Mikrofon bölümünden açabilirsin. İzin vermeden de referansları dinleyebilir ve önizlemeleri görebilirsin.',
                ),
                SizedBox(height: HarmoniaSpacing.sm),
                Text(
                  'En güvenilir sonuç için kablolu kulaklık ve sessiz bir oda önerilir. Bluetooth kulaklıkta gecikme ölçülmediği için ritim çalışmaları desteklenmeyecek.',
                ),
              ]),
              section('Gizlilik ve verilerin', [
                const Text(
                  'Ses kayıtların yalnız bu cihazda geçici olarak tutulur ve analizden sonra veya ekrandan çıkınca silinir. Hiçbir ses kaydı sunucuya, yapay zekâya veya analiz servisine gönderilmez. Hedef seçimin ve ölçülen çalışma sonuçların (ses değil, sayısal özet) bu cihazda saklanır.',
                ),
                if (AppServices.maybeOf(context)?.cleanup case final cleanup?)
                  ValueListenableBuilder(
                    valueListenable: cleanup,
                    builder: (context, report, _) =>
                        report == null || report.clean
                        ? const SizedBox.shrink()
                        : const Padding(
                            padding: EdgeInsets.only(top: HarmoniaSpacing.sm),
                            child: Text(
                              'Önceki bir oturumdan kalan bazı geçici ses dosyaları silinemedi. Uygulamayı yeniden açtığında tekrar denenir; dosyalar cihaz dışına çıkmaz.',
                              key: Key('cleanup_warning'),
                            ),
                          ),
                  ),
                if (history != null)
                  TextButton(
                    key: const Key('open_history_settings'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HistoryScreen(history: history!),
                      ),
                    ),
                    child: const Text('Çalışma geçmişini gör veya sil'),
                  ),
                if (history != null)
                  TextButton(
                    key: const Key('open_data_transfer'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DataTransferScreen(
                          history: history!,
                          profile: controller.profile,
                        ),
                      ),
                    ),
                    child: const Text('Verilerini dışa veya içe aktar'),
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
                const SizedBox(height: HarmoniaSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('delete_profile'),
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Bu cihazdaki profili sil'),
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
                          TextButton(
                            key: const Key('copy_error_report'),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(
                                  text: log.report(channel: channel.name),
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Hata raporu panoya kopyalandı.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text('Hata raporunu kopyala'),
                          ),
                        ]),
                ),
              section('Hakkında', [
                Text(
                  'Harmonia ${channel.label.toLowerCase()}dür. Ses değerlendirmesi deterministik ölçümle yapılır; yapay zekâ puan vermez. Sınav kazanma garantisi verilmez.',
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
