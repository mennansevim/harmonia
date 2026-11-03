import 'package:flutter/material.dart';

import '../../app/theme/resonia_theme.dart';
import '../../domain/audio/visual_feedback_frame.dart';
import '../../domain/models/measurement_provenance.dart';
import '../../domain/lang.dart';

/// Aurora-style diagnostic field. Position follows signed cents; energy only
/// changes the orb size. Colors never encode success and the painter cannot
/// write back to measurement or scoring state.
class PitchFeedbackField extends StatelessWidget {
  const PitchFeedbackField({super.key, required this.frame});

  final VisualFeedbackFrame frame;

  @override
  Widget build(BuildContext context) {
    final cents = frame.signedCents;
    final liveLevelOnly =
        frame.phase != VisualFeedbackPhase.diagnostic && cents == null;
    final liveTitle = frame.phase == VisualFeedbackPhase.calibrating
        ? tr('Ortam giriş seviyesi', 'Room input level')
        : tr('Canlı giriş seviyesi', 'Live input level');
    final direction = cents == null
        ? tr('ölçülmedi', 'not measured')
        : cents.abs() < 1
        ? tr('merkeze yakın', 'near the centre')
        : cents < 0
        ? tr(
            '${cents.abs().toStringAsFixed(0)} sent pes',
            '${cents.abs().toStringAsFixed(0)} cents flat',
          )
        : tr(
            '${cents.toStringAsFixed(0)} sent tiz',
            '${cents.toStringAsFixed(0)} cents sharp',
          );
    final source = switch (frame.provenance.source) {
      MeasurementSource.microphone => tr(
        'Mikrofon kaydı',
        'Microphone recording',
      ),
      MeasurementSource.mock => tr('Test kaynağı', 'Test source'),
      MeasurementSource.synthetic => tr('Sentetik kaynak', 'Synthetic source'),
      _ => tr('Doğrulanmamış kaynak', 'Unverified source'),
    };
    final reduced = ResoniaMotion.reduced(context);
    return Semantics(
      key: const Key('pitch_feedback_field'),
      label: liveLevelOnly
          ? tr(
              '$liveTitle. Perde ölçülmüyor. Puan değil.',
              '$liveTitle. Pitch is not measured. Not a score.',
            )
          : tr(
              'Tanısal perde: $direction. Puan değil.',
              'Diagnostic pitch: $direction. Not a score.',
            ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: frame.displayOffset),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            builder: (context, offset, _) => SizedBox(
              height: 132,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _PitchFieldPainter(
                    offset: offset,
                    level: frame.level01,
                    pitchMeasured: !liveLevelOnly,
                    primary: Theme.of(context).colorScheme.primary,
                    accent: context.palette.coral,
                    line: context.palette.line,
                  ),
                ),
              ),
            ),
          ),
          Text(
            liveLevelOnly
                ? liveTitle
                : tr(
                    'Tanısal sapma: $direction',
                    'Diagnostic offset: $direction',
                  ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            liveLevelOnly
                ? tr(
                    '$source · perde ölçülmüyor · cihazlar arası kalibre değil · puan değildir',
                    '$source · pitch not measured · not calibrated across devices · not a score',
                  )
                : tr(
                    '$source · güven ve kararlılık ölçülmedi · puan değildir',
                    '$source · confidence and stability not measured · not a score',
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PitchFieldPainter extends CustomPainter {
  const _PitchFieldPainter({
    required this.offset,
    required this.level,
    required this.pitchMeasured,
    required this.primary,
    required this.accent,
    required this.line,
  });

  final double offset, level;
  final bool pitchMeasured;
  final Color primary, accent, line;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            primary.withValues(alpha: 0.12),
            accent.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    final center = Offset(size.width / 2, size.height / 2);
    if (pitchMeasured) {
      canvas.drawLine(
        Offset(20, center.dy),
        Offset(size.width - 20, center.dy),
        Paint()
          ..color = line
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        Offset(center.dx, 22),
        Offset(center.dx, size.height - 22),
        Paint()
          ..color = primary.withValues(alpha: 0.45)
          ..strokeWidth = 2,
      );
    } else {
      canvas.drawCircle(
        center,
        18 + level * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = line,
      );
    }
    final x = pitchMeasured
        ? center.dx + offset * (size.width / 2 - 40)
        : center.dx;
    final point = Offset(x, center.dy);
    final radius = 13 + level * 8;
    canvas.drawCircle(
      point,
      radius + 12,
      Paint()..color = accent.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [accent, primary],
        ).createShader(Rect.fromCircle(center: point, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_PitchFieldPainter old) =>
      old.offset != offset ||
      old.level != level ||
      old.pitchMeasured != pitchMeasured ||
      old.primary != primary ||
      old.accent != accent ||
      old.line != line;
}
