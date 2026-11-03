import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/error_log.dart';
import '../domain/lang.dart';

/// Routes unexpected framework and platform errors into [log] (OPS-01a).
/// Debug builds still print them; release builds show a calm placeholder
/// instead of a red error screen. No crash service is attached.
void installGlobalErrorHandlers(LocalErrorLog log) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    log.record(details.exception, details.stack, ErrorOrigin.framework);
    if (kDebugMode) previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.record(error, stack, ErrorOrigin.platform);
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const AppErrorPlaceholder();
  }
}

class AppErrorPlaceholder extends StatelessWidget {
  const AppErrorPlaceholder({super.key});
  @override
  Widget build(BuildContext context) => Material(
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          tr(
            'Bu bölüm gösterilemedi. Geri dönüp yeniden deneyebilirsin; '
                'sonuçların ve kayıtların etkilenmedi.',
            'This part could not be shown. Go back and try again; '
                'your results and recordings are unaffected.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
