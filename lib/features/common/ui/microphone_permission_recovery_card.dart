import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/resonia_theme.dart';
import '../../../application/microphone_permission_recovery.dart';
import '../../../infrastructure/permissions/permission_handler_microphone_recovery.dart';
import 'resonia_ui.dart';
import '../../../domain/lang.dart';

/// Explicit recovery UI shown only after a microphone permission denial.
///
/// Android cannot reliably distinguish every permanently-denied state with a
/// passive status read. Keeping this action behind a real denial gives users a
/// deterministic escape without requesting permission on page load.
class MicrophonePermissionRecoveryCard extends StatefulWidget {
  const MicrophonePermissionRecoveryCard({super.key, this.recovery});

  final MicrophonePermissionRecovery? recovery;

  @override
  State<MicrophonePermissionRecoveryCard> createState() =>
      _MicrophonePermissionRecoveryCardState();
}

class _MicrophonePermissionRecoveryCardState
    extends State<MicrophonePermissionRecoveryCard> {
  bool _opening = false;
  String? _status;

  Future<void> _openSettings() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _status = null;
    });
    bool opened;
    try {
      opened =
          await (widget.recovery ?? const PermissionHandlerMicrophoneRecovery())
              .openAppSettings();
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _status = opened
          ? tr(
              'Ayarlardan mikrofonu açtıktan sonra Vocalart’a dönüp yeniden dene.',
              'After allowing the microphone in Settings, come back to Vocalart and try again.',
            )
          : tr(
              'Telefon ayarları açılamadı. Ayarlar > Vocalart > Mikrofon yolunu kullanabilirsin.',
              'Phone settings could not open. Use Settings > Vocalart > Microphone.',
            );
    });
  }

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('microphone_permission_recovery'),
    child: Padding(
      padding: const EdgeInsets.all(ResoniaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Mikrofon erişimini düzelt', 'Fix microphone access'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: ResoniaSpacing.xs),
          Text(
            tr(
              'İzin penceresi yeniden görünmüyorsa mikrofonu telefon ayarlarından açabilirsin. Vocalart izni kendiliğinden değiştiremez.',
              'If the permission prompt does not appear again, you can allow the microphone in phone settings. Vocalart cannot change the permission itself.',
            ),
          ),
          const SizedBox(height: ResoniaSpacing.sm),
          ChunkyButton(
            key: const Key('microphone_open_settings'),
            onPressed: _opening ? null : () => unawaited(_openSettings()),
            tone: ChunkyTone.neutral,
            icon: Icons.settings_outlined,
            label: _opening
                ? tr('Ayarlar açılıyor…', 'Opening Settings…')
                : tr('Mikrofon ayarlarını aç', 'Open microphone settings'),
          ),
          if (_status case final status?) ...[
            const SizedBox(height: ResoniaSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(status, key: const Key('microphone_settings_status')),
            ),
          ],
        ],
      ),
    ),
  );
}
