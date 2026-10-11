import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/harmonia_theme.dart';

/// Live input level from the recorder. The bar uses a display-only peak
/// decay; it never feeds a measurement, score or voice/pitch decision.
class InputLevelMeter extends StatefulWidget {
  const InputLevelMeter({super.key, required this.levels});
  final Stream<double> levels;
  static const floorDb = -60.0;
  @override
  State<InputLevelMeter> createState() => _InputLevelMeterState();
}

class _InputLevelMeterState extends State<InputLevelMeter> {
  StreamSubscription<double>? _sub;
  double? _db;
  double _shown = InputLevelMeter.floorDb;

  @override
  void initState() {
    super.initState();
    _sub = widget.levels.listen((db) {
      if (!mounted) return;
      setState(() {
        _db = db;
        // Display-only peak hold with 3 dB/update decay.
        _shown = db > _shown ? db : (_shown - 3).clamp(db, 0.0);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.resultColors;
    final db = _db;
    final (label, color) = db == null
        ? ('bekleniyor', colors.notMeasured)
        : db >= -3
        ? ('çok yüksek — telefondan uzaklaş', colors.incorrect)
        : db < -50
        ? ('çok düşük', colors.notMeasured)
        : ('uygun', scheme.primary);
    final fraction =
        ((_shown - InputLevelMeter.floorDb) / -InputLevelMeter.floorDb).clamp(
          0.0,
          1.0,
        );
    return Semantics(
      key: const Key('input_level_meter'),
      label: 'Giriş seviyesi: $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Giriş seviyesi: $label'),
          const SizedBox(height: HarmoniaSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(HarmoniaRadius.chip),
            child: SizedBox(
              height: 12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: scheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: fraction,
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
          Text(
            'Ses düzeyini gösterir; notanın doğru olduğunu göstermez.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
