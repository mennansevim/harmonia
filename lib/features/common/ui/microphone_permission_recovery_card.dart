import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/resonia_theme.dart';
import '../../../application/microphone_permission_recovery.dart';
import '../../../infrastructure/permissions/permission_handler_microphone_recovery.dart';
import 'resonia_ui.dart';

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
          ? 'Ayarlardan mikrofonu açtıktan sonra Resonia’ya dönüp yeniden dene.'
          : 'Telefon ayarları açılamadı. Ayarlar > Resonia > Mikrofon yolunu kullanabilirsin.';
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
            'Mikrofon erişimini düzelt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: ResoniaSpacing.xs),
          const Text(
            'İzin penceresi yeniden görünmüyorsa mikrofonu telefon ayarlarından açabilirsin. Resonia izni kendiliğinden değiştiremez.',
          ),
          const SizedBox(height: ResoniaSpacing.sm),
          ChunkyButton(
            key: const Key('microphone_open_settings'),
            onPressed: _opening ? null : () => unawaited(_openSettings()),
            tone: ChunkyTone.neutral,
            icon: Icons.settings_outlined,
            label: _opening ? 'Ayarlar açılıyor…' : 'Mikrofon ayarlarını aç',
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
