import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';

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
    padding: const EdgeInsets.all(HarmoniaSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == ContentStatusKind.loading)
          const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Yükleniyor'),
          ),
        Semantics(liveRegion: true, child: Text(message)),
        if (kind == ContentStatusKind.error && onRetry != null) ...[
          const SizedBox(height: HarmoniaSpacing.sm),
          OutlinedButton(onPressed: onRetry, child: const Text('Yeniden dene')),
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
      horizontal: HarmoniaSpacing.lg,
      vertical: HarmoniaSpacing.sm,
    ),
    child: Text(
      'Yerel çalışma • Bu ekrandaki sonuçlar cihazında tutulur; sunucuya gönderilmez.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
