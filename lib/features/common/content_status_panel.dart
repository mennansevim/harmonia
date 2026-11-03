import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/lang.dart';

enum ContentStatusKind { loading, empty, error }

/// Presentation only: cannot clear data, retry automatically or emit a score.
/// Caller supplies a safe explanation, never a raw exception/private path.
class ContentStatusPanel extends StatelessWidget {
  const ContentStatusPanel({
    super.key,
    required this.kind,
    required this.message,
    this.onRetry,
  });
  final ContentStatusKind kind;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(ResoniaSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == ContentStatusKind.loading)
          Center(
            child: CircularProgressIndicator(
              semanticsLabel: tr('Yükleniyor', 'Loading'),
            ),
          ),
        Semantics(liveRegion: true, child: Text(message)),
        if (kind == ContentStatusKind.error && onRetry != null) ...[
          const SizedBox(height: ResoniaSpacing.sm),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(tr('Yeniden dene', 'Try again')),
          ),
        ],
      ],
    ),
  );
}

/// Scoped local-storage policy, NOT a claim about WiFi/network connectivity.
class LocalOnlyNotice extends StatelessWidget {
  const LocalOnlyNotice({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: ResoniaSpacing.lg,
      vertical: ResoniaSpacing.sm,
    ),
    child: Text(
      tr(
        'Yerel çalışma • Bu ekrandaki sonuçlar cihazında tutulur; sunucuya gönderilmez.',
        'Local practice • Results on this screen stay on your device; they are not sent to a server.',
      ),
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
