import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/lang.dart';
import 'kit.dart';

/// One judged pair on a [RhythmTrack]: reference beat [ref] answered by tap
/// [tap], [offsetMs] late (negative: early). A null offset is the anchor
/// (the first tap, defined as the first beat and never timed).
class RhythmLink {
  const RhythmLink(this.ref, this.tap, this.offsetMs);
  final int ref, tap;
  final int? offsetMs;
}

/// How a tap reads against the beat it answers.
enum RhythmTone { anchor, good, near, off }

/// Reference beats on top, the learner's taps or claps below, on one time
/// axis with the first tap on the first beat.
///
/// Live ([links] null): every tap appears the moment it lands, coloured by
/// its distance to the nearest beat — within [goodMs] green, within
/// [windowMs] amber, beyond coral — and a ring marks where the next beat
/// falls. Judged: the analyser's pairs are joined and labelled with their
/// offset, missed beats stay hollow and extra taps are coral.
///
/// [lit] lights the first n beats while the reference plays; null shows
/// them all.
class RhythmTrack extends StatelessWidget {
  const RhythmTrack({
    super.key,
    required this.reference,
    required this.taps,
    this.links,
    this.lit,
    this.goodMs = 50,
    this.windowMs = 160,
    this.youLabel,
  });

  final List<int> reference;
  final List<int> taps;
  final List<RhythmLink>? links;
  final int? lit;
  final int goodMs, windowMs;
  final String? youLabel;

  static RhythmTone toneOf(int? offsetMs, {int good = 50, int window = 160}) {
    if (offsetMs == null) return RhythmTone.anchor;
    final d = offsetMs.abs();
    return d <= good
        ? RhythmTone.good
        : d <= window
        ? RhythmTone.near
        : RhythmTone.off;
  }

  static Color colorOf(RhythmTone t) => switch (t) {
    RhythmTone.anchor => TC.primarySoft,
    RhythmTone.good => TC.teal,
    RhythmTone.near => TC.amber,
    RhythmTone.off => TC.coral,
  };

  /// Signed distance of each live tap to its nearest beat.
  static List<int> liveOffsets(List<int> reference, List<int> taps) => [
    for (final (i, t) in taps.indexed)
      if (i == 0)
        0
      else
        reference
            .map((r) => t - r)
            .reduce((a, b) => a.abs() <= b.abs() ? a : b),
  ];

  @override
  Widget build(BuildContext context) {
    final judged = links;
    final good = judged?.where((l) => l.offsetMs != null).length ?? 0;
    return Semantics(
      label: judged == null
          ? tr(
              'Referans ${reference.length} vuruş, sen ${taps.length} vuruş',
              'Reference ${reference.length} beats, you ${taps.length} beats',
            )
          : tr(
              '${reference.length} vuruşun ${good + 1} tanesi eşleşti',
              '${good + 1} of ${reference.length} beats matched',
            ),
      child: ExcludeSemantics(
        child: SizedBox(
          key: const Key('rhythm_track'),
          height: 150,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrackPainter(
              base: DefaultTextStyle.of(context).style,
              reference: reference,
              taps: taps,
              links: links,
              lit: lit,
              goodMs: goodMs,
              windowMs: windowMs,
              youLabel: youLabel ?? tr('SEN', 'YOU'),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.base,
    required this.reference,
    required this.taps,
    required this.links,
    required this.lit,
    required this.goodMs,
    required this.windowMs,
    required this.youLabel,
  });

  final TextStyle base;
  final List<int> reference, taps;
  final List<RhythmLink>? links;
  final int? lit;
  final int goodMs, windowMs;
  final String youLabel;

  void _text(Canvas c, String s, Offset at, Color colour, {bool bold = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: base.merge(
          TT.small.copyWith(
            fontSize: 11,
            height: 1.1,
            color: colour,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: bold ? 1.2 : 0,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    p.paint(c, at - Offset(p.width / 2, p.height / 2));
  }

  void _dot(Canvas c, Offset at, Color fill, {double r = 8, bool ink = true}) {
    c.drawCircle(at, r, Paint()..color = fill);
    if (ink) {
      c.drawCircle(
        at,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = TC.ink,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (reference.isEmpty) return;
    final end =
        math.max(reference.last, taps.isEmpty ? 0 : taps.last) +
        math.max(150, (reference.last * 0.06).round());
    const left = 14.0;
    final w = size.width - left * 2;
    double x(int ms) => left + w * ms / end;
    const yRef = 34.0, yYou = 112.0;

    _text(
      canvas,
      tr('REFERANS', 'REFERENCE'),
      Offset(size.width / 2, 9),
      TC.muted,
      bold: true,
    );
    _text(
      canvas,
      youLabel,
      Offset(size.width / 2, size.height - 9),
      TC.muted,
      bold: true,
    );

    final track = Paint()
      ..color = TC.line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, yRef), Offset(left + w, yRef), track);
    canvas.drawLine(Offset(left, yYou), Offset(left + w, yYou), track);

    // Where each beat should land on your line: faint dotted guides.
    final guide = Paint()
      ..color = TC.primary.withValues(alpha: 0.14)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final r in reference) {
      for (var y = yRef + 12; y < yYou - 8; y += 7) {
        canvas.drawLine(Offset(x(r), y), Offset(x(r), y + 2.5), guide);
      }
    }

    final judged = links;
    final tones = <int, RhythmTone>{};
    final matchedRef = <int>{};
    if (judged != null) {
      for (final l in judged) {
        matchedRef.add(l.ref);
        final tone = RhythmTrack.toneOf(
          l.offsetMs,
          good: goodMs,
          window: windowMs,
        );
        tones[l.tap] = tone;
        final a = Offset(x(reference[l.ref]), yRef + 9);
        final b = Offset(x(taps[l.tap]), yYou - 9);
        final colour = l.offsetMs == null
            ? TC.faint
            : RhythmTrack.colorOf(tone);
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = colour
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
        final off = l.offsetMs;
        if (off != null && off.abs() > 25) {
          _text(
            canvas,
            '${off > 0 ? '+' : ''}$off',
            (a + b) / 2 + const Offset(17, 0),
            tone == RhythmTone.good ? TC.green : colour,
          );
        }
      }
    } else {
      final offsets = RhythmTrack.liveOffsets(reference, taps);
      for (var i = 0; i < taps.length; i++) {
        final tone = i == 0
            ? RhythmTone.anchor
            : RhythmTrack.toneOf(offsets[i], good: goodMs, window: windowMs);
        tones[i] = tone;
        if (i == 0 || tone == RhythmTone.off) continue;
        // A short tick toward the beat it answers.
        final r = taps[i] - offsets[i];
        canvas.drawLine(
          Offset(x(r), yYou - 30),
          Offset(x(taps[i]), yYou - 10),
          Paint()
            ..color = RhythmTrack.colorOf(tone).withValues(alpha: 0.85)
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Reference beats.
    for (var i = 0; i < reference.length; i++) {
      final c = Offset(x(reference[i]), yRef);
      final on = lit == null || i < lit!;
      final missed = judged != null && !matchedRef.contains(i);
      if (missed) {
        _dot(canvas, c, TC.card, ink: false);
        canvas.drawCircle(
          c,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = TC.coral,
        );
      } else if (on) {
        final last = lit != null && i == lit! - 1;
        _dot(canvas, c, TC.koro, r: last ? 10 : 8, ink: false);
      } else {
        _dot(canvas, c, TC.primarySoft, ink: false);
        canvas.drawCircle(
          c,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = TC.primary.withValues(alpha: 0.35),
        );
      }
    }

    // Next beat to tap, live only.
    if (judged == null && taps.isNotEmpty && taps.length < reference.length) {
      final at = Offset(x(reference[taps.length]), yYou);
      canvas.drawCircle(
        at,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = TC.primary.withValues(alpha: 0.45),
      );
    }

    // Your taps; the newest one a touch larger.
    for (var i = 0; i < taps.length; i++) {
      final tone = tones[i] ?? RhythmTone.off;
      final fill = judged != null && !tones.containsKey(i)
          ? TC.coral
          : tone == RhythmTone.anchor
          ? TC.sun
          : RhythmTrack.colorOf(tone);
      final newest = judged == null && i == taps.length - 1;
      _dot(canvas, Offset(x(taps[i]), yYou), fill, r: newest ? 9.5 : 8);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => true;
}
